# Phase 3 employee access

Implemented locally; not deployed or connected to Flutter. Owners can manage
employees, assign Staff/Manager/Accountant roles and sections, issue/reset/revoke
access, and employees can log in without Google, rotate/logout sessions, read
their current permissions and fetch permitted records through read-only routes.

## Storage and authorization

Profiles, roles and section permissions remain in the company's normalized
Employees, Roles and RolePermissions Sheets. Current rows are fetched on every
employee request. No long-lived token carries trusted role or section claims.
Google access uses the company's server-resolved, KMS-encrypted offline connection.

Invite indexes, salted scrypt hashes, code versions, attempt/lockout counters,
session hashes and mutation acknowledgments are backend-only control metadata.
No private code or employee profile is stored in the control registry. EmployeeAccess
in the company Sheet remains reserved for non-secret status projection; it does
not authorize sessions and is never exposed through employee read routes.

Codes use 18 random bytes and scrypt N=131072, r=8, p=1 with independent random
salts. Comparisons use `timingSafeEqual`. Per-process hashing concurrency is capped
at two to bound memory. Sessions use a separate Secure/HttpOnly host-only cookie,
expire after eight hours, and can rotate up to a fixed 24-hour absolute lifetime.
Reset rotates both invite and code and invalidates existing sessions. Disablement
and revocation block the next request. Revocation does not need live Google access.

Five failed attempts lock an invite for 15 minutes. Attempt reservations are atomic
across instances; correct-code login clears the counter. The current foundation
also caps all employee login attempts at 120/minute across the service, including
unknown invites. Configure edge abuse protection and revisit throughput budgets
before public rollout. Do not trust caller-supplied forwarded IP headers as an
identity for throttling. Budget at least 512 MiB per Cloud Run instance and validate
actual memory/concurrency under load before deployment.

## Invitations

The response contains `inviteLink` and identical `qrPayload`, which Flutter will
render as a QR in Phase 5. Its format is the fixed app origin followed by
`/#employee-invite=<opaque invite ID>`. Only the invite reference goes in the link;
no private code, role, company authority, file IDs or configurable gateway.

`privateCode` is returned separately and only once. An idempotent repeat of an issue
or reset operation returns `PRIVATE_CODE_ALREADY_ISSUED`; if that original response
was lost, reset with a new key. Codes cannot be retrieved from stored credentials.

## Role and field limits

Section assignment grants read access in this phase. There are no employee business
write endpoints yet; Phase 4 must authorize those separately. Owner management
endpoints require an owner session; the Manager employee role is not an owner.

- Staff sees only their own employee, attendance, overtime, payroll and payslip
  rows; only assigned assets; and their own income/expense records. Child payroll
  and attachment rows also require a visible parent.
- Manager/Accountant may read company-wide rows in assigned sections. Other
  employees' salary/allowance fields are hidden from Manager; Accountant may see
  them when Employees is assigned.
- Employee bank details, address and identity-document fields are withheld from
  all employee profile responses, including self. Owner-specific workflows handle them.
- Tenant ID, soft deletion, live role, sections and the role's privacy ceiling are
  checked server-side. Unsupported roles, permission actions or field templates
  grant no access. Authentication/control tables and the raw document registry
  cannot be fetched by employees.
- Document authorization checks current parent-record visibility and a trusted
  company folder scope. The helper is tested; upload/download endpoints themselves
  remain Phase 4 and must call it before returning bytes.

## Safe employee changes

Create/update requires a unique `Idempotency-Key` and `expectedVersion`. Changes
to the profile, assigned role and individual section rows use one atomic Sheets
batch with literal typed cells. Omitted optional contacts and untouched salary,
bank and identity fields are preserved.

One company employee mutation can be pending at a time. A durable control intent
reserves the submission; API retries reconcile the operation marker in Sheets.
An unknown outcome blocks other employee mutations and employee requests until
confirmed, preventing a pending permission removal from being bypassed. A known
pre-submission/rejected request can be retried. If no confirmation ever appears,
operator review is needed; never clear a submitted intent while a late write
could still complete. Direct concurrent edits/reordering in Sheets are outside
this API transaction boundary and require operational restrictions/review.

Read responses currently cap tables at 10,000 rows; large-scale pagination and
control-store sharding remain release prerequisites. Existing company migrations
are not performed by these routes.

## Work needed from the SaaS operator before live verification

No customer action is required. The operator must provide/configure:

1. Google Cloud project ID, chosen region, real app domain and API domain.
2. OAuth web client and the two redirect URIs documented in README; approved test
   accounts/consent configuration. Put the client secret in Secret Manager, not chat.
3. Private control bucket, symmetric KMS key, Cloud Tasks queue, runtime and worker
   service accounts with the documented permissions; use resource names in `.env`.
4. The backend's deployed `run.app` origin for worker callbacks. Deployment needs
   explicit approval; no production deployment has been executed here.

Live checks then need two separate test-owner Google accounts to confirm file
isolation, real refresh/reconnect, task delivery, and employee login after owner logout.
Real QR scanning in the Flutter UI follows Phase 5 integration. Do not publish this
backend as the completed SaaS product before those remaining phases and checks.
