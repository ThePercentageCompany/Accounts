# Validation at delivery — Google-only expansion

- PASS: 26 Node backend tests (`node --test backend/core.test.cjs`).
- PASS: Dart source delimiter check (`python3 scripts/check_source.py`). This is not a Dart compiler/analyzer.
- PASS: Firebase runtime imports/dependencies, function folder and configuration removed.
- NOT RUN: Flutter dependency resolution, Freezed generation, Flutter analyzer/tests, Android/web/iOS builds, rendered PDF visual QA or device interactions.
- NOT RUN: live Google Sign-In/OAuth, API executable, Google Sheets and Google Drive integration.

Flutter/Dart are unavailable in this workspace and the earlier SDK download was blocked. Google account/project identifiers and deployments have not been supplied.

Backend tests use in-memory Google-service substitutes. They cover invoice arithmetic/rounding/validation, numbering and retry behavior, snapshots, stale versions, payment/overpayment, void retention, archive retries, Google email allowlist rejection, employee codes, attendance uniqueness, payroll arithmetic, missing/changed attendance, approved payroll locks, duplicate salary payments, supplier settlement and invalid payroll inputs.

Flutter tests are supplied for Freezed JSON serialization, invoice/PDF basics, Cubit state, payroll calculation and cash-flow aggregation without duplicate invoice/payroll transactions. They remain unrun here.
