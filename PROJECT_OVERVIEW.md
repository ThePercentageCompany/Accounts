# Project overview

TPC Accounts uses a Flutter frontend and a shared Cloud Run backend. The active entrypoint is `lib/main.dart`, which opens `lib/core/saas/saas_app.dart`.

The frontend uses Flutter state objects, HTTP API clients, shared preferences for session settings and durable queues, and IndexedDB for workspace caching. Financial validation and posting policies live in the backend. Invoice and quotation creation uses `invoice_kit` 0.2.0 with custom branded PDF templates; other document types use `pdf`. File downloads use platform-specific utilities.

The legacy direct-Google repositories, local billing/office/quotation screens, Cubits and generated models were removed on 4 October 2026 because the active application did not import them.

See [README](README.md) for source layout and local commands, [setup](SETUP.md) for configuration, and [workflow and delivery status](SOFTWARE_WORKFLOW_AND_STATUS.md) for detailed implementation and release status.
