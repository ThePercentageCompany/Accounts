const sources = {
  Income: ['Income', 'finance_income'],
  Expenses: ['Expenses', 'expense', 'supplier_bill'],
  Invoices: ['Invoice'],
  Receipts: ['Receipt'],
  CreditNotes: ['InvoiceReturn'],
  Payroll: ['Payroll'],
  Assets: ['AssetAcquisition'],
  CapitalTransactions: ['CapitalContribution'],
  ShareholderLoans: ['ShareholderLoanReceipt'],
  MoneyTransfers: ['MoneyTransfer'],
};
const reversals = {
  Income: ['IncomeReversal'], Expenses: ['ExpensesReversal'],
  Invoices: ['InvoiceVoid'], Receipts: ['ReceiptReversal'],
  Payroll: ['PayrollReversal'], MoneyTransfers: ['MoneyTransferReversal'],
};
export const hasLedgerSources = table => Object.hasOwn(sources, table);

export function ledgerStatus(table, row, journals, companyId) {
  if (table === 'Quotations') return 'NOT_APPLICABLE';
  if (table === 'Journals') return row.status === 'POSTED' ? 'LINKED' : 'UNPOSTED';
  if (!hasLedgerSources(table)) return undefined;
  const related = journals.filter(j => j.companyId === companyId &&
    j.isDeleted !== true && j.isDeleted !== 'TRUE' && j.status === 'POSTED' &&
    (j.sourceId === row.recordId || table === 'Assets' && row.acquisitionJournalId && j.recordId === row.acquisitionJournalId));
  if (related.some(j => reversals[table]?.includes(j.sourceType))) return 'REVERSED';
  return related.some(j => sources[table].includes(j.sourceType)) ? 'LINKED' : 'UNPOSTED';
}
