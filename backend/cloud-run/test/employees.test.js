import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from './helpers.js';
import { EmployeeService } from '../src/employee-service.js';
import { digest, opaque } from '../src/crypto.js';
import { PrivateCode } from '../src/private-code.js';
import { authorizeDocument } from '../src/employee-policy.js';
import { ApiError } from '../src/errors.js';

async function setup() {
  const f = fixture(), owner = await f.login();
  const created = await f.service.createCompany(owner, { name: 'Company' }, 'employee_company_key');
  const companyId = created.company.companyId;
  f.storage.state.companies[companyId].stage = 'READY';
  const rows = { Employees: [], Roles: [], RolePermissions: [], Invoices: [], Payroll: [], PayrollItems: [], Assets: [] };
  let writes = 0, sequence = 0;
  const sheets = {
    read: async (_id, names) => structuredClone(names ? Object.fromEntries(names.map(n => [n, rows[n] || []])) : rows),
    write: async (_id, changes) => { writes++; for (const change of changes) {
      const records = rows[change.table];
      const old = records.find(r => r._row === change.row);
      if (old) Object.assign(old, change.values);
      else records.push({ ...change.values, _row: change.row });
    } },
  };
  const codes = {
    create: async () => { const code = `private-code-${++sequence}`; return { code, credential: { hash: digest(code) } }; },
    verify: async (code, credential) => digest(code) === credential.hash,
  };
  const employees = new EmployeeService({ accounts: f.service, sheets, codes, now: () => f.service.now() });
  const input = { fullName: 'Real Employee', email: 'staff@example.com', role: 'Staff', employmentStatus: 'ACTIVE',
    allowedSections: ['Employees', 'Payroll', 'Invoices'], expectedVersion: 0 };
  async function create(key = 'employee_create_key') {
    return (await employees.save(owner, companyId, null, input, key)).employeeId;
  }
  async function issue(id, key = 'employee_issue_key', kind = 'issue') { return employees.issue(owner, companyId, id, kind, key); }
  async function login(invite) { return employees.login({ inviteId: invite.inviteId, privateCode: invite.privateCode }); }
  return { ...f, owner, companyId, rows, sheets, employees, codes, input, create, issue, loginEmployee: login,
    writes: () => writes, company: () => f.storage.state.companies[companyId] };
}
const denied = e => e.code === 'EMPLOYEE_ACCESS_DENIED';

test('conflicting employee retry cannot release the active write reservation', async () => {
  const f = await setup(), read = f.sheets.read;
  let release, entered;
  const waiting = new Promise(resolve => { entered = resolve; });
  f.sheets.read = async (...args) => { entered(); await new Promise(resolve => { release = resolve; }); return read(...args); };
  const saving = f.create();
  await waiting;
  await assert.rejects(() => f.employees.save(f.owner, f.companyId, null,
    { ...f.input, fullName: 'Conflicting name' }, 'employee_create_key'), e => e.code === 'IDEMPOTENCY_CONFLICT');
  assert.ok(f.company().employeeWrite);
  release(); await saving;
  assert.equal(f.writes(), 1);
  assert.equal(f.rows.Employees[0].fullName, f.input.fullName);
});

