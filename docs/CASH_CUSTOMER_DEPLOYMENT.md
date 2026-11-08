# Cash customer invoice creation

On 8 November 2026, production API version 22 rejected invoice drafts with
`INVALID_RECORD: Record contains unsupported fields.` Its schema did not allow
`cashCustomerName`, and its invoice policies predated cash customer support.
The local editor and local API already supported this field.

API version 23 was deployed to project `ifuucosaautgobwsunmp` with the local
cash customer schema, invoice, quotation, receipt, return and document design
policies, plus their document numbering dependency. The deployment was staged
from the downloaded production source to preserve unrelated production code.
No database migration or Flutter rebuild was required for this API correction.

Validation: 31 focused document input, invoice, quotation, receipt and document
design tests passed against the staged source. Supabase reported version 23
ACTIVE and the public API health endpoint returned `status: ok`. Authenticated
invoice creation was not exercised against a customer workspace.

Previously rejected local drafts remain in Needs attention. In Settings → Sync
and device storage, choose Edit for the rejected invoice and Save correction
to submit the saved draft again. The generic Retry action does not reopen
`INVALID_RECORD` failures.
