import { requireThat } from './errors.js';

export const SECTIONS = Object.freeze(['Dashboard', 'Invoices', 'Quotations', 'Income & Expenses', 'Capital & Equity',
  'Fixed Assets', 'Balance Sheet', 'Customers', 'Employees', 'Payroll', 'Reports', 'Settings', 'Office & Attendance']);
export const ROLES = Object.freeze(['Staff', 'Manager', 'Accountant']);
export const SECTION_TABLES = {
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
  InvoiceItems: ['Invoices', 'invoiceId'], ReceiptAllocations: ['Receipts', 'receiptId'],
  QuotationItems: ['Quotations', 'quotationId'], ExpenseAttachments: ['Expenses', 'expenseId'],
  PayrollItems: ['Payroll', 'payrollId'], JournalLines: ['Journals', 'journalId'],
};
export const deleted = row => row.isDeleted === true || row.isDeleted === 'TRUE';
export function scopeFor(role, section) {
  return role === 'Staff' && ['Employees', 'Payroll', 'Office & Attendance', 'Fixed Assets', 'Income & Expenses'].includes(section) ? 'SELF' : 'COMPANY';
}
export function principalFromRows(companyId, employeeId, rows, now) {
  const employee = rows.Employees.find(r => r.recordId === employeeId && r.companyId === companyId && !deleted(r));
  requireThat(employee?.employmentStatus === 'ACTIVE' && (!employee.lastEmploymentDate || employee.lastEmploymentDate >= new Date(now).toISOString().slice(0, 10)),
    401, 'EMPLOYEE_ACCESS_DENIED', 'Employee access is unavailable.');
  const role = rows.Roles.find(r => r.recordId === employee.roleId && r.companyId === companyId && !deleted(r));
  requireThat(role && ROLES.includes(role.roleName), 401, 'EMPLOYEE_ACCESS_DENIED', 'Employee access is unavailable.');
  const grants = rows.RolePermissions.filter(p => p.companyId === companyId && p.roleId === role.recordId && !deleted(p) &&
    p.action === 'read' && p.fieldName === '*' && SECTIONS.includes(p.section) && ['SELF', 'COMPANY'].includes(p.recordScope));
  // A role's privacy limits still apply if a sheet permission is broadened.
  const permissions = Object.fromEntries(grants.map(p => [p.section,
    p.recordScope === 'SELF' || scopeFor(role.roleName, p.section) === 'SELF' ? 'SELF' : 'COMPANY']));
  return { companyId, employeeId, role: role.roleName, name: employee.fullName,
    allowedSections: SECTIONS.filter(s => permissions[s]), permissions };
}
export function visible(principal, table, row, parentRows = {}) {
  const section = SECTION_TABLES[table], scope = principal.permissions[section];
  if (!section || !scope || !row || row.companyId !== principal.companyId || deleted(row)) return false;
  if (CHILDREN[table]) {
    const [parent, field] = CHILDREN[table];
    const record = parentRows[parent]?.find(p => p.recordId === row[field]);
    if (!visible(principal, parent, record, parentRows)) return false;
  }
  if (scope !== 'SELF') return true;
  if (table === 'Employees') return row.recordId === principal.employeeId;
  if (table === 'Assets') return row.assignedEmployeeId === principal.employeeId;
  if (['PayrollItems', 'ExpenseAttachments'].includes(table)) return true; // parent already checked
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
  for (const key of ['spreadsheetId', 'driveFolderId', 'driveFileId', 'refreshToken', 'ciphertext', 'passwordHash', 'salt']) delete result[key];
  return result;
}
export function authorizeDocument(principal, document, record, file, allowedFolderIds, parentRows = {}) {
  requireThat(document?.companyId === principal.companyId && !deleted(document) &&
    document.relatedRecordId === record?.recordId && visible(principal, document.relatedSection, record, parentRows) &&
    file?.id === document.driveFileId && !file.trashed && file.ownedByMe === true &&
    file.parents?.length === 1 && allowedFolderIds.includes(file.parents[0]),
  403, 'DOCUMENT_FORBIDDEN', 'This document is not available to this employee.');
}
