# Validation

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
