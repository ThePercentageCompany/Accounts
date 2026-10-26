export const SECTIONS = Object.freeze(['Cash & Bank', 'Dashboard', 'Invoices', 'Quotations', 'Income & Expenses', 'Capital & Equity',
  'Fixed Assets', 'Balance Sheet', 'Customers', 'Employees', 'Payroll', 'Reports', 'Settings', 'Office & Attendance', 'Tasks', 'Calendar', 'Projects']);
export const WRITE_SECTIONS = Object.freeze(['Cash & Bank', 'Customers', 'Employees', 'Invoices', 'Quotations', 'Income & Expenses', 'Payroll', 'Fixed Assets', 'Capital & Equity', 'Balance Sheet', 'Settings', 'Tasks', 'Projects']);
export const ROLES = Object.freeze(['Staff', 'Manager', 'Accountant']);
// The employee directory is readable through records with normal visibility
// and field projection. Employee management uses its dedicated admin endpoint.
export function recordsEndpointAllowed(table, method, hasRecordId = false) {
  if (table === 'Employees') return method === 'GET' && !hasRecordId;
  return !['DocumentRegistry', 'NumberSequences'].includes(table);
}
export const SECTION_TABLES = {
  MoneyTransfers: 'Cash & Bank', CompanyLoans: 'Cash & Bank',
  Projects: 'Projects', Tasks: 'Tasks', TaskComments: 'Tasks', TaskActivity: 'Tasks',
  CreditNotes: 'Invoices', CreditNoteItems: 'Invoices',
  CompanyProfile: 'Settings', Customers: 'Customers', ProductsServices: 'Invoices', Invoices: 'Invoices', InvoiceItems: 'Invoices',
  Receipts: 'Invoices', ReceiptAllocations: 'Invoices', Quotations: 'Quotations', QuotationItems: 'Quotations',
  Income: 'Income & Expenses', Expenses: 'Income & Expenses', ExpenseAttachments: 'Income & Expenses',
  Employees: 'Employees', Attendance: 'Office & Attendance', Overtime: 'Office & Attendance',
  Payroll: 'Payroll', PayrollItems: 'Payroll', Payslips: 'Payroll', Assets: 'Fixed Assets',
  CapitalAccounts: 'Capital & Equity', CapitalTransactions: 'Capital & Equity', Shareholders: 'Capital & Equity',
  ShareholderEquity: 'Capital & Equity', ShareholderLoans: 'Capital & Equity',
  FinancialPeriods: 'Balance Sheet', Journals: 'Balance Sheet', JournalLines: 'Balance Sheet',
};
export const CHILDREN = {
  TaskComments: ['Tasks', 'taskId'], TaskActivity: ['Tasks', 'taskId'],
  CreditNotes: ['Invoices', 'invoiceId'], CreditNoteItems: ['Invoices', 'invoiceId'],
  InvoiceItems: ['Invoices', 'invoiceId'], ReceiptAllocations: ['Receipts', 'receiptId'],
  QuotationItems: ['Quotations', 'quotationId'], ExpenseAttachments: ['Expenses', 'expenseId'],
  PayrollItems: ['Payroll', 'payrollId'], JournalLines: ['Journals', 'journalId'],
};
export const deleted = row => row.isDeleted === true || row.isDeleted === 'TRUE';
export function scopeFor(role, section) {
  return role === 'Staff' && ['Employees', 'Payroll', 'Office & Attendance', 'Fixed Assets', 'Income & Expenses', 'Tasks', 'Calendar'].includes(section) ? 'SELF' : 'COMPANY';
}
export function visible(principal, table, row, parentRows = {}) {
  const section = SECTION_TABLES[table], scope = principal.permissions[section];
  if (!section || !scope || !row || row.companyId !== principal.companyId || deleted(row)) return false;
  if (CHILDREN[table]) {
    const [parent, field] = CHILDREN[table];
    const record = parentRows[parent]?.find(p => p.recordId === row[field]);
    if (!visible(principal, parent, record, parentRows)) return false;
  }
  // Task visibility follows task edit access, independent of the employee role.
  if (table === 'Tasks') return principal.writableSections?.includes('Tasks') || row.employeeId === principal.employeeId;
  if (scope !== 'SELF') return true;
  if (table === 'Employees') return row.recordId === principal.employeeId;
  if (table === 'Assets') return row.assignedEmployeeId === principal.employeeId;
  if (['PayrollItems', 'ExpenseAttachments', 'TaskComments', 'TaskActivity'].includes(table)) return true; // parent already checked
  if (['Payroll', 'Payslips', 'Attendance', 'Overtime'].includes(table)) return row.employeeId === principal.employeeId;
  return row.employeeId === principal.employeeId || row.createdBy === principal.employeeId;
}
export function projectRecord(principal, table, row) {
  const result = { ...row };
  if (table === 'Employees') {
    for (const key of ['roleId', 'emiratesId', 'passportNumber', 'visaExpiry', 'bankName', 'iban', 'address']) delete result[key];
    if (principal.role !== 'Accountant' && row.recordId !== principal.employeeId) {
      delete result.basicSalary; delete result.allowances;
    }
  }
  // Business reads cannot disclose internal resource locations or credentials.
  for (const key of ['refreshToken', 'ciphertext', 'passwordHash', 'salt']) delete result[key];
  return result;
}
