# Supabase deployment

Target project: `ifuucosaautgobwsunmp`.

1. Run `npx supabase login`, then `npx supabase link --project-ref ifuucosaautgobwsunmp`.
2. Run `npx supabase db push --remote --dry-run` to preview pending migrations. Verify that the target is `ifuucosaautgobwsunmp`, then run `npx supabase db push --remote` to apply them.
3. Set Edge secrets `APP_ORIGIN=https://accounts.thepercentagecompany.com` and `EMPLOYEE_INVITE_KEY` (a randomly generated secret of at least 32 characters). Keep the invitation key stable; never include it in Flutter configuration.
4. Run `npx supabase functions deploy api --project-ref ifuucosaautgobwsunmp`.
5. In Supabase Auth → URL Configuration, set the site URL to `https://accounts.thepercentagecompany.com` and add `https://accounts.thepercentagecompany.com/?auth=recovery` to Redirect URLs. Add your development origin with `/?auth=recovery` when testing locally. Enable email confirmation and configure production SMTP. Password recovery emails must use Supabase's `{{ .ConfirmationURL }}` so the recovery session is verified before opening the new-password form; do not link directly to the app.
6. Put the project URL and its **public publishable key** in `config/saas.production.json`. For Vercel, set `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` build environment variables.
7. Run `flutter analyze`, `flutter test` and `npx deno task --config=supabase/functions/deno.json test`. Build with `flutter build web --release --dart-define-from-file=config/saas.production.json`.

The Edge API verifies Auth identities explicitly. Browser database access is protected by RLS; business mutations run through a service-only atomic Postgres transaction. Employee permissions are checked against live membership and section grants. Realtime publishes invalidation events, not business record payloads.

Invoice and quotation designs are saved online per company. The same saved HTML is rendered for every authorized employee. Use Print / Save as PDF, then upload the resulting PDF to the private Supabase Storage bucket. No remote PDF renderer is needed.

## Fresh workspace

The owner requested a fresh start without importing old company data. Create an admin account with email and password, confirm its email, then create a company and issue employee invitations. Google backend code and migration tools have been removed. Historical exports are kept only in ignored local files.

## Notifications

In-app task and payroll alerts are stored in Postgres and delivered through Realtime. The payroll reminder is sent once per payroll month to accountants with company-wide Payroll access, starting on the last day of the month at 9:00 a.m. in the workspace time zone when approved payroll is still unpaid.

To enable device push delivery:

1. Deploy `task-push-worker` alongside `api`. Set the Edge secrets `FCM_SERVICE_ACCOUNT_JSON` and `TASK_PUSH_WORKER_SECRET`. Use the Firebase project configured in the app and a service account authorized to send FCM messages.
2. Enable `pg_net` in Supabase. Set the Vault secrets `tpc_push_worker_url` to the deployed worker URL and `tpc_push_worker_secret` to the same worker secret. The migration schedules the dispatcher every minute.
3. For browser and installed PWA push, configure `FCM_WEB_VAPID_KEY` and `FIREBASE_WEB_CONFIG` in the Edge secrets. The public web app configuration must match `web/firebase-config.js`.
4. For iOS, enable Push Notifications for the app identifier in Apple Developer, use a provisioning profile with that entitlement, and upload the APNs authentication key in Firebase. Distribute rebuilt Android and iOS apps.
5. On each device, sign in, open **Notifications**, and select **Enable push notifications**. Verify delivery in the foreground and with the app closed. Lock-screen alerts use generic text and omit salary amounts and task titles.
