# Validation

## September 24: private documents and Flutter transport

- PASS: 108 backend runner entries using `npm test -- --test-isolation=none`.
- PASS: five Flutter SaaS client tests: trusted origin/QR parsing, CSRF and stable
  operation keys, session expiry, proxy failures and partial sync failure handling.
- Document tests cover lost Drive/Sheets responses without duplicate resources,
  cross-owner/tenant denial, removed records, revoked sessions during download,
  bounded content, changed bytes and private HTTP response headers.
- Seeded company profile updates and same-record document attachment validation
  are covered. Generic company profile duplication/deletion is rejected.
- Cloud adapters remain substitutes. No deployment or customer-data migration.
  The new Flutter transport is not connected to existing screens or repositories.

## Local journal posting verification

- PASS: 99 backend test runner entries (`npm test -- --test-isolation=none`).
- Journal posting uses exact two-decimal sums; rejects forged totals, duplicate
  line numbers, invalid accounts/amounts and unbalanced active lines. Posted journal
  edits, deletes and line reassignment are rejected.
- Account registry validation, period closing and reversal workflows remain pending.

## Production-readiness audit and field validation

- PASS: 95 backend test runner entries (`npm test -- --test-isolation=none`).
- Financial fields reject coerced strings/booleans, non-finite numbers and values
  beyond bounds. Dates reject invalid calendar days; text and currency types checked.
- Concurrency regression covers rejected employee retries preserving pending writes.
- Production remains blocked by the items in backend/cloud-run/RELEASE_STATUS.md;
  these local results do not verify a live cloud deployment or Flutter integration.

## Local employee relationship verification

- PASS: 92 test runner entries (`npm test -- --test-isolation=none`).
- Added historical inactive-employee references, deleted-employee rejection,
  payroll/payslip employee consistency and pending employee-write exclusion.
- Document endpoints, accounting totals validation and Flutter integration remain
  pending. No cloud deployment or customer-data migration performed.

## Local business relationship verification

- PASS: 90 test runner entries using `npm test -- --test-isolation=none`.
- Checked missing, deleted and foreign-company parent rejection, required child
  parents, invalid reference types, and deletion with active dependents.
- Employee/document relations and financial aggregate validation remain pending.

## Local tombstone and HTTP sync verification

- PASS: 87 test runner entries with `npm test -- --test-isolation=none`.
- Verified minimal deletion tombstones, session revocation during a Sheets read,
  HTTP sync dispatch, CSRF rejection, request-size limits, strict download query
  parsing and browser DELETE preflight. Google adapters are still substitutes.

## Local ordered sync verification

- PASS: 85 Node test runner entries with `npm test -- --test-isolation=none`.
- Added batch replay, reordered-field idempotency, stop-on-conflict, full-envelope
  validation, cross-tenant rejection, and competing-request reservation tests.
- Ordered batch upload is implemented; documents, accounting invariants, download
  synchronization and Flutter integration remain pending. No cloud deployment.

## Shared SaaS API Phase 4 record slice — 2026-09-23

- PASS: 82 backend tests, including owner business CRUD routing, tenant isolation,
  version conflicts, system-field rejection, soft deletion, idempotent replay and
  lost-response reconciliation without duplicate Sheets writes.
- PASS: syntax checks for all backend source modules and `git diff --check`.
- Remaining Phase 4 work: batch offline sync, relationship/accounting invariant
  validation, document transfer and employee business writes. No cloud resources
  remain after the operator-approved scoped reset; no deployment was performed.

## Shared SaaS API Phase 3 — 2026-09-19

- PASS: all 76 backend tests, including real scrypt hashing and local HTTP cookie tests.
  Run from `backend/cloud-run`:

  ```powershell
  node --test --test-isolation=none test/accounts.test.js test/adapters.test.js test/google-identity.test.js test/http.test.js test/workspace.test.js test/google-workspace.test.js test/employees.test.js test/employee-sheets.test.js
  ```

