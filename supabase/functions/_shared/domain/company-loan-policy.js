import { challenge } from './crypto.js';
import { requireThat } from './errors.js';
import { assertOpenLedgerDate, validLedgerDate } from './financial-period-policy.js';
import { minor } from './journal-policy.js';
import { trialBalance } from './ledger-report.js';

const money = value => Number(value) / 100;
const active = row => row.isDeleted !== true && row.isDeleted !== 'TRUE';

export async function companyLoanChanges(records, companyId, table, id, action, old, values, system, operation) {
  if (table !== 'CompanyLoans') return { values, extra: [] };
  requireThat(['create', 'update', 'delete', 'loanPost', 'loanRepay'].includes(action),
    400, 'INVALID_COMPANY_LOAN', 'Unsupported company loan action.');
  requireThat(!old || old.status === 'DRAFT' || action === 'loanRepay',
    409, 'COMPANY_LOAN_LOCKED', 'Posted loans cannot be edited or deleted.');
  if (action === 'delete') return { values, extra: [] };
  const next = { ...old, ...values };
  if (['create', 'update'].includes(action)) {
    const editable = ['lenderName', 'lenderType', 'date', 'principal', 'interestRate', 'installmentAmount', 'dueDate', 'paymentAccount', 'reference', 'notes'];
    requireThat(Object.keys(values).every(k => editable.includes(k)), 400, 'COMPANY_LOAN_DERIVED_FIELD', 'Loan balances and status are calculated by the server.');
    requireThat(typeof next.lenderName === 'string' && next.lenderName.trim().length > 0 && next.lenderName.length <= 200 &&
      ['BANK', 'INSTITUTION', 'INDIVIDUAL'].includes(next.lenderType) && validLedgerDate(next.date) &&
      minor(next.principal) > 0n && typeof next.interestRate === 'number' && Number.isFinite(next.interestRate) &&
      next.interestRate >= 0 && next.interestRate <= 100 && Number(next.interestRate.toFixed(2)) === next.interestRate &&
      (!next.dueDate || validLedgerDate(next.dueDate) && next.dueDate >= next.date) &&
      ['Cash', 'Bank'].includes(next.paymentAccount), 400, 'INVALID_COMPANY_LOAN', 'Supply lender details, valid dates, positive principal, annual rate (0–100%) and Cash/Bank account.');
    const installment = minor(next.installmentAmount ?? 0);
    requireThat(installment >= 0n, 400, 'INVALID_COMPANY_LOAN', 'Installment must be nonnegative.');
    return { values: { ...values, lenderName: next.lenderName.trim(), installmentAmount: money(installment),
      repaidAmount: 0, interestPaid: 0, outstandingBalance: next.principal, status: 'DRAFT',
      lastRepaymentDate: '', principalPayment: 0, interestPayment: 0, paymentReference: '' }, extra: [] };
  }
  const posting = action === 'loanPost';
  requireThat(posting ? old?.status === 'DRAFT' : old?.status === 'ACTIVE',
    409, 'COMPANY_LOAN_NOT_AVAILABLE', 'Only draft loans can be posted and active loans repaid.');
  requireThat(posting || Object.keys(values).every(k => ['lastRepaymentDate', 'principalPayment', 'interestPayment', 'paymentAccount', 'paymentReference'].includes(k)),
    400, 'INVALID_LOAN_REPAYMENT', 'Supply only repayment date, principal, interest, account and reference.');
  const date = posting ? old.date : values.lastRepaymentDate;
  const account = posting ? old.paymentAccount : values.paymentAccount;
  requireThat(validLedgerDate(date) && date >= old.date && (!old.lastRepaymentDate || date >= old.lastRepaymentDate) &&
    ['Cash', 'Bank'].includes(account), 400, 'INVALID_LOAN_REPAYMENT', 'Choose Cash/Bank and a date on or after receipt and previous repayment.');
  const principal = posting ? minor(old.principal) : minor(values.principalPayment);
  const interest = posting ? 0n : minor(values.interestPayment);
  requireThat(principal >= 0n && interest >= 0n && principal + interest > 0n && principal + interest <= 100000000000000n &&
    (posting || principal <= minor(old.outstandingBalance)), 400, 'INVALID_LOAN_REPAYMENT', 'Enter a positive repayment; principal cannot exceed the outstanding balance.');
  await assertOpenLedgerDate(records, companyId, date);
  const data = await records.read(companyId, ['Journals', 'JournalLines']);
  const related = data.Journals.filter(j => j.companyId === companyId && active(j) && j.sourceId === id && j.sourceType === 'CompanyLoanReceipt');
  requireThat(posting ? related.length === 0 : related.length === 1 && related[0].status === 'POSTED',
    409, 'COMPANY_LOAN_LEDGER_CONFLICT', 'The loan must have exactly one posted receipt before repayment.');
  if (!posting) {
    const journals = data.Journals.filter(j => j.companyId === companyId && active(j) && j.sourceId === id &&
      ['CompanyLoanReceipt', 'CompanyLoanRepayment'].includes(j.sourceType));
    const trial = trialBalance(companyId, '9999-12-31', { Journals: journals, JournalLines: data.JournalLines });
    const liability = trial.accounts.find(a => a.accountId === 'company_loan');
    requireThat(journals.every(j => j.status === 'POSTED' && j.date <= date) && liability &&
      BigInt(liability.credit.replace('.', '')) - BigInt(liability.debit.replace('.', '')) === minor(old.outstandingBalance) &&
      minor(related[0].totalDebit) === minor(old.principal),
    409, 'COMPANY_LOAN_LEDGER_CONFLICT', 'The loan balance must reconcile with its posted receipt and repayments.');
  }
  const journalId = challenge(`${companyId}:${operation}:company-loan`);
  const journalRow = Math.max(1, ...data.Journals.map(r => Number(r._row) || 1)) + 1;
  const lineRow = Math.max(1, ...data.JournalLines.map(r => Number(r._row) || 1)) + 1;
  const meta = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1, isDeleted: false };
  const cash = account === 'Cash' ? 'cash' : 'bank';
  const lines = [];
  const add = (accountId, accountName, accountGroup, debit, credit) => {
    if (debit === 0n && credit === 0n) return;
    lines.push({ accountId, accountName, accountGroup, debit: money(debit), credit: money(credit) });
  };
  if (posting) {
    add(cash, account, 'Asset', principal, 0n);
    add('company_loan', 'Company Loans', 'Liability', 0n, principal);
  } else {
    add('company_loan', 'Company Loans', 'Liability', principal, 0n);
    add('loan_interest_expense', 'Loan Interest Expense', 'Expense', interest, 0n);
    add(cash, account, 'Asset', 0n, principal + interest);
  }
  const outstanding = posting ? principal : minor(old.outstandingBalance) - principal;
  return { values: posting ? { status: 'ACTIVE' } : {
    ...values, principalPayment: money(principal), interestPayment: money(interest),
    repaidAmount: money(minor(old.repaidAmount) + principal), interestPaid: money(minor(old.interestPaid) + interest),
    outstandingBalance: money(outstanding), status: outstanding === 0n ? 'REPAID' : 'ACTIVE',
  }, extra: [
    { table: 'Journals', row: journalRow, values: { ...meta, recordId: journalId, number: `AUTO-${journalId}`, date,
      description: `${posting ? 'Loan receipt' : 'Loan repayment'}: ${old.lenderName} ${values.paymentReference || old.reference || ''}`.trim(),
      sourceType: posting ? 'CompanyLoanReceipt' : 'CompanyLoanRepayment', sourceId: id,
      totalDebit: money(principal + interest), totalCredit: money(principal + interest), status: 'POSTED' } },
    ...lines.map((line, i) => ({ table: 'JournalLines', row: lineRow + i, values: { ...meta,
      recordId: challenge(`${journalId}:${i}`), journalId, lineNumber: i + 1, ...line } })),
  ] };
}
