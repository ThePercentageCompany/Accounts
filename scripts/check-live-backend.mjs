// Read-only checks. No cookies, credentials or customer data are sent or logged.
const appOrigin = process.env.APP_ORIGIN || 'https://accounts.thepercentagecompany.com';
const apiOrigin = process.env.SAAS_API_ORIGIN || appOrigin;
for (const origin of [appOrigin, apiOrigin]) {
  const url = new URL(origin);
  if (url.protocol !== 'https:' || url.origin !== origin || url.username || url.password) {
    throw new Error('Use exact trusted HTTPS origins without credentials or paths.');
  }
}
async function check(name, path, options, validate) {
  try {
    const response = await fetch(`${apiOrigin}${path}`, {
      redirect: 'manual', signal: AbortSignal.timeout(15000), ...options,
    });
    await validate(response);
    console.log(`PASS ${name}`);
    return true;
  } catch (error) {
    console.error(`FAIL ${name}: ${error.message}`);
    return false;
  }
}
function requireCheck(condition, message) { if (!condition) throw new Error(message); }
async function json(response) {
  requireCheck(response.headers.get('content-type')?.includes('application/json'),
    'Expected API JSON; check proxy ordering before the website fallback.');
  return response.json();
}
const results = await Promise.all([
  check('health', '/health', {}, async response => {
    requireCheck(response.status === 200, `HTTP ${response.status}`);
    const value = await json(response);
    requireCheck(value.status === 'ok' && value.phase === 4, 'Unexpected backend health contract.');
    for (const capability of ['report-configuration', 'task-management', 'task-calendar', 'task-attachments']) {
      requireCheck(value.capabilities?.includes(capability), `Deployed backend is missing ${capability} support.`);
    }
  }),
  ...['', '/assignees', '/' + 'b'.repeat(43)].map(suffix =>
    check('owner task route ' + (suffix || '/'), '/v1/companies/' + 'a'.repeat(43) + '/tasks' + suffix, {}, async response => {
      requireCheck(response.status === 401, 'Expected unauthenticated task route 401; received ' + response.status);
      const value = await json(response);
      requireCheck(value.error?.code === 'UNAUTHORIZED', 'Task endpoint is missing or returned an unexpected authentication response.');
      requireCheck(response.headers.get('cache-control')?.includes('no-store'), 'Task routes must disable caching.');
    })),
  ...['', '/assignees', '/' + 'b'.repeat(43)].map(suffix =>
    check('employee task route ' + (suffix || '/'), '/v1/employee/companies/' + 'a'.repeat(43) + '/tasks' + suffix, {}, async response => {
      requireCheck(response.status === 401, 'Expected unauthenticated employee task route 401; received ' + response.status);
      const value = await json(response);
      requireCheck(value.error?.code === 'EMPLOYEE_SESSION_INVALID', 'Employee task endpoint is missing or returned an unexpected authentication response.');
    })),
  check('employee invoice editor references', '/v1/employee/references/Customers?section=Invoices', {}, async response => {
    requireCheck(response.status === 401, 'Expected employee reference authentication boundary; received ' + response.status);
    const value = await json(response);
    requireCheck(value.error?.code === 'EMPLOYEE_SESSION_INVALID', 'Employee editor reference endpoint is unavailable.');
  }),
  check('owner authentication boundary', '/v1/me', { headers: { Origin: appOrigin } }, async response => {
    requireCheck(response.status === 401, `Expected unauthenticated 401; received ${response.status}.`);
    const value = await json(response);
    requireCheck(value.error?.code === 'UNAUTHORIZED', 'Unexpected owner authentication response.');
    requireCheck(response.headers.get('cache-control')?.includes('no-store'), 'Private routes must disable caching.');
    requireCheck(response.headers.get('access-control-allow-origin') === appOrigin, 'APP_ORIGIN/CORS mismatch.');
  }),
  check('report settings route', `/v1/companies/${'a'.repeat(43)}/reports/settings`, {}, async response => {
    requireCheck(response.status === 401, `Expected unauthenticated 401; received ${response.status}.`);
    const value = await json(response);
    requireCheck(value.error?.code === 'UNAUTHORIZED', 'Unexpected report settings authentication response.');
  }),
  check('report settings save preflight', `/v1/companies/${'a'.repeat(43)}/reports/settings`, { method: 'OPTIONS', headers: {
    Origin: appOrigin, 'Access-Control-Request-Method': 'PUT',
    'Access-Control-Request-Headers': 'content-type,x-tpc-csrf',
  } }, async response => {
    requireCheck(response.status >= 200 && response.status < 300, `HTTP ${response.status}`);
    requireCheck(response.headers.get('access-control-allow-origin') === appOrigin, 'Unexpected allowed origin.');
    requireCheck(response.headers.get('access-control-allow-methods')?.split(/,\s*/).includes('PUT'), 'PUT missing from allowed methods.');
  }),
  check('employee login preflight', '/v1/employee/login', { method: 'OPTIONS', headers: {
    Origin: appOrigin, 'Access-Control-Request-Method': 'POST',
    'Access-Control-Request-Headers': 'content-type,x-tpc-csrf',
  } }, async response => {
    requireCheck(response.status >= 200 && response.status < 300, `HTTP ${response.status}`);
    requireCheck(response.headers.get('access-control-allow-origin') === appOrigin, 'Unexpected allowed origin.');
    requireCheck(response.headers.get('access-control-allow-credentials') === 'true', 'Credential support missing.');
    requireCheck(response.headers.get('access-control-allow-methods')?.includes('POST'), 'POST missing from allowed methods.');
    const headers = response.headers.get('access-control-allow-headers')?.toLowerCase() || '';
    requireCheck(headers.includes('content-type') && headers.includes('x-tpc-csrf'), 'Required request headers missing.');
    requireCheck(headers.includes('x-tpc-company') && headers.includes('x-tpc-employee'), 'Employee workspace context headers missing.');
  }),
  check('employee renewal authentication boundary', '/v1/employee/refresh', { method: 'POST', headers: {
    Origin: appOrigin, 'Content-Type': 'application/json', 'X-TPC-CSRF': '1',
  }, body: '{}' }, async response => {
    requireCheck(response.status === 401, `Expected unauthenticated 401; received ${response.status}.`);
    const value = await json(response);
    requireCheck(value.error?.code === 'EMPLOYEE_SESSION_INVALID', 'Deployed backend is missing stable employee session renewal.');
    requireCheck(!response.headers.has('set-cookie'), 'Failed renewal must not overwrite the session cookie.');
  }),
]);
if (results.some(result => !result)) process.exitCode = 1;
else console.log('PUBLIC_ROUTING_CHECKS_PASSED — authenticated browser and tenant tests are still required.');