- Added coverage: employee creation/retry/version conflicts, normalized Sheets
  writes, preserving omitted contact/payroll fields, one-time private code handling,
  opaque QR payload, login without an active owner session, live permission removal,
  own-row/child-row privacy, forbidden control tables, document policy folder checks,
  reset/disable/revoke, expiring and absolutely bounded sessions, rotation/logout,
  distributed failed-attempt lockout, unknown-invite rate budget, independent cookie
  handling, tenant identifier tampering and uncertain employee-write recovery.
- Google API/storage/task adapters remain substitutes; no live cloud access tested.
- Document policy is tested as a helper. Upload/download endpoints, employee
  business writes and offline sync remain Phase 4. Flutter/QR camera integration
  and reviewed legacy migration remain Phase 5. Control Sheet projection is pending.
- Paused before live verification. Operator project/domain/resource configuration
  and deployment approval are still required. No production deployment or migration.

## Shared SaaS API Phase 2 — 2026-09-19

- PASS: 53 Node tests using the real local HTTP server and substitute Google,
  storage, KMS and task adapters. Command from `backend/cloud-run`:

  ```powershell
  node --test --test-isolation=none test/accounts.test.js test/adapters.test.js test/google-identity.test.js test/http.test.js test/workspace.test.js test/google-workspace.test.js
  ```

- PASS: syntax checks for all backend source modules and `git diff --check`.
- PASS: dependency install/audit after adding Cloud Tasks reports zero known vulnerabilities.
- Added coverage: separate offline consent and required scopes, matching Google
  subject, single-use/session-bound connection state, encrypted token persistence,
  Secret Manager/KMS CRC32C integrity, authenticated task dispatch, owner logout
  during setup, normalized RAW Sheets writes, no sample transactions, resume after
  lost create responses, concurrent/expired worker fencing, preserved resources
  on reconnect, missing-resource failures, schema mismatch and revoked access.
- Recovery limit verified: an ambiguous spreadsheet create is reconciled by tag.
  If it never becomes discoverable, setup pauses for operator review; it does not
  automatically issue another create. Folder retries use saved generated IDs.
- NOT RUN: live Google consent, Cloud Tasks/Cloud Run ingress, Secret Manager,
  KMS, real Drive/Sheets creation or browser cookie verification on production domains.
- NOT IMPLEMENTED: employee SaaS access (Phase 3), business CRUD/sync (Phase 4),
  Flutter integration and reviewed legacy migration (Phase 5), control Sheet projection.
- No production deployment, destructive migration or live company data changes.

## Shared SaaS API Phase 1 — 2026-09-19

- PASS: 24 Node tests in `backend/cloud-run`, run with `node --test
  --test-isolation=none test/accounts.test.js test/adapters.test.js
  test/google-identity.test.js test/http.test.js`.
- PASS: installed/locked backend dependencies audited with zero known vulnerabilities.
  A scoped UUID override patches the Google Storage SDK's transitive gaxios dependency.
- Coverage: concurrent and interrupted registration retries, owner isolation,
  idempotency conflicts, membership removal, stable Google subject across email
  changes, session expiry/logout/revocation, OAuth state binding/expiry/replay,
  PKCE/nonce/identity verification boundaries, CORS/CSRF, request limits, private
  response fields, fail-closed storage, generation preconditions and KMS context binding.
- Tests use substitutes for Google services; HTTP tests exercise the real local API
  server. No live OAuth, Secret Manager, Cloud Storage or KMS verification was performed.
- NOT IMPLEMENTED in Phase 1: offline Google connection, file provisioning,
  normalized schema migration, employee SaaS login, business API/sync or Flutter
  integration. These are not represented as passing tests.
- NOT RUN: production deployment or destructive migration. Existing data is unchanged.

## Historical validation — Google-only expansion

The following notes describe an earlier delivery, not the current environment.

