# Workspace caching and background synchronization

Implemented 4 October 2026 in the active shared-backend SaaS flow.

## Why navigation fetched repeatedly

`SharedWorkspace` previously replaced its selected child. Record panels and the
report view were disposed on section changes; returning ran their initialization
requests again. Record panels also ran an unconditional 60-second timer. Owner
snapshots in `WorkspaceRecordCache` were small SharedPreferences/localStorage
values, lacked a shared freshness/request policy, and did not cover employee
reads, employee administration or reports. Each recreated report also replaced
its FutureBuilder content with a spinner.

The workspace now lazily mounts visited sections in an IndexedStack. Filters,
selected record tables, report dates/types, expanded rows and scroll positions
remain in their existing widget/controller state. Only the selected section is
registered for automatic refresh. Existing ChangeNotifier/stateful-widget
patterns are retained. Legacy inactive feature repositories were removed in the
4 October 2026 source cleanup.

## Storage and scope

`SaasApi` shares one `ReadCache` coordinator across all active records, employee
administration and dashboard/report requests. Web persistence uses asynchronous
IndexedDB through `idb_shim`; non-web execution uses memory. SharedPreferences
continues to hold the existing settings and durable mutation queues, not this
dataset cache. The old owner snapshot helper is no longer used by the workspace.

Entries contain schema version 2, trusted API origin/account/company/employee
permission scope, normalized resource/query, synchronization time, freshness
duration, completed-query flag, invalidation state and response data. Equivalent
query parameter order shares a key; dates, searches, sorting and pagination
parameters remain distinct. Current API lists are full snapshots. A completed
query is not a claim that a future paginated query contains every company row.
Server revisions, cursors and ETags are null because this backend does not offer
incremental or conditional synchronization contracts.

Default policies:

| Policy | Default |
| --- | --- |
| Record and employee freshness | 2 minutes |
| Dashboard/report freshness | 1 minute |
| Maximum usable snapshot age | 7 days |
| Memory entries | 128, evicting inactive resources first |
| Persistent entries | 128 across scopes |
| Persistent total size | 20 MiB |
| Maximum persisted response | 4 MiB; larger responses stay in memory |
| Automatic active-resource check | Every 30 seconds while the tab is visible |
| Focus/visibility/connectivity debounce | 500 milliseconds |
| Temporary failure backoff | 5, 15, 60 seconds; stop after four failed attempts |
| Server rate limits | Respect Retry-After seconds or HTTP date; default 60 seconds |

Freshness and retention durations can be supplied to `ReadCache`. Browser quota,
unavailable storage, corrupt metadata and incompatible schemas fall back to
memory/network access. IndexedDB writes, invalidations and logout deletion are
serialized; read snapshots wait for earlier invalidations. Persistence failures
never turn a successful server read into a failed user operation.

## Read and refresh behavior

Authentication, invitations, company membership/setup and private document bytes
remain uncached. The existing online authentication/company flow establishes a
verified workspace before protected snapshots are exposed. Employee scopes
include role plus sorted view/edit grants. Cache data never establishes identity
or authority and never contains session tokens, private login codes or OAuth
credentials.

Reads return memory or IndexedDB snapshots first, including valid empty results.
Stale responses refresh quietly; active views observe cache updates. Initial
loading, refreshing, data, stale/offline status, synchronization time and refresh
error are separate fields. Failed background reads retain content. New responses
replace complete snapshots, so deletions disappear without merging old rows
back in. Stable row and page-storage keys preserve scroll and expansion state.

Concurrent equivalent reads and manual refreshes share one in-flight operation.
Manual refresh bypasses freshness, but not a server rate-limit cooldown. The
visible active resource refreshes when stale; hidden tabs and unselected sections
do not poll. Online/focus/visibility signals are hints: successful requests confirm
availability. Permission/authentication failures purge protected snapshots and
return through the existing session flow instead of automatically retrying.
Active workspace authorization is checked at most once per minute during resume
checks, including employee permission changes.

Account/company switches clear active memory/jobs. Browser transports abort old
record/report requests; generation and resource revision guards also discard
late responses. BroadcastChannel coordinates same-account logout and scoped
resource invalidation across tabs without broadcasting records or credentials.
If BroadcastChannel is unavailable, per-tab authorization/freshness checks still
apply. Logout removes this account's IndexedDB snapshots and the obsolete owner
read snapshots, while preserving existing durable pending edits. A failed remote
logout retains the existing session/error behavior; it does not imply that the
server cookie was revoked successfully.

## Mutations and offline limits

Only acknowledged APPLIED operations invalidate their affected lists and related
ledger/report resources. Unrelated modules retain their fresh snapshots. The
active affected screen refreshes from the server; inactive snapshots are marked
stale in memory and on disk. No optimistic financial totals or invoice numbering
are invented. Existing stable operation IDs, queue ordering, conflict handling
and explicit pending-write retry UI are preserved.

Offline viewing works for usable snapshots after a verified session has opened.
A fully offline browser restart cannot bypass the existing online authentication
gate. The implementation adds no new offline financial posting; existing durable
pending edits continue to mean pending until the server acknowledges them.
Documents and document bytes remain governed by their existing online flows.
No continuous synchronization runs after the browser/app closes. Tasks are not a
separate section in the active shared workspace, so no unsupported task API was
added. The backend and its financial/permission rules are unchanged.

## Validation

Focused tests cover cold reads/persistence, restart restoration, stale/background
updates, empty results, offline failures, concurrent requests, normalized queries,
account/company isolation, delayed-response rejection, logout, authorization
failure, mutation invalidation, retained filter/scroll state, rate limits,
visibility/active-resource refresh, corrupt/unavailable storage and bounded
IndexedDB retention. `cache_store_test.dart` also runs against native IndexedDB
when executed with Flutter's Chrome test platform.

Validation on 4 October 2026: 223 Flutter tests passed, with the browser-only
coordination test skipped on the VM; all four Chrome storage/coordination tests
passed against native IndexedDB and BroadcastChannel. Changed code analyzed
without issues. The release web build and Wasm dry run passed. The installed
Flutter Windows Chrome test server returned 404s for CanvasKit paths; a temporary
`test/canvaskit` junction to the generated release assets enabled validation and
was removed afterward. No Flutter SDK source or backend configuration was changed.
