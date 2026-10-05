# Task assignment and calendar

Implemented in the Flutter app and Cloud Run API. Live services are not deployed by this change.

## Storage and migration

- `Tasks`, `TaskComments`, and `TaskActivity` are appended to the company spreadsheet schema. Existing sheet IDs, columns, records, schema identity, and accounting data stay intact.
- The first task read creates missing task tabs and headers atomically. Reconnect verification also ensures the tabs exist. Concurrent migration retries verify the resulting headers.
- New companies receive a `Task Attachments` folder. Existing companies receive it lazily on the first task upload or during reconnect. The backend persists its generated Drive ID before creating the folder, so retries reuse the same resource. Attachments use the existing document registry, validation, ownership checks, download authorization, and durable upload queue.
- Task deletion is a soft deletion. Comments, attachments, and server activity remain historical records. Deleted tasks disappear from the board/calendar, and their attachment downloads and detail reads are denied.

## Permissions

Enable **Tasks** in employee administration. The Calendar destination inherits task visibility; a separate grant cannot bypass task access.

Staff see only assigned tasks, their comments, activity, and attachments. They can update status and add comments, but cannot create, delete, reassign, or edit task content. These restrictions apply even if someone broadens a Staff role's spreadsheet permission. Managers and Accountants need explicit Tasks edit access to create, edit, reassign, and delete. Read-only users can comment on visible tasks and update the status of their own assigned tasks.

Assignments reference active employees in the same company. The server derives the displayed employee name and generates activity records. Clients cannot directly write task activity. Comments are append-only. Mutations reuse the existing company write reservation, expected record version, CSRF/session checks, and idempotent sync protocol. Employee permissions are checked again while the reservation is held and immediately before submission.

## API

Owner base: `/v1/companies/{companyId}/tasks`

Employee base: `/v1/employee/companies/{companyId}/tasks`

- `GET {base}`: `search`, `employeeId`, `status`, `priority`, `project`, `from`, `to`, `sort`, `overdue`, `offset`, `limit`. Page size defaults to 40, maximum 100. Returns records, total, nextOffset, per-date counts, dashboard summary, and due in-app reminders.
- `GET {base}/{taskId}`: task, comments, and activity. Visibility is rechecked after dependent reads.
- `GET {base}/assignees`: active employee names and departments with `search`, `offset`, and `limit`; no payroll/private fields. Requires task-management permission.
- Task writes use existing owner/employee `/sync` endpoints and the tables `Tasks` and `TaskComments`. Activity is written atomically with the task change.
- Task attachments use existing document endpoints with `relatedSection: Tasks`.

Statuses: `TODO`, `IN_PROGRESS`, `IN_REVIEW`, `COMPLETED`. Priorities: `LOW`, `MEDIUM`, `HIGH`, `URGENT`.

Task fields: title (200 characters), description (10,000), employeeId, priority, status, startDate, dueDate, startTime, endTime, project, tags, reminder. Dates use `YYYY-MM-DD`; times use `HH:mm` in Asia/Dubai (UTC+4). Due date and employee are required. Task metadata is bounded, due date cannot precede start date, and same-day end time cannot precede start time. Comments contain 1–5,000 characters.

## Adaptive interface

The workspace's existing sidebar and mobile navigation contain Tasks and Calendar. Available content width drives adaptation: mobile defaults to cards, tablet boards can scroll within the board, and wide boards show four columns. Filters become a mobile bottom sheet. Employee assignment uses searchable, paginated selection. Create/edit uses a full-screen phone form with a safe-area primary action and desktop dialogs. Task details use a phone page or desktop side surface, with status, comments, attachments, and activity.

Calendar supports month, week, and day views. Small month cells use indicators and accessible event counts. The selected-date agenda requests that day's records when its tasks are not fully represented in the current month/week page. Task/calendar lists page records rather than downloading the entire dataset to the client.

Search is debounced. Successful writes invalidate task/record caches and update the current view. Invalidation from other tabs triggers a refresh; active task views also poll every 30 seconds and refresh on application resume. Polling pauses while task editor/detail surfaces are open. Task saves use the existing durable write queue, so interrupted saves retain their operation IDs. Confirmed failures can be discarded through the pending-change UI. Normal CRUD does not log out or replace workspace/session state.

Reminders are **in-app only while the Tasks/Calendar view is active**. This change does not add email, background push, or a notification delivery service. The server returns reminders for the assigned employee (or owner team view), and the client deduplicates notices during that view's lifetime.

## Capacity and rollout

Deploy the backend before publishing the frontend. No new OAuth scope or backend environment variable is required. Existing employee grants stay unchanged; administrators must enable Tasks for employees who need access. Task tabs/folders are migrated by the company's existing authorized backend connection, not by a separate personal Google Drive connector.

The existing Sheets adapter has a 10,000-record capacity per table. API pagination/date filtering bounds client payloads; the backend still scans bounded Sheets tables to filter and authorize them. A database/indexed storage migration is needed before exceeding that capacity. Activity history consumes one row for each task change.

Validation covers backend authorization, tenant isolation, task validation, mutation retry safety, activity history, soft deletion, employee search, additive sheet/folder migrations, and Flutter layouts at 320, 360, 375, 390, 412, 430, 768, 820, 1024, 1280, 1440, and 1920 pixels. Journey tests exercise creation, assignment, comments, completion, calendar navigation, durable queue acknowledgements, and landscape layout. Automated widget checks do not replace verification on physical phones or the deployed Google workspace.
