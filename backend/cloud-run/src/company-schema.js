export const SCHEMA_VERSION = 1;
export const FOLDERS = Object.freeze(['Company Logo', 'Invoices', 'Receipts', 'Quotations', 'Expenses',
  'Employee Documents', 'Payslips', 'Financial Reports', 'Assets', 'Exports', 'Backups']);
const SYSTEM = ['recordId', 'companyId', 'createdAt', 'createdBy', 'updatedAt', 'updatedBy',
  'recordVersion', 'syncStatus', 'isDeleted', 'idempotencyKey'];
const FIELDS = {
  SystemConfiguration: ['key', 'value'],
  CompanyProfile: ['name', 'address', 'email', 'phone', 'taxNumber', 'currency', 'invoicePrefix', 'quotationPrefix', 'bankName', 'accountHolder', 'accountNumber', 'iban', 'swift', 'logoDocumentId'],
  OwnersUsers: ['userId', 'email', 'displayName', 'status'],
  Roles: ['roleName', 'description'],
  RolePermissions: ['roleId', 'section', 'action', 'recordScope', 'fieldName'],
  Employees: ['employeeCode', 'fullName', 'email', 'phone', 'department', 'designation', 'joinDate', 'lastEmploymentDate', 'employmentStatus', 'roleId', 'basicSalary', 'allowances', 'iban', 'address', 'bankName', 'emiratesId', 'passportNumber', 'visaExpiry'],
  EmployeeAccess: ['employeeId', 'accessStatus', 'issuedAt', 'revokedAt'],
  Customers: ['name', 'email', 'phone', 'taxNumber', 'address'],
  ProductsServices: ['name', 'description', 'unit', 'unitPrice', 'taxRate', 'status'],
  Invoices: ['number', 'customerId', 'issueDate', 'dueDate', 'status', 'currency', 'subtotal', 'discount', 'taxAmount', 'total', 'paidAmount', 'balance', 'notes', 'paymentTerms', 'documentId'],
  InvoiceItems: ['invoiceId', 'lineNumber', 'productId', 'description', 'quantity', 'unitPrice', 'discount', 'taxRate', 'taxAmount', 'lineTotal'],
  Receipts: ['number', 'customerId', 'paymentDate', 'amount', 'currency', 'paymentAccount', 'reference', 'status', 'documentId'],
  ReceiptAllocations: ['receiptId', 'invoiceId', 'amount'],
  Quotations: ['number', 'customerId', 'issueDate', 'validUntil', 'status', 'currency', 'subtotal', 'discount', 'taxAmount', 'total', 'notes', 'paymentTerms', 'convertedInvoiceId', 'documentId'],
  QuotationItems: ['quotationId', 'lineNumber', 'productId', 'description', 'quantity', 'unitPrice', 'discount', 'taxRate', 'taxAmount', 'lineTotal'],
  Income: ['date', 'category', 'description', 'amount', 'taxRate', 'taxAmount', 'total', 'paymentStatus', 'paidDate', 'dueDate', 'account', 'reference'],
  Expenses: ['date', 'category', 'description', 'supplier', 'amount', 'taxRate', 'taxAmount', 'total', 'paymentStatus', 'paidDate', 'dueDate', 'account', 'reference'],
  ExpenseAttachments: ['expenseId', 'documentId'],
  Attendance: ['employeeId', 'date', 'status', 'hours', 'notes'],
  Overtime: ['employeeId', 'date', 'hours', 'rate', 'approvalStatus', 'approvedBy'],
  Payroll: ['month', 'employeeId', 'status', 'basicSalary', 'allowances', 'overtimeAmount', 'bonus', 'deductions', 'grossSalary', 'netSalary', 'paidDate', 'paymentAccount', 'paymentReference'],
  PayrollItems: ['payrollId', 'kind', 'description', 'quantity', 'rate', 'amount'],
  Payslips: ['payrollId', 'employeeId', 'documentId', 'issuedAt'],
  Assets: ['assetCode', 'name', 'category', 'purchaseDate', 'cost', 'usefulLife', 'residualValue', 'depreciationMethod', 'accumulatedDepreciation', 'netBookValue', 'status', 'location', 'assignedEmployeeId', 'serialNumber', 'acquisitionType', 'acquisitionJournalId'],
  CapitalAccounts: ['name', 'kind', 'shareholderId', 'currency', 'status'],
  CapitalTransactions: ['date', 'capitalAccountId', 'shareholderId', 'kind', 'amount', 'method', 'destinationAccount', 'assetId', 'status', 'reference'],
  Shareholders: ['name', 'email', 'phone', 'role', 'status', 'agreedCapital', 'investmentDate'],
  ShareholderEquity: ['shareholderId', 'effectiveDate', 'percentage', 'amount'],
  ShareholderLoans: ['shareholderId', 'date', 'kind', 'principal', 'interestRate', 'repaidAmount', 'outstandingBalance', 'dueDate', 'paymentAccount', 'status', 'reference'],
  FinancialPeriods: ['name', 'startDate', 'endDate', 'status', 'closedBy', 'closedAt'],
  Journals: ['number', 'date', 'description', 'sourceType', 'sourceId', 'totalDebit', 'totalCredit', 'status'],
  JournalLines: ['journalId', 'lineNumber', 'accountId', 'accountName', 'accountGroup', 'debit', 'credit'],
  DocumentRegistry: ['kind', 'name', 'mimeType', 'byteLength', 'relatedSection', 'relatedRecordId', 'status'],
  SyncOperations: ['operationId', 'actorId', 'section', 'targetRecordId', 'action', 'expectedVersion', 'resultVersion', 'status', 'errorCode'],
  AuditLog: ['actorId', 'action', 'section', 'targetRecordId', 'outcome', 'requestId'],
  NumberSequences: ['kind', 'prefix', 'period', 'nextNumber'],
};
export const TABLES = Object.freeze(Object.entries(FIELDS).map(([title, fields], index) =>
  Object.freeze({ title, sheetId: 1000 + index, headers: [...SYSTEM, ...fields] })));

// Only actual registration/identity metadata is seeded. No sample money, bank,
// tax, reviewer, employee, invoice or transaction records.
export function seedRows(company, owner) {
  const record = (recordId, extra) => ({ recordId, companyId: company.id,
    createdAt: company.createdAt, createdBy: owner.id, updatedAt: company.createdAt,
    updatedBy: owner.id, recordVersion: 1, syncStatus: 'SYNCED', isDeleted: false,
    idempotencyKey: `setup:${company.id}:${recordId}`, ...extra });
  const rows = {
    SystemConfiguration: record('schema', { key: 'schemaVersion', value: SCHEMA_VERSION }),
    CompanyProfile: record('company', { name: company.name }),
    OwnersUsers: record('owner', { userId: owner.id, email: owner.email, displayName: owner.name, status: 'ACTIVE' }),
  };
  return TABLES.filter(t => rows[t.title]).map(t => ({ title: t.title,
    values: t.headers.map(key => rows[t.title][key] ?? '') }));
}
