import test from 'node:test';
import assert from 'node:assert/strict';
import { payrollChanges } from '../src/payroll-policy.js';

const employeeId = 'e'.repeat(43);
function fixture() {
  const data = { Employees: [{ companyId: 'c', recordId: employeeId, employmentStatus: 'ACTIVE', basicSalary: 5000, allowances: 500 }],
    Overtime: [{ companyId: 'c', recordId: 'o', employeeId, date: '2026-09-10', hours: 2.5, rate: 40,
      approvalStatus: 'APPROVED' }], Payroll: [], FinancialPeriods: [], Journals: [], JournalLines: [] };
  const read = async (_id, names) => Object.fromEntries(names.map(name => [name, data[name] || []]));
  return { data, sheets: { read, readReferences: read } };
}
const system = { companyId: 'c', updatedAt: 1, updatedBy: 'owner', idempotencyKey: 'marker', isDeleted: false, syncStatus: 'SYNCED' };

test('draft payroll derives salary and approved overtime exactly', async () => {
  const f = fixture();
  const result = await payrollChanges(f.sheets, 'c', 'Payroll', 'p', 'create', null,
    { month: '2026-09', employeeId, bonus: 250, deductions: 100 }, system, 'op');
  assert.deepEqual(result.values, { month: '2026-09', employeeId, basicSalary: 5000, allowances: 500,
    overtimeAmount: 100, bonus: 250, deductions: 100, grossSalary: 5850, netSalary: 5750,
    status: 'DRAFT', paidDate: '', paymentAccount: '', paymentReference: '' });
});

test('approval accrues gross payroll and liabilities in a balanced journal', async () => {
  const f = fixture();
  const old = { companyId: 'c', recordId: 'p', month: '2026-09', employeeId, status: 'DRAFT',
    basicSalary: 5000, allowances: 500, overtimeAmount: 100, bonus: 250, deductions: 100,
    grossSalary: 5850, netSalary: 5750 };
  f.data.Payroll.push(old);
  const result = await payrollChanges(f.sheets, 'c', 'Payroll', 'p', 'approve', old, {}, system, 'approve-op');
  assert.equal(result.values.status, 'APPROVED'); assert.equal(result.extra[0].values.date, '2026-09-30');
  const lines = result.extra.slice(1).map(change => change.values);
  assert.equal(lines.reduce((sum, line) => sum + line.debit, 0), 5850);
  assert.equal(lines.reduce((sum, line) => sum + line.credit, 0), 5850);
});

test('payroll payment settles net payable through Cash or Bank', async () => {
  const f = fixture(), old = { companyId: 'c', recordId: 'p', month: '2026-09', employeeId,
    status: 'APPROVED', netSalary: 5750 };
  const result = await payrollChanges(f.sheets, 'c', 'Payroll', 'p', 'payrollPay', old,
    { paidDate: '2026-10-01', paymentAccount: 'Bank', paymentReference: 'WPS' }, system, 'pay-op');
  assert.equal(result.values.status, 'PAID'); assert.equal(result.extra[0].values.sourceType, 'PayrollPayment');
  assert.equal(result.extra[2].values.accountId, 'bank'); assert.equal(result.extra[2].values.credit, 5750);
});

test('paid payroll reversal refunds payment then reverses its accrual', async () => {
  const f = fixture(), old = { companyId: 'c', recordId: 'p', month: '2026-09', employeeId,
    status: 'PAID', netSalary: 5750 };
  f.data.Journals = [
    { companyId: 'c', recordId: 'approval', _row: 2, sourceId: 'p', sourceType: 'Payroll', status: 'POSTED', date: '2026-09-30', totalDebit: 5850, totalCredit: 5850 },
    { companyId: 'c', recordId: 'payment', _row: 3, sourceId: 'p', sourceType: 'PayrollPayment', status: 'POSTED', date: '2026-10-01', totalDebit: 5750, totalCredit: 5750 },
  ];
  f.data.JournalLines = [
    { companyId: 'c', _row: 2, journalId: 'approval', lineNumber: 1, accountId: 'expense', accountName: 'Salary Expense', accountGroup: 'Expense', debit: 5850, credit: 0 },
    { companyId: 'c', _row: 3, journalId: 'approval', lineNumber: 2, accountId: 'payable', accountName: 'Payables', accountGroup: 'Liability', debit: 0, credit: 5850 },
    { companyId: 'c', _row: 4, journalId: 'payment', lineNumber: 1, accountId: 'payable', accountName: 'Payables', accountGroup: 'Liability', debit: 5750, credit: 0 },
    { companyId: 'c', _row: 5, journalId: 'payment', lineNumber: 2, accountId: 'bank', accountName: 'Bank', accountGroup: 'Asset', debit: 0, credit: 5750 },
  ];
  const result = await payrollChanges(f.sheets, 'c', 'Payroll', 'p', 'payrollReverse', old,
    { reversalDate: '2026-10-02', reversalReason: 'Duplicate payroll run' }, system, 'reverse-op');
  assert.equal(result.values.status, 'REVERSED');
  assert.deepEqual(result.extra.filter(change => change.table === 'Journals').map(change => change.values.sourceType),
    ['PayrollRefund', 'PayrollReversal']);
  const lines = result.extra.filter(change => change.table === 'JournalLines').map(change => change.values);
  assert.equal(lines.reduce((sum, line) => sum + line.debit, 0), 11600);
  assert.equal(lines.reduce((sum, line) => sum + line.credit, 0), 11600);
});

test('payroll rejects duplicates, forged totals, excess deductions and invalid transitions', async () => {
  const f = fixture();
  f.data.Payroll.push({ companyId: 'c', recordId: 'other', employeeId, month: '2026-09', status: 'DRAFT' });
  const create = values => payrollChanges(f.sheets, 'c', 'Payroll', 'p', 'create', null,
    { month: '2026-09', employeeId, bonus: 0, deductions: 0, ...values }, system, 'op');
  await assert.rejects(create({}), error => error.code === 'PAYROLL_DUPLICATE');
  f.data.Payroll = [];
  await assert.rejects(create({ netSalary: 1 }), error => error.code === 'PAYROLL_DERIVED_FIELD');
  await assert.rejects(create({ deductions: 6000 }), error => error.code === 'INVALID_PAYROLL');
  await assert.rejects(payrollChanges(f.sheets, 'c', 'Payroll', 'p', 'payrollPay', { status: 'DRAFT' },
    { paidDate: '2026-10-01', paymentAccount: 'Bank' }, system, 'pay'), error => error.code === 'PAYROLL_NOT_PAYABLE');
  await assert.rejects(payrollChanges(f.sheets, 'c', 'Payroll', 'p', 'payrollReverse', { status: 'PAID' },
    { reversalDate: '2026-10-02', reversalReason: 'Duplicate run', netSalary: 0 }, system, 'reverse'),
  error => error.code === 'PAYROLL_NOT_REVERSIBLE');
  await assert.rejects(payrollChanges(f.sheets, 'c', 'PayrollItems', 'x', 'create', null, {}, system, 'x'),
    error => error.code === 'PAYROLL_LOCKED');
});
