# Supabase release status

The app uses project `ifuucosaautgobwsunmp` for Auth, Postgres, Edge Functions, private Storage and Realtime. Production frontend: https://accounts.thepercentagecompany.com.

- Email/password admin signup, login and password recovery.
- Admin-created employee invitations with live role and section permissions.
- Tenant RLS and service-only atomic business/ledger transactions.
- Shared company HTML invoice and quotation designs, browser PDF printing and private document uploads.
- Realtime cache invalidation, task notifications and database-scheduled reminders.
- Ledger posting indicators for admin and employee record views.
- Flutter offline queues and cached reads retained.
- Group overview and separate country legal entities, currencies, tax registrations and business time zones.
- Unified Sales, People, Work and Accounting navigation with entity overview.
- Realtime task lists, calendars, comments and activity; coalesced refresh, reconnect recovery and periodic fallback.

The owner requested a fresh start. No old company data was imported. The failed import transaction rolled back, and temporary Auth identities and uploads were cleaned up. The operator import interface was removed by migration 006.

Validation includes database/domain tests, Flutter analysis and widget tests, responsive group overview checks, country/time-zone isolation, and live cross-session Realtime task delivery. Temporary test identities, groups and entities are removed after verification. Run the documented checks for the current test counts.

Production web and Edge API are deployed. Old Google backend source has been removed; the notification scheduler, setup task queue and Cloud Run API are retired. Historical Google files and cloud image/backup storage are not used by this application.

Remaining operations: configure custom SMTP for production email delivery and rotate the project secret previously shared in chat. Native push notification delivery is not configured; Supabase in-app notifications and scheduled reminders are implemented.
