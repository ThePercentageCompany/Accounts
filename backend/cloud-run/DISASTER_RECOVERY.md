# Disaster recovery runbook

Status: procedure defined; write restore and company-data restore are not yet tested.

## Scope and safety rules

The operator control registry stores authorization and resource mappings. Company
accounting records remain in each company's Google Sheet; documents remain in its
Drive folders. Restoring only one layer can create inconsistent or insecure state.

Never overwrite `control/registry-v1.json` directly from an old generation. Never
restore an old snapshot containing sessions or access state as a way to repair
login. Never run a restore while the API can write the registry.

Before production use, define and approve recovery point and recovery time targets,
backup retention, incident ownership and the maintenance-window communication path.

## Required backup design

1. Export the control registry on a schedule to a separate backup bucket with
   retention lock, longer retention and restricted restore-writer access.
2. Record source generation, CRC32C, size, schema version and backup timestamp in
   an append-only manifest. Alert when the last verified backup exceeds its target.
3. Export each company spreadsheet in a format that preserves all tab values and
   metadata needed by the schema. Copy private documents with identity, parent,
   content hash and registry metadata. Do not create public links.
4. Encrypt backup content, test key availability and keep restore permission
   separate from normal runtime write permission.
5. Test restore into an isolated project/workspace. Never use a customer workspace
   as a drill target.

## Control-registry recovery procedure

1. Declare an incident and record the current Cloud Run revision, image digest,
   registry generation, object checksum and affected companies.
2. Fence writes using a reviewed maintenance deployment or equivalent control.
   Confirm mutation endpoints and setup workers cannot write before continuing.
3. Preserve the current registry generation as incident evidence.
4. Download the selected backup by exact generation. Verify provider checksum,
   manifest checksum, byte size and schema version before parsing it.
5. Build a restore candidate offline. Remove `sessions`, `oauth` and
   `employeeSessions`. Treat employee invitations/access versions, registrations,
   pending writes and document operations as security-sensitive; reconcile them
   against the current incident record rather than copying them blindly.
6. Verify every company spreadsheet/folder/document ID against Google APIs without
   creating or replacing resources. Fail closed on missing or changed ownership.
7. Write the candidate to a separate object, run structural/capacity/reference
   validation, and obtain incident-owner review.
8. Promote using a generation precondition against the fenced live generation.
   A mismatch aborts the restore; it must never overwrite an intervening write.
9. Deploy/route the compatible backend revision. Keep all prior sessions invalid.
10. Verify health, owner isolation, employee revocation, setup state, reports and
    private documents using designated recovery-test tenants.
11. Reopen writes gradually, monitor errors and retain incident artifacts according
    to the approved retention policy.

## Company Sheets and Drive recovery

No usable automated backup exists yet. Until scheduled exports/copies and an
isolated restore tool are implemented, loss or corruption of company Sheets or
Drive documents is not recoverable through this service. Google provider trash or
version history may help an operator, but it is not the product's verified backup.

A future restore tool must create an isolated candidate workspace, import records,
validate company IDs, relationships, journal integrity, document hashes and access
rules, and switch mappings only through a reviewed atomic registry update.

## Drill acceptance criteria

A release-grade drill must prove all of the following without customer data:

- Latest and older backup selection by manifest and checksum.
- Restoration into an isolated project with no production credentials or routes.
- Forced invalidation of every owner/employee/OAuth session.
- Company and employee cross-tenant denial after restoration.
- Reconciliation of Sheets records, reports and document hashes.
- Measured recovery point and recovery time within approved targets.
- Monitoring alert delivery for failed backup and failed restore validation.
- Documented rollback from the restore itself.

