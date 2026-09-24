#!/usr/bin/env bash
# Run in Google Cloud Shell. This deploys the API for live validation, not the Flutter app.
set -euo pipefail
umask 077
cd "$(dirname "$0")"
PROJECT=accounts-508118
REGION=me-central1
SERVICE=tpc-accounts-api
RUNTIME="tpc-api-runtime-v2@$PROJECT.iam.gserviceaccount.com"
WORKER="tpc-setup-worker-v2@$PROJECT.iam.gserviceaccount.com"
BUILDER="tpc-build-v2@$PROJECT.iam.gserviceaccount.com"
CONTROL="$PROJECT-tpc-control-v2"
SOURCE="$PROJECT-tpc-build-v2"
REPOSITORY=tpc-backend-v2
QUEUE=tpc-company-setup-v2
SECRET=tpc-google-oauth-v2
KEY=oauth-refresh-tokens-v2
CLIENT=110697421185-klclvve50ibedrqjc830doqrenp44hif.apps.googleusercontent.com
WORKER_ORIGIN="https://$SERVICE-110697421185.$REGION.run.app"
TASK_TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TASK_TEMP"' EXIT

# Only NOT_FOUND permits creation. IAM/network errors must stop deployment.
ensure() {
  local kind="$1"; shift
  if "$@" >"$TASK_TEMP/result" 2>"$TASK_TEMP/error"; then return 0; fi
  if grep -Eq 'NOT_FOUND|NotFound|not found|does not exist|404' "$TASK_TEMP/error"; then return 1; fi
  cat "$TASK_TEMP/error" >&2
  echo "Cannot inspect $kind; stopping without assuming it is absent." >&2
  exit 1
}
gcloud projects describe "$PROJECT" --format='value(projectNumber)' | grep -qx 110697421185
gcloud billing projects describe "$PROJECT" --format='value(billingEnabled)' | grep -iq '^true$'
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com \
  cloudtasks.googleapis.com secretmanager.googleapis.com cloudkms.googleapis.com \
  iam.googleapis.com iamcredentials.googleapis.com drive.googleapis.com sheets.googleapis.com --project="$PROJECT"

for account in tpc-api-runtime-v2 tpc-setup-worker-v2 tpc-build-v2; do
  if ! ensure account gcloud iam service-accounts describe "$account@$PROJECT.iam.gserviceaccount.com" --project="$PROJECT"; then
    gcloud iam service-accounts create "$account" --display-name="TPC backend $account" --project="$PROJECT"
  fi
done
for bucket in "$CONTROL" "$SOURCE"; do
  if ! ensure bucket gcloud storage buckets describe "gs://$bucket" --project="$PROJECT"; then
    gcloud storage buckets create "gs://$bucket" --location="$REGION" --uniform-bucket-level-access --public-access-prevention --project="$PROJECT"
  fi
done
gcloud storage buckets update "gs://$CONTROL" --versioning --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets add-iam-policy-binding "gs://$CONTROL" --member="serviceAccount:$RUNTIME" --role=roles/storage.objectUser
gcloud storage buckets add-iam-policy-binding "gs://$SOURCE" --member="serviceAccount:$BUILDER" --role=roles/storage.objectViewer
if ! ensure repository gcloud artifacts repositories describe "$REPOSITORY" --location="$REGION" --project="$PROJECT"; then
  gcloud artifacts repositories create "$REPOSITORY" --repository-format=docker --location="$REGION" --project="$PROJECT"
fi
gcloud artifacts repositories add-iam-policy-binding "$REPOSITORY" --location="$REGION" --project="$PROJECT" --member="serviceAccount:$BUILDER" --role=roles/artifactregistry.writer
gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$BUILDER" --role=roles/logging.logWriter --condition=None >/dev/null
if ! ensure keyring gcloud kms keyrings describe tpc-accounts --location="$REGION" --project="$PROJECT"; then
  gcloud kms keyrings create tpc-accounts --location="$REGION" --project="$PROJECT"
fi
if ! ensure key gcloud kms keys describe "$KEY" --keyring=tpc-accounts --location="$REGION" --project="$PROJECT"; then
  gcloud kms keys create "$KEY" --keyring=tpc-accounts --location="$REGION" --purpose=encryption --rotation-period=90d \
    --next-rotation-time="$(date -u -d '+90 days' +%Y-%m-%dT%H:%M:%SZ)" --project="$PROJECT"
fi
gcloud kms keys add-iam-policy-binding "$KEY" --keyring=tpc-accounts --location="$REGION" --project="$PROJECT" --member="serviceAccount:$RUNTIME" --role=roles/cloudkms.cryptoKeyEncrypterDecrypter
if ! ensure secret gcloud secrets describe "$SECRET" --project="$PROJECT"; then
  gcloud secrets create "$SECRET" --replication-policy=automatic --project="$PROJECT"
fi
VERSION="$(gcloud secrets versions list "$SECRET" --project="$PROJECT" --filter='state=ENABLED' --sort-by='~createTime' --limit=1 --format='value(name)')"
if [[ -z "$VERSION" ]]; then
  read -r -p 'Path to the current Google OAuth web-client JSON uploaded to Cloud Shell: ' OAUTH_FILE
  python3 - "$OAUTH_FILE" "$TASK_TEMP/oauth.json" "$CLIENT" <<'PY'
