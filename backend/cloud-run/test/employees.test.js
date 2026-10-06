import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from './helpers.js';
import { EmployeeService } from '../src/employee-service.js';
import { digest, opaque } from '../src/crypto.js';
import { PrivateCode } from '../src/private-code.js';
import { authorizeDocument } from '../src/employee-policy.js';
import { ApiError } from '../src/errors.js';
import { TABLES } from '../src/company-schema.js';

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
const denied = e => ['EMPLOYEE_ACCESS_DENIED', 'EMPLOYEE_SESSION_INVALID', 'EMPLOYEE_SESSION_EXPIRED'].includes(e.code);

test('employee profile and compensation round-trip, partial edits preserve salary, payroll uses saved amounts', async () => {
  const f = await setup();
  Object.assign(f.input, { employeeCode: 'EMP-001', phone: '+971500000000', department: 'Accounts', designation: 'Accountant',
    joinDate: '2026-09-01', basicSalary: 5000.25, allowances: 500, bankName: 'Bank', iban: 'AE123',
    address: 'Dubai', emiratesId: '784-test', passportNumber: 'P123', visaExpiry: '2028-09-01' });
  const id = await f.create();
  const employee = (await f.employees.list(f.owner, f.companyId))[0];
  for (const key of ['employeeCode', 'joinDate', 'basicSalary', 'allowances', 'iban', 'visaExpiry']) assert.equal(employee[key], f.input[key]);
  await f.employees.save(f.owner, f.companyId, id, { fullName: 'Updated', role: 'Staff', employmentStatus: 'ACTIVE',
    allowedSections: [], expectedVersion: 1 }, 'employee_profile_update');
  assert.equal(f.rows.Employees[0].basicSalary, 5000.25);
  const business = { sheets: { readReferences: (company, names) => f.sheets.read(company, names) } };
  const result = await f.employees.payrollPreview(f.owner, f.companyId,
    { employeeId: id, month: '2026-09', bonus: 100, deductions: 25 }, business);
  assert.equal(result.totals.netSalary, 5575.25);
  assert.equal(f.writes(), 2); // Preview does not save records.
});

test('employee rejects invalid compensation, dates and duplicate codes before writing', async () => {
  const f = await setup();
  for (const change of [{ basicSalary: -1 }, { allowances: 1.234 }, { basicSalary: '5000' }, { joinDate: '2026-02-30' },
    { joinDate: '2026-10-01', lastEmploymentDate: '2026-09-01' }]) {
    await assert.rejects(f.employees.save(f.owner, f.companyId, null, { ...f.input, ...change }, 'invalid_employee_key'),
      e => e.code === 'INVALID_EMPLOYEE');
  }
  assert.equal(f.writes(), 0);
  f.input.employeeCode = 'EMP-001'; await f.create();
  await assert.rejects(f.employees.save(f.owner, f.companyId, null, { ...f.input, employeeCode: 'emp-001' }, 'duplicate_employee_key'),
    e => e.code === 'INVALID_EMPLOYEE');
  assert.equal(f.writes(), 1);
});

test('payroll preview and salary references require current payroll edit access', async () => {
  const f = await setup();
  Object.assign(f.input, { basicSalary: 1000, role: 'Accountant', writableSections: ['Payroll'] });
  const id = await f.create(), session = await f.loginEmployee(await f.issue(id));
  const business = { sheets: { readReferences: (company, names) => f.sheets.read(company, names) } };
  const values = { employeeId: id, month: '2026-09', bonus: 0, deductions: 0 };
  assert.equal((await f.employees.references(session.token, 'Employees', 'Payroll'))[0].basicSalary, 1000);
  assert.equal((await f.employees.payrollPreview(session.token, f.companyId, values, business, true)).totals.netSalary, 1000);
  await assert.rejects(f.employees.payrollPreview(session.token, f.companyId, values, business, true, { companyId: opaque() }),
    e => e.code === 'WORKSPACE_CHANGED');
  f.rows.RolePermissions.find(row => row.section === 'Payroll').action = 'read';
  await assert.rejects(f.employees.payrollPreview(session.token, f.companyId, values, business, true), e => e.code === 'WRITE_FORBIDDEN');
});

