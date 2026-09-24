# TPC Accounts shared API — Phases 1–4 (partial)

Implemented: backend owner sign-in, expiring/revocable owner sessions, atomic
company registration, owner company listing, separate offline Google connection,
KMS-encrypted refresh tokens, resumable Drive/Sheets setup, retry and reconnect,
employee management, opaque invitations, private-code login and permitted record reads.
Not deployed. Flutter still uses its existing authentication and repositories.
No existing workspace is migrated, modified or deleted by this package.

New companies initially stop at `GOOGLE_CONNECTION_REQUIRED`. After owner consent,
authenticated Cloud Tasks advance setup through the requested stages to `READY`.
Owner business record CRUD, ordered sync batches and private document endpoints
are implemented locally. Full accounting transactions and Flutter integration are
unfinished. See [release status](RELEASE_STATUS.md) before deploying for customers.
See [employee access and operator handoff](EMPLOYEE_ACCESS.md) for Phase 3 details.

## Local verification

Requires Node 24. From this directory:

```powershell
npm ci --ignore-scripts
npm test
```

In a sandbox that prohibits child processes, run tests in the current process:

```powershell
node --test --test-isolation=none test/accounts.test.js test/adapters.test.js test/google-identity.test.js test/http.test.js test/workspace.test.js test/google-workspace.test.js test/employees.test.js test/employee-sheets.test.js
```

Tests use substitute Google/storage adapters. They make no live Google API calls.
The production entry point always uses Google identity verification and durable
Cloud Storage; there is no environment setting to enable test authentication.

## Operator configuration

Copy `.env.example` to `.env` for an operator-controlled environment. Its empty
values deliberately fail startup; do not enter dummy URLs. Never put this file or
the backend's secrets into Flutter, Vercel frontend build variables, or source control.

| Variable | Meaning |
| --- | --- |
| `APP_ORIGIN` | Exact HTTPS Flutter origin, without a trailing slash. |
| `API_ORIGIN` | Exact HTTPS API origin; determines the fixed Google callback URL. |
| `GOOGLE_OAUTH_CLIENT_ID` | Operator's Google web OAuth client. |
| `GOOGLE_OAUTH_SECRET_VERSION` | Secret Manager version resource holding JSON with a `clientSecret` field. Prefer a pinned version. |
| `CONTROL_BUCKET` | Private operator bucket for control metadata only. |
| `CONTROL_OBJECT` | Control object name, default `control/registry-v1.json`. |
| `GOOGLE_REFRESH_KMS_KEY` | Symmetric KMS key resource for owner/company-bound refresh-token encryption. |
| `SETUP_TASK_QUEUE` | Existing operator Cloud Tasks queue resource: `projects/.../locations/.../queues/...`. |
| `SETUP_WORKER_EMAIL` | Service account used to sign worker deliveries; must belong to the queue's project. |
| `SETUP_WORKER_ORIGIN` | Default HTTPS `run.app` origin of this same API service, without a trailing slash. |
| `PORT` | Cloud Run listening port, normally injected by Cloud Run. |

The Cloud Run runtime service account uses Application Default Credentials.
Grant secret access only to the specified OAuth secret, bucket object access only
to the control bucket, and KMS encrypt/decrypt access only to the refresh-token key.
Use uniform bucket-level access and enforce public access prevention. No service
account JSON keys are needed in the repository or container.

Register `API_ORIGIN/v1/auth/google/callback` and `API_ORIGIN/v1/google/callback`
as exact OAuth redirect URIs.
Sign-in requests only `openid email profile`. It does not connect Sheets/Drive.
Configure a public OAuth consent application for the intended customer audience;
evaluate verification requirements for `spreadsheets` and `drive.file`. The separate
connection flow requests those scopes with offline access, consent and PKCE. It
requires the same verified Google `sub` as the signed-in owner. Legacy file adoption
is not implemented; `drive.file` covers resources created through this OAuth client.

Configure the Cloud Tasks API and an existing queue, with retries/backoff and a
dispatch deadline of at least 180 seconds. Give the runtime account
`roles/cloudtasks.enqueuer` on that queue and `iam.serviceAccounts.actAs` on the
worker service account. Retain the Cloud Tasks service agent's token-generation
permissions. Task payloads carry only opaque company IDs. The worker verifies
Google's signature, issuer, audience and configured service-account identity; an
owner cookie does not authorize `/internal/setup`. Set a Cloud Run response timeout
of at least 180 seconds. Tasks target the default `run.app` origin, while browser
and Google consent redirects use the configured public API origin.

