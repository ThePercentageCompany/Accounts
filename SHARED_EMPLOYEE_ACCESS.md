# Shared employee access rollout

Update 2026-09-25: the production source entrypoint now uses only `SaasApp`.
There is no legacy fallback when the API setting is empty. The old sources are
retained for migration reference, but are not imported by the entrypoint.
Use `SETUP.md` and `scripts/build-shared-web.sh` for the current preview flow.

The old “Employee login is not set up” message refers to the Apps Script
`EMPLOYEE_GATEWAY_URL`. Cloud Run is a different API; never put its URL in that
setting. Do not deploy a per-customer Apps Script gateway for the SaaS rollout.

## Implemented locally

- `SAAS_API_ORIGIN` selects the shared employee authentication screen when the
  employee button is pressed or a backend-issued invitation opens the app.
- `vercel-build.sh` now forwards this setting into Flutter. For a manual build,
  put it in the operator's dart-define JSON file or supply `--dart-define`.
- Login calls `/v1/employee/login` with an opaque invitation ID and separate
  private code. The browser keeps the session in HttpOnly cookies.
- QR codes cannot select another backend or app origin. Legacy invites must be
  reissued. A scanned invitation requires its code even on a shared device.
- Successful login shows server-approved identity and assigned sections. The
  shared accounting screens are **not connected yet**; this is an authentication
  integration, not a completed employee accounting workspace.

## Required before enabling for employees

1. Complete the trusted same-site API routing and OAuth setup for the deployed
   application. The current Cloud Run deployment alone does not establish this.
   Do not use a different-site run.app origin as a reliable production cookie
   solution, and do not create a load balancer just to silence the warning.
2. Register and provision the company through the shared backend. Existing
   legacy Sheets workspaces require verified migration; creating a new company
   does not migrate the owner's current records or offline edits.
3. Save employees and issue invitations through the backend owner endpoints.
   Legacy Apps Script private codes do not authenticate to this backend.
4. Complete the shared workspace data adapters and owner access-management UI.
5. Set `SAAS_API_ORIGIN` to the verified trusted HTTPS API origin and rebuild.
   Test owner registration, employee sign-in, logout, revoked access and two
   unrelated companies in real browsers before production rollout.

No production API setting, DNS or cloud configuration was changed by the local
authentication implementation. No OAuth client secret belongs in Flutter,
Vercel frontend environment variables or QR codes.
