# Endpoint connection audit

Checked on 11 October 2026 against `lib/core/network/saas_api.dart` and
`backend/cloud-run/src/http.js`.

| Feature | Frontend/backend connection |
| --- | --- |
| Authentication and workspace setup | Google authorization, owner/employee sessions, workspace creation/status/retry and logout routes match. |
| Records and offline sync | Owner company record/sync routes and employee record/sync routes match. Stable operation IDs and expected versions are preserved. |
| Employee profiles | POST/PATCH employee routes return employee ID, version and generated code; local acknowledgement updates the employee list. |
| Tasks | Owner and employee task list/detail/assignee routes match. Task viewers request assigned work; task editors can see all tasks. |
| Reports | Owner company reports and employee report routes match. Dashboard period requests supply both `from` and `asOf`. |
| Exchange rates | Owner and employee company exchange-rate routes match; currency and date query fields are connected. |
| Notifications | Owner and employee list/read/subscription routes match. |
| Documents | Owner and employee list/upload/download routes match. Income and Expenses attachments use Income & Expenses edit permission. |

Corrections made during this audit:

- The legacy employee document upload path now checks employee identity instead of owner identity.
- Employee HTTP uploads verify company and employee context before reading the document body.
- Pending document uploads no longer block employee identity checks or session renewal; revocation checks remain enforced.

Validation:

- All 280 backend tests passed, including HTTP routing, authentication, authorization, idempotency and document permissions.
- All 21 targeted Flutter tests passed: offline outbox, local save integration, employee dashboard and currency fields.
- Targeted Flutter analysis passed.
- Production read probes returned JSON responses through the API proxy; unauthenticated private reads were rejected. Health returned `ok`.

Limits: automated tests use fixtures/mocked accounts. No private production employee or owner records were created, edited or deleted during this audit. A signed-in smoke test is still needed to verify each real workspace's Google Drive/Sheets permissions, data and role configuration.
