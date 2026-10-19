# Structured task storage and realtime

Migration `202610190002_task_storage_realtime.sql` adds complete versioned payloads
to `business.tasks`, `business.task_comments`, and `business.task_activity` and
backfills them before switching reads. RecordStore reads these tables through a
service-only RPC; commit_workspace checks their versions for optimistic locking.
The existing transaction still writes compatibility records and synchronizes the
typed tables together. The compatibility records are retained deliberately for
foreign keys, document authorization, notifications, reminders and offline sync.
Do not delete them or write directly to the business tables.

The task list endpoint filters, sorts, paginates and calculates summaries in SQL.
Task details query only the selected task and its comments/activity, with task
visibility checked in the database. Admins and authorized task editors can see
company tasks; other task readers see only their assignments. API access/session
checks still run before returning results. Browser clients have no direct table
access and cannot execute the task query RPCs.

Database triggers send private `task_changed` Broadcast events on
`tasks:<companyId>:<userId>` to authorized editors and the affected assignees.
Reassignment notifies both old and new assignees. Events contain task ID, section,
operation and version, never document content or task descriptions. Topic RLS
allows only the signed-in user's own active company channel. Clients cannot
publish task events. Data is always fetched through the authorized API.
Migration `202610190003_task_topic_isolation.sql` also restricts stored-message
reads to the authorized topic itself.

The app invalidates task lists and the affected task detail, debounces bursts and
refetches after reconnect. Existing company_changes subscriptions provide
compatibility with older builds and fallback when private Broadcast is not
connected. Task-specific company change refreshes are skipped while Broadcast is
connected. Existing notification subscriptions remain independent.

Deploy the migration before the Edge API, then rebuild the Flutter app. Old
clients continue using the unchanged endpoints and company_changes feed.

This is not a 10M-record capacity certification. List responses are bounded, but
exact counts and summaries still aggregate matching rows, offset paging remains
for the current UI contract, histories are capped at 50,000 rows, and mutations
still perform legacy section validation and use the company revision lock. See
`database-scale.md` for the remaining pagination, concurrency and load-test work.

Verification: task_database_test.ts covers assignment visibility, editor access,
revocation, history access, pagination, search, summaries, private event recipients,
reassignment and topic isolation. verify_supabase_realtime.ts exercises real
WebSocket delivery, task list/detail and activity authors using disposable users
and entities, then removes its test data.

Production verification on 19 October 2026: both migrations applied, all existing
task payloads backfilled, and live private Broadcast/list/detail/author checks
passed. The API was deployed. The full backend suite passed 116 tests; 8 focused
Flutter tests passed, including unrelated-task filtering and preserving a typed
comment during remote updates. Static analysis reported no issues. Publish the
new Flutter build to enable the private subscription in installed clients.
