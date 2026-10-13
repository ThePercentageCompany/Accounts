// Public routing checks; no customer data or private credentials are logged.
const origin = process.env.SUPABASE_URL || 'https://ifuucosaautgobwsunmp.supabase.co';
const appOrigin = process.env.APP_ORIGIN || 'https://accounts.thepercentagecompany.com';
const project = new URL(origin);
if (project.protocol !== 'https:' || project.origin !== origin) throw new Error('Use an exact HTTPS project origin.');
const base = `${origin}/functions/v1/api`;
const checks = [
  ['health', '/health', 'GET', 200],
  ['admin authentication', '/v1/me', 'GET', 401],
  ['employee authentication', '/v1/employee/refresh', 'POST', 401],
  ['HTML document authentication', `/v1/companies/${'a'.repeat(43)}/record-html/Invoices/${'b'.repeat(43)}`, 'GET', 401],
  ['CORS preflight', '/v1/employee/login', 'OPTIONS', 204],
];
let failed = false;
for (const [name, path, method, status] of checks) {
  try {
    const response = await fetch(base + path, { method, headers: { Origin: appOrigin, ...(process.env.SUPABASE_PUBLISHABLE_KEY ? { apikey: process.env.SUPABASE_PUBLISHABLE_KEY } : {}) }, signal: AbortSignal.timeout(15000) });
    if (response.status !== status) throw new Error(`expected ${status}, received ${response.status}`);
    if (response.headers.get('access-control-allow-origin') !== appOrigin) throw new Error('CORS origin mismatch');
    if (response.headers.get('cache-control') !== 'no-store') throw new Error('Private response caching enabled');
    if (method !== 'OPTIONS') {
      const value = await response.json();
      if (status === 200 && !value.capabilities?.includes('supabase-postgres')) throw new Error('Supabase backend contract missing');
      if (status === 401 && value.error?.code !== 'UNAUTHORIZED') throw new Error('Unexpected authentication response');
    }
    console.log(`PASS ${name}`);
  } catch (error) { failed = true; console.error(`FAIL ${name}: ${error.message}`); }
}
if (failed) process.exitCode = 1;
