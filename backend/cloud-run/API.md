# API contract

All responses are JSON except 204 logout responses and the Google callback's
303 redirect. Errors are `{ "error": { "code", "message", "requestId" } }`.
All responses are non-cacheable. Current request bodies are limited to 16 KiB.
Production origin is operator-fixed; invitations cannot supply an API origin.

## Implemented in Phase 1

| Method and route | Input | Result / authorization |
| --- | --- | --- |
| `GET /healthz` | None | Process liveness; no private configuration. |
| `POST /v1/auth/google/start` | `{}` | Google authorization URL; sets browser-bound OAuth cookie. Requires app Origin and CSRF header. |
| `GET /v1/auth/google/callback` | Google `code`, `state` + OAuth cookie | Consume state, exchange code with PKCE, verify ID token/audience/issuer/nonce, set owner session, fixed redirect. |
| `GET /v1/me` | Owner session cookie | `{owner: {ownerId, email, name}}`. |
| `POST /v1/auth/logout` | `{}` + owner session | Revoke current session and clear cookie. |
| `POST /v1/auth/revoke-sessions` | `{}` + owner session | Increment owner's session version, invalidating all existing sessions. |
| `POST /v1/companies` | `{name}` + `Idempotency-Key` + owner session | 201 new registration or 200 replay; `{company, replayed}`. |
| `GET /v1/companies` | Owner session | Only companies with active memberships. |
| `GET /v1/companies/:companyId/setup` | Owner session | Company status after current owner membership check. Other companies return 404. |

POST routes require `Origin: APP_ORIGIN`, `X-TPC-CSRF: 1` and JSON content type.
Owner session expiry is eight hours; revocation/status is checked on each request.
Google identity tokens/access tokens are not accepted as company API authority.

Registration accepts only `name` (1–160 non-control characters). Unknown fields,
including sheet/folder IDs, roles and permissions, are rejected. The idempotency
key must be 16–128 URL-safe alphanumeric/underscore/hyphen characters. Generate
one random key for each intended company and retain it across network retries.
The same owner/key with different normalized input returns 409. Different keys
represent different intended companies, even when their names match.

Company response fields: `companyId`, `name`, `stage`, `createdAt`, `updatedAt`,
`version`, `employeeInvitationsEnabled`, `errorCode`, `nextAction`. Timestamps are Unix milliseconds.
Google resource IDs, owner subject, credentials and session hashes stay internal.
Registration records `REGISTERED` and advances to `GOOGLE_CONNECTION_REQUIRED`
atomically. Invitations are eligible only at READY; employee endpoints are Phase 3.

## Implemented in Phase 2

| Method and route | Input | Result / authorization |
| --- | --- | --- |
| `POST /v1/companies/:id/google/connect` | `{}` + current owner session, Origin and CSRF header | Offline Google consent URL, separate HttpOnly connection cookie; no credentials in response. Used for initial connect and reconnect. |
| `GET /v1/google/callback` | Google code/state + same owner session + connection cookie | Exchange/verify Google identity and granted scopes, encrypt refresh token, persist connection and queue setup, then fixed app-root redirect. |
| `POST /v1/companies/:id/setup/retry` | `{}` + current owner session, Origin and CSRF header | 202 with public company status after durable enqueue; reconnect is required if Google grant was revoked. |
| `POST /internal/setup` | `{companyId}` + Cloud Tasks Google OIDC bearer token | 204 after a bounded step and next-task enqueue. This route uses service authentication, not owner cookies or browser CSRF. |

The existing setup GET route reports stages and recovery codes. `nextAction` is
`CONNECT_GOOGLE`, `RECONNECT_GOOGLE`, `RETRY_SETUP` or null. Error responses do not
contain Google credentials, resource IDs or upstream response bodies.

Workers run after owner logout using encrypted offline authorization. Google
`invalid_grant` or a data-API 401 sets `RECONNECT_REQUIRED`; quota/transient errors
set `RECOVERABLE_FAILURE`. Reconnection keeps saved IDs and company data and
re-verifies existing resources. It cannot adopt arbitrary files submitted by clients.

`RESOURCE_CONFIRMATION_PENDING` means a spreadsheet create had an unknown outcome.
Retry reconciles the tagged original only. If no resource ever appears, operator
review is needed; no endpoint blindly clears that intent or creates a replacement.
The private control Sheet projection is still planned; no projection API is exposed.

