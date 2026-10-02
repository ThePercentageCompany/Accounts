# Live owner and employee verification

Status: **BLOCKED — authenticated browser not connected.**
Target: https://accounts.thepercentagecompany.com

## Evidence collected

- Public health: PASS.
- Owner API without authentication: PASS (401 JSON, no-store, expected origin).
- Employee login preflight: PASS (trusted origin, credentials and required headers).
- Browser inventory: no browsers available. Browser connection attempt returned
  `No browser is available`.
- No authenticated owner/employee operations or tenant-isolation checks have run.
- No companies, employees, credentials or customer records were changed.

These results do not establish that the latest local code is deployed.

## Required test setup

Use two unrelated owner Google accounts and two explicitly designated test
companies, A and B. Separate browser profiles must keep their cookies isolated.
Use a separate employee session. Owners authenticate directly in the browser;
never put passwords, cookies, private codes, OAuth links or invitation tokens in
this report. Record the deployed frontend/backend versions before testing.

## Test matrix

Every row below is NOT RUN. Record observed results, not just attempted actions.

| Test | Required observation |
| --- | --- |
| Owner A login | Google callback returns to trusted app; company list loads; refresh preserves session |
| Company A setup | New test workspace reaches READY; retry/refresh does not duplicate company or resources |
| Owner B login/setup | Independent owner session and company B reach READY without exposing A |
| Owner company isolation | A cannot read B's setup, records, employees, reports or private documents using B's known test IDs; repeat B to A |
| Owner write isolation | Controlled test mutation against the other company is denied and destination remains unchanged |
| Employee A issuance | Owner assigns limited sections to a test employee; QR/invitation and separate code are issued |
| Employee A login | Pasted invitation/link and QR camera paths establish an employee session; invalid code does not |
| Employee scope | Only assigned sections and permitted parent/child records appear; forbidden API requests fail |
| Employee company isolation | Employee A cannot read B's records/documents or invoke owner operations; employee B cannot read A |
| Permission change | Removing a section blocks its next request and does not expose stale private results |
| Code reset | Previous code and previous sessions stop working; replacement login succeeds |
| Revocation | Existing session and invitation access stop working promptly |
| Owner offline | After owner logout, authorized employee can still read assigned records |
| Employee logout | Refresh and protected requests cannot restore the logged-out employee session |
| Owner logout | Refresh and protected requests cannot restore the logged-out owner session |
| Storage reconnect | Reconnection restores access while preserving workspace IDs and existing test records |
| Private document delivery | Authorized images/PDFs load; unauthorized and revoked sessions cannot download them; no public Drive URLs |
| Shared reports | Authorized owner/employee reports reconcile to the same posted test records; ungranted reports are denied |

Use test-only records and files. Do not revoke actual customer access or alter
customer financial records. Ask for confirmation at any browser step that grants
new sensitive access. Leave test data intact until cleanup is explicitly agreed.

## Completion rule

Keep the release checklist item unchecked until both owner journeys, both employee
journeys, cross-company denials and reset/revocation checks have recorded passing
evidence. Track camera/device or reconnect checks separately if they remain untested.
