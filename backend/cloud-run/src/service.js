import { opaque, digest, challenge } from './crypto.js';
import { requireThat } from './errors.js';

export const STAGES = Object.freeze([
  'REGISTERED', 'GOOGLE_CONNECTION_REQUIRED', 'GOOGLE_CONNECTED', 'CREATING_FOLDER',
  'FOLDER_READY', 'CREATING_SPREADSHEET', 'SPREADSHEET_READY', 'CREATING_SCHEMA',
  'VERIFYING_SCHEMA', 'READY', 'RECONNECT_REQUIRED', 'RECOVERABLE_FAILURE',
]);
const validToken = value => typeof value === 'string' && /^[A-Za-z0-9_-]{43}$/.test(value);
const publicOwner = owner => ({ ownerId: owner.id, email: owner.email, name: owner.name });
// Explicit response allowlist: internal workspace IDs/credentials never escape.
export const publicCompany = c => ({ companyId: c.id, name: c.name, stage: c.stage,
  createdAt: c.createdAt, updatedAt: c.updatedAt, version: c.version,
  employeeInvitationsEnabled: c.stage === 'READY',
  errorCode: c.setupError || null,
  nextAction: c.stage === 'RECONNECT_REQUIRED' ? 'RECONNECT_GOOGLE' :
    c.stage === 'GOOGLE_CONNECTION_REQUIRED' ? 'CONNECT_GOOGLE' :
    c.stage === 'RECOVERABLE_FAILURE' ? 'RETRY_SETUP' : null,
});

