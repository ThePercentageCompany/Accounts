# API contract

All responses are JSON except 204 logout responses and the Google callback's
303 redirect. Errors are `{ "error": { "code", "message", "requestId" } }`.
All responses are non-cacheable. Current request bodies are limited to 16 KiB.
Production origin is operator-fixed; invitations cannot supply an API origin.

## Implemented in Phase 1

| Method and route | Input | Result / authorization |
| --- | --- | --- |
| `GET /healthz` | None | Process liveness; no private configuration. |
| `POST /v1/auth/google/start` | `{}` | Google authorization URL; sets browser-bound OAuth cookie. Requires app Origin and CSRF header. |
| `GET /v1/auth/google/callback` | Google `code`, `state` + OAuth cookie | Consume state, exchange code with PKCE, verify ID token/audience/issuer/nonce, set owner session, fixed redirect. |
| `GET /v1/me` | Owner session cookie | `{owner: {ownerId, email, name}}`. |
| `POST /v1/auth/logout` | `{}` + owner session | Revoke current session and clear cookie. |
| `POST /v1/auth/revoke-sessions` | `{}` + owner session | Increment owner's session version, invalidating all existing sessions. |
| `POST /v1/companies` | `{name}` + `Idempotency-Key` + owner session | 201 new registration or 200 replay; `{company, replayed}`. |
| `GET /v1/companies` | Owner session | Only companies with active memberships. |
| `GET /v1/companies/:companyId/setup` | Owner session | Company status after current owner membership check. Other companies return 404. |

POST routes require `Origin: APP_ORIGIN`, `X-TPC-CSRF: 1` and JSON content type.
Owner session expiry is eight hours; revocation/status is checked on each request.
Google identity tokens/access tokens are not accepted as company API authority.

Registration accepts only `name` (1–160 non-control characters). Unknown fields,
including sheet/folder IDs, roles and permissions, are rejected. The idempotency
key must be 16–128 URL-safe alphanumeric/underscore/hyphen characters. Generate
one random key for each intended company and retain it across network retries.
The same owner/key with different normalized input returns 409. Different keys
represent different intended companies, even when their names match.

Company response fields: `companyId`, `name`, `stage`, `createdAt`, `updatedAt`,
`version`, `employeeInvitationsEnabled`, `errorCode`, `nextAction`. Timestamps are Unix milliseconds.
Google resource IDs, owner subject, credentials and session hashes stay internal.
Registration records `REGISTERED` and advances to `GOOGLE_CONNECTION_REQUIRED`
atomically. Invitations are eligible only at READY; employee endpoints are Phase 3.

## Implemented in Phase 2

| Method and route | Input | Result / authorization |
| --- | --- | --- |
| `POST /v1/companies/:id/google/connect` | `{}` + current owner session, Origin and CSRF header | Offline Google consent URL, separate HttpOnly connection cookie; no credentials in response. Used for initial connect and reconnect. |
| `GET /v1/google/callback` | Google code/state + same owner session + connection cookie | Exchange/verify Google identity and granted scopes, encrypt refresh token, persist connection and queue setup, then fixed app-root redirect. |
| `POST /v1/companies/:id/setup/retry` | `{}` + current owner session, Origin and CSRF header | 202 with public company status after durable enqueue; reconnect is required if Google grant was revoked. |
| `POST /internal/setup` | `{companyId}` + Cloud Tasks Google OIDC bearer token | 204 after a bounded step and next-task enqueue. This route uses service authentication, not owner cookies or browser CSRF. |

The existing setup GET route reports stages and recovery codes. `nextAction` is
`CONNECT_GOOGLE`, `RECONNECT_GOOGLE`, `RETRY_SETUP` or null. Error responses do not
contain Google credentials, resource IDs or upstream response bodies.

Workers run after owner logout using encrypted offline authorization. Google
`invalid_grant` or a data-API 401 sets `RECONNECT_REQUIRED`; quota/transient errors
set `RECOVERABLE_FAILURE`. Reconnection keeps saved IDs and company data and
re-verifies existing resources. It cannot adopt arbitrary files submitted by clients.

`RESOURCE_CONFIRMATION_PENDING` means a spreadsheet create had an unknown outcome.
Retry reconciles the tagged original only. If no resource ever appears, operator
review is needed; no endpoint blindly clears that intent or creates a replacement.
The private control Sheet projection is still planned; no projection API is exposed.

## Implemented in Phase 3

Owner routes require the owner cookie, exact app Origin, CSRF header for mutations,
and READY workspace. `GET /v1/companies/:id/employees` lists access profiles.

| Method and route | Contract |
| --- | --- |
| `POST /v1/companies/:id/employees` | Create with `Idempotency-Key`, `expectedVersion: 0`, fullName, role, employmentStatus, allowedSections; optional email/phone/department/designation. |
| `PATCH /v1/companies/:id/employees/:employeeId` | Same required desired access fields with current expectedVersion; omitted optional contact fields are preserved. Returns employeeId, version, replayed. |
| `POST /v1/companies/:id/employees/:employeeId/access/issue` | `{}` plus unique Idempotency-Key; returns opaque invite link/QR payload and separate one-time code. |
| `POST /v1/companies/:id/employees/:employeeId/access/reset` | Same contract; replaces invite/code and invalidates sessions. |
| `POST /v1/companies/:id/employees/:employeeId/access/revoke` | `{}`; immediately revokes without depending on Google availability; 204. |
| `POST /v1/employee/login` | Only `{inviteId, privateCode}`; sets separate HttpOnly employee cookie; returns employee identity/current sections and expiresAt, no bearer token. |
| `GET /v1/employee/me` | Employee cookie; reloads current role/status/sections from Sheets. |
| `POST /v1/employee/refresh` | `{}` + employee cookie; rotates session subject to absolute lifetime. |
| `POST /v1/employee/logout` | `{}`; revokes the session and clears cookie, even if Google is unavailable. |
| `GET /v1/employee/records/:table` | Employee cookie; allowlisted normalized tables, live section/row/field rules, no control/credential tables. Read-only. |

Employee mutations use the same exact-origin/CSRF protections as owner mutations.
Company IDs in owner URLs only select a resource to authorize. Employee routes
resolve company exclusively from the invite/session, never from request parameters.
Role labels are Staff, Manager or Accountant; status is ACTIVE or INACTIVE.
See [employee access](EMPLOYEE_ACCESS.md) for role privacy limits, rate limits,
one-time code recovery and uncertain-write handling. Company-manager employee
accounts cannot call owner management routes.

## Planned routes — not implemented, no successful stubs

| Phase | Routes | Contract requirements |
| --- | --- | --- |
| 4 | `GET/POST/PATCH/DELETE /v1/companies/:id/records/:section[/recordId]` | Section/table allowlist, tenant membership, restricted fields, row visibility, versions and soft deletion. |
| 4 | `POST /v1/companies/:id/sync` | Unique operation IDs and expected versions; atomic idempotency/conflict protocol; explicit per-operation results. |
| 4 | `POST /v1/companies/:id/documents`, `GET /v1/companies/:id/documents/:documentId` | Opaque document IDs; registry and folder-scope validation; no arbitrary Drive IDs/URLs. |
| 5 | Reviewed legacy workspace adoption | Owner verification, dry run, backup, resumable migration, mapping and invite reissue; approval before destructive steps. |

Sheets does not provide multi-row compare-and-swap transactions. Phase 4 needs a
durable operation journal with deterministic application/recovery before claiming
exactly-once accounting writes. Registration idempotency alone does not solve
invoice/payment synchronization.
