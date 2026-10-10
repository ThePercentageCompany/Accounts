# TPC Accounts

Flutter business accounting workspace backed by a shared Cloud Run API. Owners sign in through the backend and provision company Google storage; employees use backend-issued invitations and private codes.

The project is under implementation. See [workflow and delivery status](SOFTWARE_WORKFLOW_AND_STATUS.md) for implemented features, validation and remaining release work.

## Local development

Install Flutter with Dart 3.8 or later, then run:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --dart-define-from-file=config/saas.example.json
```

Set the example configuration's SAAS_API_ORIGIN to a trusted backend. Without an API origin the app displays a configuration error. See [setup](SETUP.md) for operator configuration and release builds.

## Source layout

- `lib/main.dart`: application entrypoint.
- `lib/features/`: authentication, workspace, documents, customers, accounting, employees and reports, grouped by feature and responsibility.
- `lib/features/auth/domain/`: the session repository contract.
- `lib/features/auth/presentation/cubit/`: Bloc/Cubit session state with Freezed immutable snapshots.
- `lib/features/employees/presentation/cubit/`: employee administration state and durable write coordination.
- `lib/core/network/` and `cache/`: shared API transport and persistent read cache.
- `lib/core/theme/`, `widgets/` and `utils/`: shared appearance, QR rendering and platform downloads.
- `backend/cloud-run/`: shared API, provisioning, permissions and accounting policies.
- `test/`: tests for the active Flutter application.
- `scripts/`: setup, build and verification tools.

The active app uses the shared API. Existing editors, queues and reporting logic are reused in the feature folders; no duplicate legacy screen tree remains. Regenerate Freezed state after editing its declaration:

```bash
flutter pub run build_runner build
```

## Multi-currency transactions

Invoices, quotations, customer receipts, payroll, income and expenses retain their original currency and amounts. Posted journals and financial reports use the company accounting currency. Set employee salary currency and customer preferred currency in their respective editors.

The authenticated `GET /v1/companies/{companyId}/exchange-rate?currency=INR&date=2026-10-10` endpoint (also under `/v1/employee/companies/`) returns a dated Frankfurter reference rate, its date and accounting currency. Forms fill this rate automatically and allow manual changes, including payment-date rates. The convention is **1 transaction-currency unit = exchangeRate accounting-currency units**. Saved rates do not change when reference rates update; settlements post exchange gains/losses. If the provider is unavailable, enter a manual rate.

Currency dropdowns show codes and names from the public Frankfurter `/v2/currencies` catalog, cached for the app session. Common currencies and saved currency codes remain available offline. Selecting a transaction currency refreshes its dated exchange rate through the authenticated backend endpoint. Receipt and payment currencies remain locked to their source document.

Existing spreadsheet columns are extended without changing historical money or journal values. Existing posted records retain their original ledger scale. This release does not add automatic period-end revaluation, currency-specific bank account registers, or bank-fee reconciliation; bank fees can be recorded separately as expenses. Supported transaction amounts retain the application's two-decimal precision.