test('employee creation is idempotent, normalized and business details remain outside control storage', async () => {
  const f = await setup(), id = await f.create();
  assert.equal(await f.create(), id);
  assert.equal(f.rows.Employees.length, 1);
  assert.equal(f.rows.Roles.length, 1);
  assert.equal(f.writes(), 1);
  assert.ok(f.rows.RolePermissions.every(p => typeof p.section === 'string'));
  assert.ok(!JSON.stringify(f.storage.state).includes('Real Employee'));
  assert.ok(!JSON.stringify(f.storage.state).includes('staff@example.com'));
});
test('QR contains only opaque invite reference and separate code is never persisted', async () => {
  const f = await setup(), id = await f.create(), issued = await f.issue(id);
  const url = new URL(issued.qrPayload);
  assert.equal(url.origin, f.config.appOrigin);
  assert.equal(url.hash, `#employee-invite=${issued.inviteId}`);
  assert.equal(url.search, '');
  for (const secret of [issued.privateCode, f.companyId, id, 'Staff', 'gateway']) assert.ok(!issued.qrPayload.includes(secret));
  assert.ok(!JSON.stringify(f.storage.state).includes(issued.privateCode));
  assert.ok(!JSON.stringify(f.storage.state.employeeInvites).includes(issued.inviteId));
  await assert.rejects(f.issue(id), e => e.code === 'PRIVATE_CODE_ALREADY_ISSUED');
});
test('employee login works after owner logout and session holds no cached permissions', async () => {
  const f = await setup(), id = await f.create(), invite = await f.issue(id);
  await f.service.logout(f.owner);
  const session = await f.loginEmployee(invite);
  assert.deepEqual(session.employee.allowedSections, ['Invoices', 'Employees', 'Payroll']);
  assert.ok(!JSON.stringify(f.storage.state.employeeSessions).includes(session.token));
  assert.ok(!JSON.stringify(f.storage.state.employeeSessions).includes('Payroll'));
});
test('permission removal and role changes apply on subsequent reads without token refresh', async () => {
  const f = await setup(), id = await f.create(), invite = await f.issue(id), session = await f.loginEmployee(invite);
  f.rows.Invoices.push({ recordId: 'invoice', companyId: f.companyId, isDeleted: false, total: 100 });
  assert.equal((await f.employees.records(session.token, 'Invoices')).length, 1);
  f.rows.RolePermissions.find(p => p.section === 'Invoices').isDeleted = true;
  await assert.rejects(f.employees.records(session.token, 'Invoices'), e => e.code === 'SECTION_FORBIDDEN');
  assert.ok(!(await f.employees.principal(session.token)).allowedSections.includes('Invoices'));
  f.rows.Roles[0].roleName = 'unknown-role';
  await assert.rejects(f.employees.principal(session.token), denied);
});
test('staff can read only own payroll and child rows, private employee fields are removed', async () => {
  const f = await setup(), id = await f.create(), session = await f.loginEmployee(await f.issue(id));
  Object.assign(f.rows.Employees[0], { passportNumber: 'secret', iban: 'private', basicSalary: 1000 });
  f.rows.Employees.push({ recordId: 'someone-else', companyId: f.companyId, fullName: 'Other', isDeleted: false });
  f.rows.Payroll.push({ recordId: 'own', employeeId: id, companyId: f.companyId, isDeleted: false },
    { recordId: 'other', employeeId: 'someone-else', createdBy: id, companyId: f.companyId, isDeleted: false });
  f.rows.PayrollItems.push({ recordId: 'own-item', payrollId: 'own', companyId: f.companyId, isDeleted: false },
    { recordId: 'other-item', payrollId: 'other', companyId: f.companyId, isDeleted: false });
  const employees = await f.employees.records(session.token, 'Employees');
  assert.equal(employees.length, 1); assert.equal(employees[0].basicSalary, 1000);
  assert.equal(employees[0].passportNumber, undefined); assert.equal(employees[0].iban, undefined);
  assert.equal((await f.employees.records(session.token, 'Payroll')).length, 1);
  assert.deepEqual((await f.employees.records(session.token, 'PayrollItems')).map(r => r.recordId), ['own-item']);
  for (const table of ['EmployeeAccess', 'OwnersUsers', 'RolePermissions', 'DocumentRegistry', 'SyncOperations']) {
    await assert.rejects(f.employees.records(session.token, table), e => e.code === 'TABLE_FORBIDDEN');
  }
});
test('reset invalidates previous invite, code and active sessions; refresh rotates tokens', async () => {
  const f = await setup(), id = await f.create(), old = await f.issue(id), session = await f.loginEmployee(old);
  const replacement = await f.issue(id, 'new_reset_operation', 'reset');
  await assert.rejects(f.loginEmployee(old), denied);
  await assert.rejects(f.employees.principal(session.token), denied);
  const fresh = await f.loginEmployee(replacement);
  const refreshed = await f.employees.refresh(fresh.token);
  await assert.rejects(f.employees.principal(fresh.token), denied);
  await f.employees.principal(refreshed.token);
  await f.employees.logout(refreshed.token);
  await assert.rejects(f.employees.principal(refreshed.token), denied);
});
test('employee disabled in Sheets cannot use existing session', async () => {
  const f = await setup(), id = await f.create(), session = await f.loginEmployee(await f.issue(id));
  f.rows.Employees[0].employmentStatus = 'INACTIVE';
  await assert.rejects(f.employees.principal(session.token), denied);
});
test('owner disablement through API revokes credentials permanently until reissue', async () => {
  const f = await setup(), id = await f.create(), invite = await f.issue(id), session = await f.loginEmployee(invite);
  await f.employees.save(f.owner, f.companyId, id, { ...f.input, expectedVersion: 1, employmentStatus: 'INACTIVE' }, 'employee_disable_key');
  assert.equal(f.company().employeeAccess[id].status, 'REVOKED');
  await assert.rejects(f.employees.principal(session.token), denied);
  await f.employees.save(f.owner, f.companyId, id, { ...f.input, expectedVersion: 2 }, 'employee_enable_key');
  await assert.rejects(f.loginEmployee(invite), denied);
});
test('expiry, absolute session lifetime and independent owner revoke are enforced', async () => {
  const f = await setup(), id = await f.create(), invite = await f.issue(id), session = await f.loginEmployee(invite);
  f.advance(8 * 3600000 + 1);
  await assert.rejects(f.employees.principal(session.token), denied);
  const fresh = await f.loginEmployee(invite);
  // A new owner session can revoke even when Google is unavailable.
  const owner = await f.login();
  f.sheets.read = async () => { throw new Error('Google down'); };
  await f.employees.revoke(owner, f.companyId, id);
  await assert.rejects(f.employees.principal(fresh.token), denied);
});
test('five failed attempts lock across instances and expiry allows retry', async () => {
  const f = await setup(), id = await f.create(), invite = await f.issue(id);
  const second = new EmployeeService({ accounts: f.service, sheets: f.sheets, codes: f.codes, now: () => f.service.now() });
  for (let i = 0; i < 5; i++) await assert.rejects((i % 2 ? second : f.employees).login({ inviteId: invite.inviteId, privateCode: 'wrong' }), denied);
  await assert.rejects(f.loginEmployee(invite), e => e.code === 'LOGIN_RATE_LIMITED');
  f.advance(15 * 60000 + 1);
  assert.equal((await f.loginEmployee(invite)).employee.employeeId, id);
});

