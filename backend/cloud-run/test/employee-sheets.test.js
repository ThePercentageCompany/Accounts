import test from 'node:test';
import assert from 'node:assert/strict';
import { EmployeeSheets } from '../src/employee-sheets.js';
import { TABLES } from '../src/company-schema.js';

const company = { resources: { spreadsheetId: 'private-sheet' } };
const workspace = { withGoogle: async (_id, action) => action('private-token', company) };
test('employee reads validate schema, tenant identity and duplicate record IDs', async () => {
  const table = TABLES.find(t => t.title === 'Employees');
  let records = [{ recordId: 'e', companyId: 'c', fullName: 'Employee', recordVersion: 1 }];
  const google = { rows: async (_token, _id, ranges) => {
    assert.deepEqual(ranges, ["'Employees'!A1:AZ10002"]);
    return [[table.headers, ...records.map(r => table.headers.map(h => r[h] ?? ''))]];
  } };
  const sheets = new EmployeeSheets(workspace, google);
  assert.equal((await sheets.read('c', ['Employees'])).Employees[0]._row, 2);
  records.push(records[0]);
  await assert.rejects(sheets.read('c', ['Employees']), e => e.code === 'RECORD_IDENTITY_MISMATCH');
  records = [{ recordId: 'e', companyId: 'other' }];
  await assert.rejects(sheets.read('c', ['Employees']), e => e.code === 'RECORD_IDENTITY_MISMATCH');
});
test('employee writes use atomic batch and typed scalar values, preserving untouched columns', async () => {
  let sent;
  const google = {
    metadata: async () => ({ sheets: [{ properties: { title: 'Employees', sheetId: 77, gridProperties: { rowCount: 1000 } } }] }),
    request: async (...args) => { sent = args; },
  };
  const sheets = new EmployeeSheets(workspace, google);
  await sheets.write('c', [{ table: 'Employees', row: 2, values: { fullName: '=literal text', recordVersion: 2, isDeleted: false } }]);
  assert.equal(sent[2], 'POST');
  assert.equal(sent[3].requests.length, 3);
  const changes = sent[3].requests.map(r => r.updateCells.rows[0].values[0].userEnteredValue);
  assert.deepEqual(changes, [{ stringValue: '=literal text' }, { numberValue: 2 }, { boolValue: false }]);
  assert.ok(!JSON.stringify(sent[3]).includes('formulaValue'));
  const salaryColumn = TABLES.find(t => t.title === 'Employees').headers.indexOf('basicSalary');
  assert.ok(sent[3].requests.every(r => r.updateCells.start.columnIndex !== salaryColumn));
});
test('pre-write Google failure can retry, post-submission uncertainty stays marked', async () => {
  const first = new EmployeeSheets({ withGoogle: async () => { throw new Error('offline'); } }, {});
  await assert.rejects(first.write('c', []), e => e.definitelyNotSubmitted === true);
  const second = new EmployeeSheets(workspace, {
    metadata: async () => ({ sheets: [] }), request: async () => { throw new Error('lost response'); },
  });
  await assert.rejects(second.write('c', []), e => !e.definitelyNotSubmitted);
});
