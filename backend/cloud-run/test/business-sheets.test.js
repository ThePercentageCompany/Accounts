import test from 'node:test';
import assert from 'node:assert/strict';
import { BusinessSheets } from '../src/business-sheets.js';

function fixture() {
  const calls = [];
  const google = {
    metadata: async () => ({ sheets: ['Income', 'Journals', 'JournalLines'].map((title, sheetId) =>
      ({ properties: { title, sheetId, gridProperties: { rowCount: 2 } } })) }),
    request: async (...args) => { calls.push(args); },
  };
  const workspace = { withGoogle: async (id, action) => {
    assert.equal(id, 'company');
    return action('test-token', { resources: { spreadsheetId: 'company-sheet' } });
  } };
  return { sheets: new BusinessSheets(workspace, google), calls, google };
}

test('source and journal changes use one atomic request with literal typed cells', async () => {
  const f = fixture();
  await f.sheets.writeBatch('company', [
    { table: 'Income', row: 2, values: { description: '=not a formula', amount: 10, isDeleted: false } },
    { table: 'Journals', row: 3, values: { status: 'POSTED' } },
    { table: 'JournalLines', row: 5, values: { debit: 10 } },
    { table: 'JournalLines', row: 3, values: { credit: 10 } },
  ]);
  assert.equal(f.calls.length, 1);
  assert.equal(f.calls[0][1], 'https://sheets.googleapis.com/v4/spreadsheets/company-sheet:batchUpdate');
  const requests = f.calls[0][3].requests;
  const growth = requests.filter(r => r.updateSheetProperties).map(r => r.updateSheetProperties.properties);
  assert.deepEqual(growth, [{ sheetId: 1, gridProperties: { rowCount: 103 } },
    { sheetId: 2, gridProperties: { rowCount: 105 } }]);
  const cells = requests.filter(r => r.updateCells).map(r => r.updateCells.rows[0].values[0].userEnteredValue);
  assert.deepEqual(cells.slice(0, 3), [{ stringValue: '=not a formula' }, { numberValue: 10 }, { boolValue: false }]);
  assert.equal(cells.length, 6);
});

test('invalid batch members prevent every write including valid preceding members', async () => {
  const valid = { table: 'Income', row: 2, values: { amount: 10 } };
  for (const invalid of [valid,
    { ...valid, row: 1 }, { ...valid, row: 10002 },
    { ...valid, row: 3, values: { amount: Infinity } },
    { ...valid, row: 3, values: { companyId: 'other' } },
    { ...valid, row: 3, values: {} },
    { ...valid, row: 3, values: { unknown: 1 } },
    { ...valid, table: 'Employees' },
    { ...valid, table: 'Expenses' }, // Missing from Google metadata.
  ]) {
    const f = fixture();
    await assert.rejects(f.sheets.writeBatch('company', [valid, invalid]), e => e.definitelyNotSubmitted === true);
    assert.equal(f.calls.length, 0);
  }
  for (const changes of [[], Array(101).fill(valid)]) {
    const f = fixture();
    await assert.rejects(f.sheets.writeBatch('company', changes), e => e.code === 'INVALID_BATCH');
    assert.equal(f.calls.length, 0);
  }
});

test('single-record writes share batch handling and keep uncertain submissions distinct', async () => {
  const f = fixture();
  await f.sheets.write('company', 'Income', 2, { amount: 10 });
  assert.equal(f.calls.length, 1);
  f.google.request = async () => { throw new Error('response lost'); };
  await assert.rejects(f.sheets.write('company', 'Income', 2, { amount: 11 }), e => !e.definitelyNotSubmitted);
  f.google.metadata = async () => { throw new Error('metadata unavailable'); };
  await assert.rejects(f.sheets.write('company', 'Income', 2, { amount: 11 }), e => e.definitelyNotSubmitted === true);
});
