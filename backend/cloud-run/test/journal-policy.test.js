import test from 'node:test';
import assert from 'node:assert/strict';
import { validateJournal } from '../src/journal-policy.js';

function fixture() {
  const journal = { recordId: 'j', companyId: 'c', status: 'DRAFT', date: '2026-09-26' };
  const lines = [
    { companyId: 'c', journalId: 'j', accountId: 'cash', lineNumber: 1, debit: 0.3, credit: 0 },
    { companyId: 'c', journalId: 'j', accountId: 'income', lineNumber: 2, debit: 0, credit: 0.1 },
    { companyId: 'c', journalId: 'j', accountId: 'income', lineNumber: 3, debit: 0, credit: 0.2 },
  ];
  lines.forEach((line, index) => { line.recordId = `l${index + 1}`; });
  const periods = [];
  const sheets = { read: async () => ({ Journals: [journal], JournalLines: lines, FinancialPeriods: periods }) };
  const post = (values = {}) => validateJournal(sheets, 'c', 'Journals', 'j', 'update', journal,
    { status: 'POSTED', totalDebit: 0.3, totalCredit: 0.3, ...values });
  return { journal, lines, sheets, post, periods };
}

test('journal posting respects closed periods including both date boundaries', async () => {
  const f = fixture();
  f.periods.push({ companyId: 'c', startDate: '2026-09-01', endDate: '2026-09-30', status: 'CLOSED' });
  for (const date of ['2026-09-01', '2026-09-26', '2026-09-30']) {
    await assert.rejects(() => f.post({ date }), e => e.code === 'PERIOD_CLOSED');
  }
  await f.post({ date: '2026-10-01' });
  await assert.rejects(() => f.post({ date: '2026-02-30' }), e => e.code === 'INVALID_JOURNAL_DATE');
});
test('posting balances decimal amounts exactly and rejects forged header totals', async () => {
  const f = fixture(); await f.post();
  await assert.rejects(() => f.post({ totalDebit: 1 }), e => e.code === 'JOURNAL_UNBALANCED');
  f.lines[2].credit = 0.21;
  await assert.rejects(() => f.post(), e => e.code === 'JOURNAL_UNBALANCED');
});
test('posting rejects malformed or deleted lines', async () => {
  for (const change of [{ credit: 0.201 }, { lineNumber: 2 }, { debit: 0.1 }, { accountId: '' }, { isDeleted: true }]) {
    const f = fixture(); Object.assign(f.lines[2], change);
    await assert.rejects(() => f.post());
  }
});
test('posted journal and line mutations are locked including moving a line away', async () => {
  const f = fixture(); f.journal.status = 'POSTED';
  for (const action of ['update', 'delete']) {
    await assert.rejects(() => validateJournal(f.sheets, 'c', 'Journals', 'j', action, f.journal, { status: 'DRAFT' }), e => e.code === 'JOURNAL_LOCKED');
    await assert.rejects(() => validateJournal(f.sheets, 'c', 'JournalLines', 'l', action, f.lines[0], { journalId: 'other' }), e => e.code === 'JOURNAL_LOCKED');
  }
});
test('journals begin as drafts and draft lines require one-sided amounts', async () => {
  const f = fixture();
  await assert.rejects(() => validateJournal(f.sheets, 'c', 'Journals', 'j', 'create', null, { status: 'POSTED' }), e => e.code === 'INVALID_JOURNAL_STATUS');
  await validateJournal(f.sheets, 'c', 'JournalLines', 'l', 'create', null, { ...f.lines[0], lineNumber: 4 });
  await assert.rejects(() => validateJournal(f.sheets, 'c', 'JournalLines', 'l', 'update', f.lines[0], { debit: 0 }), e => e.code === 'INVALID_JOURNAL_LINE');
});

test('draft line saves reject duplicate numbers on create, renumber and move', async () => {
  const f = fixture();
  const save = (recordId, old, values) => validateJournal(f.sheets, 'c', 'JournalLines', recordId,
    old ? 'update' : 'create', old, values);
  await assert.rejects(() => save('new', null, f.lines[0]), e => e.code === 'INVALID_JOURNAL_LINE');
  await assert.rejects(() => save('l1', f.lines[0], { lineNumber: 2 }), e => e.code === 'INVALID_JOURNAL_LINE');
  await save('l1', f.lines[0], { debit: 0.4 });
  const destination = { recordId: 'other', companyId: 'c', status: 'DRAFT' };
  f.lines.push({ ...f.lines[1], recordId: 'destination-line', journalId: 'other', lineNumber: 1 });
  const read = f.sheets.read;
  f.sheets.read = async (...args) => ({ ...await read(...args), Journals: [f.journal, destination] });
  await assert.rejects(() => save('l1', f.lines[0], { journalId: 'other' }), e => e.code === 'INVALID_JOURNAL_LINE');
});

test('draft number uniqueness ignores other tenants, journals and deleted records', async () => {
  const f = fixture();
  f.lines[0].isDeleted = true;
  f.lines.push({ ...f.lines[0], recordId: 'foreign', isDeleted: false, companyId: 'foreign' });
  f.lines.push({ ...f.lines[0], recordId: 'other-journal', isDeleted: false, journalId: 'other' });
  await validateJournal(f.sheets, 'c', 'JournalLines', 'new', 'create', null,
    { ...f.lines[0], recordId: 'new', isDeleted: false });
  // Deleting a corrupt duplicate remains possible so the owner can repair a draft.
  await validateJournal(f.sheets, 'c', 'JournalLines', 'l2', 'delete', f.lines[1], {});
});
