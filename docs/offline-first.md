# Local-first workspace data flow

Workspace saves commit a durable record overlay and outbox operation before
returning to the screen. Related views receive a local change notification;
Supabase synchronization and authoritative validation run in the background.
Server snapshots remain separate from local projections.

The PWA uses transactional IndexedDB for durable outbox partitions and cached
snapshots. A storage failure is reported as an unsuccessful save. Each partition
remains scoped to its origin, account, role and workspace.

Task lists, calendars, details, dashboard cards, employee section overviews,
project choices and entity counts consume local changes. Draft document and
cash-entry totals are calculated locally without modifying the queued request.

Financial reports project pending posting operations over confirmed snapshots
and label the result provisional. Available previews cover cash posting,
same-rate settlements, invoice issue, transfers, payroll approval/payment,
asset acquisition/depreciation/disposal, capital contributions and shareholder
loans. Reversals require cached original journals and lines. Missing inputs,
unsupported operations and foreign-currency settlement calculations are explicitly
counted as requiring online calculation; their totals are not guessed. Draft
saves alone do not post transactions or change posted report totals. Failed
operations are excluded from financial previews.

Submitted posting commands also require authoritative calculation. A response
can be lost after commit, while a realtime-refreshed statement already includes
the posting. Without a report-level operation receipt, adding its estimate to
that snapshot could count it twice. Such commands retain their original queue
identity and pending indicator, but do not add speculative statement amounts.
Unsubmitted permitted commands can still project balanced, labelled previews.
Journal posting requests retain `DRAFT` in the local record until acknowledged;
only the queued command contains the requested `POSTED` transition.

## Storage choice and boundaries

[IndexedDB](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)
stores both read snapshots and atomic outbox envelopes. A save is acknowledged
only after the transaction commits. Writes are serialized across store instances
and tabs coordinate through Web Locks and BroadcastChannel.

Opening a cached section returns saved rows first. Stale snapshots refresh in
the background. Explicit refresh also returns local rows immediately while
refreshing in the background. Payroll, document lists, and multi-table section overviews publish
available cached rows without waiting for unrelated requests. A first visit with
no saved snapshot still needs a successful online fetch.

Online identity checks and resolving rejected operation versions use explicit
server reads; cached page reads cannot supply those authoritative sync baselines.

Enqueued writes start syncing immediately in the background. Browser
online/focus/visibility events restart network-failed operations with their
original idempotency keys. Reconnection does not bypass validation failures or
server Retry-After delays. Synchronization requires an open app tab.

* `tpc_read_cache_v2` stores complete read snapshots with account, workspace and
  permission scopes. Existing limits are seven days, 128 entries and 20 MiB.
* `tpc_offline_v1` database version 2 stores one transactional partition per
  API origin, role, actor ID and company. Each partition contains record
  overlays, ordered operations, temporary ID mappings and uncertain online
  workflow requests. Record changes and operation insertion commit together.
* A partition has an 8 MiB serialized limit. A failed/quota-limited transaction
  does not acknowledge a save or publish its overlay. Pending work is never
  evicted to make room. Acknowledged overlays retire when a covering server
  snapshot arrives. ID mappings persist for editors opened before sync.
* Existing preferences queues, registration requests, employee requests,
  uploads and HTML templates migrate before their source keys are removed.
  Interrupted migration reuses the original operation ID. Small preferences
  (appearance, selected workspace and session mode) remain in preferences.
* Cookies, login codes, tokens and permission claims are not persisted in the
  outbox. One-time employee access codes remain ephemeral.

## Supported actions

| Action | Offline behavior |
| --- | --- |
| Customer create/update/delete | Atomic local overlay and queued operation |
| Invoice/quotation draft create/update/delete | Atomic header/items draft and queued operation |
| Read previously fetched records/reports | Cached snapshots in a verified open session |
| HTML document design | Local IndexedDB preference, independent of synchronization |
| Tasks, projects, employee records, attendance, overtime and supported reference records | Durable local overlays with background sync |
| Draft financial records, transfers and draft journals | Durable local overlays with background sync |
| Payments, posting/reversals, payroll, assets, capital/loans | Durable pending requests; provisional report previews where inputs are available; server confirmation assigns final accounting results |
| Uploads and report settings | Durable local queue with background delivery |
| Sign-in, access management and workspace setup | Online identity/authorization operations |

Draft editors need previously available customer/company reference data. Local
drafts display “Saved on this device”; final numbers, validation, totals and
confirmed reports remain authoritative on the server. Pending deletion uses a tombstone;
a rejected deletion becomes visible again with its failure explanation.

## Synchronization and conflicts

An open visible tab periodically checks the queue, and connection/focus/resume
events request another attempt. Browser connectivity is a hint: actual identity
and sync requests determine success. There is no promise of execution after
the tab closes. The queue resumes on reopening after authentication.

