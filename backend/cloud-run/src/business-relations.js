import { requireThat } from './errors.js';

// Employee reads are internal validation only; generic record APIs cannot expose
// employee tables. Inactive employees remain valid for historical payroll.
export const RELATIONS = {
  Invoices: { customerId: 'Customers' }, Receipts: { customerId: 'Customers' },
  Quotations: { customerId: 'Customers', convertedInvoiceId: 'Invoices' },
  InvoiceItems: { invoiceId: 'Invoices', productId: 'ProductsServices' },
  QuotationItems: { quotationId: 'Quotations', productId: 'ProductsServices' },
  ReceiptAllocations: { receiptId: 'Receipts', invoiceId: 'Invoices' },
  ExpenseAttachments: { expenseId: 'Expenses' }, PayrollItems: { payrollId: 'Payroll' },
  Payslips: { payrollId: 'Payroll', employeeId: 'Employees' }, JournalLines: { journalId: 'Journals' },
  Payroll: { employeeId: 'Employees' }, Attendance: { employeeId: 'Employees' }, Overtime: { employeeId: 'Employees' },
  Assets: { acquisitionJournalId: 'Journals', assignedEmployeeId: 'Employees' },
  CapitalAccounts: { shareholderId: 'Shareholders' },
  CapitalTransactions: { capitalAccountId: 'CapitalAccounts', shareholderId: 'Shareholders', assetId: 'Assets' },
  ShareholderEquity: { shareholderId: 'Shareholders' }, ShareholderLoans: { shareholderId: 'Shareholders' },
};
const REQUIRED = {
  InvoiceItems: ['invoiceId'], QuotationItems: ['quotationId'], ReceiptAllocations: ['receiptId', 'invoiceId'],
  ExpenseAttachments: ['expenseId'], PayrollItems: ['payrollId'], Payslips: ['payrollId', 'employeeId'],
  Payroll: ['employeeId'], Attendance: ['employeeId'], Overtime: ['employeeId'],
  JournalLines: ['journalId'], ShareholderEquity: ['shareholderId'], ShareholderLoans: ['shareholderId'],
};
const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';

export async function validateRelations(sheets, companyId, table, recordId, action, values) {
  if (action === 'delete') {
    const references = Object.entries(RELATIONS).flatMap(([source, fields]) =>
      Object.entries(fields).filter(([, target]) => target === table).map(([field]) => ({ source, field })));
    if (!references.length) return;
    const rows = await sheets.read(companyId, [...new Set(references.map(r => r.source))]);
    requireThat(!references.some(({ source, field }) => rows[source].some(row => active(row) && row[field] === recordId)),
      409, 'RECORD_REFERENCED', 'Remove or reassign dependent records before deleting this record.');
    return;
  }
  const fields = RELATIONS[table] || {};
  for (const field of REQUIRED[table] || []) requireThat(typeof values[field] === 'string' && values[field].length > 0,
    400, 'REFERENCE_REQUIRED', `A ${field} reference is required.`);
  const populated = Object.entries(fields).filter(([field]) => values[field] !== undefined && values[field] !== '');
  for (const [field] of populated) requireThat(typeof values[field] === 'string' && /^[A-Za-z0-9_-]{43}$/.test(values[field]),
    400, 'INVALID_REFERENCE', 'Invalid related record identifier.');
  if (!populated.length) return;
  const names = [...new Set(populated.map(([, target]) => target))];
  const rows = await (names.includes('Employees') ? sheets.readReferences(companyId, names) : sheets.read(companyId, names));
  for (const [field, target] of populated) requireThat(rows[target].some(row =>
    row.companyId === companyId && row.recordId === values[field] && active(row)),
  409, 'REFERENCE_NOT_FOUND', 'A related record is missing or deleted in this company.');
  if (table === 'Payslips') requireThat(rows.Payroll.find(row => row.recordId === values.payrollId)?.employeeId === values.employeeId,
    409, 'REFERENCE_MISMATCH', 'Payslip employee must match the payroll employee.');
}
