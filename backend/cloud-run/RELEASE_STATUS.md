# Release status

Status: NOT READY for customer production use.

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
The latest backend run has 108 passing test runner entries using substitute cloud
adapters. The Flutter SaaS transport and session controller have eight passing
tests. A reusable company setup view supports owner sign-in, company selection,
registration recovery, Google connection and setup retries. These components are
not yet connected to the production entrypoint, repositories or offline queue.
Registration request keys persist per owner before sending, so a lost response
can be retried after restarting without requesting a second company.

Deployment constraint: keep the multi-company architecture for the initial small
customer base. No load balancer has been created. Choose a low-cost same-site API
route before frontend rollout; direct cross-site cookie authentication against a
run.app URL is not a reliable browser deployment strategy. Existing cloud
resources can incur charges even at low usage; zero cost is not guaranteed.

Release-blocking work:

- Authoritative accounting totals, balanced journals, payment allocation limits,
  finalized-record controls and atomic multi-record business operations.
- Live verification of private document delivery and registry linkage. Local
  transfer code bounds content to 5 MiB and identifies PNG/JPEG/PDF signatures;
  it does not implement malware scanning, retention/deletion or a full decoder.
- Flutter API session/onboarding integration and repository adapters, preserving
  pending offline edits and reporting per-operation failures.
- Employee business writes with explicit action permissions.
- Reviewed legacy migration with backup, dry-run mapping and rollback.
- Real two-company isolation tests, OAuth callbacks, employee camera login,
  private image rendering, owner-offline access and revoked-connection recovery.
- Deployment identity, protected secrets, log redaction, monitoring, backup and
  restore checks, abuse/load checks and resource limits.

The bounded whole-object control registry and full-table reads are initial
implementation limits. They need measured capacity and a growth strategy before
supporting an unrestricted number of companies. Unit-test success alone is not
release approval. Local implementation can continue without cloud access; live
validation requires authenticated Google Cloud access and a reviewed deployment.