- PASS: 26 Node backend tests (`node --test backend/core.test.cjs`).
- PASS: Dart source delimiter check (`python3 scripts/check_source.py`). This is not a Dart compiler/analyzer.
- PASS: Firebase runtime imports/dependencies, function folder and configuration removed.
- NOT RUN: Flutter dependency resolution, Freezed generation, Flutter analyzer/tests, Android/web/iOS builds, rendered PDF visual QA or device interactions.
- NOT RUN: live Google Sign-In/OAuth, API executable, Google Sheets and Google Drive integration.

Flutter/Dart are unavailable in this workspace and the earlier SDK download was blocked. Google account/project identifiers and deployments have not been supplied.

Backend tests use in-memory Google-service substitutes. They cover invoice arithmetic/rounding/validation, numbering and retry behavior, snapshots, stale versions, payment/overpayment, void retention, archive retries, Google email allowlist rejection, employee codes, attendance uniqueness, payroll arithmetic, missing/changed attendance, approved payroll locks, duplicate salary payments, supplier settlement and invalid payroll inputs.

Flutter tests are supplied for Freezed JSON serialization, invoice/PDF basics, Cubit state, payroll calculation and cash-flow aggregation without duplicate invoice/payroll transactions. They remain unrun here.
# SaaS session integration — 2026-09-24

- Full Flutter regression suite: **154 tests passed**.
- SaaS API/session tests cover trusted origins, CSRF headers, partial sync
  failures, expired sessions, registration recovery after a lost response and
  preservation of local pending edits on logout.
- Added reusable company setup controls and a shared-backend session controller.
  These are not enabled in the production entrypoint yet. Accounting repository
  migration, browser OAuth/cookies and live two-company checks remain required.
- No cloud resources, frontend deployment or DNS changes were made in this step.
# Sign-in redesign — 2026-09-25

- Replaced the production entry screen's old login card with a responsive
  desktop/mobile layout and separate owner and employee access sections.
- Existing Google authorization, account switching, employee login and QR
  handlers remain connected. This does not switch accounting to the SaaS API.
- Three focused widget tests passed, including 375px and 1200px layouts with
  150% text scaling and employee-login navigation. Fixed the discovered narrow
  screen brand overflow. Browser Google button and live OAuth still need manual
  verification before deployment.
# Shared employee authentication — 2026-09-25

- Added a shared-backend employee login route selected by `SAAS_API_ORIGIN`;
  the web build now forwards this setting. Legacy gateway fallback is retained
  only when the shared API is not configured.
- Eleven focused tests passed (API, session, employee login and app mounting).
  Foreign-origin invitation links cannot submit credentials. Fresh invitations
  always require a private code; successful login shows server-approved access.
- Production configuration is not enabled. Company migration, backend-issued
  invitations, same-site routing and employee accounting adapters remain required.
  See `SHARED_EMPLOYEE_ACCESS.md` for the exact boundary of this implementation.
# Shared-only entrypoint — 2026-09-25

- Replaced `main.dart` startup/navigation with the shared backend flow; removed
  GoogleSession initialization, Apps Script fallback and old workspace routes.
- Extracted QR scanning into the SaaS module with trusted-origin invite checks.
- Added `scripts/build-shared-web.sh`, delegated Vercel builds to it, and rewrote
  `SETUP.md`. Builds require explicit API configuration and preview opt-in while
  accounting integration is incomplete.
- Full Flutter suite: **158 tests passed**. Targeted analyzer: no issues.
- No production deployment performed. Legacy business source and local data are
  preserved for migration; shared accounting and employee administration remain
  incomplete. This source cutover is not a production-ready replacement yet.
# Shared workspace integration — 2026-09-25

- Owners can open a provisioned company, list/add/edit employees, assign roles
  and sections, issue a QR with a separate one-time code, reset and revoke access.