import json,sys
try:
    with open(sys.argv[1], encoding='utf-8-sig') as f: web=json.load(f)['web']
    assert web['client_id']==sys.argv[3] and isinstance(web['client_secret'],str) and web['client_secret']
    with open(sys.argv[2],'w') as f: json.dump({'clientSecret':web['client_secret']},f)
except Exception:
    sys.exit('OAuth JSON is missing or invalid for the configured client. No secret was printed.')
PY
  gcloud secrets versions add "$SECRET" --data-file="$TASK_TEMP/oauth.json" --project="$PROJECT" >/dev/null
  VERSION="$(gcloud secrets versions list "$SECRET" --project="$PROJECT" --filter='state=ENABLED' --sort-by='~createTime' --limit=1 --format='value(name)')"
fi
VERSION="${VERSION##*/}"
gcloud secrets add-iam-policy-binding "$SECRET" --project="$PROJECT" --member="serviceAccount:$RUNTIME" --role=roles/secretmanager.secretAccessor
if ! ensure queue gcloud tasks queues describe "$QUEUE" --location="$REGION" --project="$PROJECT"; then
  gcloud tasks queues create "$QUEUE" --location="$REGION" --max-concurrent-dispatches=2 --max-dispatches-per-second=2 \
    --max-attempts=20 --min-backoff=10s --max-backoff=300s --project="$PROJECT"
fi
gcloud tasks queues add-iam-policy-binding "$QUEUE" --location="$REGION" --project="$PROJECT" --member="serviceAccount:$RUNTIME" --role=roles/cloudtasks.enqueuer
gcloud iam service-accounts add-iam-policy-binding "$WORKER" --project="$PROJECT" --member="serviceAccount:$RUNTIME" --role=roles/iam.serviceAccountUser

TAG="$(date -u +%Y%m%d-%H%M%S)"
IMAGE="$REGION-docker.pkg.dev/$PROJECT/$REPOSITORY/api:$TAG"
cat >"$TASK_TEMP/build.yaml" <<YAML
steps:
- name: node:24-bookworm-slim
  entrypoint: bash
  args: ['-c', 'npm ci --ignore-scripts && npm test']
- name: gcr.io/cloud-builders/docker
  args: ['build', '-t', '$IMAGE', '.']
images: ['$IMAGE']
serviceAccount: projects/$PROJECT/serviceAccounts/$BUILDER
options:
  logging: CLOUD_LOGGING_ONLY
YAML
gcloud builds submit . --config="$TASK_TEMP/build.yaml" --gcs-source-staging-dir="gs://$SOURCE/source" --project="$PROJECT"
DIGEST="$(gcloud artifacts docker images describe "$IMAGE" --project="$PROJECT" --format='value(image_summary.digest)')"
[[ "$DIGEST" =~ ^sha256:[a-f0-9]{64}$ ]] || { echo 'Image digest missing; stopping.' >&2; exit 1; }
cat >"$TASK_TEMP/env.yaml" <<YAML
NODE_ENV: production
APP_ORIGIN: https://accounts.thepercentagecompany.com
API_ORIGIN: https://api.accounts.thepercentagecompany.com
GOOGLE_OAUTH_CLIENT_ID: $CLIENT
GOOGLE_OAUTH_SECRET_VERSION: projects/$PROJECT/secrets/$SECRET/versions/$VERSION
CONTROL_BUCKET: $CONTROL
CONTROL_OBJECT: control/registry-v1.json
GOOGLE_REFRESH_KMS_KEY: projects/$PROJECT/locations/$REGION/keyRings/tpc-accounts/cryptoKeys/$KEY
SETUP_TASK_QUEUE: projects/$PROJECT/locations/$REGION/queues/$QUEUE
SETUP_WORKER_EMAIL: $WORKER
SETUP_WORKER_ORIGIN: $WORKER_ORIGIN
YAML
gcloud run deploy "$SERVICE" --image="${IMAGE%:*}@$DIGEST" --region="$REGION" --project="$PROJECT" \
  --service-account="$RUNTIME" --allow-unauthenticated --ingress=all --cpu=1 --memory=512Mi \
  --concurrency=20 --min-instances=0 --max-instances=2 --timeout=300 --env-vars-file="$TASK_TEMP/env.yaml"
URL="$(gcloud run services describe "$SERVICE" --region="$REGION" --project="$PROJECT" --format='value(status.url)')"
if ! curl --fail --silent --show-error --retry 4 --retry-delay 5 --max-time 30 "$URL/health" >"$TASK_TEMP/health.json"; then
  echo 'Deployment exists, but public health verification failed. Do not change frontend/DNS.' >&2
  gcloud run services logs read "$SERVICE" --region="$REGION" --project="$PROJECT" --limit=30
  exit 1
fi
python3 - "$TASK_TEMP/health.json" <<'PY'
import json,sys
with open(sys.argv[1]) as f: health=json.load(f)
assert health.get('status')=='ok' and health.get('phase')==4, 'Unexpected API health response'
print('BACKEND_HEALTH_OK')
PY
echo "Service: $URL"
echo 'Next: configure and verify api.accounts.thepercentagecompany.com, OAuth redirects and real tenant tests.'
echo 'The Flutter frontend has not been changed by this deployment.'