## Implemented in Phase 3

Owner routes require the owner cookie, exact app Origin, CSRF header for mutations,
and READY workspace. `GET /v1/companies/:id/employees` lists access profiles.

| Method and route | Contract |
| --- | --- |
| `POST /v1/companies/:id/employees` | Create with `Idempotency-Key`, `expectedVersion: 0`, fullName, role, employmentStatus, allowedSections; optional email/phone/department/designation. |
| `PATCH /v1/companies/:id/employees/:employeeId` | Same required desired access fields with current expectedVersion; omitted optional contact fields are preserved. Returns employeeId, version, replayed. |
| `POST /v1/companies/:id/employees/:employeeId/access/issue` | `{}` plus unique Idempotency-Key; returns opaque invite link/QR payload and separate one-time code. |
| `POST /v1/companies/:id/employees/:employeeId/access/reset` | Same contract; replaces invite/code and invalidates sessions. |
| `POST /v1/companies/:id/employees/:employeeId/access/revoke` | `{}`; immediately revokes without depending on Google availability; 204. |
| `POST /v1/employee/login` | Only `{inviteId, privateCode}`; sets separate HttpOnly employee cookie; returns employee identity/current sections and expiresAt, no bearer token. |
| `GET /v1/employee/me` | Employee cookie; reloads current role/status/sections from Sheets. |
| `POST /v1/employee/refresh` | `{}` + employee cookie; rotates session subject to absolute lifetime. |
| `POST /v1/employee/logout` | `{}`; revokes the session and clears cookie, even if Google is unavailable. |
| `GET /v1/employee/records/:table` | Employee cookie; allowlisted normalized tables, live section/row/field rules, no control/credential tables. Read-only. |

Employee mutations use the same exact-origin/CSRF protections as owner mutations.
Company IDs in owner URLs only select a resource to authorize. Employee routes
resolve company exclusively from the invite/session, never from request parameters.
Role labels are Staff, Manager or Accountant; status is ACTIVE or INACTIVE.
See [employee access](EMPLOYEE_ACCESS.md) for role privacy limits, rate limits,
one-time code recovery and uncertain-write handling. Company-manager employee
accounts cannot call owner management routes.

## Implemented Phase 4 slice: owner business records

Allowlisted normalized business tables now support owner reads and writes. Server
fields cannot be supplied by clients. Writes use expected versions, stable
idempotency keys, soft deletion and uncertain-write reconciliation.

Financial fields require finite JSON numbers (absolute limit 1e12); quantity,
rate and other nonnegative fields reject negative values. Percentages/tax rates
are 0–100, line numbers are positive integers. Text fields reject non-text values
and control characters; dates use valid YYYY-MM-DD, payroll months YYYY-MM, and
currencies three uppercase letters. These are type/range checks, not accounting
aggregate validation. See RELEASE_STATUS.md for remaining release gates.

| Method and route | Contract |
| --- | --- |
| `GET /v1/companies/:id/records/:table` | Active records after live owner/company/READY authorization. Internal markers and sheet row numbers are omitted. |
| `POST /v1/companies/:id/records/:table` | `{expectedVersion: 0, values: {...}}` plus `Idempotency-Key`; generates record ID and version 1. |
| `PATCH /v1/companies/:id/records/:table/:recordId` | `{expectedVersion, values: {...}}`; changes allowlisted business fields. |
| `DELETE /v1/companies/:id/records/:table/:recordId` | `{expectedVersion}`; writes a versioned soft deletion. |

Employee/access and control tables are excluded from generic record APIs.
Multi-record accounting invariants remain planned. Private documents use the
separate endpoints below.

Business-to-business references are now validated before submission while the
company write reservation is held. Populated references must identify an active
record in the same company. Child rows require their parent IDs. Deleting a parent
with active dependents returns `RECORD_REFERENCED`; reassign or delete dependents
first. Optional references can be cleared with an empty string. Polymorphic
journal sources are not covered yet, and direct manual
Sheets edits cannot be serialized by this API.

`POST /v1/companies/:id/sync` accepts `{operations: [...]}` with 1–20 operations,
within the existing 16 KiB body limit. Each operation has `operationId` (the stable
idempotency key), `table`, `action`, `expectedVersion`, and `values` for create or
update. Updates/deletes also require `recordId`; creates must omit it. Deletes
must omit `values`. The whole envelope is validated before any write.