test('employee reports require company-wide Reports permission and recheck revocation', async () => {
  const f = await setup();
  const id = await f.create(), session = await f.loginEmployee(await f.issue(id));
  await assert.rejects(() => f.employees.report(session.token, 'dashboard', '2026-09-01', '2026-09-30'), e => e.code === 'SECTION_FORBIDDEN');
  const roleId = f.rows.Employees[0].roleId;
  f.rows.RolePermissions.push({ recordId: opaque(), companyId: f.companyId, roleId, section: 'Reports', action: 'read', fieldName: '*', recordScope: 'COMPANY' });
  assert.equal((await f.employees.report(session.token, 'dashboard', '2026-09-01', '2026-09-30')).netProfit, '0.00');
  const read = f.sheets.read;
  f.sheets.read = async (companyId, names) => {
    if (names?.includes('Journals')) f.rows.RolePermissions.at(-1).isDeleted = true;
    return read(companyId, names);
  };
  await assert.rejects(() => f.employees.report(session.token, 'general-ledger', '2026-09-01', '2026-09-30'), e => e.code === 'SECTION_FORBIDDEN');
});

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
  await f.employees.principal(fresh.token);
  f.advance(60001);
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

test('expired access can renew before the absolute limit after unrelated registry writes', async () => {
  const f = await setup(), id = await f.create(), session = await f.loginEmployee(await f.issue(id));
  f.advance(8 * 3600000 + 1);
  await assert.rejects(f.employees.principal(session.token), e => e.code === 'EMPLOYEE_SESSION_EXPIRED' && !e.message.includes('code'));
  await f.registry.transact(() => {});
  const renewed = await f.employees.refresh(session.token);
  assert.equal((await f.employees.principal(renewed.token)).employeeId, id);
  assert.equal(renewed.absoluteExpiresAt, session.absoluteExpiresAt);
});

test('concurrent renewal keeps in-flight requests valid and logout revokes the entire family', async () => {
  const f = await setup(), id = await f.create(), session = await f.loginEmployee(await f.issue(id));
  const [first, second] = await Promise.all([f.employees.refresh(session.token), f.employees.refresh(session.token)]);
  for (const token of [session.token, first.token, second.token]) await f.employees.principal(token);
  f.advance(60001);
  await assert.rejects(f.employees.principal(session.token), e => e.code === 'EMPLOYEE_SESSION_INVALID');
  await f.employees.logout(first.token);
  await assert.rejects(f.employees.principal(second.token), e => e.code === 'EMPLOYEE_SESSION_INVALID');
});

test('renewal checks current permissions and never resurrects revoked access', async () => {
  const f = await setup(), id = await f.create(), session = await f.loginEmployee(await f.issue(id));
  f.rows.RolePermissions.find(p => p.section === 'Invoices').isDeleted = true;
  const renewed = await f.employees.refresh(session.token);
  assert.ok(!renewed.employee.allowedSections.includes('Invoices'));
  await f.employees.revoke(f.owner, f.companyId, id);
  await assert.rejects(f.employees.refresh(renewed.token), e => e.code === 'EMPLOYEE_SESSION_INVALID');
});

