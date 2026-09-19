# Private control registry and company schema plan

Phases 1–2: atomic control metadata is stored in the operator's private Cloud Storage
object. No company accounting data is stored there. A normalized operator-owned
Google Sheet is proposed as a recoverable control registry projection in a later step.
It is not yet created or populated by this code.

The projection must not authorize requests: Sheets row writes do not provide the
atomic conditional updates needed for concurrent registration and session changes.
Server-side control storage resolves membership, company resource locations and
credentials. Projection writers use deterministic row identity, record versions,
and serialized/recoverable updates so retries do not append duplicates. A stale
projection must not restore permissions or reactivate revoked sessions.

## Proposed operator Sheet

Each item has dedicated columns; no complete-record JSON cells. This sheet belongs
to the operator, is not returned to Flutter, and is never shared with customers.

| Tab | Columns |
| --- | --- |
| RegistryConfig | key, value, schemaVersion, updatedAt, updatedBy |
| Owners | ownerId, googleSub, email, displayName, status, sessionVersion, createdAt, updatedAt |
| Companies | companyId, companyName, stage, ownerId, spreadsheetId, rootFolderId, schemaVersion, recordVersion, createdAt, updatedAt, deletedAt |
| Memberships | membershipId, ownerId, companyId, role, status, createdAt, updatedAt, recordVersion |
| SetupOperations | operationId, companyId, stage, idempotencyDigest, requestDigest, resourceOperationTag, attempts, errorCode, createdAt, updatedAt, recordVersion |
| GoogleConnections | connectionId, companyId, ownerId, googleSub, status, grantedScopes, credentialReference, connectedAt, revokedAt, recordVersion |
| Documents | documentId, companyId, kind, driveFileId, parentFolderId, mimeType, byteLength, createdAt, createdBy, deletedAt, recordVersion |
| ControlAudit | eventId, companyId, actorId, action, targetId, outcome, requestId, createdAt |

`credentialReference` is an opaque server reference, never a plaintext or encrypted
refresh token copied into a shared sheet. Refresh-token ciphertext is held in
private backend storage with KMS owner/company-bound authenticated context.
OAuth secrets stay in Secret Manager. Session/OAuth records and future employee
credential hashes are kept in backend-only storage, not exposed through sync.

## Proposed per-company business sheets

Phase 2 implements this normalized schema for newly provisioned workspaces in
`src/company-schema.js`. It replaces no existing company sheet. Detailed field
mapping and a non-destructive migration report are required before legacy adoption.

Shared fields where applicable: `recordId`, `companyId`, `createdAt`, `createdBy`,
`updatedAt`, `updatedBy`, `recordVersion`, `syncStatus`, `isDeleted`,
`idempotencyKey`. Parent/child relationships use stable IDs. Role permissions,
invoice/quotation items, receipt allocations and payroll items use separate rows.

| Group | Tabs |
| --- | --- |
| Configuration and access | SystemConfiguration, CompanyProfile, OwnersUsers, Roles, RolePermissions, Employees, EmployeeAccess |
| Sales | Customers, ProductsServices, Invoices, InvoiceItems, Receipts, ReceiptAllocations, Quotations, QuotationItems |
| Finance | Income, Expenses, ExpenseAttachments, FinancialPeriods, Journals, JournalLines |
| Workforce | Attendance, Overtime, Payroll, PayrollItems, Payslips |
| Capital and assets | Assets, CapitalAccounts, CapitalTransactions, Shareholders, ShareholderEquity, ShareholderLoans |
| Operations | DocumentRegistry, SyncOperations, AuditLog, NumberSequences |

EmployeeAccess in a customer Sheet may contain non-secret access status only.
The backend-owned invite index, salted code hashes, lockout counters and session
revocation state must not be editable by an employee through business APIs.
No bootstrap transactions, tax numbers, bank values or reviewer sharing are seeded.

## Implemented company Drive folders

```text
TPC Accounts - Company Name/
  Company Logo/
  Invoices/
  Receipts/
  Quotations/
  Expenses/
  Employee Documents/
  Payslips/
  Financial Reports/
  Assets/
  Exports/
  Backups/
  TPC Accounts Database (spreadsheet)
```

Each external create operation requires a persisted operation tag and resource
reconciliation after uncertain outcomes. Save returned IDs immediately. Do not
retry Drive/Sheets creation blindly after a timeout. Resolve legacy logo/document
links internally during migration and give Flutter opaque document identifiers.
