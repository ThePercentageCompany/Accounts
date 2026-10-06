import { challenge } from './crypto.js';
import { requireThat } from './errors.js';
import { assertOpenLedgerDate, validLedgerDate } from './financial-period-policy.js';
import { minor } from './journal-policy.js';

const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';
const money = cents => Number(cents) / 100;
const nextRow = rows => Math.max(1, ...rows.map(row => Number(row._row) || 1)) + 1;
const monthEnd = month => {
  const [year, value] = month.split('-').map(Number);
  return new Date(Date.UTC(year, value, 0)).toISOString().slice(0, 10);
};

function calculated(employee, overtime, values) {
  const basic = minor(employee.basicSalary === '' ? 0 : employee.basicSalary ?? 0),
    allowances = minor(employee.allowances === '' ? 0 : employee.allowances ?? 0);
  let overtimeAmount = 0n;
  for (const entry of overtime) {
    const hours = minor(entry.hours), rate = minor(entry.rate);
    overtimeAmount += (hours * rate + 50n) / 100n;
  }
  const bonus = minor(values.bonus ?? 0), deductions = minor(values.deductions ?? 0);
  const gross = basic + allowances + overtimeAmount + bonus;
  requireThat(gross > 0n && deductions <= gross, 400, 'INVALID_PAYROLL', 'Payroll deductions cannot exceed gross salary.');
  return { basicSalary: money(basic), allowances: money(allowances), overtimeAmount: money(overtimeAmount),
    bonus: money(bonus), deductions: money(deductions), grossSalary: money(gross), netSalary: money(gross - deductions) };
}

export async function previewPayroll(sheets, companyId, values) {
  requireThat(values && typeof values.month === 'string' && /^\d{4}-(0[1-9]|1[0-2])$/.test(values.month) &&
    typeof values.employeeId === 'string', 400, 'INVALID_PAYROLL', 'Choose an employee and payroll month.');
  const data = await sheets.readReferences(companyId, ['Employees', 'Overtime']);
  const employee = data.Employees.find(row => row.companyId === companyId && row.recordId === values.employeeId && active(row));
  requireThat(employee && employee.employmentStatus === 'ACTIVE', 409, 'PAYROLL_EMPLOYEE_INVALID', 'Choose an active employee.');
  requireThat((!employee.joinDate || employee.joinDate <= monthEnd(values.month)) &&
    (!employee.lastEmploymentDate || employee.lastEmploymentDate >= `${values.month}-01`),
    409, 'PAYROLL_EMPLOYEE_INVALID', 'Payroll month must overlap the employee employment dates.');
  const overtime = data.Overtime.filter(row => row.companyId === companyId && row.employeeId === values.employeeId && active(row) &&
    row.date?.startsWith(`${values.month}-`) && row.approvalStatus === 'APPROVED');
  return calculated(employee, overtime, values);
}