[Web Locks](https://developer.mozilla.org/en-US/docs/Web/API/Web_Locks_API)
coordinate same-origin tabs. Each worker acquires the actor/workspace lock,
reloads committed state and submits one operation at a time. Unsupported or
insecure browser contexts preserve the queue and display a storage/sync error
rather than run competing workers. BroadcastChannel carries scope notifications,
not records or credentials. Each submission verifies the actual principal;
owner sync additionally sends the original owner ID for a server-side check.

Retries retain immutable operation IDs and submitted payloads. Transient errors
use exponential backoff (bounded to five minutes) with jitter and Retry-After.
Only a matching APPLIED result with a record ID and revision acknowledges the
operation. Temporary IDs and dependent payload references reconcile atomically.
An uncertain outcome remains pending, even if the server may have completed it.

Customers and document drafts use expectedVersion. Conflicts/validation failures
block dependent edits and retain the rejected edit; independent records continue.
Transient record-specific failures also allow unrelated ready commands to run,
while authentication, network loss and rate limiting pause the pass. Each
operation is attempted at most once per pass. “Review rejected change”
fetches the current server record, displays both versions and offers explicit
correction using the current revision and a new operation ID. There is no silent
overwrite or automatic retry of a definitely rejected local edit. Dependent
changes prevent unsafe discard. “Export pending changes” exposes JSON for
copying before manual recovery. Correction history retains the last 50 rejected
operations. Online-only entities retain their existing server validation and
explicit recovery flows.

The sync editor compares the saved values with the latest authorized server
record before correction. Version conflicts cannot be blindly retried from the
settings panel. A correction uses a new immutable command ID and the reviewed
server revision, so a second concurrent edit produces another conflict.

`WorkspaceDependencies` supplies shared local/server invalidation rules.
Per-resource local revisions retain unrelated cached projections. Task views and
financial report views use these revisions to avoid recomputing unrelated data.
Workspace realtime events are deduplicated by event ID and coalesced in bounded
120 ms batches. Out-of-order events for different sections are retained rather
than discarded using a global revision watermark. Pending batches are cancelled
when the workspace subscription is replaced.

## Authentication, logout and upgrades

Cached data is accessible only in the currently verified account/workspace.
Logout detaches the read context and purges account snapshots; queued edits stay
in their original IndexedDB partition. Session expiry pauses synchronization.
Reauthentication resumes only matching actor/workspace queues. Owner workspace
deletion blocks when that owner's partition contains queued or uncertain work.
Other actors' queues cannot be inspected by this client; deleting a workspace
externally can leave retained work requiring manual export/recovery.

The public app shell uses `tpc-sw.js`; it never caches API requests,
credentials or record responses. The release preparation script hashes public
assets into a versioned shell cache. New workers wait for old tabs to close;
activation removes old shell caches, not IndexedDB. CanvasKit and fonts are
served locally. Build with `scripts/build-shared-web.sh`, or run
`node scripts/prepare_offline_web.mjs` and then `node tool/build_pwa.mjs`
after a manual release build.

### Vercel hosting

Use the repository's `vercel.json`: build command `bash vercel-build.sh`,
output directory `build/web`. The build entrypoint calls
`scripts/build-shared-web.sh`, which supplies the backend configuration and
generates the custom worker's versioned resource manifest. Do not replace this
pipeline with `--pwa-strategy offline-first`; offline support is provided by
`tpc-sw.js`, independently of Flutter's legacy generated worker.

The existing catch-all rewrite serves `index.html` for online deep links while
preserving the `/health` backend rewrite. Offline navigation uses the installed
worker's cached `index.html` and requires a previously successful shell install;
a hosting rewrite cannot handle a request without a network connection.
Worker scripts explicitly use `public, max-age=0, must-revalidate` so browsers
and shared caches revalidate them online. Registration also uses
`updateViaCache: 'none'`. These HTTP headers do not disable the worker's explicit
Cache Storage app-shell cache.

Keep `.html` URLs enabled: the update recovery flow explicitly uses
`update.html`, so `cleanUrls` is unnecessary for SPA routing. Repository settings
are ready for the next deployment; dashboard overrides and live response headers
must be checked separately when deploying.

Offline shell access does **not** restore authorization from a cached identity.
A cold start without a network connection requires reconnecting to verify sign-in
before workspace records can be shown. An already verified open session can read
cached data and save supported drafts during disconnection. Browser/site-data
clearing removes local work; exports and server sync remain the recovery options.

## Verification

Run `flutter analyze --no-pub` and `flutter test --no-pub`. New outbox tests cover
atomic persistence/abort, recreation, temporary IDs and dependencies, tombstones,
uncertain response retry, revisions/correction, quota failures, authentication,
account switching, coordinator exclusion and local API reads without a snapshot.
Existing responsive/editor/navigation tests remain part of the suite.

Historical verification before the local projection/native persistence changes:
Flutter analysis reported no issues; the complete Flutter suite
passes 242 tests with one existing skipped test; the business/employee backend
suites pass 70 tests. Chrome and Edge release fixtures retained pending work
through offline page reload and acknowledged one submission across two tabs.
With the deliberately delayed loader, first data readiness was 1,979 ms in
Chrome and 3,693 ms in Edge during concurrent builds/tests. Local persistence
took 9 ms and 23 ms respectively; cached repeat reads took 0–2 ms and made zero
additional loader requests. These timings include machine contention and are
controlled fixture results, not a claimed production speedup.

Release browser fixture (no credentials or production records):

```text
flutter build web --release --no-pub --no-wasm-dry-run -t tool/offline_release_probe.dart --output=build/offline-probe
node scripts/prepare_offline_web.mjs build/offline-probe
node scripts/check_offline_release.mjs
node scripts/check_offline_release.mjs "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
```

The driver exercises actual browser IndexedDB, offline shell reload, retained
pending work, reconnect, desktop/mobile dimensions and concurrent tabs. The
fixture uses a 1.5-second simulated data loader and a 500-ms acknowledgement
delay. Its timings measure data readiness/local persistence after Flutter starts,
not total download/startup time or live API latency. They are not a production
before/after benchmark. Live authenticated production journeys, physical mobile
browsers, Safari/Firefox, and native release deployment require separate checks.

Deployment must roll out the backend ownerId sync validation before the new
client. An older backend rejects the expanded sync envelope; retained writes
remain pending/failed for explicit recovery rather than being marked synced.
