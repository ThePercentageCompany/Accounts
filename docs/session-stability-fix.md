# Authentication sessions

Supabase Auth manages admin and employee sessions and refresh tokens. The Edge API verifies identities, live membership, section permissions and reset-session timestamps. Queues and caches are scoped by identity, role and company. Realtime changes invalidate caches and revalidate access. Logout clears private caches and the Auth session. Mutations use stable operation IDs and expected versions.
