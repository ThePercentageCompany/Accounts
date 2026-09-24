import test from 'node:test';
import assert from 'node:assert/strict';
import { validateJournal } from '../src/journal-policy.js';

function fixture() {
  const journal = { recordId: 'j', companyId: 'c', status: 'DRAFT' };
  const lines = [
    { companyId: 'c', journalId: 'j', accountId: 'cash', lineNumber: 1, debit: 0.3, credit: 0 },
    { companyId: 'c', journalId: 'j', accountId: 'income', lineNumber: 2, debit: 0, credit: 0.1 },
    { companyId: 'c', journalId: 'j', accountId: 'income', lineNumber: 3, debit: 0, credit: 0.2 },
  ];
  const sheets = { read: async () => ({ Journals: [journal], JournalLines: lines }) };
  const post = (values = {}) => validateJournal(sheets, 'c', 'Journals', 'j', 'update', journal,
    { status: 'POSTED', totalDebit: 0.3, totalCredit: 0.3, ...values });
  return { journal, lines, sheets, post };
}
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
  await validateJournal(f.sheets, 'c', 'JournalLines', 'l', 'create', null, f.lines[0]);
  await assert.rejects(() => validateJournal(f.sheets, 'c', 'JournalLines', 'l', 'update', f.lines[0], { debit: 0 }), e => e.code === 'INVALID_JOURNAL_LINE');
});
