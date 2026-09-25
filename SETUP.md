# Shared-backend setup

The application now starts with the Cloud Run API flow. There is no Apps Script,
GoogleSession or direct-Sheets login fallback in `lib/main.dart`. Old local
records are retained; this cutover does not migrate them into a new company.

## Operator configuration

1. Deploy the shared backend using `backend/cloud-run/deploy-cloud-shell.sh`.
   This is the backend deployment script, not `backend/apps-script/Code.gs` or
   `EmployeeGateway.gs`. Existing deployment configuration must be reviewed
   before rerunning it; it currently names the planned API domain.
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

Accounting repositories, offline migration and the employee management screen
must be connected to the shared API. Provisioned companies currently show setup
status, and authenticated employees show their assigned access; these are not
complete accounting workspaces. Legacy invitations need reissuing through the
backend after verified company migration. No customer should deploy scripts.

Retained legacy source and tests are migration references, not active routes.
Cloud resources and the live website have not been changed by this local cutover.