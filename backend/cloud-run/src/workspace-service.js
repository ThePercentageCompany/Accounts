import { opaque, digest, challenge } from './crypto.js';
import { ApiError, requireThat } from './errors.js';
import { publicCompany } from './service.js';
import { FOLDERS, SCHEMA_VERSION } from './company-schema.js';
import { FOLDER_MIME, SHEET_MIME } from './google-workspace.js';
import { ReconnectRequired } from './google-connection.js';

const operation = (companyId, kind) => digest(`workspace-v1:${companyId}:${kind}`);
const isToken = value => typeof value === 'string' && /^[A-Za-z0-9_-]{43}$/.test(value);
export class WorkspaceService {
  constructor({ accounts, connection, vault, google, queue, now = Date.now }) {
    Object.assign(this, { accounts, connection, vault, google, queue, now });
    this.registry = accounts.registry;
  }
  async startConnection(token, companyId) {
    const stateToken = opaque(), binding = opaque(), nonce = opaque(), verifier = opaque(), attempt = opaque();
    const owner = await this.registry.transact(state => {
      const owner = this.accounts.companyOwner(state, token, companyId);
      requireThat(Object.keys(state.oauth).length < 1000, 429, 'SIGN_IN_BUSY', 'Please try connecting later.');
      state.companies[companyId].connectionAttempt = attempt;
      state.oauth[digest(stateToken)] = { kind: 'connection', companyId, ownerId: owner.id,
        googleSub: owner.googleSub, sessionHash: digest(token), attempt, nonce, verifier,
        bindingHash: digest(binding), expiresAt: this.now() + this.accounts.config.oauthMs };
      return owner;
    });
    return { binding, authorizationUrl: this.connection.authorizationUrl({ state: stateToken,
      nonce, challenge: challenge(verifier), email: owner.email }) };
  }
  async finishConnection(token, stateToken, binding, code) {
    requireThat(isToken(stateToken) && isToken(binding) && typeof code === 'string' && code.length > 0 && code.length <= 4096,
      401, 'OAUTH_STATE_INVALID', 'Start Google connection again.');
    const tx = await this.registry.transact(state => {
      const tx = state.oauth[digest(stateToken)];
      requireThat(tx?.kind === 'connection' && tx.expiresAt > this.now() && tx.bindingHash === digest(binding) &&
        isToken(token) && tx.sessionHash === digest(token), 401, 'OAUTH_STATE_INVALID', 'Google connection expired or was already used.');
      const owner = this.accounts.companyOwner(state, token, tx.companyId);
      requireThat(owner.id === tx.ownerId && state.companies[tx.companyId].connectionAttempt === tx.attempt,
        409, 'CONNECTION_SUPERSEDED', 'A newer Google connection was started.');
      delete state.oauth[digest(stateToken)];
      return tx;
    });
    const grant = await this.connection.exchange(code, tx);
    const ciphertext = await this.vault.encrypt(grant.refreshToken, tx.ownerId, tx.companyId);
    const company = await this.registry.transact(state => {
      this.accounts.companyOwner(state, token, tx.companyId);
      const c = state.companies[tx.companyId];
      requireThat(c.connectionAttempt === tx.attempt, 409, 'CONNECTION_SUPERSEDED', 'A newer Google connection was started.');
      c.connection = { ownerId: tx.ownerId, googleSub: grant.sub, ciphertext, scopes: grant.scopes,
        version: (c.connection?.version || 0) + 1, connectedAt: this.now() };
      delete c.lease;
      c.verifiedResources = {};
      this.transition(c, 'GOOGLE_CONNECTED');
      return structuredClone(c);
    });
    // Await durable enqueue before responding. If delivery fails, /setup/retry
    // re-enqueues the saved connection without a second OAuth exchange.
    await this.queue.enqueue(company.id, company.version);
    return publicCompany(company);
  }
  async retry(token, companyId) {
    const { state } = await this.registry.read();
    this.accounts.companyOwner(state, token, companyId);
    const c = state.companies[companyId];
    requireThat(c.connection && c.stage !== 'RECONNECT_REQUIRED', 409, 'RECONNECT_REQUIRED', 'Connect or reconnect Google to continue.');
    if (c.stage !== 'READY') await this.queue.enqueue(c.id, c.version, opaque());
    return publicCompany(c);
  }
  async withGoogle(companyId, action) {
    const { state } = await this.registry.read();
    const c = state.companies[companyId];
    requireThat(c && !c.deleted && c.stage === 'READY', 409,
      c?.stage === 'RECONNECT_REQUIRED' ? 'RECONNECT_REQUIRED' : 'WORKSPACE_NOT_READY', 'Company workspace is not ready.');
    const owner = state.owners[c.connection?.ownerId];
    const membership = owner && state.memberships[digest(`${owner.id}:${companyId}`)];
    requireThat(owner?.status === 'ACTIVE' && membership?.status === 'ACTIVE' && membership.role === 'OWNER',
      403, 'OWNER_DISABLED', 'Company owner access is unavailable.');
    try {
      const refresh = await this.vault.decrypt(c.connection.ciphertext, c.connection.ownerId, companyId);
      const token = await this.connection.accessToken(refresh);
      return await action(token, c);
    } catch (error) {
      if (error instanceof ReconnectRequired) await this.registry.transact(latest => {
        const current = latest.companies[companyId];
        if (current?.connection?.version === c.connection.version) this.transition(current, 'RECONNECT_REQUIRED', error.code);
      });
      throw error;
    }
  }
  transition(company, stage, error = null) {
    company.stage = stage;
    company.setupError = error;
    company.updatedAt = this.now();
    company.version++;
    company.stageHistory = [...(company.stageHistory || []), { stage, at: this.now() }].slice(-40);
  }
  async work(companyId) {
    const lease = opaque();
    let company = await this.registry.transact(state => {
      const c = state.companies[companyId];
      requireThat(c && !c.deleted, 404, 'COMPANY_NOT_FOUND', 'Company not found.');
      if (c.stage === 'READY' || c.stage === 'RECONNECT_REQUIRED') return null;
      const owner = state.owners[c.connection?.ownerId];
      const membership = owner && state.memberships[digest(`${owner.id}:${companyId}`)];
      requireThat(owner?.status === 'ACTIVE' && membership?.status === 'ACTIVE' && membership.role === 'OWNER',
        403, 'OWNER_DISABLED', 'Company owner access is unavailable.');
      requireThat(!c.lease || c.lease.expiresAt <= this.now(), 503, 'SETUP_BUSY', 'Setup is already running.');
      c.lease = { id: lease, expiresAt: this.now() + 150_000 };
      return structuredClone(c);
    });
    if (!company) return;
    const connectionVersion = company.connection.version;
    const update = async change => {
      company = await this.registry.transact(state => {
        const c = state.companies[companyId];
        requireThat(c?.lease?.id === lease && c.lease.expiresAt > this.now() && c.connection.version === connectionVersion,
          409, 'SETUP_SUPERSEDED', 'A newer setup attempt is running.');
        const owner = state.owners[c.connection.ownerId];
        const membership = state.memberships[digest(`${c.connection.ownerId}:${companyId}`)];
        requireThat(owner?.status === 'ACTIVE' && membership?.status === 'ACTIVE' && membership.role === 'OWNER',
          403, 'OWNER_DISABLED', 'Company owner access is unavailable.');
        change(c);
        return structuredClone(c);
      });
    };
    try {
      const refresh = await this.vault.decrypt(company.connection.ciphertext, company.connection.ownerId, company.id);
      const access = await this.connection.accessToken(refresh);
      const { state } = await this.registry.read();
      const owner = state.owners[company.connection.ownerId];
      if (!company.folderPlan) {
        const ids = await this.google.generateFolderIds(access, FOLDERS.length + 1);
        await update(c => {
          c.folderPlan = { root: ids[0], children: Object.fromEntries(FOLDERS.map((name, i) => [name, ids[i + 1]])) };
          c.resources = { folders: {} };
          this.transition(c, 'CREATING_FOLDER');
        });
      } else if (!company.resources.rootFolderId) {
        const file = await this.google.ensureFolder(access, { id: company.folderPlan.root,
          name: `TPC Accounts - ${company.name}`, companyId, operation: operation(companyId, 'root') });
        await update(c => { c.resources.rootFolderId = file.id; this.transition(c, 'FOLDER_READY'); });
      } else if (FOLDERS.some(name => !company.resources.folders[name])) {
        const name = FOLDERS.find(name => !company.resources.folders[name]);
        const file = await this.google.ensureFolder(access, { id: company.folderPlan.children[name], name,
          companyId, operation: operation(companyId, name), parent: company.resources.rootFolderId });
        await update(c => { c.resources.folders[name] = file.id; this.transition(c, 'FOLDER_READY'); });
      } else if (!company.resources.spreadsheetId) {
        const op = operation(companyId, 'spreadsheet');
        let file = await this.google.findSpreadsheet(access, companyId, op);
        if (!file) {
          requireThat(!company.spreadsheetSubmitted, 503, 'RESOURCE_CONFIRMATION_PENDING',
            'Confirming spreadsheet creation. Retry later; no duplicate will be created.');
          // This durable intent is never reset after ambiguous I/O. A worker that
          // resumes after a crash only reconciles; it cannot issue a second create.
          await update(c => { c.spreadsheetSubmitted = true; this.transition(c, 'CREATING_SPREADSHEET'); });
          try {
            file = await this.google.createFile(access, { name: 'TPC Accounts Database', mimeType: SHEET_MIME,
              companyId, operation: op, parent: company.resources.rootFolderId });
          } catch (error) {
            if (error.definitelyRejected || (error.googleStatus >= 400 && error.googleStatus < 500)) {
              await update(c => { c.spreadsheetSubmitted = false; });
            }
            throw error;
          }
        }
        this.google.validateFile(file, companyId, op, SHEET_MIME, company.resources.rootFolderId);
        await update(c => { c.resources.spreadsheetId = file.id; this.transition(c, 'SPREADSHEET_READY'); });
      } else if (!company.schemaCreated) {
        await update(c => this.transition(c, 'CREATING_SCHEMA'));
        await this.google.ensureSchema(access, company, owner);
        await update(c => { c.schemaCreated = true; this.transition(c, 'VERIFYING_SCHEMA'); });
      } else {
        const resources = [{ key: 'root', id: company.resources.rootFolderId, mime: FOLDER_MIME },
          ...FOLDERS.map(name => ({ key: name, id: company.resources.folders[name], mime: FOLDER_MIME, parent: company.resources.rootFolderId })),
          { key: 'spreadsheet', id: company.resources.spreadsheetId, mime: SHEET_MIME, parent: company.resources.rootFolderId }];
        const remaining = resources.find(r => !company.verifiedResources?.[r.key]);
        if (remaining) {
          const file = await this.google.file(access, remaining.id);
          this.google.validateFile(file, companyId, operation(companyId, remaining.key), remaining.mime, remaining.parent);
          await update(c => { c.verifiedResources ??= {}; c.verifiedResources[remaining.key] = true; this.transition(c, 'VERIFYING_SCHEMA'); });
        } else {
          await this.google.verifySchema(access, company);
          await update(c => { c.schemaVersion = SCHEMA_VERSION; this.transition(c, 'READY'); });
        }
      }
    } catch (error) {
      try {
        await update(c => this.transition(c, error instanceof ReconnectRequired ? 'RECONNECT_REQUIRED' : 'RECOVERABLE_FAILURE',
          error instanceof ApiError ? error.code : 'GOOGLE_UNAVAILABLE'));
      } catch { /* A stale worker must not overwrite a newer connection or lease. */ }
      if (!(error instanceof ReconnectRequired)) throw error;
    } finally {
      await this.registry.transact(state => {
        const c = state.companies[companyId];
        if (c?.lease?.id === lease) delete c.lease;
      });
    }
    const { state: latest } = await this.registry.read();
    const c = latest.companies[companyId];
    if (!['READY', 'RECONNECT_REQUIRED'].includes(c.stage)) await this.queue.enqueue(c.id, c.version);
  }
}