test('refresh cannot extend absolute lifetime past 24 hours', async () => {
  const f = await setup(), id = await f.create(), invite = await f.issue(id);
  let session = await f.loginEmployee(invite);
  for (let i = 0; i < 3; i++) { f.advance(7 * 3600000); session = await f.employees.refresh(session.token); }
  f.advance(3 * 3600000 + 1);
  await assert.rejects(f.employees.refresh(session.token), denied);
});
test('global distributed attempt budget covers unknown invites too', async () => {
  const f = await setup();
  f.storage.state.employeeLoginRate = { minute: Math.floor(f.service.now() / 60000), count: 120 };
  await assert.rejects(f.employees.login({ inviteId: opaque(), privateCode: 'wrong' }), e => e.code === 'LOGIN_RATE_LIMITED');
});
test('tenant changes, client authority fields and non-READY companies are rejected', async () => {
  const f = await setup(), other = await f.login('other'), id = await f.create();
  await assert.rejects(f.employees.issue(other, f.companyId, id, 'issue', 'other_issue_key123'), e => e.code === 'COMPANY_NOT_FOUND');
  await assert.rejects(f.employees.save(f.owner, f.companyId, null, { ...f.input, spreadsheetId: 'attacker' }, 'invalid_create_key'), e => e.code === 'INVALID_EMPLOYEE');
  await assert.rejects(f.employees.login({ inviteId: opaque(), privateCode: 'code', role: 'Manager' }), denied);
  f.company().stage = 'GOOGLE_CONNECTED';
  await assert.rejects(f.issue(id), e => e.code === 'WORKSPACE_NOT_READY');
});
test('lost employee write response is reconciled and cannot duplicate rows', async () => {
  const f = await setup(), write = f.sheets.write;
  f.sheets.write = async (...args) => { await write(...args); throw new Error('response lost'); };
  await assert.rejects(f.create());
  assert.ok(f.company().employeeWrite);
  const id = await f.create();
  assert.equal(f.rows.Employees[0].recordId, id); assert.equal(f.rows.Employees.length, 1); assert.equal(f.writes(), 1);
  assert.equal(f.company().employeeWrite, undefined);
});
test('unknown write outcome blocks other mutations and access until confirmed', async () => {
  const f = await setup();
  f.sheets.write = async () => { throw new Error('unknown write outcome'); };
  await assert.rejects(f.create());
  await assert.rejects(f.create(), e => e.code === 'EMPLOYEE_WRITE_CONFIRMATION_PENDING');
  await assert.rejects(f.create('different_create_key'), e => e.code === 'EMPLOYEE_UPDATE_PENDING');
});
test('version conflicts do not permanently lock company access or overwrite data', async () => {
  const f = await setup(), id = await f.create();
  await assert.rejects(f.employees.save(f.owner, f.companyId, id, { ...f.input, expectedVersion: 10 }, 'conflicting_update'), e => e.code === 'VERSION_CONFLICT');
  assert.equal(f.company().employeeWrite, undefined);
  await f.issue(id);
  await f.employees.save(f.owner, f.companyId, id, { ...f.input, expectedVersion: 1, fullName: 'Updated' }, 'valid_update_key1');
  assert.equal(f.rows.Employees[0].fullName, 'Updated');
});

