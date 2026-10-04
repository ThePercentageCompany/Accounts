import test from 'node:test';
import assert from 'node:assert/strict';
import { financialReport, movementTrialBalance, variance } from '../src/financial-report.js';
import { reportConfiguration, validateReportConfiguration } from '../src/report-configuration.js';
import { BusinessService } from '../src/business-service.js';
import { fixture as serviceFixture } from './helpers.js';

const config = accounts => ({ ...reportConfiguration({}), version: 1, accounts });
const mapping = (accountId, group, role, code = accountId) => ({ accountId, code, name: accountId, group, role,
  normalSide: ['Asset', 'Expense'].includes(group) ? 'Debit' : 'Credit', active: true });
function fixture() {
  const rows = { Journals: [], JournalLines: [], CompanyProfile: [{ companyId: 'c', name: 'Actual company', currency: 'AED' }] };
  function post(id, date, lines) {
    const total = lines.reduce((n, l) => n + (l[2] > 0 ? l[2] : 0), 0);
    rows.Journals.push({ recordId: id, companyId: 'c', date, status: 'POSTED', number: id, totalDebit: total, totalCredit: total });
    lines.forEach(([accountId, accountGroup, value], i) => rows.JournalLines.push({ companyId: 'c', journalId: id, lineNumber: i + 1,
      accountId, accountName: accountId, accountGroup, debit: value > 0 ? value : 0, credit: value < 0 ? -value : 0 }));
  }
  return { rows, post };
}

test('movement trial separates opening, gross movements and net closing exactly', () => {
  const f = fixture();
  f.post('open', '2026-08-31', [['cash', 'Asset', 0.3], ['income', 'Income', -0.3]]);
  f.post('move', '2026-09-01', [['expense', 'Expense', 0.1], ['cash', 'Asset', -0.1]]);
  const r = movementTrialBalance('c', '2026-09-01', '2026-09-30', f.rows);
  const cash = r.accounts.find(a => a.accountId === 'cash');
  assert.equal(cash.openingDebit, '0.30'); assert.equal(cash.periodCredit, '0.10'); assert.equal(cash.debit, '0.20');
  assert.equal(r.totalOpeningDebit, '0.30'); assert.equal(r.totalOpeningCredit, '0.30');
  assert.equal(r.totalPeriodDebit, '0.10'); assert.equal(r.totalPeriodCredit, '0.10');
  assert.equal(r.openingDifference, '0.00'); assert.equal(r.periodDifference, '0.00'); assert.equal(r.closingDifference, '0.00');
  assert.equal(r.accounts.find(a => a.accountId === 'income').credit, '0.30');
});

test('zero comparison is defined only for zero current and decimals stay exact', () => {
  assert.deepEqual(variance('0.00', '0.00'), { amount: '0.00', percent: '0.00' });
  assert.deepEqual(variance('0.30', '0.00'), { amount: '0.30', percent: null });
  assert.deepEqual(variance('0.30', '0.20'), { amount: '0.10', percent: '50.00' });
  assert.deepEqual(variance('-0.30', '-0.20'), { amount: '-0.10', percent: '-50.00' });
  assert.equal(variance('90071992547409.93', '90071992547409.92').amount, '0.01');
});

test('comparisons retain accounts that exist only in the previous period', () => {
  const f = fixture();
  f.post('old', '2026-08-31', [['cash', 'Asset', 1], ['income', 'Income', -1]]);
  const r = financialReport('c', 'profit-and-loss', '2026-09-01', '2026-09-30', f.rows, { name: 'c' },
    { compareFrom: '2026-08-01', compareAsOf: '2026-08-31' }, 0);
  assert.equal(r.accounts.length, 1); assert.equal(r.accounts[0].amount, '0.00');
  assert.equal(r.accounts[0].comparison.previous, '1.00'); assert.equal(r.accounts[0].comparison.percent, '-100.00');
  assert.equal(r.accounts[0].comparison.favorable, false);
  assert.equal(r.metadata.companyName, 'Actual company'); assert.equal(r.metadata.generatedAt, '1970-01-01T00:00:00.000Z');
});

test('reviewed classifications produce gross and operating profit without inferred categories', () => {
  const f = fixture();
  f.post('sale', '2026-09-02', [['cash', 'Asset', 100], ['revenue', 'Income', -100]]);
  f.post('cost', '2026-09-03', [['cogs', 'Expense', 30], ['cash', 'Asset', -30]]);
  f.post('rent', '2026-09-04', [['rent', 'Expense', 20], ['cash', 'Asset', -20]]);
  const company = { reporting: config([mapping('revenue', 'Income', 'revenue'), mapping('cogs', 'Expense', 'cogs'), mapping('rent', 'Expense', 'operating-expenses')]) };
  const r = financialReport('c', 'profit-and-loss', '2026-09-01', '2026-09-30', f.rows, company);
  assert.equal(r.grossProfit, '70.00'); assert.equal(r.operatingProfit, '50.00'); assert.equal(r.netProfit, '50.00');
  assert.equal(r.grossMargin, '70.00'); assert.equal(r.netMargin, '50.00');
  const unclassified = financialReport('c', 'profit-and-loss', '2026-09-01', '2026-09-30', f.rows, {});
  assert.equal(unclassified.classificationComplete, false); assert.equal(unclassified.grossProfit, undefined);
  assert.equal(unclassified.accounts[0].section.includes('Unclassified'), true);
});

