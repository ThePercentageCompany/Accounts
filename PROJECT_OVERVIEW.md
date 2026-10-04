# Project overview

TPC Accounts uses a Flutter frontend and a shared Cloud Run backend. The active entrypoint is `lib/main.dart`, which opens `lib/features/auth/presentation/saas_app.dart`.

The frontend groups existing screens and services by feature. Session and employee administration use Bloc/Cubit with generated Freezed state snapshots. Authentication exposes a domain repository contract implemented by the shared API client. Shared network, cache, theme, form and platform utilities remain under `core`; document/record queues and exports sit in feature data folders. Local form inputs remain in their existing StatefulWidgets. Shared preferences store session settings and durable queues, and IndexedDB stores workspace read snapshots. Financial validation and posting policies live in the backend. Invoice and quotation creation uses `invoice_kit` 0.2.0 with custom branded PDF templates; other document types use `pdf`.

The legacy direct-Google repositories, local billing/office/quotation screens, Cubits and generated models were removed on 4 October 2026 because the active application did not import them.

See [README](README.md) for source layout and local commands, [setup](SETUP.md) for configuration, and [workflow and delivery status](SOFTWARE_WORKFLOW_AND_STATUS.md) for detailed implementation and release status.
