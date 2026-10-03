# Infrastructure, backup, monitoring and restore verification

Verification date: 4 October 2026 (Asia/Dubai)

Status: **PARTIAL — release checklist remains open.**

All cloud checks were read-only. The recovery drill downloaded two private object
generations, validated their JSON structure locally, and deleted the temporary
copies. It did not overwrite the live registry or modify customer data.

## Verified infrastructure

| Control | Evidence | Result |
| --- | --- | --- |
| Public API routing | `/health`, unauthenticated `/v1/me`, and employee-login preflight passed through `accounts.thepercentagecompany.com` | Pass |
| Cloud Run availability | `tpc-accounts-api-00003-rqx` is Ready and receives 100% of traffic | Pass |
| Runtime limits | Runtime identity is `tpc-api-runtime-v2`; concurrency 20, timeout 300 seconds, maximum scale 2 | Pass |
| Rollback artifacts | Three immutable image digests and three Cloud Run revisions are present | Pass, operational rollback not exercised |
| Setup queue | Queue is RUNNING; concurrency/rate limits are 2; 20 attempts; 10–300 second backoff | Pass |
| Control storage | Regional `ME-CENTRAL1`, uniform access, public-access prevention, object versioning, seven-day soft delete | Pass |
| OAuth secret | Secret version 1 is ENABLED; only runtime service account has secret accessor on the secret | Pass |
| Refresh-token key | KMS primary version is ENABLED; 90-day rotation configured; next rotation 23 December 2026; only runtime has encrypt/decrypt on the key | Pass |
| Setup task identity | Runtime alone can enqueue setup tasks and impersonate the setup worker | Pass |
| Application error sample | No severity `ERROR` Cloud Run entries found in the preceding seven days | Informational only |
| Log retention | Default logging bucket is active with 30-day retention; required/default sinks exist | Pass for basic retention |

The Cloud Run service intentionally permits unauthenticated invocation because the
application performs its own cookie/session authorization. This makes origin,
cookie and abuse-control testing essential.

## Backup findings

The control registry has two recoverable generations. Both downloaded successfully,
parsed as schema version 1, and contained the required top-level collections. The
current object matched its published size and cloud checksum metadata during the
provider-managed download validation.

This is short-window recovery protection, not a complete backup system:

- Only seven days of soft-delete protection is configured.
- There is no scheduled independent copy, retention lock, cross-region copy or
  documented recovery-point objective.
- The registry generations inspected contained no owners, companies or memberships,
  so the drill did not prove restoration of real tenant mappings.
- Company accounting data lives in company-owned Google Sheets and document bytes
  live in company-owned Drive. No scheduled export/copy job or verified restore
  source exists for these records.
- The provisioned `Backups` folder is structure only; source contains no job that
  populates or verifies it.
- Secret Manager and KMS availability were verified, but no independent escrow or
  disaster-recovery procedure for their loss was found.

## Monitoring findings

Cloud Logging is available, but operational monitoring is not configured:

- No Cloud Monitoring alert policies.
- No uptime checks.
- No monitoring dashboards.
- No verified notification channel evidence.
- Cloud Scheduler API is disabled, so there is no scheduled backup/health job there.
- No alerts for Cloud Run availability/error rate/latency, task queue failures,
  registry capacity, setup failures, backup age or KMS/Secret access failures.

The absence of error logs is not evidence that alerts work. The public `/health`
endpoint checks process availability; it does not verify Sheets, Drive, Storage,
KMS, Secret Manager or Cloud Tasks end to end.

## Restore drill and safety result

The read-only portion passed: both known registry generations can be selected by
generation number, downloaded and schema-validated. A production restore was not
performed because the current restore design is unsafe:

- Old registry snapshots can contain owner sessions, OAuth attempts, employee
  sessions, invitation state and access versions.
- Blind replacement can reactivate revoked access or roll back company/resource IDs.
- There is no maintenance-mode/fencing procedure to stop concurrent writes.
- There is no restore-candidate validator that removes ephemeral authorization
  state and reconciles current company resources before promotion.
- There is no tested procedure for restoring company Sheets and Drive documents.

Use [the recovery runbook](backend/cloud-run/DISASTER_RECOVERY.md) as the required
implementation and drill plan. It deliberately prohibits blind registry rollback.

## Release decision

Do not mark the infrastructure/backups/monitoring/restore checklist complete. The
deployed runtime and basic control-store recoverability are verified, but production
monitoring, independent backups, business-data restore and a safe write restore
drill remain release blockers.

