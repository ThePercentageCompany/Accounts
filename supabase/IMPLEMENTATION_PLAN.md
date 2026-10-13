# Supabase release status

The app uses project `ifuucosaautgobwsunmp` for Auth, Postgres, Edge Functions, private Storage and Realtime. Production frontend: https://accounts.thepercentagecompany.com.

- Email/password admin signup, login and password recovery.
- Admin-created employee invitations with live role and section permissions.
- Tenant RLS and service-only atomic business/ledger transactions.
- Shared company HTML invoice and quotation designs, browser PDF printing and private document uploads.
- Realtime cache invalidation, task notifications and database-scheduled reminders.
- Ledger posting indicators for admin and employee record views.
- Flutter offline queues and cached reads retained.

The owner requested a fresh start. No old company data was imported. The failed import transaction rolled back, and temporary Auth identities and uploads were cleaned up. The operator import interface was removed by migration 006.

Validation: 87 database/domain tests, 27 Flutter tests, Flutter analysis, release web build, production routing checks, and live admin/company/employee invitation/login/deletion smoke checks. Test identities and workspaces were removed.

Production web and Edge API are deployed. Old Google backend source has been removed; the notification scheduler, setup task queue and Cloud Run API are retired. Historical Google files and cloud image/backup storage are not used by this application.

Remaining operations: configure custom SMTP for production email delivery and rotate the project secret previously shared in chat. Native push notification delivery is not configured; Supabase in-app notifications and scheduled reminders are implemented.
