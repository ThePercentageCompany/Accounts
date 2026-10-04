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
- `lib/core/saas/`: authentication, company setup, workspace, editors, reports, documents and caching.
- `lib/core/theme/`, `widgets/` and `utils/`: shared appearance, QR rendering and platform downloads.
- `backend/cloud-run/`: shared API, provisioning, permissions and accounting policies.
- `test/`: tests for the active Flutter application.
- `scripts/`: setup, build and verification tools.

The obsolete direct-Sheets/local application, generated models and their tests have been removed. The active app uses the shared API; code generation is no longer required.
