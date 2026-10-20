const SYSTEM = ['recordId', 'companyId', 'createdAt', 'createdBy', 'updatedAt', 'updatedBy',
  'recordVersion', 'syncStatus', 'isDeleted', 'idempotencyKey'];
const FIELDS = {
  CompanyProfile: ['name', 'address', 'email', 'phone', 'taxNumber', 'currency', 'invoicePrefix', 'quotationPrefix', 'bankName', 'accountHolder', 'accountNumber', 'iban', 'swift', 'logoDocumentId'],
  Employees: ['employeeCode', 'fullName', 'email', 'phone', 'department', 'designation', 'joinDate', 'lastEmploymentDate', 'employmentStatus', 'roleId', 'basicSalary', 'allowances', 'iban', 'address', 'bankName', 'emiratesId', 'passportNumber', 'visaExpiry', 'currency'],
  Customers: ['name', 'email', 'phone', 'taxNumber', 'address', 'preferredCurrency'],
  ProductsServices: ['name', 'description', 'unit', 'unitPrice', 'taxRate', 'status'],
  Invoices: ['number', 'customerId', 'issueDate', 'dueDate', 'status', 'currency', 'subtotal', 'discount', 'taxAmount', 'total', 'paidAmount', 'balance', 'voidDate', 'voidReason', 'notes', 'paymentTerms', 'documentId'],
  InvoiceItems: ['invoiceId', 'lineNumber', 'productId', 'description', 'quantity', 'unitPrice', 'discount', 'taxRate', 'taxAmount', 'lineTotal'],
  Receipts: ['number', 'customerId', 'paymentDate', 'amount', 'currency', 'paymentAccount', 'reference', 'status', 'reversalDate', 'reversalReason', 'documentId'],
  ReceiptAllocations: ['receiptId', 'invoiceId', 'amount'],
  Quotations: ['number', 'customerId', 'issueDate', 'validUntil', 'status', 'currency', 'subtotal', 'discount', 'taxAmount', 'total', 'notes', 'paymentTerms', 'convertedInvoiceId', 'documentId'],
  QuotationItems: ['quotationId', 'lineNumber', 'productId', 'description', 'quantity', 'unitPrice', 'discount', 'taxRate', 'taxAmount', 'lineTotal'],
  Income: ['date', 'category', 'description', 'amount', 'taxRate', 'taxAmount', 'total', 'paymentStatus', 'paidDate', 'dueDate', 'account', 'reference'],
  Expenses: ['date', 'category', 'description', 'supplier', 'amount', 'taxRate', 'taxAmount', 'total', 'paymentStatus', 'paidDate', 'dueDate', 'account', 'reference'],
  ExpenseAttachments: ['expenseId', 'documentId'],
  Attendance: ['employeeId', 'date', 'status', 'hours', 'notes'],
  Overtime: ['employeeId', 'date', 'hours', 'rate', 'approvalStatus', 'approvedBy'],
  Payroll: ['month', 'employeeId', 'status', 'basicSalary', 'allowances', 'overtimeAmount', 'bonus', 'deductions', 'bonusNotes', 'deductionNotes', 'grossSalary', 'netSalary', 'paidDate', 'paymentAccount', 'paymentReference', 'reversalDate', 'reversalReason'],
  PayrollItems: ['payrollId', 'kind', 'description', 'quantity', 'rate', 'amount'],
  Payslips: ['payrollId', 'employeeId', 'documentId', 'issuedAt'],
  Assets: ['assetCode', 'name', 'category', 'purchaseDate', 'cost', 'usefulLife', 'residualValue', 'depreciationMethod', 'paymentAccount', 'accumulatedDepreciation', 'netBookValue', 'lastDepreciationDate', 'disposalDate', 'disposalProceeds', 'disposalAccount', 'disposalReason', 'status', 'location', 'assignedEmployeeId', 'serialNumber', 'acquisitionType', 'acquisitionJournalId'],
  CapitalAccounts: ['name', 'kind', 'shareholderId', 'currency', 'status'],
  CapitalTransactions: ['date', 'capitalAccountId', 'shareholderId', 'kind', 'amount', 'method', 'destinationAccount', 'assetId', 'status', 'reference'],
  Shareholders: ['name', 'email', 'phone', 'role', 'status', 'agreedCapital', 'investmentDate', 'ownershipPercentage'],
  ShareholderEquity: ['shareholderId', 'effectiveDate', 'percentage', 'amount'],
  ShareholderLoans: ['shareholderId', 'date', 'kind', 'principal', 'interestRate', 'repaidAmount', 'outstandingBalance', 'dueDate', 'paymentAccount', 'lastRepaymentDate', 'paymentReference', 'status', 'reference'],
  FinancialPeriods: ['name', 'startDate', 'endDate', 'status', 'closedBy', 'closedAt'],
  Journals: ['number', 'date', 'description', 'sourceType', 'sourceId', 'totalDebit', 'totalCredit', 'status'],
  JournalLines: ['journalId', 'lineNumber', 'accountId', 'accountName', 'accountGroup', 'debit', 'credit'],
  DocumentRegistry: ['kind', 'name', 'mimeType', 'byteLength', 'relatedSection', 'relatedRecordId', 'status'],
  NumberSequences: ['kind', 'prefix', 'period', 'nextNumber'],
  CreditNotes: ['number', 'invoiceId', 'customerId', 'date', 'reason', 'currency', 'subtotal', 'discount', 'taxAmount', 'total', 'refundAmount', 'refundAccount', 'status'],
  CreditNoteItems: ['creditNoteId', 'invoiceId', 'invoiceItemId', 'lineNumber', 'description', 'quantity', 'unitPrice', 'discount', 'taxRate', 'taxAmount', 'lineTotal', 'subtotal'],
  Tasks: ['title', 'description', 'employeeId', 'assigneeName', 'priority', 'status', 'startDate', 'dueDate', 'startTime', 'endTime', 'project', 'tags', 'reminder'],
  TaskComments: ['taskId', 'body'],
  TaskActivity: ['taskId', 'action', 'summary', 'authorName'],
  Projects: ['name', 'description', 'status'],
  MoneyTransfers: ['date', 'fromAccount', 'toAccount', 'amount', 'description', 'reference', 'status', 'bankStatus', 'statementDate', 'statementReference', 'reversalDate', 'reversalReason'],
};
for (const name of ['Invoices', 'Quotations', 'Receipts', 'Income', 'Expenses', 'Payroll']) {
  for (const field of ['currency', 'baseCurrency', 'exchangeRate', 'rateDate', 'rateSource', 'paymentExchangeRate', 'baseAmount']) {
    if (!FIELDS[name].includes(field)) FIELDS[name].push(field);
  }
}
export const TABLES = Object.freeze(Object.entries(FIELDS).map(([title, fields]) =>
  Object.freeze({ title, headers: [...SYSTEM, ...fields] })));
