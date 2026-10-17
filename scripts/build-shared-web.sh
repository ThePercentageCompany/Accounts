#!/usr/bin/env bash
# Operator build entrypoint for the shared-backend web application.
set -euo pipefail
cd "$(dirname "$0")/.."
SUPABASE_URL="${SUPABASE_URL:-$(node -p 'JSON.parse(require("fs").readFileSync("config/saas.production.json", "utf8")).SUPABASE_URL')}"
SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-$(node -p 'JSON.parse(require("fs").readFileSync("config/saas.production.json", "utf8")).SUPABASE_PUBLISHABLE_KEY')}"
: "${SUPABASE_URL:?Set SUPABASE_URL to the project HTTPS origin}"
: "${SUPABASE_PUBLISHABLE_KEY:?Set the Supabase public publishable key}"
if [[ ! "$SUPABASE_URL" =~ ^https://[a-zA-Z0-9.-]+(:443)?/?$ ]]; then
  echo 'SUPABASE_URL must be an HTTPS origin without credentials, path or query.' >&2
  exit 1
fi
flutter pub get
flutter build web --release --dart-define="SUPABASE_URL=$SUPABASE_URL" --dart-define="SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY"
node scripts/prepare_offline_web.mjs
node tool/build_pwa.mjs
