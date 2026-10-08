#!/usr/bin/env bash
# Run from this directory in Cloud Shell after deploying the notification backend.
set -euo pipefail
umask 077
cd "$(dirname "$0")"
PROJECT=accounts-508118
REGION=me-central1
SERVICE=tpc-accounts-api
SECRET=tpc-web-push-v1
RUNTIME="tpc-api-runtime-v2@$PROJECT.iam.gserviceaccount.com"
WORKER="tpc-setup-worker-v2@$PROJECT.iam.gserviceaccount.com"
: "${PUSH_CONTACT:?Set PUSH_CONTACT to an operator mailto: or HTTPS contact URL}"
case "$PUSH_CONTACT" in mailto:*|https://*) ;; *) echo 'Use a mailto: or HTTPS operator contact.' >&2; exit 1;; esac
case "$PUSH_CONTACT" in *','*|*$'\n'*) echo 'Contact must not contain commas or newlines.' >&2; exit 1;; esac
TASK_TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TASK_TEMP"' EXIT
gcloud run services describe "$SERVICE" --project="$PROJECT" --region="$REGION" --format=json >"$TASK_TEMP/service.json"
# Preserve the key pair across reruns; existing secrets must never be rotated implicitly.
gcloud secrets list --project="$PROJECT" --filter="name:$SECRET" --format='value(name)' >"$TASK_TEMP/secrets"
if grep -Eq "(^|/)$SECRET$" "$TASK_TEMP/secrets"; then
  VERSION="$(gcloud secrets versions list "$SECRET" --project="$PROJECT" --filter='state:ENABLED' --sort-by='~createTime' --limit=1 --format='value(name)')"
  test -n "$VERSION"
  gcloud secrets versions access "$VERSION" --secret="$SECRET" --project="$PROJECT" >"$TASK_TEMP/keys.json"
else
  npm ci --no-audit --no-fund
  node --input-type=module -e 'import webPush from "web-push"; process.stdout.write(JSON.stringify(webPush.generateVAPIDKeys()));' >"$TASK_TEMP/keys.json"
  gcloud secrets create "$SECRET" --project="$PROJECT" --replication-policy=automatic --data-file="$TASK_TEMP/keys.json" >/dev/null
  VERSION=1
fi
PUBLIC_KEY="$(node -e 'const fs=require("fs");const k=JSON.parse(fs.readFileSync(process.argv[1]));if(!k.publicKey||!k.privateKey)process.exit(1);process.stdout.write(k.publicKey)' "$TASK_TEMP/keys.json")"
gcloud secrets add-iam-policy-binding "$SECRET" --project="$PROJECT" --member="serviceAccount:$RUNTIME" --role=roles/secretmanager.secretAccessor >/dev/null
node --input-type=module - "$PUBLIC_KEY" "$PROJECT" "$SECRET" "$VERSION" "$PUSH_CONTACT" >"$TASK_TEMP/push.yaml" <<'JS'
const [key,project,secret,version,subject]=process.argv.slice(2);
if (!/^(mailto:|https:\/\/)/.test(subject)) throw Error('Contact must be mailto: or HTTPS');
for (const [name,value] of Object.entries({PUSH_VAPID_PUBLIC_KEY:key,
  PUSH_VAPID_SECRET_VERSION:`projects/${project}/secrets/${secret}/versions/${version.split('/').pop()}`,
  PUSH_VAPID_SUBJECT:subject})) console.log(`${name}: ${JSON.stringify(value)}`);
JS
gcloud run services update "$SERVICE" --project="$PROJECT" --region="$REGION" --update-env-vars="$(node -e 'const fs=require("fs");const k=JSON.parse(fs.readFileSync(process.argv[1]));process.stdout.write(`PUSH_VAPID_PUBLIC_KEY=${k.publicKey},PUSH_VAPID_SECRET_VERSION=projects/${process.argv[2]}/secrets/${process.argv[3]}/versions/${process.argv[4].split("/").pop()},PUSH_VAPID_SUBJECT=${process.argv[5]}`)' "$TASK_TEMP/keys.json" "$PROJECT" "$SECRET" "$VERSION" "$PUSH_CONTACT")" >/dev/null
WORKER_ORIGIN="$(node -e 'const fs=require("fs");const s=JSON.parse(fs.readFileSync(process.argv[1]));const e=s.spec.template.spec.containers[0].env;process.stdout.write(e.find(x=>x.name==="SETUP_WORKER_ORIGIN").value)' "$TASK_TEMP/service.json")"
gcloud services enable cloudscheduler.googleapis.com --project="$PROJECT" >/dev/null
gcloud scheduler jobs list --project="$PROJECT" --location="$REGION" --format='value(name)' >"$TASK_TEMP/jobs"
ACTION=create
if grep -q '/tpc-task-notifications$' "$TASK_TEMP/jobs"; then ACTION=update; fi
gcloud scheduler jobs "$ACTION" http tpc-task-notifications --project="$PROJECT" --location="$REGION" \
  --schedule='* * * * *' --time-zone=Asia/Dubai --uri="$WORKER_ORIGIN/internal/notifications" \
  --http-method=POST --headers='Content-Type=application/json' --message-body='{}' \
  --oidc-service-account-email="$WORKER" --oidc-token-audience="$WORKER_ORIGIN" >/dev/null
echo 'Push keys and deadline scheduler configured. Open the notification bell and choose Enable notifications.'