export async function payrollChanges(sheets, companyId, table, id, action, old, values, system, operation) {
  if (table === 'PayrollItems') requireThat(false, 409, 'PAYROLL_LOCKED', 'Payroll details are controlled by the payroll workflow.');
  if (table !== 'Payroll') return { values, extra: [] };
  requireThat(['create', 'update', 'delete', 'approve', 'payrollPay', 'payrollReverse'].includes(action), 400, 'INVALID_PAYROLL', 'Unsupported payroll action.');
  if (action === 'payrollReverse') {
    requireThat(Object.keys(values).every(key => ['reversalDate', 'reversalReason'].includes(key)) &&
      ['APPROVED', 'PAID'].includes(old?.status) && validLedgerDate(values.reversalDate) &&
      typeof values.reversalReason === 'string' && values.reversalReason.trim().length >= 3 && values.reversalReason.trim().length <= 1000,
    409, 'PAYROLL_NOT_REVERSIBLE', 'Choose approved or paid payroll and enter a valid reversal date and reason.');
    await assertOpenLedgerDate(sheets, companyId, values.reversalDate);
    const data = await sheets.read(companyId, ['Journals', 'JournalLines']);
    const related = data.Journals.filter(row => row.companyId === companyId && active(row) && row.sourceId === id &&
      ['Payroll', 'PayrollPayment', 'PayrollReversal', 'PayrollRefund'].includes(row.sourceType));
    const expected = old.status === 'PAID' ? ['Payroll', 'PayrollPayment'] : ['Payroll'];
    const originals = related.filter(row => expected.includes(row.sourceType));
    requireThat(related.length === expected.length && originals.length === expected.length && expected.every(type =>
      originals.filter(row => row.sourceType === type && row.status === 'POSTED').length === 1),
    409, 'PAYROLL_NOT_REVERSIBLE', 'Payroll ledger history cannot be reversed safely.');
    requireThat(originals.every(row => values.reversalDate >= row.date), 400, 'PAYROLL_NOT_REVERSIBLE',
      'Reversal cannot precede payroll approval or payment.');
    let journalRow = nextRow(data.Journals), lineRow = nextRow(data.JournalLines);
    const extra = [], journalSystem = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
    for (const original of originals.sort((a, b) => a.sourceType === 'Payroll' ? 1 : b.sourceType === 'Payroll' ? -1 : 0)) {
      const lines = data.JournalLines.filter(row => row.companyId === companyId && active(row) && row.journalId === original.recordId)
        .sort((a, b) => Number(a.lineNumber) - Number(b.lineNumber));
      const debit = lines.reduce((sum, row) => sum + minor(row.credit), 0n);
      const credit = lines.reduce((sum, row) => sum + minor(row.debit), 0n);
      requireThat(lines.length >= 2 && debit === credit && debit === minor(original.totalDebit),
        409, 'PAYROLL_NOT_REVERSIBLE', 'Payroll ledger history cannot be reversed safely.');
      const payment = original.sourceType === 'PayrollPayment', journalId = challenge(`${companyId}:${operation}:${payment ? 'payroll-refund' : 'payroll-reversal'}`);
      extra.push({ table: 'Journals', row: journalRow++, values: { ...journalSystem, recordId: journalId,
        number: `AUTO-${journalId}`, date: values.reversalDate, description: `${payment ? 'Refund' : 'Reversal'} payroll ${old.month}: ${values.reversalReason.trim()}`,
        sourceType: payment ? 'PayrollRefund' : 'PayrollReversal', sourceId: id,
        totalDebit: money(debit), totalCredit: money(credit), status: 'POSTED' } });
      lines.forEach((line, index) => extra.push({ table: 'JournalLines', row: lineRow++, values: {
        ...journalSystem, recordId: challenge(`${journalId}:${index}`), journalId, lineNumber: index + 1,
        accountId: line.accountId, accountName: line.accountName, accountGroup: line.accountGroup,
        debit: line.credit, credit: line.debit,
      } }));
    }
    return { values: { reversalDate: values.reversalDate, reversalReason: values.reversalReason.trim(), status: 'REVERSED' }, extra };
  }
  if (action === 'payrollPay') {
    requireThat(old?.status === 'APPROVED' && Object.keys(values).every(key =>
      ['paidDate', 'paymentAccount', 'paymentReference'].includes(key)) && validLedgerDate(values.paidDate) &&
      ['Cash', 'Bank'].includes(values.paymentAccount) && typeof (values.paymentReference ?? '') === 'string',
    409, 'PAYROLL_NOT_PAYABLE', 'Approve payroll and provide a valid payment date and account.');
    await assertOpenLedgerDate(sheets, companyId, values.paidDate);
    const data = await sheets.read(companyId, ['Journals', 'JournalLines']);
    const amount = minor(old.netSalary), journalId = challenge(`${companyId}:${operation}:payroll-payment`);
    const journalSystem = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
    const accountId = values.paymentAccount === 'Cash' ? 'cash' : 'bank';
    return { values: { paidDate: values.paidDate, paymentAccount: values.paymentAccount,
      paymentReference: values.paymentReference ?? '', status: 'PAID' }, extra: [
      { table: 'Journals', row: nextRow(data.Journals), values: { ...journalSystem, recordId: journalId,
        number: `AUTO-${journalId}`, date: values.paidDate, description: `Payroll payment ${old.month}`,
        sourceType: 'PayrollPayment', sourceId: id, totalDebit: money(amount), totalCredit: money(amount), status: 'POSTED' } },
      { table: 'JournalLines', row: nextRow(data.JournalLines), values: { ...journalSystem,
        recordId: challenge(`${journalId}:0`), journalId, lineNumber: 1, accountId: 'salary_payable',
        accountName: 'Salary Payable', accountGroup: 'Liability', debit: money(amount), credit: 0 } },
      { table: 'JournalLines', row: nextRow(data.JournalLines) + 1, values: { ...journalSystem,
        recordId: challenge(`${journalId}:1`), journalId, lineNumber: 2, accountId,
        accountName: values.paymentAccount, accountGroup: 'Asset', debit: 0, credit: money(amount) } },
    ] };
  }
  requireThat(!old || old.status === 'DRAFT', 409, 'PAYROLL_LOCKED', 'Approved payroll cannot be edited or deleted.');
  if (action === 'delete') return { values, extra: [] };
  const next = { ...old, ...values };
  requireThat(typeof next.month === 'string' && /^\d{4}-(0[1-9]|1[0-2])$/.test(next.month) &&
    typeof next.employeeId === 'string', 400, 'INVALID_PAYROLL', 'Choose an employee and payroll month.');
  requireThat(!Object.keys(values).some(key => ['status', 'basicSalary', 'allowances', 'overtimeAmount', 'grossSalary', 'netSalary',
    'paidDate', 'paymentAccount', 'paymentReference'].includes(key)), 400, 'PAYROLL_DERIVED_FIELD', 'Payroll totals and status are assigned by the server.');
  const all = await sheets.read(companyId, ['Payroll']);
  requireThat(!all.Payroll.some(row => row.companyId === companyId && row.recordId !== id && active(row) &&
    row.employeeId === next.employeeId && row.month === next.month), 409, 'PAYROLL_DUPLICATE', 'Payroll already exists for this employee and month.');
  const totals = await previewPayroll(sheets, companyId, next);
  if (action === 'approve') {
    requireThat(old && old.basicSalary === totals.basicSalary && old.allowances === totals.allowances &&
      old.overtimeAmount === totals.overtimeAmount && old.bonus === totals.bonus && old.deductions === totals.deductions &&
      old.grossSalary === totals.grossSalary && old.netSalary === totals.netSalary,
    409, 'PAYROLL_TOTAL_MISMATCH', 'Refresh payroll totals before approval.');
    const date = monthEnd(old.month); await assertOpenLedgerDate(sheets, companyId, date);
    const ledger = await sheets.read(companyId, ['Journals', 'JournalLines']);
    const gross = minor(totals.grossSalary), net = minor(totals.netSalary), deductions = minor(totals.deductions);
    const journalId = challenge(`${companyId}:${operation}:payroll-approval`), journalSystem = {
      ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
    const lines = [
      { accountId: 'salary_expense', accountName: 'Salary Expense', accountGroup: 'Expense', debit: money(gross), credit: 0 },
      { accountId: 'salary_payable', accountName: 'Salary Payable', accountGroup: 'Liability', debit: 0, credit: money(net) },
      ...(deductions > 0n ? [{ accountId: 'payroll_deductions_payable', accountName: 'Payroll Deductions Payable',
        accountGroup: 'Liability', debit: 0, credit: money(deductions) }] : []),
    ];
    return { values: { ...totals, status: 'APPROVED' }, extra: [
      { table: 'Journals', row: nextRow(ledger.Journals), values: { ...journalSystem, recordId: journalId,
        number: `AUTO-${journalId}`, date, description: `Payroll ${old.month}`, sourceType: 'Payroll', sourceId: id,
        totalDebit: money(gross), totalCredit: money(gross), status: 'POSTED' } },
      ...lines.map((line, index) => ({ table: 'JournalLines', row: nextRow(ledger.JournalLines) + index,
        values: { ...journalSystem, recordId: challenge(`${journalId}:${index}`), journalId, lineNumber: index + 1, ...line } })),
    ] };
  }
  return { values: { ...values, ...totals, status: 'DRAFT', paidDate: '', paymentAccount: '', paymentReference: '' }, extra: [] };
}
