# Release status

Status: NOT READY for customer production use.

For the consolidated workflow and current module checklist, see
[Software workflow and delivery status](../../SOFTWARE_WORKFLOW_AND_STATUS.md)
(26 September 2026). Earlier deployment and test results below are historical.

Confirmed target: accounts-508118; app https://accounts.thepercentagecompany.com.
The operator deployed the replacement on September 24, 2026: Cloud Build
`6a6f871b-c52c-474d-9bea-adfa3fe60a4a` succeeded and Cloud Run revision
`tpc-accounts-api-00001-2x8` serves 100 percent of traffic in me-central1.
The initial /healthz check returned HTTP 404, but /v1/me reached the application
and returned the expected UNAUTHORIZED JSON. After changing the check to /health,
build `783be07c-8c8f-4181-83db-274180c9e36c` succeeded and revision
`tpc-accounts-api-00002-kxf` passed BACKEND_HEALTH_OK at 100 percent traffic.
Public application reachability is verified from the operator's Cloud Shell.
Custom-domain TLS, OAuth login and live tenant isolation still require validation.
The earlier Google frontend 404 was not conclusively diagnosed; the local proxy
forwarded to the same public URL and did not independently test the container.
Do not attribute that failure to a regional outage without further evidence.

Locally implemented: owner identity and registration, Google provisioning,
employee login/access, owner record CRUD, ordered batch upload, deletion markers,
business/employee references, bounded field types, draft/posted journal guards,
private document upload/download, and same-record document attachment checks.
The latest recorded backend run has 187 passing test runner entries using
substitute cloud adapters. The shared-only Flutter entrypoint connects owner
setup, employee authentication/administration and shared record screens. Customer,
income/expense, period, invoice/receipt, quotation, payroll, fixed-asset and paid
capital-contribution owner writes are connected. Shareholder-loan posting and
full repayment are connected; durable requests reconcile uncertain responses.
Registration request keys persist per owner before sending, so a lost response
can be retried after restarting without requesting a second company.

Deployment constraint: keep the multi-company architecture for the initial small
customer base. No load balancer has been created. Choose a low-cost same-site API
route before frontend rollout; direct cross-site cookie authentication against a
run.app URL is not a reliable browser deployment strategy. Existing cloud
resources can incur charges even at low usage; zero cost is not guaranteed.

Release-blocking work:

Update 2026-09-26: financial period management is connected to owner forms.
Backend rules validate dates, prevent overlapping periods, stamp closing identity,
block closing with drafts, and prevent journal posting in closed periods. Closed
period reopening remains unimplemented. The initial supported source-transaction
ledger scope is implemented locally.

Local UI update (2026-09-25): the new app opens shared workspaces, implements
owner employee administration (including issue/reset/revoke), reads permission-
checked employee records, and creates/edits customers through durable requests.
Other financial tables are read-only. This does not complete accounting writes
or establish live cookie/OAuth readiness.

Update 2026-09-26: owner income/expense create/edit forms now use the durable
record queue. Backend entry validation calculates tax/totals and rejects invalid
dates, payment states and inconsistent supplied totals. Confirmed rejected edits
can be explicitly discarded; uncertain network outcomes remain retryable.
An explicit owner Post to ledger action now generates balanced income/expense
accrual and optional payment journals atomically with the source version. Source
records then lock. Later full payments are supported through a separate atomic
settlement action. Unpaid entries can be reversed with an opposite journal while
preserving original history. Invoice receipts support partial and final customer
payments with server numbering, allocation, balance updates and Cash/Bank-to-AR
posting in one retry-safe batch. Payroll approval/payment and paid asset acquisition/
monthly depreciation plus Cash/Bank capital contributions are also implemented
locally. Paid-entry refunds, receipt reversals, invoice voids, payroll reversals,
asset disposal, and interest-free shareholder-loan receipt/full repayment are
implemented locally. Partial credit notes, configurable accounts/tax treatment,
interest accrual and partial loan repayments remain outside the initial scope.
Deploy the updated backend policy before enabling these frontend entry forms:
the earlier deployed generic-record API does not calculate these totals.

- Authoritative accounting totals, balanced journals, payment allocation limits,
  finalized-record controls and atomic multi-record business operations.
- Live verification of private document delivery and registry linkage. Local
  transfer code bounds content to 5 MiB and identifies PNG/JPEG/PDF signatures;
  it does not implement malware scanning, retention/deletion or a full decoder.
- Flutter API session/onboarding integration and repository adapters, preserving
  pending offline edits and reporting per-operation failures.
- Employee business writes with explicit action permissions.
- Real two-company isolation tests, OAuth callbacks, employee camera login,
  private image rendering, owner-offline access and revoked-connection recovery.
- Deployment identity, protected secrets, log redaction, monitoring, backup and
  restore checks, abuse/load checks and resource limits.

The bounded whole-object control registry and full-table reads are initial
implementation limits. They need measured capacity and a growth strategy before
supporting an unrestricted number of companies. Unit-test success alone is not
release approval. Local implementation can continue without cloud access; live
validation requires authenticated Google Cloud access and a reviewed deployment.
