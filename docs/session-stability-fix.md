# Session and workspace stability

## Confirmed causes

- `SaasApi` classified both 401 and 403 as authentication loss. A cached employee Customers read without the Customers grant returned `SECTION_FORBIDDEN`; `ReadCache` then detached every resource, broadcast logout, and cleared the session. The invoice/quotation editor requests Customers to select a customer. Permission-denied regression tests reproduce and prevent this sequence.
- The service had an employee renewal endpoint, but Flutter never used it. Employee access expired after eight hours, and the cookie also disappeared at eight hours despite a 24-hour absolute session limit. Registry cleanup removed expired access sessions, preventing later renewal.
- Renewal immediately deleted the previous token. A request already carrying that cookie, or a concurrent renewal in another tab, could fail during an otherwise valid save.
- Session failures reused the login error saying the private code was invalid, expired or disabled. CRUD submits no invitation/private code: that message could actually mean an expired/revoked session. Session expiry and revocation now have separate codes/messages.
- Owner restoration cleared the selected company and selected the first company. Workspace-open state was only in memory. Both owner and employee cookies could exist; restoration always preferred the owner. The employee invitation fragment also remained in the URL, causing refresh to restart invitation login.
- Document editors closed before sending their save. Server rejection therefore removed the editable form even when the queue retained a pending operation.

These findings are reproduced against substitute adapters and HTTP clients. Production request logs confirmed failures occur, but do not contain enough information to attribute a particular customer's save to a specific code. No live customer invoice or quotation was created or changed during verification.

## Resulting behavior

Authentication remains in Secure, HttpOnly, host-only cookies, with explicit credentials, CORS and CSRF checks. Owner Google sign-in retains the configured eight-hour fixed session; there is no supported owner refresh endpoint or browser refresh token. Google Drive/Sheets grants remain separately encrypted on the server and use the existing Google client refresh mechanism.

Employee access still expires after eight hours. The existing renewal endpoint accepts the secure session cookie until the original 24-hour absolute limit, rechecks employee status, credential version and current role permissions, and rotates the cookie. Its predecessor is accepted for at most 60 seconds for in-flight requests; logout removes all tokens in that session family. Registry cleanup retains renewable sessions only until their absolute limit. Expired predecessor tokens cannot renew beyond their overlap window.

Flutter shares one renewal future and tracks completed renewals so late expiry responses reuse the current cookie. It renews before requests when the known access expiry is near. Only explicit `EMPLOYEE_SESSION_EXPIRED` permits one replay, and only for reads or sync requests with stable per-operation IDs. Network/unknown-outcome mutations are not automatically replayed. Revoked sessions are not renewed; non-JSON proxy errors are not treated as authentication loss.

Permission denial removes the denied memory/disk snapshot and displays the error without logging out. Updated permissions replace the cache scope and employee permissions without ending a valid session. Pending employee writes include the original company and employee ID; the server rejects a changed identity/workspace before any write. Employee record/report requests also carry verified context headers. These are assertions checked against the authenticated principal, never a substitute for authentication.

Owner company selection and workspace-open preference contain identifiers/booleans only and are scoped by owner ID. Restoration verifies the company against the server's authorized list. Removed access returns to company selection instead of silently opening another company. Employee mode is remembered, and successful invitation login removes the invitation fragment from browser history. Logout clears session mode, workspace selection and private read caches.

Existing cache keys continue to include API origin, owner/employee identity, workspace, permission fingerprint and normalized resource/query. Reads deduplicate, fresh navigation reuses snapshots, stale data revalidates in the background, and acknowledged mutations invalidate dependent lists and reports. Outdated generations cannot populate a new workspace. Reference loads for document editing run concurrently; financial editing still explicitly refreshes the document's lines.

Invoice/quotation editors remain open until save is confirmed. Failed saves preserve all fields, pending submissions disable further saves/edits, and safely rejected requests can be corrected. Uncertain requests retain their original operation ID and cannot be silently changed into another save. Closing a changed editor asks before discarding; browser reload/navigation requests the browser's unsaved-work prompt. No new persistent unsent draft store was introduced. The existing account/workspace-scoped pending-write queue remains the recovery mechanism for submitted but unconfirmed changes.

## Deployment and configuration

Deploy backend and frontend together. The new backend accepts legacy employee sync bodies during rollout and verifies company/employee context when present. CORS now permits `X-TPC-Company` and `X-TPC-Employee` in addition to the existing CSRF/content headers. No Google OAuth client, secret, redirect URI or cookie-domain changes are needed. Existing eight-hour cookies issued before the upgrade may require one new employee login to receive a cookie lasting until the absolute limit.

Employees creating invoices/quotations still need their existing Customers read permission and the appropriate document edit grant. This fix does not add unassigned access. An administrator must grant the missing section if the new permission message identifies it.

## Validation

- Backend tests cover expired-session renewal after registry cleanup, absolute lifetime, revocation, current permissions, parallel rotations, family logout, cookie security and context mismatch.
- Employee invoice/quotation integration tests cover create/update, renewal, employee audit identity, uncertain write reconciliation and duplicate prevention.
- Flutter regression tests cover single-flight/late-expiry renewal, bounded retries, proxy/network errors, 403 preservation, permission scope changes, employee-mode restoration, selected-company restoration and logout cleanup.
- Editor widget tests cover retained values after a denied save, disabled duplicate submission, confirmed-success closure and unsaved-change confirmation.
- Existing cache tests cover normalized keys, deduplication, background revalidation, invalidation, cross-workspace late responses, persistence and logout.

`scripts/check-live-backend.mjs` verifies public routing, renewal authentication boundaries, context CORS headers and report settings support without credentials or customer writes. Authenticated live browser saves and a real cross-tab race remain unverified; automated adapters and widget tests exercise those failure paths without touching customer records.

## Verified release

- Backend: 229 tests passed. Cloud Build `917a27b4-f94e-4b36-ae18-c6bbb2edbbfb` succeeded and revision `tpc-accounts-api-00010-niv` serves all production traffic.
- Flutter: the full-suite run passed 158 tests with one existing skip. Subsequent focused runs passed the final session/write/workspace tests (26 tests) and document/cache recovery checks (16 tests with one existing skip). Static analysis reported no issues.
- Frontend: Vercel production deployment `dpl_9xqP1PDKiDfa3qAUWXfqKrAEx4rW` built successfully and was promoted to the existing production domains.
- Live checks: all six public backend checks passed through `https://accounts.thepercentagecompany.com`. The app returned HTTP 200, and its published JavaScript contains the renewal, context-header, session-mode and unsaved-change fixes.
