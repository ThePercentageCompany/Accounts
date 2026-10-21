# Payroll notes

Payroll accepts optional `notes`, `bonusNotes`, and `deductionNotes` strings,
each trimmed and limited to 1,000 characters. Empty strings clear existing notes.
Draft payroll can be edited or deleted; approved or paid payroll stays locked.

The existing authenticated endpoints carry these fields:

- `POST /v1/companies/{companyId}/records/Payroll`: `{expectedVersion: 0, values: {...}}`
- `GET /v1/companies/{companyId}/records/Payroll`: returns saved payroll and notes.
- `PATCH /v1/companies/{companyId}/records/Payroll/{recordId}`: `{expectedVersion, values: {...}}`
- `DELETE /v1/companies/{companyId}/records/Payroll/{recordId}`: `{expectedVersion}`

Writes require a stable `Idempotency-Key`. Employee routes use
`/v1/employee/companies/{companyId}` and require Payroll write access.
The existing sync endpoint also accepts these fields in payroll operations.

Apply `202610210001_payroll_notes.sql` and deploy the `api` Edge Function
before releasing the updated Flutter client. The migration adds note columns to
`business.payroll`, updates the projection function, and copies existing notes
from authoritative `public.business_records` JSON payloads. No separate notes
endpoint is needed.

Deployment verified on 21 October 2026 for project `ifuucosaautgobwsunmp`:
the payroll notes migration was applied and the `api` function deployed as
active version 19. The previous deployed version predated the notes fields
and rejected creation requests with `Record contains unsupported fields.`

If CRUD fails in a deployed environment, capture its response code and message.
`INVALID_RECORD` can indicate an older deployed API schema; version conflicts
require refreshing the record; approved payroll cannot be edited or deleted.
