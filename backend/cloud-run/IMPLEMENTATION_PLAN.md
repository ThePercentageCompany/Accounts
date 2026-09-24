# Repository review and phased implementation

## Current architecture

- Vercel builds and serves Flutter web; `vercel.json` rewrites frontend routes to
  `index.html`. No shared SaaS API existed before this package.
- `GoogleSession` owns Google sign-in, browser access tokens, employee sessions,
  current workspace selection and scheduled sync. Owner sign-in currently requests
  identity and broad Drive/Sheets scopes together.
- `GoogleWorkspaceService` calls Google APIs directly from Flutter. It creates
  folders/Sheets, reads and writes the existing schema, uploads and fetches private
  documents, and returns resource IDs in `WorkspaceConfig`.
- `CompanyOnboardingView` creates the workspace using that client-side service.
  Empty customer fields and opt-in reviewer sharing were already corrected.
- `EmployeeGateway` accepts only the compiled trusted Apps Script URL. The script
  authenticates employees and validates section/row access using live employee data.
- Billing, office and quotation Cubits consume repository interfaces. Hybrid
  repositories preserve local operation and enqueue cloud changes. Freezed models
  represent invoices, employees, payroll, assets and other accounting records.
- `SyncManager` persists pending operations and caches locally, including resource
  IDs and record versions. Existing schema combines some item/relationship fields;
  it is not yet the full normalized target requested for SaaS.

## Existing gateway security limitations

These are migration constraints; existing permission checks must be preserved.

- Its configured spreadsheet/folder and effective Apps Script owner represent one
  company. Reusing it as a public shared endpoint cannot isolate arbitrary tenants.
- Owner management checks a verified email against a configured owner email rather
  than registering Google `sub` with tenant memberships and revocable owner sessions.
- Workspace responses expose spreadsheet and folder IDs, contrary to the new
  backend-only resource resolution requirement. IDs alone are not Google credentials,
  but the new API should not require or disclose them.
- Legacy invite payloads identify employee/company context instead of a server-side
  opaque invite index. They require reissue after tenant registration.
- Flutter owner repositories bypass a shared API and control authorization boundary.
  Securing only employee routes would not complete the requested architecture.
- Apps Script credentials/storage and single-deployment lifecycle do not implement
  operator Secret Manager/KMS or separate offline Google connections per company.

## Backend structure

```text
backend/cloud-run/
  src/
    server.js           production composition and lifecycle
    config.js           validated operator settings
    http.js             routes, cookies, CORS, CSRF, body limits, safe errors
    service.js          owner sessions and tenant registration authorization
    google-identity.js  Google authorization-code/PKCE and ID-token verification
    registry.js         atomic transaction/retry boundary
    google-storage.js   private durable control store with generation checks
    crypto.js           random identifiers, hashes, KMS token vault boundary
    errors.js           public typed API errors
  test/                 service, HTTP, identity and adapter tests
  Dockerfile            Cloud Run container packaging
  .env.example          blank operator settings, no secrets
  API.md                phase-labelled contract
  CONTROL_REGISTRY.md   normalized control/business schema proposal
```

Phase 2 adds `google-connection.js`, `google-workspace.js`, `workspace-service.js`,
`company-schema.js`, `setup-queue.js` and `integrity.js` for offline consent,
resumable provisioning, normalized schema, authenticated tasks and integrity checks.
Phase 3 adds `employee-service.js`, `employee-sheets.js`, `employee-policy.js` and
`private-code.js` for employee CRUD/access, live Sheets authorization, privacy
policies and scrypt codes. Subsequent phases add business writes, documents, sync
and Flutter migration.
Secrets and Google resource IDs are never part of frontend-facing company models.

## Existing files affected

Phase 1 changes documentation (`SAAS_ONBOARDING.md`, `SETUP.md`, `VALIDATION.md`)
and the `.env.example` ignore exception. It adds the backend package. Earlier
upload/sync and onboarding work remains intact; no accounting modules are rewritten.

Planned Flutter integration touches:

- `lib/core/auth/google_session.dart`, `employee_gateway.dart`,
  `google_workspace_service.dart`: replace direct owner Google authority and
  resource-ID-based configuration with fixed API sessions and opaque company IDs.
- `lib/core/auth/company_onboarding_view.dart` and employee login/access screens:
  connect Google, progress/retry, reconnect, opaque invitations and code handling.
- `lib/core/sync/sync_manager.dart`: retain pending changes, rekey scope by company,
  send stable operation IDs and expected versions to the API.
- Billing/office/quotation repository implementations: route remote operations
  through API adapters while retaining domain interfaces and offline behavior.
- Domain models and generated Freezed files only where opaque IDs or normalized
  relationships require changes; accounting calculations stay intact.
- `lib/main.dart`, frontend build/config examples and `vercel-build.sh`: trusted
  fixed API origin and new session/navigation wiring once the backend is ready.
- Existing tests plus migration and cross-tenant integration tests.

## Phases and acceptance gates

1. **Backend foundation, owner auth, registration — implemented locally.** Verified
   Google identity by `sub`, state/nonce/PKCE, HttpOnly hashed sessions, logout/all
   session revocation, company membership and idempotent registration. Test tenant
   isolation, concurrent retry, ambiguous successful writes and resource-ID hiding.
2. **Google connection and provisioning — implemented locally.** Separate owner-bound offline consent;
   Secret Manager/KMS; all requested resumable stages; tagged resource reconciliation;
   normalized schema creation/verification; authenticated Cloud Tasks; setup retry;
   reconnect without replacement. An ambiguous spreadsheet create that never
   becomes discoverable needs operator review; see the README recovery limit.
   The private control Sheet projection remains planned, not an authorization source.
3. **Employee access and authorization — implemented locally.** Opaque invite index,
   salted scrypt codes, distributed attempt limits/lockout, reset/revoke, live
   roles/sections/record/field policies and read-only employee record API. Document
   policy helper is tested; serving document bytes and employee business writes
   remain Phase 4. No Flutter QR rendering/scanner integration yet.
4. **Business API and offline sync — in progress locally.** Allowlisted owner CRUD,
   expected versions, soft deletion, stable operation keys and deterministic
   uncertain-write recovery, ordered batch upload and tombstone downloads are implemented. Relationship/accounting
   invariant validation, documents and employee business writes remain.
5. **Flutter integration and reviewed migration.** Connect API auth/onboarding,
   progress/reconnect screens, repository adapters, opaque invites, local-cache and
   queue mapping, adoption dry run and backup. Verify legacy data and reissue invites.
6. **Preproduction verification and approved release.** Two real tenants, owner
   offline access, revoked Google connection recovery, real camera QR, private images,
   load/contention, IAM, logging, abuse controls and restoration tests.

Registration alone does not create company Google files. Phase 2 queues their
creation after owner Google consent. Existing workspace migration is still pending.
Production deployment and destructive migration require explicit approval.
