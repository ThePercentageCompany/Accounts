# Form validation audit

All `TextField`, `TextFormField`, `Form`, dropdown and payment-method aliases in
`lib/` were searched. Production forms now construct their text form inputs
through `ValidatedTextField`; the only direct `TextFormField` constructor is in
that shared component. Search/filter inputs and the HTML source editor retain
plain `TextField` semantics with appropriate restrictions.

## Shared rules

`app_validation.dart` supplies required, text, name, reference, email, phone,
integer, decimal, money, percentage and calendar validation, plus input
formatters. Explicit field-key policies distinguish contact data, money,
quantities, life/count integers, percentages and references. Existing domain
validators run after these checks, preserving balance limits, positive amount
requirements, date ordering, unique codes and other entity rules.

* Integers use a numeric keyboard and digits-only formatter. Asset life retains
  its existing 1–1200-month limit.
* Amounts and invoice quantities retain the project's existing **two-decimal**
  format and supported magnitude. Fractional invoice and return quantities are
  intentional; changing those fields to integers would break the business model.
* Decimal edits permit intermediate `12.` but malformed paste such as `12abc`,
  `10..50`, exponent notation or a third decimal place is rejected as a whole.
  A complete number is required on submission. Negative values require an
  explicitly configured signed formatter/domain range; the current editable
  financial forms use nonnegative amounts and existing positive checks.
* Percentages use the existing 0–100 range. Financial parsing/calculations and
  authoritative backend policies were not changed.
* Optional phone fields accept 7–15 digits, an initial international `+`, spaces,
  parentheses and hyphens. UAE local and international numbers are covered.
* Optional emails trim for validation, support common punctuation/plus addressing
  and international text, and report `Invalid email address` for malformed input.
* Names retain Unicode, punctuation, spaces, apostrophes and hyphens. Name fields
  reject embedded control characters. Notes/descriptions/addresses allow normal
  punctuation, newlines and tabs. Existing per-field length limits remain.
* References preserve alphanumeric formats and leading zeros. Existing invoice
  prefix/account ID/account code patterns are centralized, and their uniqueness
  checks remain at the form/domain boundary.
* Validation runs on submit and after interaction, not on focus alone. Required
  fields use a shared marker and inline errors. The submission helper scrolls to
  the first invalid field and focuses its text input where available.
* Submit payloads continue trimming fields as before. Input formatting does not
  mutate historical controller values during initial loading.

## Coverage

| Area | Applied checks |
| --- | --- |
| Customers/company profile/shareholders | Required names, optional email/phone, addresses and references |
| Income/expenses | Description, amount, tax percentage, calendar dates, payment-account dropdown |
| Cash payments/customer receipts | Required account selection, dates, references, positive receipt amounts and balance caps |
| Assets | Codes/names, money, integer life, dates, payment/disposal accounts; residual and disposal rules retained |
| Capital contributions/shareholder loans/repayment | Money, dates, account dropdowns and references |
| Payroll/employee profile | Money and contact fields, calendar month/date, payment account; payroll preview/calculation unchanged |
| Invoice/quotation drafts and returns | Descriptions, decimal quantities, money, tax percentage, discount/remaining-quantity checks, refund account |
| Financial periods/reversals/report account configuration | Required names/reasons/codes, date rules, uniqueness/ordering checks |
| Company registration/employee login | Inline required/domain errors, trusted invitation URL checks, unchanged private-code format |
| Tasks/comments/saved report views | Required title/comment/view name, text lengths and existing date/time rules |
| Searches, record pickers and project filters | Control-character rejection and a 200-character query limit; optional empty queries remain valid |
| HTML/CSS design source | Control-character restriction; existing 100-KB/template-placeholder validation; failures below source, success feedback separate |

## Payment compatibility

There are no separate persisted `paymentMethod`/`paymentType`/`paymentMode` fields
in this project. The financial API posts against `Cash` and `Bank` accounts.
`PaymentMethodDropdown` is used at all ten payment-account entry points, including
the previously free-text income/expense account. The existing account labels and
payload keys (`account`, `paymentAccount`, `disposalAccount` and refund account)
remain unchanged. The shared component also exposes the requested eight default
method labels for a future method-aware backend, but does not send unsupported
labels into today's account fields.

No automatic mapping turns a cheque/card/transfer into a ledger account. Unknown
historical values display as legacy values instead of causing a dropdown assertion
or silently becoming Bank. Income/expense draft accounts are permissive text in
the backend, so their existing legacy value may be retained unchanged while other
fields are edited. Strict posting forms require an explicit supported account.
Read-only historical transactions are not rewritten. Live production Sheets were
not accessed; compatibility checks use the schema, policies and test fixtures.

## Verification

`test/app_validation_test.dart` exercises valid/invalid values, optional fields,
Unicode/punctuation, money limits, percentage ranges, copy/paste, intermediate
decimals, composing input, focus behavior, legacy accounts and the dropdown at
320/1200 pixels with large text. Existing create/edit/API-payload and responsive
tests are included in the full Flutter suite.

The release fixture mounts actual customer, company, expense, asset, shareholder,
payment and receipt editors, validates them and scrolls them. It checks 81
scenarios across 320/740/1366 pixels and text scaling from 100% to 300%, retaining
Flutter's default error reporting and printing full exception stacks.

```text
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub --no-wasm-dry-run
flutter build web --release --no-pub --no-wasm-dry-run -t tool/form_release_probe.dart --output=build/form-probe
node scripts/check_form_release.mjs
node scripts/check_form_release.mjs "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
```

Physical mobile devices, native mobile release builds, Safari/Firefox and live
authenticated production datasets require separate checks. Browser fixture checks
do not claim coverage of those environments.

Local verification: Flutter analysis is clean; the complete Flutter suite passes
248 tests with one existing skipped test; 70 business/employee backend tests pass;
the application and diagnostic web release builds succeed. Chrome and Edge
release fixtures complete all 81 scenarios without reported Flutter exceptions,
viewport errors or RenderFlex overflows.