The public owner/login API must be reachable by browsers; application routes
enforce their own sessions. Keep the worker's Google OIDC Authorization header
intact for application verification. Test the real ingress/auth configuration
before release. Configure queue retry monitoring and a bounded retry policy;
exhausted tasks remain recoverable through the owner's setup retry endpoint.

See [authenticated Cloud Tasks](https://docs.cloud.google.com/tasks/docs/samples/cloud-tasks-create-http-task-with-token)
and [Cloud Run task execution](https://docs.cloud.google.com/run/docs/triggering/using-tasks).

Use related custom domains such as the app and API subdomains of the same site
while keeping Flutter hosted on Vercel. Cross-site Vercel/run.app hostnames can
encounter third-party cookie restrictions. The OAuth binding cookie uses Lax so
Google's top-level callback can send it; session cookies use Secure, HttpOnly,
host-only scope and SameSite=None. Serve local browser integration over HTTPS.

Browser requests use `credentials: include`. POSTs must send `Content-Type:
application/json`, `X-TPC-CSRF: 1` and the exact configured app Origin. CORS permits
only that origin. Start sign-in with a POST, then navigate to its returned Google
authorization URL. The callback sets the session cookie and redirects to the
fixed app root; no session token appears in Flutter JSON or redirect parameters.

## Persistence and concurrency

`GoogleControlStorage` reads a generation-pinned object and writes with
`ifGenerationMatch`. Owner, session, membership and registration changes commit
atomically in the same object. A lost registration response can be retried with
the same key. Access failures never become empty data or successful writes.
Only session token hashes are persisted; OAuth state is hashed and single-use.

Google connection callbacks bind state to the company, current owner session,
browser cookie and latest connection attempt. Secret Manager and KMS payloads have
CRC32C integrity checks. Refresh-token plaintext is never written to the registry,
returned to Flutter or included in task payloads. Reconnect replaces only the grant
and verification checkpoints, preserving saved IDs and schema state.

Setup workers use a 150-second lease plus connection-version checks to reject stale
checkpoints. Each dispatch performs bounded work, saves progress, then awaits durable
enqueue of the next step. Folder IDs are generated and persisted before creation.
The spreadsheet is created in the root folder through Drive with an operation tag;
all schema writes use dedicated columns and RAW input. Existing matching rows are
not overwritten. Only actual registration/owner metadata is seeded, with no sample
financial, bank, tax, employee or reviewer data. The default blank Sheet1 is left
intact; setup never deletes sheets.

**Spreadsheet creation recovery limit:** Google does not support pre-generated IDs
for native spreadsheets. If a create response is uncertain, subsequent attempts
only search for its saved operation tag. If the original resource appears, setup
resumes; if it never appears (including a crash after saving intent but before
sending the request), setup remains `RESOURCE_CONFIRMATION_PENDING` for operator
review. Never clear the intent or blindly create another sheet. This explicit
recoverable condition preserves the no-duplicate guarantee.
See [Google's pre-generated ID limitations](https://developers.google.com/workspace/drive/api/guides/create-file).

The control store is deliberately bounded (8 MiB, 1,000 pending OAuth attempts,
12 CAS attempts). It is a foundation, not a large-scale production datastore.
Before public rollout, shard control metadata with an explicit cross-object
transaction design, load-test contention, add per-source distributed throttling
and abuse controls, and establish retention/backups/restore procedures. Do not
simply remove the bounds or rely on max-instances=1 for correctness.

Accounting and company business records remain in each company's Sheets.
Document bytes will remain in each company's Drive. Cloud Storage here contains
only authentication/control metadata and the company registration name, not
invoices, expenses, payroll, bank details or documents. No Firestore dependency.

See [the control registry design](CONTROL_REGISTRY.md) for the planned Sheets
projection and [the API contract](API.md) for implemented versus future routes.

## Packaging and remaining deployment checks

The Dockerfile packages this service for Cloud Run, runs as an unprivileged user,
and uses the committed dependency lockfile. Deployment is intentionally not run.
The UUID override patches a transitive advisory in gaxios 6.7.1; that package uses
the compatible CommonJS `v4()` API. Reevaluate the override when upgrading Storage.

Before deployment approval: verify live OAuth callback/cookies on the real domains,
Secret Manager permissions, GCS concurrent writes across instances, KMS
encryption/decryption, real Sheets/Drive provisioning and task authentication/retries.
Ensure edge/access logs exclude or redact OAuth callback query parameters and
cookies; application logs deliberately exclude them. Validate data recovery and
rate limits. Health status is process liveness, not a guarantee of Google API access.

Reconnect preserves backend IDs; Flutter cache/queue migration is still Phase 5. Do not
delete or repoint this registry, or restore an old copy containing active sessions,
as a way to fix authorization. Restores require session invalidation and a reviewed
recovery procedure.
