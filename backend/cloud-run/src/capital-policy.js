import { challenge } from './crypto.js';
import { requireThat } from './errors.js';
import { assertOpenLedgerDate, validLedgerDate } from './financial-period-policy.js';
import { minor } from './journal-policy.js';

const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';
const money = cents => Number(cents) / 100;
const nextRow = rows => Math.max(1, ...rows.map(row => Number(row._row) || 1)) + 1;

export async function capitalChanges(sheets, companyId, table, id, action, old, values, system, operation) {
  if (table === 'Shareholders') {
    requireThat(['create', 'update', 'delete'].includes(action), 400, 'INVALID_SHAREHOLDER', 'Unsupported shareholder action.');
    if (action === 'delete') return { values, extra: [] };
    const next = { ...old, ...values };
    requireThat(typeof next.name === 'string' && next.name.trim().length > 0 &&
      ['ACTIVE', 'INACTIVE'].includes(next.status) && minor(next.agreedCapital ?? 0) >= 0n &&
      (!next.investmentDate || validLedgerDate(next.investmentDate)), 400, 'INVALID_SHAREHOLDER',
    'Supply a shareholder name, status, agreed capital and valid investment date.');
    return { values: { ...values, name: next.name.trim() }, extra: [] };
  }
  if (table === 'ShareholderLoans') {
    requireThat(['create', 'update', 'delete', 'loanPost', 'loanRepay'].includes(action), 400, 'INVALID_SHAREHOLDER_LOAN', 'Unsupported shareholder loan action.');
    requireThat(!old || old.status === 'DRAFT' || action === 'loanRepay', 409, 'SHAREHOLDER_LOAN_LOCKED', 'Posted shareholder loans cannot be edited or deleted.');
    if (action === 'delete') return { values, extra: [] };
    if (action === 'loanPost') {
      requireThat(old?.status === 'DRAFT', 409, 'SHAREHOLDER_LOAN_NOT_POSTABLE', 'Only a draft shareholder loan can be posted.');
      await assertOpenLedgerDate(sheets, companyId, old.date);
      const ledger = await sheets.read(companyId, ['Journals', 'JournalLines']);
      const amount = minor(old.principal), journalId = challenge(`${companyId}:${operation}:shareholder-loan-receipt`);
      const meta = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
      const accountId = old.paymentAccount === 'Cash' ? 'cash' : 'bank';
      return { values: { status: 'ACTIVE' }, extra: [
        { table: 'Journals', row: nextRow(ledger.Journals), values: { ...meta, recordId: journalId,
          number: `AUTO-${journalId}`, date: old.date, description: `Shareholder loan ${old.reference || ''}`.trim(),
          sourceType: 'ShareholderLoanReceipt', sourceId: id, totalDebit: money(amount), totalCredit: money(amount), status: 'POSTED' } },
        { table: 'JournalLines', row: nextRow(ledger.JournalLines), values: { ...meta, recordId: challenge(`${journalId}:0`),
          journalId, lineNumber: 1, accountId, accountName: old.paymentAccount, accountGroup: 'Asset', debit: money(amount), credit: 0 } },
        { table: 'JournalLines', row: nextRow(ledger.JournalLines) + 1, values: { ...meta, recordId: challenge(`${journalId}:1`),
          journalId, lineNumber: 2, accountId: 'shareholder_loan', accountName: 'Shareholder Loan', accountGroup: 'Liability', debit: 0, credit: money(amount) } },
      ] };
    }
    if (action === 'loanRepay') {
      requireThat(old?.status === 'ACTIVE' && Object.keys(values).every(key =>
        ['lastRepaymentDate', 'paymentAccount', 'paymentReference'].includes(key)) && validLedgerDate(values.lastRepaymentDate) &&
        values.lastRepaymentDate >= old.date && ['Cash', 'Bank'].includes(values.paymentAccount) &&
        typeof (values.paymentReference ?? '') === 'string', 409, 'SHAREHOLDER_LOAN_NOT_REPAYABLE',
      'Choose a valid repayment date and Cash/Bank account for an active loan.');
      await assertOpenLedgerDate(sheets, companyId, values.lastRepaymentDate);
      const amount = minor(old.outstandingBalance), ledger = await sheets.read(companyId, ['Journals', 'JournalLines']);
      requireThat(amount > 0n, 409, 'SHAREHOLDER_LOAN_NOT_REPAYABLE', 'This shareholder loan has no outstanding principal.');
      const journalId = challenge(`${companyId}:${operation}:shareholder-loan-repayment`);
      const meta = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
      const accountId = values.paymentAccount === 'Cash' ? 'cash' : 'bank';
      return { values: { repaidAmount: money(minor(old.principal)), outstandingBalance: 0,
        lastRepaymentDate: values.lastRepaymentDate, paymentAccount: values.paymentAccount,
        paymentReference: values.paymentReference ?? '', status: 'REPAID' }, extra: [
        { table: 'Journals', row: nextRow(ledger.Journals), values: { ...meta, recordId: journalId,
          number: `AUTO-${journalId}`, date: values.lastRepaymentDate, description: `Shareholder loan repayment ${values.paymentReference || ''}`.trim(),
          sourceType: 'ShareholderLoanRepayment', sourceId: id, totalDebit: money(amount), totalCredit: money(amount), status: 'POSTED' } },
        { table: 'JournalLines', row: nextRow(ledger.JournalLines), values: { ...meta, recordId: challenge(`${journalId}:0`),
          journalId, lineNumber: 1, accountId: 'shareholder_loan', accountName: 'Shareholder Loan', accountGroup: 'Liability', debit: money(amount), credit: 0 } },
        { table: 'JournalLines', row: nextRow(ledger.JournalLines) + 1, values: { ...meta, recordId: challenge(`${journalId}:1`),
          journalId, lineNumber: 2, accountId, accountName: values.paymentAccount, accountGroup: 'Asset', debit: 0, credit: money(amount) } },
      ] };
    }
    requireThat(!Object.keys(values).some(key => ['repaidAmount', 'outstandingBalance', 'lastRepaymentDate', 'paymentReference', 'status'].includes(key)),
      400, 'SHAREHOLDER_LOAN_DERIVED_FIELD', 'Loan balances, repayment details and status are assigned by the server.');
    const next = { ...old, ...values };
    requireThat(typeof next.shareholderId === 'string' && next.shareholderId.length > 0 && validLedgerDate(next.date) &&
      next.kind === 'LOAN_TO_COMPANY' && minor(next.principal) > 0n && next.interestRate === 0 &&
      (!next.dueDate || (validLedgerDate(next.dueDate) && next.dueDate >= next.date)) && ['Cash', 'Bank'].includes(next.paymentAccount),
    400, 'INVALID_SHAREHOLDER_LOAN', 'Supply an interest-free company loan, valid dates, positive principal and Cash/Bank account.');
    return { values: { ...values, kind: 'LOAN_TO_COMPANY', interestRate: 0, repaidAmount: 0,
      outstandingBalance: money(minor(next.principal)), lastRepaymentDate: '', paymentReference: '', status: 'DRAFT' }, extra: [] };
  }
  if (table !== 'CapitalTransactions') return { values, extra: [] };
  requireThat(['create', 'update', 'delete', 'capitalPost'].includes(action), 400, 'INVALID_CAPITAL_TRANSACTION', 'Unsupported capital action.');
  requireThat(!old || old.status === 'DRAFT', 409, 'CAPITAL_LOCKED', 'Posted capital cannot be edited or deleted.');
  if (action === 'delete') return { values, extra: [] };
  if (action === 'capitalPost') {
    requireThat(old?.status === 'DRAFT', 409, 'CAPITAL_NOT_POSTABLE', 'Only a draft contribution can be posted.');
    await assertOpenLedgerDate(sheets, companyId, old.date);
    const ledger = await sheets.read(companyId, ['Journals', 'JournalLines']);
    const amount = minor(old.amount), journalId = challenge(`${companyId}:${operation}:capital-contribution`);
    const meta = { ...system, createdAt: system.updatedAt, createdBy: system.updatedBy, recordVersion: 1 };
    const accountId = old.destinationAccount === 'Cash' ? 'cash' : 'bank';
    return { values: { status: 'POSTED' }, extra: [
      { table: 'Journals', row: nextRow(ledger.Journals), values: { ...meta, recordId: journalId,
        number: `AUTO-${journalId}`, date: old.date, description: `Capital contribution ${old.reference || ''}`.trim(),
        sourceType: 'CapitalContribution', sourceId: id, totalDebit: money(amount), totalCredit: money(amount), status: 'POSTED' } },
      { table: 'JournalLines', row: nextRow(ledger.JournalLines), values: { ...meta, recordId: challenge(`${journalId}:0`),
        journalId, lineNumber: 1, accountId, accountName: old.destinationAccount, accountGroup: 'Asset', debit: money(amount), credit: 0 } },
      { table: 'JournalLines', row: nextRow(ledger.JournalLines) + 1, values: { ...meta, recordId: challenge(`${journalId}:1`),
        journalId, lineNumber: 2, accountId: 'shareholder_equity', accountName: 'Shareholder Equity', accountGroup: 'Equity', debit: 0, credit: money(amount) } },
    ] };
  }
  requireThat(!Object.hasOwn(values, 'status'), 400, 'CAPITAL_DERIVED_FIELD', 'Capital status is assigned by the server.');
  const next = { ...old, ...values };
  requireThat(validLedgerDate(next.date) && typeof next.shareholderId === 'string' && next.shareholderId.length > 0 &&
    next.kind === 'CAPITAL_CONTRIBUTION' && minor(next.amount) > 0n && next.method === 'PAID' &&
    ['Cash', 'Bank'].includes(next.destinationAccount) && (!next.capitalAccountId || typeof next.capitalAccountId === 'string') &&
    (!next.assetId || typeof next.assetId === 'string'), 400, 'INVALID_CAPITAL_TRANSACTION',
  'Supply a date, shareholder, positive paid contribution and Cash/Bank destination.');
  const data = await sheets.read(companyId, ['CapitalTransactions']);
  requireThat(!data.CapitalTransactions.some(row => row.companyId === companyId && row.recordId !== id && active(row) &&
    row.reference && next.reference && row.reference === next.reference), 409, 'CAPITAL_REFERENCE_DUPLICATE', 'Capital reference already exists.');
  return { values: { ...values, kind: 'CAPITAL_CONTRIBUTION', method: 'PAID', capitalAccountId: '', assetId: '', status: 'DRAFT' }, extra: [] };
}