test('old workspace and actor contexts fail before reading or submitting another employee data', async () => {
  const f = await setup(), id = await f.create(), session = await f.loginEmployee(await f.issue(id));
  const wrong = { companyId: 'x'.repeat(43), employeeId: id };
  await assert.rejects(f.employees.records(session.token, 'Invoices', wrong), e => e.code === 'WORKSPACE_CHANGED');
  await assert.rejects(f.employees.sync(session.token, { ...wrong, operations: [] }, {}), e => e.code === 'WORKSPACE_CHANGED');
  await assert.rejects(f.employees.sync(session.token, { companyId: f.companyId, employeeId: 'x'.repeat(43), operations: [] }, {}), e => e.code === 'WORKSPACE_CHANGED');
  assert.equal((await f.employees.principal(session.token)).employeeId, id);
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


test('admin controls employee editing; writes audit the employee and recheck revocation', async () => {
  const f = await setup();
  f.input.allowedSections.push('Customers');
  const id = await f.create(), login = await f.loginEmployee(await f.issue(id));
  const data = [];
  const businessSheets = {
    table: () => ({ headers: ['recordId', 'companyId', 'name'] }),
    read: async (_id, names) => Object.fromEntries(names.map(n => [n, n === 'Customers' ? structuredClone(data) : []])),
    write: async (_id, _table, row, values) => { data.push({ ...values, _row: row }); },
  };
  const operation = { operationId: 'employee_business_001', table: 'Customers', action: 'create', expectedVersion: 0, values: { name: 'Customer' } };
  const run = op => f.employees.sync(login.token, { operations: [op] }, { sheets: businessSheets });
  assert.equal((await run(operation)).results[0].error.code, 'WRITE_FORBIDDEN');
  await f.employees.save(f.owner, f.companyId, id, { ...f.input, writableSections: ['Customers'], expectedVersion: 1 }, 'grant_customer_edit_001');
  assert.deepEqual((await f.employees.principal(login.token)).writableSections, ['Customers']);
  const result = await run(operation);
  assert.equal(result.results[0].status, 'APPLIED');
  assert.equal(result.results[0].operationId, operation.operationId);
  assert.equal(data[0].createdBy, id);
  assert.equal((await run(operation)).results[0].replayed, true);
  assert.equal(data.length, 1);
  const read = businessSheets.read;
  businessSheets.read = async (...args) => {
    const grant = f.rows.RolePermissions.find(p => p.section === 'Customers');
    grant.action = 'read';
    return read(...args);
  };
  assert.equal((await run({ ...operation, operationId: 'employee_business_002' })).results[0].error.code, 'WRITE_FORBIDDEN');
  assert.equal(data.length, 1);
  assert.equal(f.company().businessWrite, undefined);
});

test('self-only employee sections cannot receive write grants', async () => {
  const f = await setup();
  await assert.rejects(() => f.employees.save(f.owner, f.companyId, null,
    { ...f.input, writableSections: ['Payroll'] }, 'invalid_self_write_001'), e => e.code === 'INVALID_EMPLOYEE');
});

for (const [table, child] of [['Invoices', 'InvoiceItems'], ['Quotations', 'QuotationItems']]) {
  test(`employee ${table} create/update survive renewal and reconcile uncertain saves once`, async () => {
    const f = await setup();
    f.input.role = 'Accountant';
    f.input.allowedSections = ['Invoices', 'Quotations', 'Customers'];
    f.input.writableSections = ['Invoices', 'Quotations'];
    const id = await f.create();
    let session = await f.loginEmployee(await f.issue(id));
    const data = Object.fromEntries(TABLES.map(t => [t.title, []]));
    data.Customers.push({ companyId: f.companyId, recordId: 'c'.repeat(43), name: 'Client', _row: 2 });
    let batches = 0, uncertain = true;
    const sheets = {
      table: name => TABLES.find(t => t.title === name),
      read: async (_id, names) => Object.fromEntries(names.map(name => [name, structuredClone(data[name])])),
      writeBatch: async (_id, changes) => {
        batches++;
        for (const { table, row, values } of changes) {
          const old = data[table].find(r => r._row === row);
          if (old) Object.assign(old, values); else data[table].push({ ...values, _row: row });
        }
        if (uncertain) { uncertain = false; throw new Error('Uncertain delivery'); }
      },
    };
    const values = { customerId: 'c'.repeat(43), issueDate: '2026-10-05', currency: 'AED',
      ...(table === 'Quotations' ? { validUntil: '2026-11-05' } : {}),
      items: [{ description: 'Service', quantity: 1, unitPrice: 100, discount: 0, taxRate: 5 }] };
    const operation = { operationId: `employee_create_${table}`, table, action: 'create', expectedVersion: 0, values };
    const run = op => f.employees.sync(session.token, { operations: [op] }, { sheets });
    assert.equal((await run(operation)).results[0].status, 'FAILED');
    session = await f.employees.refresh(session.token);
    assert.equal((await run(operation)).results[0].status, 'APPLIED');
    assert.equal(batches, 1);
    assert.equal(data[table].length, 1);
    assert.equal(data[child].length, 1);
    assert.equal(data[table][0].createdBy, id);
    f.advance(8 * 3600000 + 1);
    session = await f.employees.refresh(session.token);
    const update = { ...operation, operationId: `employee_update_${table}`, action: 'update', recordId: data[table][0].recordId,
      expectedVersion: 1, values: { ...values, notes: 'Revised' } };
    assert.equal((await run(update)).results[0].status, 'APPLIED');
    assert.equal((await run(update)).results[0].replayed, true);
    assert.equal(data[table][0].notes, 'Revised');
    assert.equal(data[table].length, 1);
    assert.equal(batches, 2);
  });
}
test('Staff task writes are limited to assigned status and comments, including under broadened sheet grants', async () => {
  const f = await setup(); f.input.allowedSections = ['Tasks'];
  const id = await f.create(), session = await f.loginEmployee(await f.issue(id));
  const own = opaque(), other = opaque();
  f.rows.Tasks = [
    { recordId: own, companyId: f.companyId, employeeId: id, title: 'Own task', status: 'TODO', priority: 'HIGH', dueDate: '2026-10-05', recordVersion: 1, _row: 2 },
    { recordId: other, companyId: f.companyId, employeeId: opaque(), title: 'Private task', status: 'TODO', priority: 'HIGH', dueDate: '2026-10-05', recordVersion: 1, _row: 3 },
  ];
  f.rows.TaskActivity = []; f.rows.TaskComments = [];
  const businessSheets = {
    table: name => TABLES.find(t => t.title === name), read: f.sheets.read, readReferences: f.sheets.read,
    write: (companyId, table, row, values) => f.sheets.write(companyId, [{ table, row, values }]),
    writeBatch: f.sheets.write,
  };
  const run = (table, action, recordId, values, expectedVersion = 1) => f.employees.sync(session.token,
    { companyId: f.companyId, employeeId: id, operations: [{ operationId: opaque(), table, action, ...(recordId ? { recordId } : {}), expectedVersion, values }] }, { sheets: businessSheets });
  assert.equal((await f.employees.records(session.token, 'Tasks')).length, 1);
  for (const [table, action, recordId, values, version] of [
    ['Tasks', 'update', own, { employeeId: f.rows.Tasks[1].employeeId }, 1],
    ['Tasks', 'update', other, { status: 'COMPLETED' }, 1],
    ['Tasks', 'create', null, { title: 'Forbidden' }, 0],
    ['TaskComments', 'create', null, { taskId: other, body: 'Forbidden' }, 0],
  ]) assert.equal((await run(table, action, recordId, values, version)).results[0].error.code, 'WRITE_FORBIDDEN');
  assert.equal((await run('Tasks', 'update', own, { status: 'IN_PROGRESS' })).results[0].status, 'APPLIED');
  assert.equal((await run('TaskComments', 'create', null, { taskId: own, body: 'Started' }, 0)).results[0].status, 'APPLIED');
  assert.equal(f.rows.Tasks[0].status, 'IN_PROGRESS'); assert.equal(f.rows.TaskComments.length, 1);
  const permission = f.rows.RolePermissions.find(p => p.section === 'Tasks'); permission.recordScope = 'COMPANY'; permission.action = 'write';
  assert.equal((await f.employees.records(session.token, 'Tasks')).length, 1);
  assert.equal((await run('Tasks', 'update', other, { status: 'COMPLETED' })).results[0].error.code, 'WRITE_FORBIDDEN');
});
test('document editors load scoped customer and company references without Customers or Settings grants', async () => {
  const f = await setup(); f.input.allowedSections = ['Quotations']; f.input.writableSections = ['Quotations'];
  const id = await f.create(), session = await f.loginEmployee(await f.issue(id));
  f.rows.Customers = [{recordId: opaque(), companyId: f.companyId, name: 'Client', email: 'client@example.com', privateField: 'hidden'}];
  f.rows.CompanyProfile = [{recordId: 'company', companyId: f.companyId, name: 'Company', currency: 'USD', accountNumber: 'secret', iban: 'secret'}];
  await assert.rejects(f.employees.records(session.token, 'Customers'), e => e.code === 'SECTION_FORBIDDEN');
  const customers = await f.employees.references(session.token, 'Customers', 'Quotations'); assert.equal(customers[0].name, 'Client'); assert.equal(customers[0].privateField, undefined);
  const company = await f.employees.references(session.token, 'CompanyProfile', 'Quotations'); assert.equal(company[0].currency, 'USD'); assert.equal(company[0].iban, undefined);
  await assert.rejects(f.employees.references(session.token, 'Customers', 'Invoices'), e => e.code === 'WRITE_FORBIDDEN');
  await assert.rejects(f.employees.references(session.token, 'EmployeeAccess', 'Quotations'), e => e.code === 'REFERENCE_FORBIDDEN');
  const read = f.sheets.read; f.sheets.read = async (...args) => { const rows = await read(...args); if (args[1]?.includes('Customers')) rows.RolePermissions.forEach(p => { p.action = 'none'; }); return rows; };
  await assert.rejects(f.employees.references(session.token, 'Customers', 'Quotations'), e => e.code === 'WRITE_FORBIDDEN');
});
