import test from 'node:test';
import assert from 'node:assert/strict';
import { trialBalance, profitAndLoss, balanceSheet, dashboard, generalLedger } from '../src/ledger-report.js';

function fixture() {
  return { Journals: [{ recordId: 'j', companyId: 'c', status: 'POSTED', date: '2026-09-27', totalDebit: 0.3, totalCredit: 0.3 }],
    JournalLines: [
      { companyId: 'c', journalId: 'j', lineNumber: 1, accountId: 'cash', accountName: 'Cash', accountGroup: 'Asset', debit: 0.3, credit: 0 },
      { companyId: 'c', journalId: 'j', lineNumber: 2, accountId: 'income', accountName: 'Income', accountGroup: 'Income', debit: 0, credit: 0.1 },
      { companyId: 'c', journalId: 'j', lineNumber: 3, accountId: 'income', accountName: 'Income', accountGroup: 'Income', debit: 0, credit: 0.2 },
    ] };
}

test('dashboard reconciles period profit with cumulative assets and equity', () => {
  const f = fixture(); f.JournalLines[0].accountId = 'cash_in_hand';
  const result = dashboard('c', '2026-09-27', '2026-09-30', f);
  assert.equal(result.netProfit, '0.30'); assert.equal(result.cash, '0.30');
  assert.equal(result.bank, '0.00'); assert.equal(result.totalAssets, result.totalEquity);
  const later = dashboard('c', '2026-09-28', '2026-09-30', f);
  assert.equal(later.netProfit, '0.00'); assert.equal(later.totalAssets, '0.30');
  f.JournalLines[0].debit = 1;
  assert.throws(() => dashboard('c', '2026-09-28', '2026-09-30', f));
});

test('general ledger carries opening balances, signed reversals and exact closing balances', () => {
  const f = fixture();
  f.Journals.push({ ...f.Journals[0], recordId: 'reverse', date: '2026-10-01' });
  f.JournalLines.push(...f.JournalLines.map(l => ({ ...l, journalId: 'reverse', debit: l.credit, credit: l.debit })));
  const ledger = generalLedger('c', '2026-10-01', '2026-10-01', f);
  assert.equal(ledger.journalCount, 1);
  assert.equal(ledger.accounts[0].opening, '0.30'); assert.equal(ledger.accounts[0].closing, '0.00');
  assert.equal(ledger.accounts[0].credit, '0.30'); assert.equal(ledger.accounts[0].entries[0].balance, '0.00');
  assert.equal(ledger.accounts[1].opening, '-0.30'); assert.equal(ledger.accounts[1].debit, '0.30');
  const cutoff = generalLedger('c', '2026-09-28', '2026-09-30', f);
  assert.equal(cutoff.accounts[0].entries.length, 0); assert.equal(cutoff.accounts[0].closing, '0.30');
  for (const account of generalLedger('c', '2026-09-01', '2026-10-01', f).accounts) {
    assert.equal(account.closing, '0.00');
  }
  assert.throws(() => generalLedger('c', '2026-10-02', '2026-10-01', f), e => e.code === 'INVALID_REPORT_DATE');
});

test('balance sheet includes cumulative earnings and excludes future postings', () => {
  const result = balanceSheet('c', '2026-09-27', fixture());
  assert.equal(result.totalAssets, '0.30'); assert.equal(result.accumulatedEarnings, '0.30');
  assert.equal(result.totalLiabilitiesAndEquity, '0.30'); assert.equal(result.balanced, true);
  assert.equal(result.accounts.length, 1);
  assert.equal(balanceSheet('c', '2026-09-26', fixture()).totalAssets, '0.00');
});

test('equity closing transfer is not counted twice and contra assets retain their sign', () => {
  const f = fixture();
  f.Journals.push({ ...f.Journals[0], recordId: 'close' });
  f.JournalLines.push(
    { ...f.JournalLines[1], journalId: 'close', lineNumber: 1, debit: 0.3, credit: 0 },
    { ...f.JournalLines[1], journalId: 'close', lineNumber: 2, accountId: 'retained', accountName: 'Retained Earnings', accountGroup: 'Equity', credit: 0.3 });
  let result = balanceSheet('c', '2026-09-27', f);
  assert.equal(result.postedEquity, '0.30'); assert.equal(result.accumulatedEarnings, '0.00');
  assert.equal(result.totalEquity, '0.30');
  const loss = fixture();
  loss.JournalLines[0].accountGroup = 'Expense';
  for (const l of loss.JournalLines.slice(1)) { l.accountGroup = 'Asset'; l.accountName = 'Accumulated Depreciation'; }
  result = balanceSheet('c', '2026-09-27', loss);
  assert.equal(result.totalAssets, '-0.30'); assert.equal(result.accumulatedEarnings, '-0.30');
  assert.equal(result.totalLiabilitiesAndEquity, '-0.30');
});

test('profit and loss includes both period boundaries and excludes balance sheet accounts', () => {
  const f = fixture();
  const result = profitAndLoss('c', '2026-09-27', '2026-09-27', f);
  assert.equal(result.totalIncome, '0.30'); assert.equal(result.totalExpenses, '0.00');
  assert.equal(result.netProfit, '0.30'); assert.equal(result.accounts.length, 1);
  assert.equal(profitAndLoss('c', '2026-09-28', '2026-09-30', f).netProfit, '0.00');
  assert.throws(() => profitAndLoss('c', '2026-10-01', '2026-09-27', f), e => e.code === 'INVALID_REPORT_DATE');
  assert.throws(() => profitAndLoss('c', null, '2026-09-27', f), e => e.code === 'INVALID_REPORT_DATE');
});

test('expense losses and later-period income reversals retain negative signs', () => {
  const expense = fixture();
  for (const line of expense.JournalLines) {
    [line.debit, line.credit] = [line.credit, line.debit];
    if (line.accountGroup === 'Income') { line.accountGroup = 'Expense'; line.accountName = 'Expense'; }
  }
  assert.equal(profitAndLoss('c', '2026-09-01', '2026-09-30', expense).netProfit, '-0.30');
  const f = fixture();
  f.Journals.push({ ...f.Journals[0], recordId: 'rev', date: '2026-10-01' });
  f.JournalLines.push(...f.JournalLines.map(l => ({ ...l, journalId: 'rev', debit: l.credit, credit: l.debit })));
  assert.equal(profitAndLoss('c', '2026-10-01', '2026-10-31', f).totalIncome, '-0.30');
  assert.equal(profitAndLoss('c', '2026-09-01', '2026-10-31', f).netProfit, '0.00');
});
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