test('permission updates preserve omitted contact and payroll fields', async () => {
  const f = await setup(), id = await f.create();
  f.rows.Employees[0].basicSalary = 7000;
  f.rows.Employees[0].iban = 'kept-private';
  await f.employees.save(f.owner, f.companyId, id, { fullName: 'Real Employee', role: 'Staff', employmentStatus: 'ACTIVE',
    allowedSections: ['Dashboard'], expectedVersion: 1 }, 'permission_only_key');
  assert.equal(f.rows.Employees[0].email, 'staff@example.com');
  assert.equal(f.rows.Employees[0].basicSalary, 7000);
  assert.equal(f.rows.Employees[0].iban, 'kept-private');
});
test('document policy checks current record visibility and trusted folder scope', () => {
  const p = { companyId: 'c', employeeId: 'e', role: 'Staff', permissions: { Payroll: 'SELF' } };
  const record = { recordId: 'pay', companyId: 'c', employeeId: 'e', isDeleted: false };
  const document = { companyId: 'c', relatedSection: 'Payroll', relatedRecordId: 'pay', driveFileId: 'file' };
  const file = { id: 'file', ownedByMe: true, parents: ['private-folder'] };
  authorizeDocument(p, document, record, file, ['private-folder']);
  assert.throws(() => authorizeDocument(p, document, record, { ...file, parents: ['other-folder'] }, ['private-folder']), e => e.code === 'DOCUMENT_FORBIDDEN');
  assert.throws(() => authorizeDocument(p, document, { ...record, employeeId: 'other' }, file, ['private-folder']));
});
test('real private codes use independent salts and memory-hard verification', async () => {
  const codes = new PrivateCode(), first = await codes.create(), second = await codes.create();
  assert.notEqual(first.credential.salt, second.credential.salt);
  assert.equal(first.credential.algorithm, 'scrypt-131072-8-1');
  assert.equal(await codes.verify(first.code, first.credential), true);
  assert.equal(await codes.verify('wrong', first.credential), false);
});