export class AccountsService {
  constructor(registry, identity, config, { now = Date.now } = {}) {
    Object.assign(this, { registry, identity, config, now });
  }
  ownerSession(state, token) {
    requireThat(validToken(token), 401, 'UNAUTHORIZED', 'Sign in to continue.');
    const session = state.sessions[digest(token)];
    const owner = session && state.owners[session.ownerId];
    requireThat(session && session.expiresAt > this.now() && !session.revokedAt &&
      owner?.status === 'ACTIVE' && owner.sessionVersion === session.version,
    401, 'UNAUTHORIZED', 'Your session has expired or was revoked.');
    return owner;
  }
  async startSignIn(previousBinding) {
    const stateToken = opaque(), binding = opaque(), nonce = opaque(), verifier = opaque();
    const expiresAt = this.now() + this.config.oauthMs;
    const url = this.identity.authorizationUrl({ state: stateToken, nonce, challenge: challenge(verifier) });
    await this.registry.transact(state => {
      if (validToken(previousBinding)) {
        for (const [key, tx] of Object.entries(state.oauth)) {
          if (tx.bindingHash === digest(previousBinding)) delete state.oauth[key];
        }
      }
      requireThat(Object.keys(state.oauth).length < 1000, 429, 'SIGN_IN_BUSY', 'Please try signing in later.');
      state.oauth[digest(stateToken)] = { kind: 'signin', bindingHash: digest(binding), nonce, verifier, expiresAt };
    });
    return { authorizationUrl: url, binding };
  }
  async finishSignIn(stateToken, binding, code, previousSession) {
    requireThat(validToken(stateToken) && validToken(binding), 401, 'OAUTH_STATE_INVALID', 'Start sign-in again.');
    requireThat(typeof code === 'string' && code.length > 0 && code.length <= 4096, 400, 'OAUTH_CODE_INVALID', 'Google authorization code is missing.');
    const transaction = await this.registry.transact(state => {
      const tx = state.oauth[digest(stateToken)];
      requireThat(tx && (!tx.kind || tx.kind === 'signin') && tx.expiresAt > this.now() && tx.bindingHash === digest(binding),
        401, 'OAUTH_STATE_INVALID', 'Sign-in has expired or was already used.');
      delete state.oauth[digest(stateToken)];
      return tx;
    });
    const identity = await this.identity.exchange(code, transaction);
    const ownerId = digest(`google:${identity.sub}`), token = opaque(), now = this.now();
    await this.registry.transact(state => {
      const existing = state.owners[ownerId];
      requireThat(!existing || existing.status === 'ACTIVE', 403, 'OWNER_DISABLED', 'This account is disabled.');
      const owner = state.owners[ownerId] = { id: ownerId, googleSub: identity.sub,
        email: identity.email, name: identity.name, status: 'ACTIVE',
        sessionVersion: existing?.sessionVersion || 1, createdAt: existing?.createdAt || now, updatedAt: now };
      if (validToken(previousSession)) delete state.sessions[digest(previousSession)];
      state.sessions[digest(token)] = { ownerId, createdAt: now, expiresAt: now + this.config.sessionMs,
        version: owner.sessionVersion };
    });
    return { token, expiresAt: now + this.config.sessionMs };
  }
  async me(token) {
    const { state } = await this.registry.read();
    return publicOwner(this.ownerSession(state, token));
  }
  async logout(token, all = false) {
    await this.registry.transact(state => {
      const owner = this.ownerSession(state, token);
      if (all) owner.sessionVersion++;
      delete state.sessions[digest(token)];
    });
  }
  async createCompany(token, input, idempotencyKey) {
    requireThat(input && typeof input === 'object' && !Array.isArray(input) &&
      Object.keys(input).every(k => k === 'name'), 400, 'INVALID_COMPANY', 'Only a company name is accepted during registration.');
    requireThat(typeof input.name === 'string' && input.name.trim().length >= 1 &&
      input.name.trim().length <= 160 && !/[\x00-\x1f\x7f]/.test(input.name),
    400, 'INVALID_COMPANY', 'Enter a company name between 1 and 160 characters.');
    requireThat(typeof idempotencyKey === 'string' && /^[A-Za-z0-9_-]{16,128}$/.test(idempotencyKey),
      400, 'IDEMPOTENCY_KEY_REQUIRED', 'Supply a stable unique Idempotency-Key for this registration.');
    const name = input.name.trim(), fingerprint = digest(JSON.stringify({ name }));
    const companyId = opaque(), now = this.now();
    return this.registry.transact(state => {
      const owner = this.ownerSession(state, token);
      const operationKey = digest(`${owner.id}:${idempotencyKey}`);
      const previous = state.registrations[operationKey];
      if (previous) {
        requireThat(previous.fingerprint === fingerprint, 409, 'IDEMPOTENCY_CONFLICT', 'This key was already used with different company details.');
        const membership = state.memberships[digest(`${owner.id}:${previous.companyId}`)];
        requireThat(membership?.status === 'ACTIVE' && membership.role === 'OWNER' &&
          state.companies[previous.companyId] && !state.companies[previous.companyId].deleted,
        404, 'COMPANY_NOT_FOUND', 'Company not found.');
        return { company: publicCompany(state.companies[previous.companyId]), replayed: true };
      }
      const company = state.companies[companyId] = { id: companyId, name,
        stage: 'GOOGLE_CONNECTION_REQUIRED', createdAt: now, updatedAt: now, version: 1,
        createdBy: owner.id, updatedBy: owner.id, registeredAt: now,
        registrationStage: 'REGISTERED', deleted: false };
      state.memberships[digest(`${owner.id}:${companyId}`)] = { ownerId: owner.id, companyId,
        role: 'OWNER', status: 'ACTIVE', createdAt: now };
      state.registrations[operationKey] = { companyId, ownerId: owner.id, fingerprint, createdAt: now };
      return { company: publicCompany(company), replayed: false };
    });
  }
  async listCompanies(token) {
    const { state } = await this.registry.read();
    const owner = this.ownerSession(state, token);
    return Object.values(state.memberships).filter(m => m.ownerId === owner.id && m.status === 'ACTIVE')
      .map(m => state.companies[m.companyId]).filter(c => c && !c.deleted).map(publicCompany);
  }
  async companyStatus(token, companyId) {
    const { state } = await this.registry.read();
    this.companyOwner(state, token, companyId);
    return publicCompany(state.companies[companyId]);
  }
  companyOwner(state, token, companyId) {
    const owner = this.ownerSession(state, token);
    const member = state.memberships[digest(`${owner.id}:${companyId}`)];
    const company = state.companies[companyId];
    requireThat(member?.status === 'ACTIVE' && member.role === 'OWNER' && company && !company.deleted,
      404, 'COMPANY_NOT_FOUND', 'Company not found.');
    return owner;
  }
}