- Employee edits persist by owner/company before submission. Ambiguous writes
  reuse their original request key after restart. Only confirmed rejections can
  be explicitly discarded. Codes are never stored in preferences.
- Owners and employees can read backend records; employee reads use only the
  employee endpoints. No legacy local account data is loaded into this workspace.
- Customer create/edit uses a durable queue with separate storage per operation;
  only APPLIED results are acknowledged, including within HTTP 200 batches.
- Eighteen focused tests passed across API/session, employee administration,
  employee login, record scope, pending writes and app startup. Tests used
  workspace-local temporary storage after the system temp disk filled up.
- Financial writes remain read-only in the new workspace. Invoice/payment
  transaction integration, payroll/ledger workflows, legacy migration and live
  OAuth/tenant validation are still incomplete. Production restriction remains.
# Income and expense integration — 2026-09-26

- Owner income/expense create and edit forms use the shared backend and durable
  write queue. Employee record views remain read-only.
- The API calculates tax/total in integer minor units with half-up rounding,
  validates amount precision, dates and payment status, and recalculates partial
  updates. Incorrect client-supplied totals are rejected before writing.
- Confirmed rejected edits can be explicitly discarded and refreshed. An unknown
  network outcome cannot be discarded through this recovery action.
- Backend: 113-test suite passed before adding the integration case; all 16
  business/policy tests passed with that case included. Five targeted Flutter
  form/queue/workspace tests passed; targeted analyzer found no issues. A debug
  web compilation completed at `build/saas-test-web` (not a deployed build).
- These are income/expense records, not automatic posted journal transactions.
  Invoice/payment, payroll/ledger integration and live rollout remain incomplete.
# Financial period controls — 2026-09-26

- Owners can create/edit open periods and explicitly confirm closing them.
- Server posting checks reject closed-period dates and invalid journal dates.
  Periods cannot overlap; drafts prevent closing; journals prevent resizing or
  deleting their period. Closing metadata is server assigned.
- All 119 backend tests and four targeted Flutter tests passed.
- Automatic invoice/income/expense ledger posting, reversals, account validation
  and live migration remain incomplete. This is a local change, not deployment.
# Draft journal uniqueness validation — 26 September 2026

Draft line creates and edits reject a number already used by another active line
in the same company and journal, including moves between drafts. Self updates,
other companies/journals and deleted lines do not cause false conflicts. Posting
retains its independent uniqueness check. Full backend suite: 121 passed using
`npm test -- --test-isolation=none`. This change is local, not deployed.
# Atomic business writer validation — 26 September 2026

The internal BusinessSheets writer now supports bounded multi-record writes in
one spreadsheets.batchUpdate request. Single-record writes use the same path.
Tests verify typed literal values, one growth operation per sheet, rejection of
duplicate row targets and invalid members before submission, tenant identity,
capacity limits, and pre-submission versus uncertain network failures.
Full backend suite: 124 passed (`npm test -- --test-isolation=none`). These tests
use substitute Google adapters; source-to-ledger posting is not yet connected
and no cloud deployment was performed.
# Legacy backend removal and source protection — 26 September 2026

Removed the five retired Apps Script files and their two dedicated test files.
Historical test results below refer to those files before removal. Cloud Run is
the active backend. Shared ledger/cash date validation now uses one implementation.
Linked income/expense updates and deletes fail before submission and release the
unsubmitted reservation. Automatic posting remains incomplete.

Validation: 126 backend tests passed; the business integration suite passed again
after adding linked-source rejection assertions; two Flutter record-queue tests
passed. No cloud resources or customer data were changed.
# Explicit cash ledger posting — 26 September 2026

Owner sync accepts post operations only for Income/Expenses, without client
values. Source and generated journals/lines commit in one Sheets batch. Tests
cover income/expense balancing, accrual/payment dates, unpaid entries, closed
payment periods, duplicate requests, lost responses, linked-source locking,
invalid payment details and tenant denial. Full backend suite: 130 passed.
Flutter record-queue/cash-editor tests: five passed. Targeted analyzer: no issues.
Debug web build with the public production-origin configuration succeeded in
`build/saas-test-web`. This is a local operator preview, not a production deployment.
# Later cash payment validation — 27 September 2026

