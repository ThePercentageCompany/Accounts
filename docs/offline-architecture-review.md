# Offline architecture implementation review

This upgrades the existing application. It retains Supabase Auth, the authorized
Edge API, transactional Postgres accounting writes, the existing Cubit/UI
controllers, the shared `SaasApi`/`ReadCache` repositories, and IndexedDB. A
second state-management framework or database has not been introduced.

## Implemented foundation and changes

| Area | Implementation |
| --- | --- |
| Durable local saves | `IndexedOfflineStore` commits overlays and queued commands in one transaction; a failed/quota-limited save is not acknowledged. Existing v1 envelopes migrate to schema v2. |
| Isolation | Read snapshots include account, workspace and permissions; outbox partitions include origin, actor, role and workspace. Submission rechecks identity and server authorization. |
| Optimistic CRUD | Existing record, document, task, employee and upload queues retain local changes before returning. Temporary references reconcile after parent creation. Unsupported final financial effects remain pending commands. |
| Reactive dependencies | `WorkspaceDependencies` now centralizes local/server invalidation. Resource-specific local revisions and report change signatures suppress unrelated projection work and report rebuilds. |
| Retry scheduling | The outbox now lets unrelated ready commands continue after record-specific transient errors. Authentication/network/rate-limit failures pause the pass. Attempts retain command IDs and immutable submitted payloads; jittered backoff is capped at five minutes. |
| Command status | The sync panel distinguishes syncing, pending sync, conflicts and needs-attention states. Existing persisted states remain compatible. |
| Conflict recovery | Saved values and current authorized server values are shown together. Conflict retry requires review; corrections get a new command ID and expected version. Workspace switches prevent correction/discard through an obsolete screen. |
| Financial arithmetic | Provisional decimal parsing and FX multiplication now use exact scaled integers, including scientific notation. Unsupported precision is not silently truncated. |
| Posting integrity | Journals remain draft locally until acknowledgement. Existing backend double-entry, period, version, numbering and reversal rules remain authoritative. Lost-response postings cannot be added twice to refreshed statements. |
| Realtime | Existing RLS-protected company subscriptions and private task topics remain. Workspace events now coalesce, suppress duplicate IDs, retain out-of-order section changes and cancel pending callbacks on teardown. |
| Browser storage recovery | A failed snapshot-database open can be retried; version changes close the old connection. Failed cache transactions have their completion errors observed. |
| PWA hosting | Existing custom worker generation and Vercel SPA rewrite remain. Worker scripts have revalidation headers; recovery remains available at `update.html`. |

## Verification for this change

On 22 October 2026, `flutter analyze --no-pub` reported no issues,
`flutter test --no-pub test/offline_architecture_test.dart` passed 25 tests, and
`node --test supabase/functions/tests/domain/*.test.js` passed 100 tests.
Release browser persistence/coordination fixtures passed in Chrome and Edge.
The application release build also passed using the existing public production
configuration, with output isolated at `build/offline-upgrade-web`. Both offline
asset preparation scripts completed for that output; generated worker,
bootstrap and PWA scripts passed JavaScript syntax checks. No deployment ran.

The new Flutter regression suite covers atomic failure, persistence recreation,
quota rejection, workspace isolation, temporary references, retry identity,
independent work, conflicts, authentication pauses, bounded retries, pending
posting safety, exact arithmetic, resource-specific invalidation, realtime event
ordering and the conflict comparison UI.

The backend domain suite exercises existing accounting policies and the new
batch-result HTTP error classification. Browser release fixtures use real
IndexedDB, offline reloads and two simultaneous tabs in Chrome and Edge. These
are controlled fixtures with no production credentials or financial records.
They verify persistence and submission coordination, not production latency or
live multi-device authorization.

## Boundaries still requiring work or deployment verification

This is not certification that every item in the full offline specification is
finished:

* General company events identify changed sections, not a durable record-level
  delta cursor. They refresh affected active queries; large sections can still
  require a complete section fetch. Private task queries are already bounded.
  A transactional, authorized record change log and cursor API are needed for
  reliable general incremental replication and deletion/visibility deltas.
* Local storage uses indexed snapshot/partition keys and bounded envelopes,
  rather than individually indexed business-record tables. Very large offline
  datasets need a measured migration to record/index stores while preserving
  atomic command writes and existing pending changes.
* A submitted financial operation is counted as awaiting server calculation,
  rather than added to statements that might already include it. Report-level
  command receipts or consistent server revision metadata are needed to maintain
  exact provisional arithmetic through every acknowledgement/realtime race.
* Existing posting previews intentionally do not guess unsupported FX
  settlements, missing source journals or unavailable reference data. Drafts
  never become confirmed ledger rows through projection.
* Sign-in, authorization changes and other existing online-only operations
  retain their current restrictions. Offline records cannot grant access.
* Web Locks require a supported secure browser context. Browsers without safe
  coordination retain pending work and report the limitation. Durable storage
  cannot be guaranteed after browser/site-data clearing or denied persistence.
* Background execution after closing the PWA is browser-dependent. Foreground
  retry/reconciliation remains required; service-worker delivery is best effort.
* The backend error-status addition must be deployed to the Edge API, and the
  Flutter build must be published, before those changes reach users. This work
  does not deploy code, change the live database, or verify live role grants.
* Live multi-device journeys, permission revocation, production load, Safari,
  Firefox and physical mobile browser recovery need separate integration runs.
  The pre-existing test-file deletions in the working tree were not restored or
  treated as a passing historical suite.

See `offline-first.md`, `task-realtime.md` and `database-scale.md` for existing
storage contracts, server authorization and capacity boundaries.
