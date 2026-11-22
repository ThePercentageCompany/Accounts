# Tasks and calendar

Flutter task and calendar views connect to Supabase Edge Functions. Task editors manage company assignments; readers see assigned work. Comments and activity follow parent task visibility. Postgres stores tasks, assignments and activity. Assignees receive assignment alerts, and editors with company-wide Tasks access receive status updates. Supabase Realtime and pg_cron deliver in-app alerts and scheduled reminders. See [Notifications setup](../SETUP.md#notifications) for device push configuration.

Task lists, calendar views and open details subscribe to the workspace's Supabase Realtime invalidation events. Bursts are coalesced before fetching current authorized data. Reconnects fetch the latest snapshot; disconnected task lists fall back to periodic checks. Unsaved editor fields and comment text are preserved. Raw business rows are never broadcast to bypass employee permissions.
