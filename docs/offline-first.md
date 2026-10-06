# Offline-first web data flow

The shared-backend web application retains its existing stale-while-revalidate
read cache and now adds durable local writes for Customers and DRAFT Invoices
and Quotations. Final accounting and authorization remain server operations.

## Storage choice and boundaries

The project already depends on [idb_shim](https://pub.dev/packages/idb_shim).
Using its browser IndexedDB implementation avoids adding a second database
framework and supports the same transaction tests with its in-memory factory.
This is structured IndexedDB storage, not a localStorage record cache.

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
| Issue/send/convert, payments, posting/reversals, payroll, assets, capital/loans | Online server confirmation required |
| Tasks, employee administration, uploads, setup | Online actions; uncertain requests retain their exact retry identity |

Draft editors need previously available customer/company reference data. Local
drafts display “Saved on this device”; final numbers, validation, totals and
reports remain authoritative on the server. Pending deletion uses a tombstone;
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
stop the ordered queue and retain the rejected edit. “Review rejected change”
fetches the current server record, displays both versions and offers explicit
correction using the current revision and a new operation ID. There is no silent
overwrite or automatic retry of a definitely rejected local edit. Dependent
changes prevent unsafe discard. “Export pending changes” exposes JSON for
copying before manual recovery. Correction history retains the last 50 rejected
operations. Online-only entities retain their existing server validation and
explicit recovery flows.

## Authentication, logout and upgrades

Cached data is accessible only in the currently verified account/workspace.
Logout detaches the read context and purges account snapshots; queued edits stay
in their original IndexedDB partition. Session expiry pauses synchronization.
Reauthentication resumes only matching actor/workspace queues. Owner workspace
deletion blocks when that owner's partition contains queued or uncertain work.
Other actors' queues cannot be inspected by this client; deleting a workspace
externally can leave retained work requiring manual export/recovery.

The public app shell uses `offline_worker.js`; it never caches API requests,
credentials or record responses. The release preparation script hashes public
assets into a versioned shell cache. New workers wait for old tabs to close;
activation removes old shell caches, not IndexedDB. CanvasKit and fonts are
served locally. Build with `scripts/build-shared-web.sh`, or run
`node scripts/prepare_offline_web.mjs` after a manual release build.

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

Verified locally: Flutter analysis reports no issues; the complete Flutter suite
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