Payroll, attendance, overtime and payslips require a same-company, non-deleted
employee reference; asset assignments validate it when provided. Inactive employees
remain valid references for historical records. Payslip employee IDs must match
their payroll record. Internal reference reads never expose the Employees table
through generic routes. Pending employee and business writes mutually block until
confirmed. Document IDs must reference a completed upload for the same record;
expense attachments reference a document for their parent expense. Polymorphic
journal sources remain pending.

Results are ordered and contain `operationId` and status `APPLIED`, `FAILED`, or
`NOT_ATTEMPTED`. Applied results include recordId/version/replayed. A failed result
includes a sanitized error code/message. Execution stops at the first failure.
HTTP 200 means results are available, not that all writes succeeded. Keep failed
and unattempted changes locally; retry uncertain writes with the same operation IDs
and payloads. Successful operations replay without writing again. Resolve a version
conflict before submitting the corrected edit. Creates return IDs for subsequent
dependent operations; temporary-ID substitution is not implemented.

This is an ordered per-operation protocol, not an all-or-nothing accounting
transaction or a download/change-feed API. Manual concurrent Sheets edits remain
outside its concurrency guarantees.

Owner record downloads support `?includeDeleted=true` for offline reconciliation.
Deleted records return only recordId, companyId, recordVersion, updatedAt and
isDeleted; ordinary reads omit deletions. Apply these tombstones to the local cache
without discarding pending edits. Downloads recheck owner authorization after the
Sheets request. This is a bounded full-table read, not a paginated change feed or
an atomic snapshot across tables.

## Journal validation

Income/expense entry policy (2026-09-26): owner writes require a valid entry date,
nonempty description, positive amount (up to two decimals) and paymentStatus
`PAID` or `UNPAID`. Paid entries require a valid paidDate; unpaid entries clear it.
The server calculates taxAmount and total from amount and taxRate using integer
minor units and half-up tax rounding. Rates support up to two decimal places,
from 0 to 100. Explicit inconsistent totals are rejected. Partial amount/rate
edits recalculate existing totals. This is single-record entry validation; it
does not generate ledger postings or implement invoice/payment transactions.

Journal writes now require DRAFT creation. Posting (PATCH status POSTED) requires
at least two active lines with distinct positive line numbers, nonempty account
identifiers, and exactly one positive debit/credit per line. Debit and credit sums
and supplied header totals must agree exactly. The initial ledger contract permits
two decimal places, summed as integer minor units. Other precisions are rejected.
Posted journals and their lines cannot be edited, deleted, or moved through generic
CRUD. Posting requires a valid date and rejects dates within closed or unknown-state
financial periods (including start/end dates). Dates without a configured period
remain allowed. Reversal workflows and chart-of-account validation are still
pending. Draft header totals are provisional and checked at posting.

Financial periods are created OPEN with valid ordered dates and cannot overlap
another active period. Closing requires all contained journals to be POSTED; the
server stamps closedBy/closedAt. A period containing journals cannot be resized
or deleted. Closed periods are immutable through generic CRUD; reopening requires
a future dedicated audited workflow. Direct manual Sheet edits remain outside
the API's concurrency guarantees.


## Private documents — implemented locally

`POST /v1/companies/:id/documents` requires an owner session, CSRF header and a
stable `Idempotency-Key`. JSON fields: `name`, `mimeType`, `relatedSection` (table
name), `relatedRecordId`, `data` (canonical base64). PNG/JPEG/PDF only, at most
5 MiB decoded, 7 MiB request. Company logos accept only images. Format signatures
are checked; this is not a malware scan. Accepted tables: CompanyProfile,
Invoices, Receipts, Quotations, Expenses, Employees, Payslips and Assets.

The target record must already exist. Upload returns `{documentId, replayed}`.
Then attach that ID with the record's expected version. The seeded company profile
is updated at `/records/CompanyProfile/company`; duplicate creation and deletion
are rejected. Existing uploaded content is immutable through this API.

