# Operator configuration handoff

## Confirmed by the operator

| Setting | Value |
| --- | --- |
| Google Cloud project ID | `accounts-508118` |
| Google Cloud project number | `110697421185` |
| Production Flutter origin | `https://accounts.thepercentagecompany.com` |
| Vercel project | `accounts` under `irshads-projects-303e06dd` |
| Accepted API origin | `https://api.accounts.thepercentagecompany.com` |
| OAuth client type | Web application (operator confirmed; not inspected live) |

Use the production domain for application redirects and CORS, not the individual
Vercel deployment hostname. This records the operator's supplied values; it does
not assert that DNS, Cloud Run or Google authorization has been verified live.

The local ignored `.env` now contains the production app origin and the OAuth
client ID already found in `config/google.web.json`:
`110697421185-klclvve50ibedrqjc830doqrenp44hif.apps.googleusercontent.com`.
Its redirect configuration and client secret are not yet verified live.
All missing backend resource settings remain blank; the server cannot start with
this incomplete configuration.

## Deployment defaults

Use `me-central1` (Doha) as the planning default near the operator in the UAE;
the operator has not named a region or a data-residency requirement. Both
[Cloud Run](https://cloud.google.com/run/docs/locations) and
[Cloud Tasks](https://docs.cloud.google.com/tasks/docs/locations) list this region.
No resources or DNS records have been created.

Plan the custom API domain through a global external HTTPS Application Load
Balancer with a serverless NEG and managed certificate, following
[Google's custom-domain guidance](https://docs.cloud.google.com/run/docs/mapping-custom-domains).
This introduces billable infrastructure; review it before provisioning. Keep the
task worker's default run.app URL available with verified OIDC delivery.

The exact OAuth redirect URIs to add (preserving existing Flutter settings) are:

- `https://api.accounts.thepercentagecompany.com/v1/auth/google/callback`
- `https://api.accounts.thepercentagecompany.com/v1/google/callback`

Store the client secret in Secret Manager as described in README; do not send it
in chat or commit it.

## Project checks completed by the operator

The operator supplied Cloud Shell output confirming project `accounts-508118`,
number `110697421185`, lifecycle `ACTIVE`, and billing enabled (`True`). Cloud Run,
Artifact Registry, Cloud Build, KMS, Secret Manager, IAM, IAM Credentials, Storage,
Drive and Sheets APIs are enabled. The operator subsequently supplied a successful
operation result enabling Cloud Tasks and Compute Engine APIs. This does not verify resource-level IAM
or the existence of runtime resources.

Completed API enablement command:

```bash
gcloud services enable cloudtasks.googleapis.com compute.googleapis.com --project=accounts-508118
```

This enables service APIs; it does not deploy the app, create a queue or load
balancer, or change DNS.
See [service enablement](https://docs.cloud.google.com/sdk/gcloud/reference/services/enable)
and [Cloud Tasks setup](https://docs.cloud.google.com/tasks/docs/add-task-queue).

### Read-only commands used

Open [Google Cloud Shell](https://console.cloud.google.com/welcome?project=accounts-508118)
using the terminal icon in the top bar. Run these commands and return their output.
They inspect project identity, billing status and enabled APIs without creating
resources or reading secrets. If a command reports permission denied, return that
error rather than changing permissions blindly.

```bash
gcloud projects describe accounts-508118 --format='yaml(projectId,projectNumber,lifecycleState)'
gcloud billing projects describe accounts-508118 --format='value(billingEnabled)'
gcloud services list --enabled --project=accounts-508118 --format='value(config.name)'
```

## Next operator action: identities and setup queue

Run each command separately, stopping on an error. These names are planned until
creation results are supplied. An ALREADY_EXISTS result needs inspection of the
existing resource; do not delete it or create replacement names blindly.

```bash
gcloud iam service-accounts create tpc-api-runtime --display-name="TPC Accounts API runtime" --project=accounts-508118
gcloud iam service-accounts create tpc-setup-worker --display-name="TPC Accounts setup task identity" --project=accounts-508118
gcloud tasks queues create tpc-company-setup --location=me-central1 --max-concurrent-dispatches=2 --max-dispatches-per-second=2 --max-attempts=20 --min-backoff=10s --max-backoff=300s --project=accounts-508118
```

The runtime identity runs the API; the worker identity signs task delivery tokens.
No service-account keys or broad project roles are created. Scoped IAM follows
after the target resources exist. Queue limits are conservative initial defaults
for validation, not a verified production capacity setting. This step does not
deploy Cloud Run, submit tasks or modify customer data.

Command references: [service accounts](https://docs.cloud.google.com/sdk/gcloud/reference/iam/service-accounts/create),
[task queues](https://docs.cloud.google.com/sdk/gcloud/reference/tasks/queues/create).

### Resources created successfully

The operator supplied successful Cloud Shell results for:

- Runtime identity: `tpc-api-runtime@accounts-508118.iam.gserviceaccount.com`
- Task identity: `tpc-setup-worker@accounts-508118.iam.gserviceaccount.com`
- Setup queue: `projects/accounts-508118/locations/me-central1/queues/tpc-company-setup`

No service-account keys were created. Resource-level IAM and live task delivery
remain unverified.

## Next operator action: private infrastructure

Run these commands separately and stop on an error:

```bash
gcloud storage buckets create gs://accounts-508118-tpc-control --project=accounts-508118 --location=me-central1 --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update gs://accounts-508118-tpc-control --versioning
gcloud kms keyrings create tpc-accounts --location=me-central1 --project=accounts-508118
gcloud kms keys create oauth-refresh-tokens --keyring=tpc-accounts --location=me-central1 --purpose=encryption --rotation-period=90d --next-rotation-time=2026-12-20T00:00:00Z --project=accounts-508118
gcloud artifacts repositories create tpc-backend --repository-format=docker --location=me-central1 --description="TPC Accounts backend images" --project=accounts-508118
```

The bucket contains backend control metadata only and has public access prevention,
uniform access and object versioning. The KMS key encrypts customer Google refresh
tokens. The Artifact Registry repository stores deployable backend images. These
commands do not deploy Cloud Run, change DNS or touch customer Sheets/Drive data.

### Private infrastructure created successfully

The operator supplied successful Cloud Shell results for:

- Control bucket: `accounts-508118-tpc-control`, with versioning enabled
- KMS key: `projects/accounts-508118/locations/me-central1/keyRings/tpc-accounts/cryptoKeys/oauth-refresh-tokens`
- Docker repository: `me-central1-docker.pkg.dev/accounts-508118/tpc-backend`

The KMS create commands normally produce no success text; subsequent IAM commands
also serve as an existence check. Public access and uniform access still need a
read-only verification before deployment.

## Next operator action: scoped IAM and secret container

Run the following commands one at a time. They grant only the backend capabilities
required by the current implementation and create an empty Secret Manager secret.
They do not deploy the service or add the OAuth client secret value.

```bash
gcloud storage buckets add-iam-policy-binding gs://accounts-508118-tpc-control --member=serviceAccount:tpc-api-runtime@accounts-508118.iam.gserviceaccount.com --role=roles/storage.objectAdmin
gcloud kms keys add-iam-policy-binding oauth-refresh-tokens --keyring=tpc-accounts --location=me-central1 --member=serviceAccount:tpc-api-runtime@accounts-508118.iam.gserviceaccount.com --role=roles/cloudkms.cryptoKeyEncrypterDecrypter --project=accounts-508118
gcloud tasks queues add-iam-policy-binding tpc-company-setup --location=me-central1 --member=serviceAccount:tpc-api-runtime@accounts-508118.iam.gserviceaccount.com --role=roles/cloudtasks.enqueuer --project=accounts-508118
gcloud iam service-accounts add-iam-policy-binding tpc-setup-worker@accounts-508118.iam.gserviceaccount.com --member=serviceAccount:tpc-api-runtime@accounts-508118.iam.gserviceaccount.com --role=roles/iam.serviceAccountUser --project=accounts-508118
gcloud iam service-accounts add-iam-policy-binding tpc-setup-worker@accounts-508118.iam.gserviceaccount.com --member=serviceAccount:service-110697421185@gcp-sa-cloudtasks.iam.gserviceaccount.com --role=roles/iam.serviceAccountTokenCreator --project=accounts-508118
gcloud secrets create tpc-google-oauth --replication-policy=user-managed --locations=me-central1 --project=accounts-508118
```

Do not paste an OAuth client secret into chat or a command-line argument. Add its
first version through Secret Manager's protected value editor after the redirect
URIs have been configured. The required stored value is JSON with one field named
`clientSecret`; the exact procedure follows after the commands above succeed.

### Scoped IAM and secret container completed

The operator supplied successful results for bucket object administration, KMS
encrypt/decrypt, queue enqueue, runtime act-as-worker, and the Cloud Tasks service
agent's token-creation permission. Secret `tpc-google-oauth` was created. A repeated
create returned the expected `already exists` conflict and requires no correction.

## Next operator action: OAuth redirect and protected secret value

First grant the runtime access to this specific secret:

```bash
gcloud secrets add-iam-policy-binding tpc-google-oauth --member=serviceAccount:tpc-api-runtime@accounts-508118.iam.gserviceaccount.com --role=roles/secretmanager.secretAccessor --project=accounts-508118
```

Then open Google Cloud Console > APIs & Services > Credentials and edit Web client
`110697421185-klclvve50ibedrqjc830doqrenp44hif.apps.googleusercontent.com`.
Preserve all existing entries and add these exact authorized redirect URIs:

- `https://api.accounts.thepercentagecompany.com/v1/auth/google/callback`
- `https://api.accounts.thepercentagecompany.com/v1/google/callback`

Save the client. Obtain its existing client secret without rotating or deleting it.
Open Secret Manager > `tpc-google-oauth` > New version and enter this value, replacing
the placeholder inside Google Console only:

```json
{"clientSecret":"PASTE_EXISTING_CLIENT_SECRET_HERE"}
```

Do not paste the client secret or saved JSON into chat. Report only the created
secret version number (normally `1`). If the existing secret cannot be viewed or
downloaded, stop and report that fact before rotating it because rotation can break
another application using the same OAuth client.

### Security incident: OAuth secret disclosed

The operator pasted the existing OAuth client secret into chat on 2026-09-20.
The value is intentionally not reproduced or stored in this repository. Treat it
as compromised: create a replacement secret in the Google Auth Platform client,
store only the replacement as a Secret Manager version, and disable the exposed
secret before deployment. Do not deploy while the exposed secret remains active.
Follow [Google's client-secret rotation procedure](https://support.google.com/cloud/answer/15549257).

The operator later confirmed that the exposed secret was disabled and both API
redirect URIs were added. However, a read-only `gcloud secrets versions list`
returned `NOT_FOUND` for `tpc-google-oauth`, despite an earlier successful create
and IAM update. Treat the Secret Manager resource/version as unverified until its
current project state is listed; do not configure or deploy the runtime yet.

The subsequent project listing showed one current secret named `TPC-Accounts` and
no `tpc-google-oauth`. Secret names are case-sensitive. Verify the versions and
replication metadata for `TPC-Accounts`; if it contains the replacement OAuth
secret, grant the runtime access to that resource and configure its pinned enabled
version rather than creating another duplicate secret.

Version listing confirmed enabled versions 1 and 2. A non-disclosing structure
check confirmed version 2 contains exactly a non-empty `clientSecret` JSON field,
which matches the backend parser. The local ignored environment now pins
`projects/accounts-508118/secrets/TPC-Accounts/versions/2`. Grant the runtime
access to this actual secret and disable older version 1; version disablement can
be reversed if an unexpected dependency is found.

## Production deployment approval and first build attempt

The operator explicitly approved the first Cloud Build and Cloud Run production
deployment. Local tests passed (77/77), GitHub `main` was verified at commit
`da96f3924ed5e3f6a72a5f08581f95ca29784fb1`, and that exact source was submitted.
The first Cloud Build did not execute: the selected default build identity
`110697421185-compute@developer.gserviceaccount.com` lacked `storage.objects.get`
on `accounts-508118_cloudbuild`. No Cloud Run deployment occurred.

Grant that build identity source-object viewer on the Cloud Build bucket,
Artifact Registry writer on repository `tpc-backend`, and project log writer,
then retry the same immutable image tag. These are build-time permissions only;
do not grant the build identity access to runtime secrets, KMS, tenant storage or
Cloud Run administration.

After the scoped build permissions were applied, Cloud Build
`23b7bc82-0f89-405a-abbf-b4a16f4f2e87` completed successfully from the approved
source. It published
`me-central1-docker.pkg.dev/accounts-508118/tpc-backend/api@sha256:4721ceed6c26cda8cc50f7754b121fddef965e6c6073faefdc5ea18eb2842c31`.
The container install reported zero known dependency vulnerabilities. Deploy by
this immutable digest, then verify `/healthz` before creating DNS or integrating
the frontend.

Cloud Run deployment completed successfully as service `tpc-accounts-api`, revision
`tpc-accounts-api-00001-655`, serving 100% of traffic. The deployment-reported
deterministic URL is
`https://tpc-accounts-api-110697421185.me-central1.run.app`. A first health check
used the different hash-based `status.url`
`https://tpc-accounts-api-2knwa6weda-ww.a.run.app` and received a Google routing
404, so application health remains unverified. Test the deterministic URL and
inspect revision conditions/logs before any DNS or frontend change.

On 2026-09-23, independent HTTPS checks of both the deterministic and hash-based
run.app URLs still returned Google frontend 404 pages. This rules out a transient
single-client result and does not exercise the Node `/healthz` handler. Inspect
Cloud Run conditions, ingress/default-URL settings, IAM and revision logs before
changing or redeploying the service.

Service inspection showed Ready/ConfigurationsReady/RoutesReady, ingress `all`,
and `allUsers` with `roles/run.invoker`, but no application logs. An authenticated
request to the deterministic URL also received the Google frontend 404. This
isolates the failure to default URL routing rather than application auth or the
Node handler. Explicitly restore the default URL before considering a regional
redeployment or load balancer.

An explicit `gcloud beta run services update --default-url` completed, but the
hash-based URL continued returning the Google frontend 404. Before creating a
second regional service, use the authenticated Cloud Run local proxy to determine
whether the deployed revision itself serves `/healthz` when bypassing public URL
routing.

The authenticated proxy also returned the same Google routing 404. The operator
explicitly approved a controlled Dammam (`me-central2`) Cloud Run routing test on
2026-09-23. Use the same immutable image and runtime resources, zero minimum
instances and a maximum of two. Keep the Doha service intact until the Dammam
health result is known; do not change DNS or frontend configuration during this
test.

## Approved scoped reset

After the Dammam deployment was rejected by `LOCATION_POLICY_VIOLATED`, the
operator explicitly approved deletion of only the TPC backend resources created
during this setup. Preserve project `accounts-508118`, its OAuth client, Vercel,
Sheets, Drive, GitHub and unrelated cloud resources. The approved targets are the
Doha Cloud Run service, setup queue, backend Artifact Registry repository, control
bucket, the two TPC service accounts, secret `TPC-Accounts`, setup-specific IAM
grants, the two known Cloud Build source archives, and destruction scheduling for
the created KMS key version. Google Cloud KMS key/key-ring containers cannot be
deleted. Record actual command results before treating this reset as complete.

The operator supplied successful deletion results for the Doha Cloud Run service,
Cloud Tasks queue, Artifact Registry repository, secret `TPC-Accounts`, control
bucket, both known Cloud Build source archives and both TPC service accounts. The
build-time project log-writer and source-bucket viewer grants were removed. A
second bucket removal returned 404 and a repeated service-account deletion failed
after the first successful deletion; both are harmless repeat attempts. The KMS
version-destroy command emitted no text, so verify its state is
`DESTROY_SCHEDULED`. The local ignored `.env` resource references were cleared to
prevent accidental use of deleted infrastructure.

After checking these results, prepare resource creation and IAM configuration for
review: a private control bucket, KMS key, OAuth secret, task queue, runtime/worker
identities, container registry and Cloud Run service. Then configure the load
balancer, certificate and API DNS. Populate environment resource references only
from actual creation results. Customer companies never perform these steps.

## Still to provision or verify

- OAuth consent configuration, client redirects and test-owner accounts.
- Private control bucket, symmetric KMS key and OAuth Secret Manager version.
- Cloud Tasks queue, runtime/worker service accounts and scoped permissions.
- Cloud Run service URL, custom API domain, cookies and task-delivery authentication.

The `.env` must reference real resource names after those resources exist. Do not
fill it with guessed names. The Google Cloud CLI was not found on the current PATH;
the agent has not executed cloud configuration or deployment commands. The
operator ran the read-only checks and API enablement recorded above in Cloud Shell.

Production deployment still requires explicit approval. Flutter API integration
and migration remain pending; setting environment values alone does not switch
the live website from its existing Apps Script flow.
