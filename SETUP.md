# Shared-backend setup

The application now starts with the Cloud Run API flow. There is no Apps Script,
GoogleSession or direct-Sheets login fallback in `lib/main.dart`. Old local
records are outside this release. New SaaS companies receive empty workspaces.

## Operator configuration

1. Deploy the shared backend using `backend/cloud-run/deploy-cloud-shell.sh`.
   The retired Apps Script backend and its tests have been removed. Existing deployment configuration must be reviewed
   before rerunning it. It now uses the website origin for API callbacks;
   `vercel.json` routes `/v1/*` to the existing Cloud Run service.
2. Verify the trusted API origin, same-site browser cookies, OAuth callbacks,
   Google connection, company provisioning and live tenant isolation.
3. Set `SAAS_API_ORIGIN` to that verified HTTPS origin. No OAuth client secret
   is compiled into Flutter. Do not put a Cloud Run URL in EMPLOYEE_GATEWAY_URL.
4. For operator testing, set `SHARED_WORKSPACE_PREVIEW=1` and run:

```bash
bash scripts/build-shared-web.sh
```

The Vercel build delegates to the same script. The script intentionally blocks
an ordinary production build until the remaining workspace integration is
finished. Do not deploy this preview over a working accounting site.

## New flow

- Owner: Google sign-in through the backend, create/select company, connect
  Google storage, refresh/retry provisioning.
- Employee: scan/paste a backend-issued invitation, enter a separate private
  code, receive a server-verified identity and assigned sections.
- Missing API configuration: display an operator configuration error rather
  than reverting to legacy authentication.

## Work still required before rollout

Employee administration and shared record views are connected. Owners can manage
employee access, create/edit customers and income/expense entries, and manage
financial periods. Most other financial modules remain read-only in the new app.
Full accounting/ledger integration, reports, document UI and legacy offline/data
live verification remains required. No customer should deploy scripts.

See [Software workflow and delivery status](SOFTWARE_WORKFLOW_AND_STATUS.md) for
the consolidated completed/pending checklist dated 26 September 2026.

Retained legacy source and tests are historical references, not active routes.
Cloud resources and the live website have not been changed by this local cutover.

## Deployment access and routing verification

Install the Google Cloud CLI and Vercel CLI on the operator computer. Authenticate
locally with `gcloud auth login`, `gcloud config set project accounts-508118`, and
`vercel login`. Never paste access tokens or OAuth secrets into chat or commit them.

The prepared routing configuration uses `https://accounts.thepercentagecompany.com`
for both `APP_ORIGIN` and `API_ORIGIN`. Set Vercel's `SAAS_API_ORIGIN` to that same
origin when releasing the completed frontend. `config/saas.production.json` holds
only this public value for local Flutter builds; Vercel uses its environment setting.

Before switching the backend origin, add these exact authorized redirect URIs to
the existing Google OAuth web client:

- `https://accounts.thepercentagecompany.com/v1/auth/google/callback`
- `https://accounts.thepercentagecompany.com/v1/google/callback`

Keep any existing redirect URIs required by the running app during the transition.
The proxy and backend origin must be released together and verified with actual
browser sign-in, cookie persistence and Google storage connection.

Run `node scripts/check-live-backend.mjs` after deployment. It checks public health,
unauthenticated access rejection and employee login CORS without sending credentials
or creating data. To check Cloud Run directly in PowerShell:

```powershell
$env:SAAS_API_ORIGIN = 'https://tpc-accounts-api-110697421185.me-central1.run.app'
node scripts/check-live-backend.mjs
Remove-Item Env:SAAS_API_ORIGIN
```

Passing these checks does not establish accounting correctness or tenant isolation.
The production build restriction remains until the outstanding integration and
live verification in `SOFTWARE_WORKFLOW_AND_STATUS.md` are complete. New company
provisioning creates schema and actual company/owner metadata, with no sample
customers, employees or accounting transactions.
