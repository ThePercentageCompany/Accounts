# Multi-currency validation

Validated on 2026-10-11.

## Automated checks

- Backend: `npm --prefix backend/cloud-run test` — 274 tests passed.
- Flutter: `flutter test test/currency_fields_test.dart` — 4 tests passed, covering automatic rate loading, manual overrides, stale responses, saved-rate preservation and provider-outage fallback.
- Targeted Flutter analysis passed for the changed currency forms and connected editors.
- Local Flutter web release and production Vercel builds passed.
- `git diff --check` passed.

Backend coverage includes foreign invoices and receipts, payroll, income and expense settlement, exchange gains/losses, receipt reversals, rounding and additive spreadsheet schema migration.

## Production deployment

- Frontend deployment: `dpl_8jwXxzBRHeWGSPuxvbmiVVo3fnST`.
- Backend revision: `tpc-accounts-api-00024-mom`, serving 100% of traffic.
- Backend image digest: `sha256:e5df6c3200ada0d3cce010afce499d6e01e4b03ab7eaa44bfa88c446a172ee42`.
- Production homepage and `/health` returned HTTP 200.
- Health advertises the `multi-currency` capability.
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
