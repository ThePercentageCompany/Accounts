const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const crypto = require('node:crypto');

function gateway() {
  const records = new Map();
  const ctx = vm.createContext({
    console, Date, Math, JSON, Number, String, Array, RegExp, Error,
    Utilities: {
      getUuid: () => crypto.randomUUID(),
      DigestAlgorithm: {SHA_256: 'sha256'}, Charset: {UTF_8: 'utf8'},
      computeDigest: (_, value) => [...crypto.createHash('sha256').update(value).digest()],
    },
    CacheService: {getScriptCache: () => ({get: () => null, put() {}, remove() {}})},
    UrlFetchApp: {fetch: (_, options) => ({
      getResponseCode: () => options.headers.Authorization === 'Bearer owner-access-token-valid' ? 200 : 401,
      getContentText: () => JSON.stringify({email_verified: true, email: 'owner@example.com'}),
    })},
  });
  vm.runInContext(fs.readFileSync(__dirname + '/apps-script/EmployeeGateway.gs', 'utf8'), ctx);
  const employee = {id: 'employee-1', name: 'Alex', role: 'Sales', sections: ['Invoices']};
  ctx.egEmployee_ = (_, id) => {
    ctx.egRequire_(id === employee.id && !employee.disabled, 'Employee access is disabled.', 'UNAUTHORIZED');
    return employee;
  };
  ctx.egPrivateGet_ = (_, key) => structuredClone(records.get(key) || null);
  ctx.egPrivatePut_ = (_, value) => records.set(value.key, structuredClone(value));
  ctx.egTable_ = () => ({rows: []});
  const config = {spreadsheetId: 'sheet-1', driveFolderId: 'folder-1', ownerEmail: 'owner@example.com', pepper: 'test-pepper'};
  const data = {employeeId: employee.id, spreadsheetId: config.spreadsheetId, driveFolderId: config.driveFolderId};
  return {ctx, employee, config, data, records};
}

test('provision requires owner authentication and matching workspace', () => {
  const {ctx, config, data, records} = gateway();
  assert.throws(() => ctx.egProvision_(config, data, 'invalid-token-000000000'), /Owner Google session expired/);
  assert.throws(() => ctx.egProvision_(config, {...data, spreadsheetId: 'other-sheet'}, 'owner-access-token-valid'), /another workspace/);
  assert.throws(() => ctx.egProvision_(config, {...data, driveFolderId: 'other-folder'}, 'owner-access-token-valid'), /another workspace/);
  assert.equal(records.size, 0);
});

test('private code signs in and role changes apply to the same session', () => {
  const {ctx, employee, config, data, records} = gateway();
  const provision = ctx.egProvision_(config, data, 'owner-access-token-valid');
  assert.match(provision.loginCode, /^[A-F0-9]{4}(?:-[A-F0-9]{4}){4}$/);
  assert.equal(JSON.stringify([...records.values()]).includes(provision.loginCode), false);
  const login = ctx.egLogin_(config, {employeeId: employee.id, loginCode: provision.loginCode.toLowerCase()});
  assert.equal(login.workspace.employeeRole, 'Sales');
  assert.equal(ctx.egCanWrite_(ctx.egAuthenticate_(config, login.sessionToken).employee, 'Finance', []), false);
  employee.sections = ['Income & Expenses'];
  employee.role = 'Accountant';
  const auth = ctx.egAuthenticate_(config, login.sessionToken);
  assert.equal(ctx.egCanWrite_(auth.employee, 'Invoices', []), false);
  assert.equal(ctx.egCanWrite_(auth.employee, 'Finance', []), true);
});

test('existing credentials are not exposed again and reset revokes sessions', () => {
  const {ctx, config, data} = gateway();
  const first = ctx.egProvision_(config, data, 'owner-access-token-valid');
  const login = ctx.egLogin_(config, {employeeId: data.employeeId, loginCode: first.loginCode});
  assert.equal(ctx.egProvision_(config, data, 'owner-access-token-valid').loginCode, undefined);
  const reset = ctx.egProvision_(config, {...data, reset: true}, 'owner-access-token-valid');
  assert.notEqual(reset.loginCode, first.loginCode);
  assert.throws(() => ctx.egAuthenticate_(config, login.sessionToken), /reset or revoked/);
  assert.throws(() => ctx.egLogin_(config, {employeeId: data.employeeId, loginCode: first.loginCode}), /incorrect or has been reset/);
});

test('disabled employees and incorrect staff codes cannot log in', () => {
  const {ctx, employee, config, data} = gateway();
  const provision = ctx.egProvision_(config, data, 'owner-access-token-valid');
  assert.throws(() => ctx.egLogin_(config, {employeeId: data.employeeId, loginCode: 'EMP001'}), /incorrect or has been reset/);
  employee.disabled = true;
  assert.throws(() => ctx.egLogin_(config, {employeeId: data.employeeId, loginCode: provision.loginCode}), /disabled/);
});

test('employee HR access cannot grant permissions or change login identity', () => {
  const {ctx} = gateway();
  const row = Array(27).fill('');
  row[0] = 'employee-1'; row[1] = 'EMP001'; row[11] = 'active';
  row[22] = 'Staff'; row[23] = 'Office & Attendance';
  const changed = row.slice(); changed[23] = 'Employees, Payroll';
  assert.throws(() => ctx.egCheckEmployeeEdit_(row, changed), /Only the owner/);
});
