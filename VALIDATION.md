# Multi-currency validation

## Local saves and background sync — 2026-10-11

- 17 Flutter tests passed across `offline_outbox_test.dart`, `local_save_integration_test.dart` and `currency_fields_test.dart`.
- Coverage: editing during an in-flight request; durable restart recovery; stable retries; temporary-ID and version dependencies; unrelated progress after a rejection; dependent discard; account/company isolation; expired authentication; failed device writes; retrying financial action envelopes; local employee references; multiple queued attachments; local report settings; currency behavior.
- Targeted analysis passed for the changed queues, API, workspace, employee/payroll, document and task screens.
- Service-worker JavaScript syntax and `git diff --check` passed.
- Local release build and production release build passed. Production deployment: `dpl_7NTQdFSwtSiw6n33y1cdxgnUMrdz`; registered PWA shell: `67d114fe221f02dd6a1a`, containing 41 public resources.
- The release build now generates the worker actually registered by `pwa.js`. The previous build generated only a separate worker, leaving the registered worker with an incomplete development shell.
- Isolated Chrome verification passed: installable manifest, offline reload, compiled app included in shell cache, API exclusion, controlled updates and retained pending changes; no uncaught browser errors. Screenshots are under `build/pwa-verification`.
- Private production account transactions were not created during validation. Recheck in a test company with browser networking disabled, restore networking, and verify that saved changes sync while another form remains usable. Repeat after closing/reopening the PWA and from two tabs.
- Server confirmation remains required for official numbering, financial reports and access-code issuance. Missing cached data requires a connection. Closed-app background delivery depends on browser support.

Validated on 2026-10-11.

## Automated checks

- Backend: `npm --prefix backend/cloud-run test` — 274 tests passed.
- Flutter: `flutter test test/currency_fields_test.dart` — 5 tests passed, covering dropdown selection and rate loading, manual overrides, stale responses, saved-rate preservation and provider-outage fallback.
- Targeted Flutter analysis passed for the changed currency forms and connected editors.
- Local Flutter web release and production Vercel builds passed.
- `git diff --check` passed.

Backend coverage includes foreign invoices and receipts, payroll, income and expense settlement, exchange gains/losses, receipt reversals, rounding and additive spreadsheet schema migration.

## Production deployment

- Frontend deployment: `dpl_A7meuAz3REw8wrcbWxHEG6vErDU4` (includes currency dropdowns).
- Backend revision: `tpc-accounts-api-00024-mom`, serving 100% of traffic.
- Backend image digest: `sha256:e5df6c3200ada0d3cce010afce499d6e01e4b03ab7eaa44bfa88c446a172ee42`.
- Production homepage and `/health` returned HTTP 200.
- Health advertises the `multi-currency` capability.
- Frankfurter currency catalog returned HTTP 200 and permits the production origin through CORS; the dated INR/AED rate endpoint returned a valid rate.
- The exchange-rate endpoint rejects an unauthenticated request with HTTP 401.

## Signed-in verification still required

Automated tests use fixtures; no transaction was created in a customer's production account during validation. In a test company, check these workflows:

1. Set the company accounting currency, a customer preferred currency and an employee salary currency.
2. Create a foreign-currency invoice, confirm the dated rate fills automatically, override it and save. Reopen it and confirm the saved rate remains unchanged.
3. Issue the invoice and receive payment at a different rate. Confirm the report shows the company-currency amount and the exchange gain or loss.
4. Approve and pay foreign-currency payroll; post and settle foreign income and expenses.
5. Reverse a receipt and confirm its original company-currency journal and exchange adjustment are reversed.
6. Confirm existing records still load after their spreadsheet headers are extended.

## Scope

Rates are dated reference rates and can be overridden with the actual bank rate. Transaction amounts retain two-decimal precision. Automatic period-end revaluation, currency-specific bank account registers and bank-fee reconciliation are outside this release; bank fees can be recorded as separate expenses.
