import test from 'node:test';
import assert from 'node:assert/strict';
import { trialBalance } from '../src/ledger-report.js';

function fixture() {
  return { Journals: [{ recordId: 'j', companyId: 'c', status: 'POSTED', date: '2026-09-27', totalDebit: 0.3, totalCredit: 0.3 }],
    JournalLines: [
      { companyId: 'c', journalId: 'j', lineNumber: 1, accountId: 'cash', accountName: 'Cash', accountGroup: 'Asset', debit: 0.3, credit: 0 },
      { companyId: 'c', journalId: 'j', lineNumber: 2, accountId: 'income', accountName: 'Income', accountGroup: 'Income', debit: 0, credit: 0.1 },
      { companyId: 'c', journalId: 'j', lineNumber: 3, accountId: 'income', accountName: 'Income', accountGroup: 'Income', debit: 0, credit: 0.2 },
    ] };
}
test('trial balance uses exact decimal balances and an inclusive cutoff', () => {
  const f = fixture();
  const result = trialBalance('c', '2026-09-27', f);
  assert.equal(result.totalDebit, '0.30'); assert.equal(result.totalCredit, '0.30');
  assert.equal(result.journalCount, 1); assert.equal(result.balanced, true);
  assert.equal(result.accounts[1].credit, '0.30');
  assert.equal(trialBalance('c', '2026-09-26', f).journalCount, 0);
});
test('draft, deleted and foreign journals cannot contribute to a report', () => {
  for (const change of [{ status: 'DRAFT' }, { isDeleted: true }, { companyId: 'other' }]) {
    const f = fixture(); Object.assign(f.Journals[0], change);
    assert.equal(trialBalance('c', '2026-09-27', f).totalDebit, '0.00');
  }
});
test('reversal nets each account to zero while retaining journal count', () => {
  const f = fixture();
  f.Journals.push({ ...f.Journals[0], recordId: 'reverse' });
  f.JournalLines.push(...f.JournalLines.map(l => ({ ...l, journalId: 'reverse', debit: l.credit, credit: l.debit })));
  const result = trialBalance('c', '2026-09-27', f);
  assert.equal(result.journalCount, 2); assert.equal(result.totalDebit, '0.00');
  assert.equal(result.totalCredit, '0.00');
});
test('corrupt ledger fails instead of displaying financial totals', () => {
  for (const mutate of [f => { f.JournalLines[0].debit = 1; },
    f => { f.JournalLines[2].accountGroup = 'Asset'; },
    f => { f.JournalLines[2].lineNumber = 1; },
    f => { f.Journals[0].date = 'bad'; },
    f => { f.JournalLines[0].isDeleted = true; },
    f => { f.JournalLines[2].accountName = 'Different'; },
    f => { f.Journals.push(f.Journals[0]); }]) {
    const f = fixture(); mutate(f); assert.throws(() => trialBalance('c', '2026-09-27', f));
  }
  assert.throws(() => trialBalance('c', '2026-02-30', fixture()), e => e.code === 'INVALID_REPORT_DATE');
});
