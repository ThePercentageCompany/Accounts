import { opaque, digest } from './crypto.js';
import { requireThat, ApiError } from './errors.js';
import { PrivateCode } from './private-code.js';
import { SECTIONS, ROLES, scopeFor, principalFromRows, SECTION_TABLES, CHILDREN, visible, projectRecord } from './employee-policy.js';

const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{43}$/.test(value);
const keyRequired = key => requireThat(typeof key === 'string' && /^[A-Za-z0-9_-]{16,128}$/.test(key),
  400, 'IDEMPOTENCY_KEY_REQUIRED', 'Use one stable Idempotency-Key for each intended change.');
const accessDenied = () => new ApiError(401, 'EMPLOYEE_ACCESS_DENIED', 'The invite or private code is invalid, expired or disabled.');
const cleanEmployee = row => Object.fromEntries(['recordId', 'fullName', 'email', 'phone', 'department', 'designation', 'employmentStatus', 'recordVersion'].map(k => [k, row[k] ?? '']));

export class EmployeeService {
  constructor({ accounts, sheets, codes = new PrivateCode(), now = Date.now }) {
    Object.assign(this, { accounts, sheets, codes, now }); this.registry = accounts.registry;
  }
  ready(state, companyId, allowWrite = false) {
    const c = state.companies[companyId];
    requireThat(c && !c.deleted && c.stage === 'READY', 409, c?.stage === 'RECONNECT_REQUIRED' ? 'RECONNECT_REQUIRED' : 'WORKSPACE_NOT_READY', 'Company workspace is not ready.');
    requireThat(allowWrite || !c.employeeWrite, 409, 'EMPLOYEE_UPDATE_PENDING', 'An employee update is being confirmed. Retry shortly.');
    requireThat(!c.businessWrite, 409, 'BUSINESS_WRITE_PENDING', 'A business update is being confirmed. Retry shortly.');
    requireThat(!c.documentWrite, 409, 'DOCUMENT_WRITE_PENDING', 'A document upload is being confirmed. Retry shortly.');
    return c;
  }
  owner(state, token, companyId, allowWrite = false) {
    this.accounts.companyOwner(state, token, companyId); return this.ready(state, companyId, allowWrite);
  }
  async list(token, companyId) {
    this.owner((await this.registry.read()).state, token, companyId);
    const rows = await this.sheets.read(companyId);
    return rows.Employees.filter(e => e.isDeleted !== true && e.isDeleted !== 'TRUE').map(e => ({ ...cleanEmployee(e),
      role: rows.Roles.find(r => r.recordId === e.roleId)?.roleName || '',
      allowedSections: rows.RolePermissions.filter(p => p.roleId === e.roleId && p.action === 'read' && p.isDeleted !== true && p.isDeleted !== 'TRUE').map(p => p.section) }));
  }
  input(input) {
    const allowed = ['fullName', 'email', 'phone', 'department', 'designation', 'employmentStatus', 'role', 'allowedSections', 'expectedVersion'];
    requireThat(input && !Array.isArray(input) && Object.keys(input).every(k => allowed.includes(k)), 400, 'INVALID_EMPLOYEE', 'Unsupported employee fields.');
    requireThat(typeof input.fullName === 'string' && input.fullName.trim().length > 0 && input.fullName.length <= 160 && !/[\x00-\x1f]/.test(input.fullName) &&
      ROLES.includes(input.role) && ['ACTIVE', 'INACTIVE'].includes(input.employmentStatus) &&
      Number.isSafeInteger(input.expectedVersion) && input.expectedVersion >= 0 &&
      Array.isArray(input.allowedSections) && input.allowedSections.every(s => SECTIONS.includes(s)) &&
      new Set(input.allowedSections).size === input.allowedSections.length,
    400, 'INVALID_EMPLOYEE', 'Supply a name, valid role/status, sections and expectedVersion.');
    const value = { fullName: input.fullName.trim(), role: input.role, employmentStatus: input.employmentStatus,
      allowedSections: SECTIONS.filter(s => input.allowedSections.includes(s)), expectedVersion: input.expectedVersion };
    for (const key of ['email', 'phone', 'department', 'designation']) {
      if (!Object.hasOwn(input, key)) continue;
      const text = input[key];
      requireThat(typeof text === 'string' && text.length <= 200 && !/[\x00-\x1f]/.test(text), 400, 'INVALID_EMPLOYEE', 'Invalid employee contact details.');
      value[key] = text.trim();
    }
    requireThat(!value.email || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.email), 400, 'INVALID_EMPLOYEE', 'Invalid employee email.');
    return value;
  }
  async save(token, companyId, employeeId, input, key) {
    this.accounts.companyOwner((await this.registry.read()).state, token, companyId);
    const reservation = opaque();
    try { return await this.saveOperation(token, companyId, employeeId, input, key, reservation); }
    catch (error) {
      const opKey = typeof key === 'string' ? digest(`employee:${companyId}:${key}`) : '';
      await this.registry.transact(state => {
        const c = state.companies[companyId], op = c?.employeeOps?.[opKey];
        if (c?.employeeWrite === opKey && op?.reservation === reservation && !op.submitted && !op.completed) {
          delete c.employeeWrite; delete c.employeeOps[opKey];
        }
      });
      throw error;
    }
  }
  async saveOperation(token, companyId, employeeId, input, key, reservation = opaque()) {
    keyRequired(key); const values = this.input(input);
    requireThat(employeeId === null ? values.expectedVersion === 0 : validId(employeeId) && values.expectedVersion > 0,
      400, 'INVALID_EMPLOYEE', 'Invalid employee ID or version.');
    const proposedId = employeeId || opaque(), fingerprint = digest(JSON.stringify({ employeeId, values }));
    const opKey = digest(`employee:${companyId}:${key}`);
    const op = await this.registry.transact(state => {
      const c = this.owner(state, token, companyId, true); c.employeeOps ??= {};
      const existing = c.employeeOps[opKey];
      if (existing) {
        requireThat(existing.fingerprint === fingerprint, 409, 'IDEMPOTENCY_CONFLICT', 'This key was used for a different change.'); return existing;
      }
      requireThat(!c.employeeWrite, 409, 'EMPLOYEE_UPDATE_PENDING', 'Confirm the previous employee update before making another change.');
      c.employeeWrite = opKey;
      return c.employeeOps[opKey] = { employeeId: proposedId, fingerprint, reservation, submitted: false, completed: false,
        version: values.expectedVersion + 1, at: this.now() };
    });
    if (op.completed) return { employeeId: op.employeeId, version: op.version, replayed: true };
    const rows = await this.sheets.read(companyId);
    const old = rows.Employees.find(e => e.recordId === op.employeeId);
    const roleId = digest(`role:${op.employeeId}`);
    const role = rows.Roles.find(r => r.recordId === roleId);
    const marker = `employee:${opKey}`;
    const permissionId = section => digest(`${roleId}:${section}`);
    const confirmed = old?.idempotencyKey === marker && role?.idempotencyKey === marker &&
      SECTIONS.every(section => rows.RolePermissions.some(r => r.recordId === permissionId(section) && r.idempotencyKey === marker));
    if (!confirmed) {
      requireThat(!op.submitted, 409, 'EMPLOYEE_WRITE_CONFIRMATION_PENDING', 'Confirming the prior write. Retry with the same key; no duplicate write was issued.');
      requireThat((Number(old?.recordVersion) || 0) === values.expectedVersion && (!employeeId || old),
        409, 'VERSION_CONFLICT', 'Employee changed. Refresh before editing.');
      const current = await this.registry.read();
      const actor = this.accounts.companyOwner(current.state, token, companyId).id;
      const common = (id, previous) => ({ recordId: id, companyId, createdAt: previous?.createdAt ?? op.at,
        createdBy: previous?.createdBy || actor, updatedAt: op.at, updatedBy: actor,
        recordVersion: op.version, syncStatus: 'SYNCED', isDeleted: false, idempotencyKey: marker });
      const nextRow = records => Math.max(1, ...records.map(r => r._row)) + 1;
      const changes = [{ table: 'Employees', row: old?._row || nextRow(rows.Employees), values: {
        ...common(op.employeeId, old), fullName: values.fullName,
        ...Object.fromEntries(['email', 'phone', 'department', 'designation'].filter(k => Object.hasOwn(values, k)).map(k => [k, values[k]])),
        employmentStatus: values.employmentStatus, roleId } },
      { table: 'Roles', row: role?._row || nextRow(rows.Roles), values: { ...common(roleId, role), roleName: values.role, description: 'Employee assigned role' } }];
      let permissionRow = nextRow(rows.RolePermissions);
      for (const section of SECTIONS) {
        const id = permissionId(section), previous = rows.RolePermissions.find(p => p.recordId === id);
        changes.push({ table: 'RolePermissions', row: previous?._row || permissionRow++, values: {
          ...common(id, previous), roleId, section, action: values.allowedSections.includes(section) ? 'read' : 'none',
          recordScope: scopeFor(values.role, section), fieldName: '*', isDeleted: !values.allowedSections.includes(section) } });
      }
      await this.registry.transact(state => {
        const c = this.owner(state, token, companyId, true), pending = c.employeeOps[opKey];
        requireThat(c.employeeWrite === opKey && pending?.reservation === op.reservation && !pending.submitted, 409, 'EMPLOYEE_UPDATE_PENDING', 'This employee update is already being submitted.');
        pending.submitted = true;
      });
      try { await this.sheets.write(companyId, changes); }
      catch (error) {
        if (error.definitelyNotSubmitted || error.definitelyRejected || (error.googleStatus >= 400 && error.googleStatus < 500)) {
          await this.registry.transact(state => { const c = state.companies[companyId];
            if (c.employeeWrite === opKey) c.employeeOps[opKey].submitted = false; });
        }
        throw error;
      }
    }
    await this.registry.transact(state => {
      const c = this.owner(state, token, companyId, true), pending = c.employeeOps[opKey];
      if (pending.completed) return;
      requireThat(c.employeeWrite === opKey, 409, 'EMPLOYEE_UPDATE_PENDING', 'Employee update changed.');
      pending.completed = true; delete c.employeeWrite;
      c.employeeAccess ??= {};
      const access = c.employeeAccess[op.employeeId] ??= { version: 0, status: 'UNISSUED' };
      if (values.employmentStatus !== 'ACTIVE') { access.version++; access.status = 'REVOKED'; }
    });
    return { employeeId: op.employeeId, version: op.version, replayed: confirmed };
  }
  async issue(token, companyId, employeeId, kind, key) {
    keyRequired(key);
    requireThat(validId(employeeId) && ['issue', 'reset'].includes(kind), 400, 'INVALID_ACCESS', 'Invalid employee access action.');
    const opKey = digest(`access:${key}`);
    const { state } = await this.registry.read(); const c = this.owner(state, token, companyId);
    requireThat(!c.credentialOps?.[opKey], 409, 'PRIVATE_CODE_ALREADY_ISSUED', 'Codes cannot be read back. Reset using a new operation key if the response was lost.');
    const principal = principalFromRows(companyId, employeeId, await this.sheets.read(companyId), this.now());
    const generated = await this.codes.create(), invite = opaque(), inviteHash = digest(invite);
    await this.registry.transact(latest => {
      const company = this.owner(latest, token, companyId); company.credentialOps ??= {}; company.employeeAccess ??= {};
      requireThat(!company.credentialOps[opKey], 409, 'PRIVATE_CODE_ALREADY_ISSUED', 'Code already issued. Reset with a new key if needed.');
      const previous = company.employeeAccess[employeeId];
      requireThat(kind === 'reset' || previous?.status !== 'ACTIVE', 409, 'ACCESS_ALREADY_ISSUED', 'Use reset to replace an existing private code.');
      latest.employeeInvites ??= {};
      if (previous?.inviteHash) delete latest.employeeInvites[previous.inviteHash];
      latest.employeeInvites[inviteHash] = { companyId, employeeId };
      company.employeeAccess[employeeId] = { credential: generated.credential, inviteHash, version: (previous?.version || 0) + 1,
        status: 'ACTIVE', failedAttempts: 0, lockedUntil: 0, issuedAt: this.now() };
      company.credentialOps[opKey] = { employeeId, kind, at: this.now() };
    });
    const link = new URL(this.accounts.config.appOrigin); link.hash = `employee-invite=${invite}`;
    return { employeeId, inviteId: invite, inviteLink: link.toString(), qrPayload: link.toString(), privateCode: generated.code,
      allowedSections: principal.allowedSections };
  }
  async revoke(token, companyId, employeeId) {
    await this.registry.transact(state => {
      this.accounts.companyOwner(state, token, companyId);
      const c = state.companies[companyId], a = c.employeeAccess?.[employeeId];
      requireThat(a, 404, 'EMPLOYEE_NOT_FOUND', 'Employee access not found.');
      a.version++; a.status = 'REVOKED'; a.revokedAt = this.now();
      if (a.inviteHash) delete (state.employeeInvites || {})[a.inviteHash];
    });
  }
  async login(input) {
    requireThat(input && Object.keys(input).every(k => ['inviteId', 'privateCode'].includes(k)) && validId(input.inviteId) &&
      typeof input.privateCode === 'string' && input.privateCode.length <= 128, 401, 'EMPLOYEE_ACCESS_DENIED', 'The invite or private code is invalid, expired or disabled.');
    const reservation = await this.registry.transact(state => {
      const minute = Math.floor(this.now() / 60000);
      if (state.employeeLoginRate?.minute !== minute) state.employeeLoginRate = { minute, count: 0 };
      if (state.employeeLoginRate.count >= 120) return { throttled: true };
      state.employeeLoginRate.count++;
      const invite = state.employeeInvites?.[digest(input.inviteId)], c = invite && state.companies[invite.companyId];
      const access = c?.employeeAccess?.[invite.employeeId];
      if (!access || access.status !== 'ACTIVE') return {};
      if (access.lockedUntil > this.now()) return { throttled: true };
      if (access.lockedUntil) { access.failedAttempts = 0; access.lockedUntil = 0; }
      access.failedAttempts++;
      if (access.failedAttempts >= 5) access.lockedUntil = this.now() + 15 * 60000;
      return { ...invite, access: structuredClone(access) };
    });
    if (reservation.throttled) throw new ApiError(429, 'LOGIN_RATE_LIMITED', 'Too many attempts. Try again later or ask the owner to reset access.');
    if (!reservation.access || !await this.codes.verify(input.privateCode.trim(), reservation.access.credential)) throw accessDenied();
    const { companyId, employeeId, access } = reservation;
    this.ready((await this.registry.read()).state, companyId);
    const principal = principalFromRows(companyId, employeeId, await this.sheets.read(companyId), this.now());
    const token = opaque(), expiresAt = this.now() + 8 * 3600000;
    await this.registry.transact(state => {
      const c = this.ready(state, companyId), current = c.employeeAccess?.[employeeId];
      if (current?.version !== access.version || current.status !== 'ACTIVE') throw accessDenied();
      current.failedAttempts = 0; current.lockedUntil = 0;
      state.employeeSessions ??= {};
      state.employeeSessions[digest(token)] = { companyId, employeeId, version: current.version,
        expiresAt, absoluteExpiresAt: this.now() + 24 * 3600000 };
    });
    return { token, expiresAt, employee: this.publicPrincipal(principal) };
  }
  session(state, token) {
    const session = validId(token) && state.employeeSessions?.[digest(token)];
    if (!session || session.expiresAt <= this.now() || session.absoluteExpiresAt <= this.now()) throw accessDenied();
    const c = this.ready(state, session.companyId), access = c.employeeAccess?.[session.employeeId];
    if (!access || access.status !== 'ACTIVE' || access.version !== session.version) throw accessDenied();
    return session;
  }
  publicPrincipal(p) { return { companyId: p.companyId, employeeId: p.employeeId, name: p.name, role: p.role, allowedSections: p.allowedSections }; }
  async principal(token) {
    const session = this.session((await this.registry.read()).state, token);
    const principal = principalFromRows(session.companyId, session.employeeId, await this.sheets.read(session.companyId), this.now());
    this.session((await this.registry.read()).state, token);
    return principal;
  }
  async refresh(token) {
    const principal = await this.principal(token), replacement = opaque();
    const expiresAt = await this.registry.transact(state => {
      const session = this.session(state, token);
      delete state.employeeSessions[digest(token)];
      session.expiresAt = Math.min(this.now() + 8 * 3600000, session.absoluteExpiresAt);
      state.employeeSessions[digest(replacement)] = session; return session.expiresAt;
    });
    return { token: replacement, expiresAt, employee: this.publicPrincipal(principal) };
  }
  async logout(token) {
    await this.registry.transact(state => { if (validId(token)) delete (state.employeeSessions || {})[digest(token)]; });
  }
  async records(token, table) {
    requireThat(Object.hasOwn(SECTION_TABLES, table), 403, 'TABLE_FORBIDDEN', 'This table is not available to employees.');
    const p = await this.principal(token);
    requireThat(p.permissions[SECTION_TABLES[table]], 403, 'SECTION_FORBIDDEN', 'This section is not assigned to you.');
    const names = [...new Set([table, ...(CHILDREN[table] ? [CHILDREN[table][0]] : []), 'Employees', 'Roles', 'RolePermissions'])];
    const rows = await this.sheets.read(p.companyId, names);
    const latest = principalFromRows(p.companyId, p.employeeId, rows, this.now());
    this.session((await this.registry.read()).state, token);
    return rows[table].filter(r => visible(latest, table, r, rows)).map(r => {
      const value = projectRecord(latest, table, r); delete value._row; return value;
    });
  }
}