test('contra revenue discounts and returns reduce net revenue', () => {
  const f = fixture();
  f.post('sale', '2026-09-02', [['cash', 'Asset', 100], ['revenue', 'Income', -100]]);
  f.post('return', '2026-09-03', [['returns', 'Income', 20], ['cash', 'Asset', -20]]);
  const company = { reporting: config([mapping('revenue', 'Income', 'revenue'), { ...mapping('returns', 'Income', 'sales-returns'), normalSide: 'Debit' }]) };
  const r = financialReport('c', 'profit-and-loss', '2026-09-01', '2026-09-30', f.rows, company);
  assert.equal(r.netRevenue, '80.00'); assert.equal(r.grossProfit, '80.00'); assert.equal(r.netProfit, '80.00');
  assert.equal(r.accounts.find(a => a.accountId === 'returns').abnormal, false);
});

test('monthly trends use real posting dates and preserve partial boundaries', () => {
  const f = fixture();
  f.post('before', '2026-08-01', [['cash', 'Asset', 1], ['income', 'Income', -1]]);
  f.post('aug', '2026-08-31', [['cash', 'Asset', 2], ['income', 'Income', -2]]);
  f.post('sep', '2026-09-01', [['cash', 'Asset', 3], ['income', 'Income', -3]]);
  const r = financialReport('c', 'dashboard', '2026-08-15', '2026-09-15', f.rows, {});
  assert.deepEqual(r.trends.map(t => [t.from, t.asOf, t.income]), [['2026-08-15', '2026-08-31', '2.00'], ['2026-09-01', '2026-09-15', '3.00']]);
  assert.equal(r.totalIncome, '5.00'); assert.equal(r.totalAssets, '6.00');
});

test('prior corrupt postings and mapping conflicts fail before activity is exposed', () => {
  const f = fixture(); f.post('bad', '2026-08-01', [['cash', 'Asset', 1], ['income', 'Income', -1]]);
  f.rows.JournalLines[0].debit = 2;
  assert.throws(() => financialReport('c', 'profit-and-loss', '2026-09-01', '2026-09-30', f.rows, {}), e => e.code === 'LEDGER_INTEGRITY');
  f.rows.JournalLines[0].debit = 1;
  assert.throws(() => financialReport('c', 'balance-sheet', null, '2026-09-30', f.rows,
    { reporting: config([mapping('cash', 'Liability', 'payables')]) }), e => e.code === 'REPORT_CLASSIFICATION_CONFLICT');
});

test('configuration rejects invalid classifications, duplicate codes and authority fields', () => {
  const settings = reportConfiguration({}); delete settings.version;
  settings.accounts = [mapping('cash', 'Asset', 'cash')];
  assert.equal(validateReportConfiguration({ expectedVersion: 0, settings }).accounts.length, 1);
  for (const mutate of [s => { s.accounts[0].role = 'revenue'; }, s => { s.accounts.push({ ...s.accounts[0], accountId: 'other' }); },
    s => { s.financialYearDay = 31; }, s => { s.ownerId = 'foreign'; }]) {
    const value = structuredClone(settings); mutate(value);
    assert.throws(() => validateReportConfiguration({ expectedVersion: 0, settings: value }));
  }
});

test('configuration writes are owner-only, versioned and idempotently reviewable on reload', async () => {
  const f = serviceFixture(), token = await f.login(), registration = await f.service.createCompany(token, { name: 'Reporting' }, 'report_config_test_1');
  const companyId = registration.company.companyId;
  await f.registry.transact(s => { s.companies[companyId].stage = 'READY'; });
  const business = new BusinessService({ accounts: f.service, sheets: { async read() { return { JournalLines: [] }; } } });
  const settings = await business.reportSettings(token, companyId), version = settings.version; delete settings.version;
  const saved = await business.saveReportSettings(token, companyId, { expectedVersion: version, settings });
  assert.equal(saved.version, 1);
  await assert.rejects(() => business.saveReportSettings(token, companyId, { expectedVersion: 0, settings }), e => e.code === 'VERSION_CONFLICT');
  const other = await f.login('other');
  await assert.rejects(() => business.reportSettings(other, companyId));
  await assert.rejects(() => business.saveReportSettings(other, companyId, { expectedVersion: 1, settings }));
  assert.equal((await business.reportSettings(token, companyId)).version, 1);
});
