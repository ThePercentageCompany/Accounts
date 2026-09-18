# Setup and deployment

For the planned SaaS product, customers should only sign in, create their company,
and invite employees. They must not deploy scripts or edit app configuration.
See [the SaaS onboarding design](SAAS_ONBOARDING.md) for the proposed shared
backend and implementation requirements.

**Current implementation:** company signup creates Sheets and Drive storage,
but employee login still uses a single-company Apps Script gateway. Automatic
SaaS employee provisioning is not implemented yet. The instructions below are
for the existing single-company deployment, not the intended customer signup flow.

## Existing single-company employee QR login setup

Employee login uses the company owner's Apps Script gateway. The QR identifies
the employee; a separate private login code authenticates them. The gateway reads
current permissions from the Employees sheet on each request. Employees do not
need Google accounts or direct access to the company spreadsheet.

## Deploy the employee gateway

1. Open Apps Script using the Google account that owns the company workspace.
2. Create a project and copy `backend/apps-script/EmployeeGateway.gs` into it.
   Enable the manifest in project settings and copy
   `backend/apps-script/appsscript.json`. The `script.external_request` scope is
   required to verify the owner's Google identity when issuing private codes.
3. In **Project settings > Script properties**, set:
   - `SPREADSHEET_ID`: the existing company spreadsheet ID.
   - `DRIVE_FOLDER_ID`: the company Drive root folder ID.
   - `OWNER_EMAIL`: the deploying owner's Google email address.
4. Use **Deploy > New deployment > Web app**, execute as **Me**, and allow access
   to **Anyone**. The gateway itself authenticates every employee request. Copy
   the deployment URL ending in `/exec`; do not use the editor or `/dev` URL.
   See [Google's web app deployment instructions](https://developers.google.com/apps-script/guides/web).
5. Use the spreadsheet already created by this Flutter app, with its normal
   column headers. Do not run the legacy `Code.gs` setup against it: that code
   uses a different JSON-row schema. The gateway creates its private
   `EmployeeAccess` sheet automatically. Keep the spreadsheet owner-only.

For updates, edit the existing deployment and select a new version so the `/exec`
URL remains unchanged. Authorize any newly added scopes as the owner.

## Configure and rebuild the app

Fill these fields in `config/google.web.json` alongside the existing Google OAuth
settings:

```json
{
  "EMPLOYEE_GATEWAY_URL": "https://script.google.com/macros/s/YOUR_DEPLOYMENT_ID/exec",
  "EMPLOYEE_LOGIN_URL": "https://YOUR_APP_HOST/"
}
```

`EMPLOYEE_LOGIN_URL` is the deployed app website, not the gateway URL. When empty,
web builds use the current HTTPS site (or localhost for development); native
builds use the `tpc://employee-login` app link. Set the HTTPS website explicitly
when generating QR codes from a native app for people signing in through a browser.

```powershell
flutter pub get
flutter build web --dart-define-from-file=config/google.web.json
```

For Vercel, set `EMPLOYEE_GATEWAY_URL` and `EMPLOYEE_LOGIN_URL` in the project's
environment variables and redeploy. `vercel-build.sh` passes both into Flutter.
The employee device and owner's app must use the same configured gateway.
An empty gateway setting deliberately disables employee access setup and login.

## Issue employee access

1. Sign in as the company owner, open **Employees > Access & QR Login**.
2. Choose the employee's role and sections. Save permissions and generate access
   while online; the employee record must reach the spreadsheet first.
3. Give the employee the new QR/login link and their separately displayed private
   login code. This is not their staff number. Copy the code before closing;
   stored credentials cannot be read back.
4. The employee opens **Employee Login**, scans the QR or pastes the login link,
   then enters the private code. Camera scanning in a browser needs HTTPS or
   localhost and camera permission.
5. If the code is lost, use **Reset login code**. This invalidates the old code
   and sessions. Reissue QR codes generated before this fix.

Verify with a staff account: only assigned sections should appear; changing
permissions should take effect on the next online sync. Real camera scanning and
live Apps Script access require the deployed website and gateway.