Owners can record a full later payment against a posted unpaid income/expense.
The source and settlement journal commit together; accrual remains unchanged.
The backend rejects duplicate payments, mismatched balances/totals, unposted
sources, closed payment dates and attempts to change the amount. Lost-response
retries reconcile the existing marker. Full backend suite: 134 passed. Four
focused Flutter payment/queue tests passed. Local changes only, not deployed.
# Unpaid cash reversal — 27 September 2026

Added owner reversal of unpaid posted income/expense. Original source financial
fields and journals remain immutable; opposite entries and the source version
commit atomically. Duplicate/retried reversal, payment after reversal, closed or
backdated reversal, paid/unposted sources and empty reasons are covered by tests.
Full backend suite: 137 passed. Five focused Flutter reversal/payment/queue tests
and targeted static analysis passed. Not deployed.
# Owner trial balance — 27 September 2026

Implemented the scoped trial-balance endpoint and owner Reports screen. Exact
integer minor-unit aggregation returns decimal strings. Cutoffs, cancellation
by reversal, malformed ledgers, tenant denial, session revocation, pending writes
and HTTP query/caching are covered. Full backend suite: 143 passed. Report widget
test passed, including rejection of stale totals after a failed refresh. Local
implementation only; no production deployment or live accounting certification.
# Period profit and loss — 27 September 2026

Added owner period profit/loss API and a selector beside trial balance. Date bounds
are inclusive and ordered. Exact signed minor-unit calculations preserve expense
losses and later-period reversals. Full backend suite: 146 passed. The report
remains limited to posted shared journals; this is not a completed accounting
release or a production deployment.
# Balance sheet — 27 September 2026

Added owner balance-sheet API and report selection. Assets reconcile to liabilities
plus posted equity and accumulated earnings. Tests cover cutoffs, closing transfers
without double-counting, negative/contra balances, tenant denial and HTTP queries.
Full backend suite: 149 passed. Three report widget tests passed. This remains
limited to posted shared journals; full transaction coverage and deployment are
still pending.
# Draft invoice policy — 27 September 2026

Added authoritative line rounding and atomic invoice-header refresh, draft-only
mutation guards, server-owned totals and numbering, and protection against direct
issuing. Tested malformed amounts, discounts/tax, duplicates, finalized parents,
moving lines, forged totals, header version conflicts and lost-response retry.
Full backend suite: 154 passed. Invoice forms, issuing, receipts and ledger posting
remain incomplete; no deployment was performed. Two focused Flutter invoice form
tests passed, confirming validation and that calculated totals/status are omitted
from client submissions.

# Invoice issuing — 28 September 2026

Added explicit owner issuing from the shared workspace. The backend assigns the
yearly prefixed number and atomically saves the locked invoice plus balanced
receivable/revenue/VAT journal. Empty/stale invoices, closed periods, invalid
prefixes, repeated issuing and forged client values are rejected. Lost-response
retry does not allocate another number or journal. Full backend suite: 156 passed;
six focused Flutter invoice/queue tests and targeted analysis passed. Not deployed.

# Customer receipt posting — 28 September 2026

Added a server-controlled receipt operation that validates the open invoice,
customer, currency, payment date, period and exact balance. Receipt numbering,
allocation, invoice balance/status update and Cash/Bank-to-Accounts-Receivable
posting commit in one retry-safe batch. Generic receipt/allocation edits are
locked. The owner UI selects only open invoices and validates overpayment.

Full backend suite: **160 passed**. Eight focused Flutter receipt/invoice/queue
tests and the full **177-test Flutter suite** passed. Static analysis introduced
no new errors. Not deployed.
