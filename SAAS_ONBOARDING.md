# Automatic company onboarding for SaaS

Status: Phases 1–3 of the shared backend are implemented in `backend/cloud-run`, with local
automated tests. It is not deployed or connected to Flutter yet. Owner identity,
sessions, company registration, separate Google connection, resumable workspace
provisioning, reconnect, employee management, private-code login and current
permission enforcement are implemented. Business writes/sync, document endpoints,
Flutter integration and migration remain subsequent phases. Uncertain spreadsheet creation is reconciled without duplicate
creation; an unresolved outcome needs operator review (see the backend README).
The existing app automatically creates company Sheets and Drive storage, but its
employee gateway is configured for a single owner and spreadsheet. Sharing that
gateway URL across unrelated companies would not provide SaaS tenant isolation.

## Customer experience

1. The owner signs in and enters their company details.
2. The owner grants Google access through the normal consent screen if they want
   to keep using company-owned Sheets and Drive. No scripts or configuration files.
3. The app creates or resumes the company workspace and shows setup progress.
4. Once setup succeeds, the owner adds employees, assigns roles and sections,
   and issues a QR link and separate private login code.
5. Employees scan or open the link and enter their code. They need no Google account.

The company creation form now starts without sample company, tax or bank details.
Optional reviewer sharing starts empty; a new customer's documents are not shared
with a preset software administrator merely because they registered.

## Recommended operator-owned backend

Keep the Flutter website on Vercel and deploy one shared API on Cloud Run.
Use Secret Manager for operator secrets and Cloud KMS for encrypted refresh tokens.
Use a private Cloud Storage control store with generation-based atomic updates for
registration and session metadata; add a normalized private Sheets control registry
projection. Do not use Firestore. Retain each company's existing Sheets/Drive data.
This avoids combining a login migration with an accounting database migration.

The SaaS operator configures the backend, OAuth client, app domain, encryption
keys, database permissions and monitoring once. Customers do not configure these.
Google OAuth consent/verification requirements must be checked for the chosen
scopes before public rollout.

The backend needs the owner's offline Google authorization to access their private
files while they are signed out. Exchange an authorization code on the server and
encrypt refresh tokens with an operator-managed key; never ship those tokens or
the OAuth client secret in Flutter. Use state validation and an authorization flow
appropriate to each platform. Revoked Google access should prompt the owner to
reconnect, preserving the existing company and pending changes.

References: [Google server-side OAuth and offline access](https://developers.google.com/identity/protocols/oauth2/web-server),
[Cloud Storage generation preconditions](https://docs.cloud.google.com/storage/docs/request-preconditions).

## Registration and isolation

- Authenticate owners using verified Google identity; identify them by the stable
  provider subject, not a client-supplied email or spreadsheet ID.
- Allocate an opaque company ID server-side and store an owner membership.
  Resolve its sheet/folder IDs and Google credentials only from server records.
- Store provisioning stages durably: registration, Google connection, folder,
  spreadsheet, schema, ready. Authorize retries and resume existing resources.
  Persist external resource IDs immediately and use operation identifiers to
  reconcile uncertain API outcomes before creating replacements.
- Existing users explicitly connect their current workspace. Verify ownership
  before adoption; preserve records, document references and pending edits.
- Authorize every employee and owner operation against current tenant membership
  and permissions. A submitted company ID, sheet ID, role or allowed-section list
  never grants authority. Backend service-account IAM does not replace these checks.
- Deny direct client access to credentials/session collections. Separate operator
  support access from customer roles and record sensitive support operations.

## API and app integration

Target API overview (owner authentication, registration, connection, provisioning,
retry, status, employee access and permitted record reads are implemented).
See the [exact API contract](backend/cloud-run/API.md).

| Operation | Required behavior |
| --- | --- |
| Create company | Verify owner; accept company details and idempotency key; return company ID and provisioning status. |
| Connect Google | Bind the OAuth transaction to the authenticated owner/company; save encrypted offline authorization. |
| Read setup status | Authorize owner; report ready or a recoverable failure; support retry. |
| Issue/reset employee access | Authorize owner/admin; save current permissions; return a private code once and an opaque invite ID. |
| Employee login | Resolve invite to company and employee; verify a salted password hash; rate-limit attempts; issue an expiring session. |
| Sync and document access | Resolve tenant from the session; enforce sections, record visibility, allowed fields and Drive folder scope. |
| Revoke/logout | Invalidate credentials or sessions server-side; enforce expiry and permission changes on subsequent requests. |

Replace the compiled Apps Script gateway restriction with the operator's shared
API configuration. Do not accept an arbitrary API URL from a scanned QR.
New invite links contain an opaque identifier, not credentials or trusted roles.
Native and web clients must share the same trusted API and app-link origin.
Preserve the separate private code and current server-side RBAC behavior.

Company creation must wait for backend registration and the ready state before
enabling employee invitations. A failed setup should offer retry, not ask a
customer to paste deployment URLs. Existing local-only workspace configuration
must be associated with the authenticated owner's server-side company registry.

## Required verification before rollout

- Two unrelated companies cannot read, change, invite or upload into each other's
  workspaces, even with altered tenant, record or file identifiers.
- An interrupted or repeated signup resumes the same company without duplicates.
- Employee login and sync work after the owner signs out; reconnect works after
  revocation without recreating the workspace.
- Reset codes, expired sessions, permission changes, brute-force protection,
  restricted fields and private document downloads are enforced by the API.
- Existing company data, uploaded logos, offline pending changes and accounting
  results survive migration. Reissue legacy employee invites after registration.

Cloud Run is the selected provider. The operator's project and canonical API/app
origins are still required for live validation. Setting a dummy gateway URL or
suppressing the current warning does not enable SaaS login.

Implementation details:

- [Repository findings and phased plan](backend/cloud-run/IMPLEMENTATION_PLAN.md)
- [Operator configuration and tests](backend/cloud-run/README.md)
- [Implemented and planned API routes](backend/cloud-run/API.md)
- [Control registry, normalized company schema and Drive structure](backend/cloud-run/CONTROL_REGISTRY.md)
- [Employee permissions and operator handoff](backend/cloud-run/EMPLOYEE_ACCESS.md)

No production deployment or destructive migration has been performed. Those
actions require the owner's approval. Current customer workspaces and legacy
invites remain on the existing flow until a reviewed migration is implemented.
