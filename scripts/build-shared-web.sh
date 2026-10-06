#!/usr/bin/env bash
# Operator build entrypoint for the shared-backend web application.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SAAS_API_ORIGIN:?Set SAAS_API_ORIGIN to the verified trusted HTTPS API origin}"
if [[ ! "$SAAS_API_ORIGIN" =~ ^https://[a-zA-Z0-9.-]+(:443)?/?$ ]]; then
  echo 'SAAS_API_ORIGIN must be an HTTPS origin without credentials, path or query.' >&2
  exit 1
fi
flutter pub get
flutter build web --release --dart-define="SAAS_API_ORIGIN=$SAAS_API_ORIGIN"
node scripts/prepare_offline_web.mjs
