import test from 'node:test';
import assert from 'node:assert/strict';
import { companyLoanChanges } from '../../_shared/domain/company-loan-policy.js';
import { financialReport } from '../../_shared/domain/financial-report.js';
import { validateBusinessValues } from '../../_shared/domain/business-values.js';

const system = { companyId: 'c', updatedAt: 1, updatedBy: 'owner', isDeleted: false, syncStatus: 'SYNCED' };
const input = { lenderName: 'Example Bank', lenderType: 'BANK', date: '2026-10-01', principal: 1000,
  interestRate: 6, installmentAmount: 100, dueDate: '2027-10-01', paymentAccount: 'Bank', reference: 'LN-1', notes: '' };
function fixture() {
  const data = { FinancialPeriods: [], Journals: [], JournalLines: [] };
  const records = { read: async (_id, names) => Object.fromEntries(names.map(n => [n, data[n] || []])) };
  let row, count = 0;
  async function run(action, values = {}) {
    validateBusinessValues(values);
    const result = await companyLoanChanges(records, 'c', 'CompanyLoans', 'loan', action, row, values, system, String(++count));
    row = { ...row, ...result.values };
    for (const change of result.extra) data[change.table].push({ ...change.values, _row: change.row });
    return result;
  }
  const report = () => financialReport('c', 'dashboard', '2026-10-01', '2026-10-31', data, {});
  return { data, run, report, get row() { return row; } };
}

test('bank, institution and individual loans support receipt, installments, interest and full settlement', async () => {
  for (const lenderType of ['BANK', 'INSTITUTION', 'INDIVIDUAL']) {
    const f = fixture();
    await f.run('create', { ...input, lenderType });
    assert.equal(f.row.status, 'DRAFT');
    assert.equal(f.report().bank, '0.00');
    await f.run('loanPost');
    assert.equal(f.report().bank, '1000.00');
    assert.equal(f.report().totalLiabilities, '1000.00');
    assert.equal(f.report().totalIncome, '0.00');
    const payment = { lastRepaymentDate: '2026-10-05', principalPayment: 200, interestPayment: 5.25,
      paymentAccount: 'Bank', paymentReference: 'PAY-1' };
    await f.run('loanRepay', payment);
    assert.equal(f.row.outstandingBalance, 800);
    assert.equal(f.row.interestPaid, 5.25);
    assert.equal(f.report().bank, '794.75');
    assert.equal(f.report().totalLiabilities, '800.00');
    assert.equal(f.report().totalExpenses, '5.25');
    assert.equal(f.report().netProfit, '-5.25');
    await f.run('loanRepay', { ...payment, lastRepaymentDate: '2026-10-06', principalPayment: 800, interestPayment: 0 });
    assert.equal(f.row.status, 'REPAID');
    assert.equal(f.row.repaidAmount, 1000);
    assert.equal(f.row.outstandingBalance, 0);
    assert.equal(f.report().bank, '-5.25');
    assert.equal(f.report().totalLiabilities, '0.00');
    assert.equal(f.data.Journals.length, 3);
    await assert.rejects(f.run('loanRepay', payment));
  }
});

test('interest-only payments retain principal, cash payment uses the selected account', async () => {
  const f = fixture();
  await f.run('create', { ...input, paymentAccount: 'Cash' });
  await f.run('loanPost');
  await f.run('loanRepay', { lastRepaymentDate: '2026-10-02', principalPayment: 0, interestPayment: 10, paymentAccount: 'Cash' });
  assert.equal(f.row.outstandingBalance, 1000);
  assert.equal(f.row.status, 'ACTIVE');
  assert.equal(f.report().cash, '990.00');
  assert.equal(f.report().totalExpenses, '10.00');
});

test('invalid drafts, forged balances and unsupported actions are rejected', async () => {
  for (const patch of [{ lenderName: '' }, { lenderType: 'OTHER' }, { principal: 0 }, { principal: 0.001 },
    { interestRate: 101 }, { interestRate: 1.001 }, { installmentAmount: -1 }, { date: '2026-02-30' },
    { dueDate: '2026-09-01' }, { paymentAccount: 'Wallet' }, { status: 'ACTIVE' }, { outstandingBalance: 1 }]) {
    await assert.rejects(fixture().run('create', { ...input, ...patch }));
  }
  const f = fixture();
  await f.run('create', input);
  await assert.rejects(f.run('loanRepay', {}));
  await f.run('update', { principal: 1200 });
  assert.equal(f.row.outstandingBalance, 1200);
  await f.run('loanPost');
  for (const action of ['update', 'delete', 'loanPost', 'reverse']) await assert.rejects(f.run(action));
});

test('overpayments, zero payments, backdated payments and corrupt loan balances are rejected', async () => {
  const f = fixture();
  await f.run('create', input);
  await f.run('loanPost');
  const valid = { lastRepaymentDate: '2026-10-05', principalPayment: 100, interestPayment: 1, paymentAccount: 'Bank' };
  for (const patch of [{ principalPayment: 1001 }, { principalPayment: -1 }, { principalPayment: 0, interestPayment: 0 },
    { interestPayment: 0.001 }, { lastRepaymentDate: '2026-09-30' }, { outstandingBalance: 0 }, { paymentAccount: 'Other' }]) {
    await assert.rejects(f.run('loanRepay', { ...valid, ...patch }));
  }
  await f.run('loanRepay', valid);
  await assert.rejects(f.run('loanRepay', { ...valid, lastRepaymentDate: '2026-10-04' }));
  f.row.outstandingBalance = 1;
  await assert.rejects(f.run('loanRepay', { ...valid, principalPayment: 1 }), e => e.code === 'COMPANY_LOAN_LEDGER_CONFLICT');
});

test('closed financial periods block loan receipts and repayments', async () => {
  const f = fixture();
  await f.run('create', input);
  f.data.FinancialPeriods.push({ companyId: 'c', startDate: '2026-10-01', endDate: '2026-10-31', status: 'CLOSED' });
  await assert.rejects(f.run('loanPost'), e => e.code === 'PERIOD_CLOSED');
  f.data.FinancialPeriods[0].status = 'OPEN';
  await f.run('loanPost');
  f.data.FinancialPeriods[0].status = 'CLOSED';
  await assert.rejects(f.run('loanRepay', { lastRepaymentDate: '2026-10-05', principalPayment: 100, interestPayment: 1, paymentAccount: 'Bank' }), e => e.code === 'PERIOD_CLOSED');
});
