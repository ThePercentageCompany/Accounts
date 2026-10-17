# Supabase endpoint validation

Flutter connects to the project's `/functions/v1/api` using Supabase Auth bearer sessions.

Verified live: health, admin login, company creation, employee creation, invitation issuance, employee login and workspace deletion. Temporary test identities and records were removed.

Run `node scripts/check-live-backend.mjs` for public routing checks. Tenant permissions and accounting transactions are tested under `supabase/functions/tests`.