`GET /v1/companies/:id/documents/:documentId` serves owner-authorized bytes.
`GET /v1/employee/companies/:id/documents/:documentId` uses the employee cookie and
current record visibility. Both check active metadata and related record access;
downloads verify Drive ownership, the configured folder, content size and SHA-256,
then recheck authorization. Responses are no-store/nosniff; PDFs are attachments.
No Google file IDs, public sharing links or arbitrary download URLs are accepted.

Interrupted uploads retain their operation, pre-generated Drive ID and reserved
Sheet row. Retry the identical payload/key; do not issue a new key to recover an
uncertain upload. Other company writes wait while the document is pending.
Google documents pre-generated-ID retry behavior in its
[upload guide](https://developers.google.com/workspace/drive/api/guides/manage-uploads).
Manual edits to the underlying Sheet are outside API serialization guarantees.
Document cancellation, deletion and retention workflows remain unimplemented.

## Planned routes — not implemented, no successful stubs

| Phase | Routes | Contract requirements |
| --- | --- | --- |
| 5 | Reviewed legacy workspace adoption | Owner verification, dry run, backup, resumable migration, mapping and invite reissue; approval before destructive steps. |

Sheets does not provide multi-row compare-and-swap transactions. Phase 4 needs a
durable operation journal with deterministic application/recovery before claiming
exactly-once accounting writes. Registration idempotency alone does not solve
invoice/payment synchronization.
# Linked cash-entry protection

Standalone updates/deletion of Income or Expenses return `409 CASH_ENTRY_LINKED`
when an active same-company journal references the source record. This includes
draft journals, to prevent source/ledger divergence. Source types are `Income`
and `Expenses`, plus retained legacy `finance_income`, `expense`, `supplier_bill`.
Saving alone does not post to the ledger. Owners can explicitly post an existing
Income/Expenses record through `/v1/companies/:companyId/sync` using an operation
with `action: "post"`, `recordId`, `expectedVersion`, `table` and `operationId`,
without `values`. The source version and generated POSTED journals/lines are
written in one atomic Sheets batch. Retrying the same operation reconciles the
source marker. A different request cannot post a linked source again.

Posting recognizes the entry on its date against receivables/payables. PAID
entries additionally settle that control account on paidDate against Cash or Bank;
payment before entry date is rejected. Income tax uses output VAT payable; expense
tax uses input VAT. Tax recoverability choices, custom accounts/currencies,
partial payments and paid-entry refunds remain unsupported. Both dates
must pass the open-period checks. Income/Expenses reads expose derived
`ledgerStatus: UNPOSTED|LINKED`, never accepted as client write authority.

Owners can settle an unpaid posted Income/Expenses entry through sync with
`action: "pay"`, the current expectedVersion, and values containing only paidDate,
account (Cash/Bank) and optional reference. The server derives the full amount,
verifies the existing posted control balance and absence of a payment journal,
then atomically saves PAID and a payment journal. The original accrual is unchanged.
Only the payment date needs an open period; a closed original period is allowed.
Stable operation IDs recover lost responses without repeating payment.

Owners can reverse an unpaid posted Income/Expenses entry with sync action
`reverse`, current expectedVersion, and values `{date, description}` (reversal date
and required reason, max 500 characters). The date must be in an open period and
cannot precede the original posting. Original source financial fields and journals
remain unchanged; a POSTED opposite journal and updated source version commit
together. Reads show `ledgerStatus: REVERSED`; subsequent payment, reposting and
ordinary edits are denied. Paid entries require a separate refund workflow and
are rejected here. Reversal dates do not reopen the original accounting period.
# Owner trial balance

Owner balance sheet uses GET `/v1/companies/:companyId/reports/balance-sheet?asOf=YYYY-MM-DD`.
It returns signed asset/liability/equity account balances, postedEquity and
accumulatedEarnings (the remaining income/expense balances through the cutoff).
totalEquity includes both, avoiding double-counting earnings already transferred
to posted equity. Assets must equal liabilities plus total equity. Exact decimal
strings preserve losses and contra balances. The report uses the same owner and
ledger-integrity checks as trial balance and only includes posted shared journals.

Owner profit/loss uses GET `/v1/companies/:companyId/reports/profit-and-loss?from=YYYY-MM-DD&asOf=YYYY-MM-DD`.
Both dates are required, inclusive and ordered. Posted income is net credit,
expenses net debit; netProfit is income minus expenses. Results are signed decimal
strings, including negative revenue from reversals in the selected period. Asset,
liability and equity balances are excluded from profit. The same owner checks,
pending-write restriction, ledger validation and no-store headers apply. Only
transactions already posted to the shared ledger contribute to the report.

GET `/v1/companies/:companyId/reports/trial-balance?asOf=YYYY-MM-DD` returns
posted balances through that date, grouped by account, with debit/credit totals
as exact two-decimal strings. Owner membership is checked before and after the
single multi-table read. Pending company writes block reporting. No employee
report endpoint is exposed yet. Responses use no-store caching.

Malformed dates, duplicate journal/line identities, inconsistent account labels
or groups, and unbalanced/mismatched posted journal totals fail instead of returning
partial figures. Draft/deleted/foreign-company journals are excluded. Reports
cannot include source transactions that have not been posted to the shared ledger.
# Draft invoice writes

Invoices begin as DRAFT with a customer, issueDate and currency. Due date, when
provided, cannot precede issueDate. Numbering, header totals, paidAmount and balance
are server fields. Generic writes cannot issue or modify finalized invoices.

InvoiceItems require a draft parent, positive quantity and unique positive line
number. Quantity/unit price/discount/tax rate currently support two decimal places.
Gross amount rounds half-up after quantity multiplication; the absolute line
discount is applied before half-up tax. Tax rate must be 0–100, and discount cannot
exceed gross. Supplied taxAmount/lineTotal must match server calculations.

Line creation, edits and soft deletion update parent totals and increment its
recordVersion in the same Sheets batch. Clients must refresh the invoice after
changing lines. Lost-response retries reconcile the line marker without a second
header update. Moving a line to a different invoice is not supported. Owner draft
and line forms are connected; InvoiceItems reads include derived `parentStatus`
so the UI hides edits after finalization.

Owners issue a draft through sync action `issue` with recordId and current
expectedVersion, without values. At least one valid line and an open issue-date
period are required. The server recalculates and matches stored totals, validates
the CompanyProfile invoicePrefix (default `INV`), and assigns
`PREFIX-YYYY-NNNNNN` using the next active invoice number for that prefix/year.
The company-wide write reservation serializes issuance.

The invoice becomes ISSUED and its accounts-receivable debit, net-revenue credit
and output-VAT credit are saved in the same Sheets batch. The source marker makes
a lost-response retry return the existing issue result without allocating another
number or journal. Issued invoices and lines are immutable through generic editing.
## Customer receipt posting

The `receive` action on `Receipts` accepts an invoice, customer, payment date,
amount, currency, Cash/Bank account and optional reference. The server validates
the open invoice and exact outstanding balance and rejects mismatches and
overpayments. It assigns `REC-YYYY-NNNNNN`, creates the allocation, updates the
invoice paid amount/balance/status, and posts Cash/Bank debit and Accounts
Receivable credit in one batch. Stable operation IDs prevent duplicates after
uncertain responses. Posted receipts and allocations cannot be edited through
generic writes. Credit, void, refund, reversal and invoice-document workflows remain.

## Quotation workflow

Quotation headers and lines begin as drafts. Header totals and line tax/total are
calculated by the server using the invoice decimal rules. The `send` action
requires at least one line, verifies stored totals, assigns the configured
quotation prefix (default `QUO`) with `PREFIX-YYYY-NNNNN`, and locks the quotation.

The `convert` action accepts a sent, unconverted quotation and atomically marks it
converted while creating one draft invoice and copied invoice lines. The new
invoice retains the customer, currency, totals, notes and payment terms and must
still pass the normal invoice issuing workflow. Stable operation IDs prevent a
lost response from creating a second invoice. Acceptance/expiry and quotation
document workflows remain.

## Payroll workflow

Payroll drafts accept employee, month, bonus and deductions. The server reads the
employee salary and allowances, includes approved overtime in that month, rejects
duplicates, and calculates gross and net salary. Payroll detail rows cannot be
written through generic record operations.

The `approve` action rechecks current source values, uses the month's final date,
requires an open accounting period, locks the payroll and atomically posts Salary
Expense against Salary Payable and Payroll Deductions Payable. `payrollPay`
requires an approved payroll plus payment date and Cash/Bank account, then posts
Salary Payable against the selected asset account and marks it paid. Stable
operation IDs prevent duplicate approval or payment journals. Payslip generation,
deduction remittance and payroll reversal remain.
