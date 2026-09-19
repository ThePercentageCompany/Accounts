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
