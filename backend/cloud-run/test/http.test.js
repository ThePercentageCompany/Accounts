import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createApi } from '../src/http.js';
import { fixture } from './helpers.js';
import { ApiError } from '../src/errors.js';

async function running(t, options = {}) {
  const f = fixture(), logs = [];
  const server = createApi(f.service, f.config, { log: value => logs.push(value), ...options });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => new Promise(resolve => { server.closeAllConnections(); server.close(resolve); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  return { ...f, logs, request: (path, options) => fetch(base + path, options) };
}
const headers = { Origin: 'https://app.test', 'Content-Type': 'application/json', 'X-TPC-CSRF': '1' };

test('balance-sheet HTTP accepts exactly one asOf and uses private responses', async t => {
  let calls = 0;
  const f = await running(t, { business: { async balanceSheet(token, id, date) {
    calls++; assert.equal(date, '2026-09-27'); return { balanced: true };
  } } });
  const path = `/v1/companies/${'c'.repeat(43)}/reports/balance-sheet`;
  for (const query of ['', '?asOf=a&asOf=b', '?asOf=a&from=b']) assert.equal((await f.request(path + query)).status, 400);
  assert.equal(calls, 0);
  const response = await f.request(path + '?asOf=2026-09-27');
  assert.equal(response.status, 200); assert.equal(response.headers.get('cache-control'), 'no-store');
});

test('profit and loss HTTP requires a single start and end date and remains private', async t => {
  let calls = 0;
  const f = await running(t, { business: { async profitAndLoss(token, companyId, from, asOf) {
    calls++; assert.equal(from, '2026-09-01'); assert.equal(asOf, '2026-09-30'); return { netProfit: '0.00' };
  } } });
  const path = `/v1/companies/${'c'.repeat(43)}/reports/profit-and-loss`;
  for (const query of ['', '?asOf=2026-09-30', '?from=a&from=b&asOf=c', '?from=a&asOf=b&unexpected=c']) {
    assert.equal((await f.request(path + query)).status, 400);
  }
  assert.equal(calls, 0);
  const response = await f.request(path + '?from=2026-09-01&asOf=2026-09-30');
  assert.equal(response.status, 200); assert.equal(response.headers.get('cache-control'), 'no-store');
});

test('trial-balance HTTP route validates date query and disables caching', async t => {
  let calls = 0;
  const id = 'c'.repeat(43);
  const f = await running(t, { business: { async trialBalance(token, companyId, asOf) {
    calls++; assert.equal(companyId, id); assert.equal(asOf, '2026-09-27');
    return { accounts: [], totalDebit: '0.00', totalCredit: '0.00' };
  } } });
  const path = `/v1/companies/${id}/reports/trial-balance`;
  for (const query of ['', '?asOf=a&asOf=b', '?asOf=2026-09-27&other=x']) {
    assert.equal((await f.request(path + query)).status, 400);
  }
  assert.equal(calls, 0);
  const response = await f.request(path + '?asOf=2026-09-27');
  assert.equal(response.status, 200); assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(calls, 1);
});
test('public health uses /health and requires no session', async t => {
  const f = await running(t, { business: {} });
  const response = await f.request('/health');
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'ok', phase: 4,
    capabilities: ['complete-document-drafts', 'invoice-item-returns', 'report-configuration'] });
});

test('new reporting and document listing routes validate queries and preserve session routing', async t => {
  const calls = [];
  const f = await running(t, {
    business: { async report(...args) { calls.push(args); return {}; } },
    employees: { async report(...args) { calls.push(args); return {}; } },
    documents: { async list(...args) { calls.push(args); return []; } },
  });
  for (const path of [`/v1/companies/${'c'.repeat(43)}/reports/dashboard`, '/v1/employee/reports/general-ledger']) {
    assert.equal((await f.request(path + '?asOf=2026-09-30')).status, 400);
    const response = await f.request(path + '?from=2026-09-01&asOf=2026-09-30', { headers: { Cookie: '__Host-tpc_employee=employee-token' } });
    assert.equal(response.status, 200); assert.equal(response.headers.get('cache-control'), 'no-store');
  }
  assert.equal(calls[1][0], 'employee-token');
  const path = `/v1/employee/companies/${'c'.repeat(43)}/documents`;
  assert.equal((await f.request(path + '?section=Invoices')).status, 400);
  assert.equal((await f.request(path + `?section=Invoices&recordId=${'r'.repeat(43)}`, { headers: { Cookie: '__Host-tpc_employee=employee-token' } })).status, 200);
  assert.equal(calls[2][0], 'employee-token'); assert.equal(calls[2][4], true);
});
test('document HTTP routes authenticate uploads and deliver private bytes with no-store headers', async t => {
  const documentId = 'd'.repeat(43); let uploads = 0;
  const documents = {
    async upload(token, companyId, input, key) { uploads++; assert.equal(input.name, 'logo.png'); assert.equal(key, 'upload_logo_123456'); return { documentId }; },
    async download(token, companyId, id, employee) { assert.equal(id, documentId); assert.equal(employee, true); assert.equal(token, 'employee-token'); return { bytes: Buffer.from('image'), mimeType: 'image/png', name: "company's logo.png" }; },
  };
  const f = await running(t, { documents });
  const token = await f.login();
  const companyId = (await f.service.createCompany(token, { name: 'Documents' }, 'document_company_123')).company.companyId;
  const path = `/v1/companies/${companyId}/documents`;
  const denied = await f.request(path, { method: 'POST', headers, body: '{}' });
  assert.equal(denied.status, 401); assert.equal(uploads, 0);
  const uploaded = await f.request(path, { method: 'POST', headers: { ...headers, Cookie: `__Host-tpc_session=${token}`, 'Idempotency-Key': 'upload_logo_123456' }, body: '{"name":"logo.png"}' });
  assert.equal(uploaded.status, 201); assert.equal(uploads, 1);
  const response = await f.request(`/v1/employee/companies/${companyId}/documents/${documentId}`, { headers: { Cookie: '__Host-tpc_employee=employee-token' } });
  assert.equal(response.status, 200); assert.equal(await response.text(), 'image');
  assert.equal(response.headers.get('cache-control'), 'no-store');
  assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
  assert.match(response.headers.get('content-disposition'), /inline; filename\*=UTF-8''company%27s%20logo.png/);
});
test('HTTP Google callback creates secure cookie and no tokens in redirect/JSON', async t => {
  const f = await running(t);
  const start = await f.request('/v1/auth/google/start', { method: 'POST', headers, body: '{}' });
  assert.equal(start.status, 200);
  const bindingCookie = start.headers.get('set-cookie');
  assert.match(bindingCookie, /HttpOnly; Secure; SameSite=Lax/);
  const { authorizationUrl } = await start.json();
  const state = new URL(authorizationUrl).searchParams.get('state');
  const response = await f.request(`/v1/auth/google/callback?code=owner-a&state=${state}`, {
    headers: { Cookie: bindingCookie.split(';')[0] }, redirect: 'manual',
  });
  assert.equal(response.status, 303);
  assert.equal(response.headers.get('location'), 'https://app.test/');
  const sessionCookie = response.headers.getSetCookie()[0];
  assert.match(sessionCookie, /^__Host-tpc_session=/);
  assert.match(sessionCookie, /HttpOnly; Secure; SameSite=None/);
  const me = await f.request('/v1/me', { headers: { Cookie: sessionCookie.split(';')[0] } });
  assert.equal(me.status, 200);
  assert.equal((await me.json()).owner.email, 'owner-a@example.com');
  assert.equal(me.headers.get('cache-control'), 'no-store');
});

test('connection routes bind cookies, redirect safely, and retry through the service', async t => {
  const companyId = 'c'.repeat(43), token = 't'.repeat(43), binding = 'b'.repeat(43);
  const workspace = {
    startConnection: async (actual, id) => { assert.equal(actual, token); assert.equal(id, companyId); return { binding, authorizationUrl: 'https://accounts.google.com/consent' }; },
    finishConnection: async (...args) => { assert.deepEqual(args, [token, 'state', binding, 'code']); },
    retry: async (actual, id) => { assert.equal(actual, token); assert.equal(id, companyId); return { companyId, stage: 'GOOGLE_CONNECTED' }; },
  };
  const f = await running(t, { workspace });
  const authHeaders = { ...headers, Cookie: `__Host-tpc_session=${token}` };
  const start = await f.request(`/v1/companies/${companyId}/google/connect`, { method: 'POST', headers: authHeaders, body: '{}' });
  assert.equal(start.status, 200);
  assert.match(start.headers.get('set-cookie'), /__Host-tpc_connection=.*HttpOnly; Secure; SameSite=Lax/);
  const callback = await f.request('/v1/google/callback?state=state&code=code', { redirect: 'manual',
    headers: { Cookie: `__Host-tpc_session=${token}; __Host-tpc_connection=${binding}` } });
  assert.equal(callback.status, 303);
  assert.equal(callback.headers.get('location'), f.config.appOrigin + '/');
  const retry = await f.request(`/v1/companies/${companyId}/setup/retry`, { method: 'POST', headers: authHeaders, body: '{}' });
  assert.equal(retry.status, 202);
});
test('internal worker route requires service authentication and rejects extra authority fields', async t => {
  let executions = 0;
  const queue = { authorize: async header => { if (header !== 'Bearer verified-worker') throw new ApiError(401, 'WORKER_UNAUTHORIZED', 'Worker authentication required'); } };
  const f = await running(t, { queue, workspace: { work: async () => { executions++; } } });
  const companyId = 'c'.repeat(43);
  const call = (auth, input) => f.request('/internal/setup', { method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(auth ? { Authorization: auth } : {}) }, body: JSON.stringify(input) });
  assert.equal((await call(null, { companyId })).status, 401);
  assert.equal((await call('Bearer owner-token', { companyId })).status, 401);
  assert.equal((await call('Bearer verified-worker', { companyId, spreadsheetId: 'attacker' })).status, 400);
  assert.equal((await call('Bearer verified-worker', { companyId })).status, 204);
  assert.equal(executions, 1);
});

test('employee login sets a separate HttpOnly cookie without disclosing bearer tokens', async t => {
  const secretToken = 't'.repeat(43), now = Date.now();
  const employees = {
    now: () => now,
    login: async input => { assert.deepEqual(input, { inviteId: 'invite', privateCode: 'private' });
      return { token: secretToken, expiresAt: now + 3600000, employee: { employeeId: 'e', allowedSections: ['Dashboard'] } }; },
    refresh: async token => { assert.equal(token, secretToken); return { token: 'r'.repeat(43), expiresAt: now + 3600000, employee: { employeeId: 'e' } }; },
    logout: async token => { assert.equal(token, secretToken); },
  };
  const f = await running(t, { employees });
  const login = await f.request('/v1/employee/login', { method: 'POST', headers, body: JSON.stringify({ inviteId: 'invite', privateCode: 'private' }) });
  assert.equal(login.status, 200);
  assert.match(login.headers.get('set-cookie'), /^__Host-tpc_employee=.*HttpOnly; Secure; SameSite=None/);
  assert.ok(!(await login.text()).includes(secretToken));
  const employeeHeaders = { ...headers, Cookie: `__Host-tpc_employee=${secretToken}` };
  const refresh = await f.request('/v1/employee/refresh', { method: 'POST', headers: employeeHeaders, body: '{}' });
  assert.equal(refresh.status, 200);
  assert.ok(!(await refresh.text()).includes('r'.repeat(43)));
  const logout = await f.request('/v1/employee/logout', { method: 'POST', headers: employeeHeaders, body: '{}' });
  assert.equal(logout.status, 204); assert.match(logout.headers.get('set-cookie'), /Max-Age=0/);
});
test('CSRF and foreign-origin calls are rejected, trusted preflight works', async t => {
  const f = await running(t);
  for (const altered of [{}, { ...headers, Origin: 'https://evil.test' }, { Origin: headers.Origin, 'Content-Type': 'application/json' }]) {
    assert.equal((await f.request('/v1/auth/google/start', { method: 'POST', headers: altered, body: '{}' })).status, 403);
  }
  const preflight = await f.request('/v1/companies', { method: 'OPTIONS', headers: { Origin: headers.Origin } });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), headers.Origin);
  assert.equal(preflight.headers.get('access-control-allow-credentials'), 'true');
  assert.ok(preflight.headers.get('access-control-allow-methods').split(', ').includes('PUT'));
});
test('HTTP registration requires session, key, JSON and tenant membership', async t => {
  const f = await running(t), token = await f.login();
  const authHeaders = { ...headers, Cookie: `__Host-tpc_session=${token}`, 'Idempotency-Key': 'company_create_123456' };
  assert.equal((await f.request('/v1/companies')).status, 401);
  const response = await f.request('/v1/companies', { method: 'POST', headers: authHeaders, body: '{"name":"A"}' });
  assert.equal(response.status, 201);
  const { company } = await response.json();
  const repeat = await f.request('/v1/companies', { method: 'POST', headers: authHeaders, body: '{"name":"A"}' });
  assert.equal(repeat.status, 200);
  const other = await f.login('owner-b');
  assert.equal((await f.request(`/v1/companies/${company.companyId}/setup`, { headers: { Cookie: `__Host-tpc_session=${other}` } })).status, 404);
  assert.equal((await f.request('/v1/companies', { method: 'POST', headers: authHeaders, body: 'invalid' })).status, 400);
  assert.equal((await f.request('/v1/companies', { method: 'POST', headers: authHeaders, body: JSON.stringify({ name: 'x'.repeat(17000) }) })).status, 413);
});
test('internal errors never reveal secrets in response or application logs', async t => {
  const f = await running(t), token = await f.login();
  f.storage.read = async () => { throw new Error('secret-client-credential'); };
  const response = await f.request('/v1/me', { headers: { Cookie: `__Host-tpc_session=${token}` } });
  assert.equal(response.status, 503);
  const output = await response.text();
  assert.ok(!output.includes('secret-client-credential'));
  assert.ok(!JSON.stringify(f.logs).includes('secret-client-credential'));
  assert.ok(!JSON.stringify(f.logs).includes(token));
});

test('sync HTTP boundary enforces CSRF, bounded bodies and tombstone queries', async t => {
  const companyId = 'c'.repeat(43), token = 't'.repeat(43), calls = [];
  const business = {
    sync: async (...args) => { calls.push(args); return { results: [{ operationId: 'operation_1234567', status: 'NOT_ATTEMPTED' }] }; },
    list: async (...args) => { calls.push(args); return []; },
  };
  const f = await running(t, { business }), path = `/v1/companies/${companyId}`;
  const auth = { ...headers, Cookie: `__Host-tpc_session=${token}` };
  const response = await f.request(path + '/sync', { method: 'POST', headers: auth, body: '{"operations":[]}' });
  assert.equal(response.status, 200);
  assert.equal((await response.json()).results[0].status, 'NOT_ATTEMPTED');
  assert.deepEqual(calls.shift(), [token, companyId, { operations: [] }]);
  assert.equal((await f.request(path + '/sync', { method: 'POST', headers: { ...auth, 'X-TPC-CSRF': '' }, body: '{}' })).status, 403);
  assert.equal((await f.request(path + '/sync', { method: 'POST', headers: auth, body: JSON.stringify({ value: 'a'.repeat(17000) }) })).status, 413);
  assert.equal((await f.request(path + '/records/Customers?includeDeleted=true', { headers: auth })).status, 200);
  assert.deepEqual(calls.shift(), [token, companyId, 'Customers', { includeDeleted: true }]);
  assert.equal((await f.request(path + '/records/Customers?includeDeleted=yes', { headers: auth })).status, 400);
  assert.equal((await f.request(path + '/records/Customers?includeDeleted=true&includeDeleted=false', { headers: auth })).status, 400);
  const preflight = await f.request(path + '/records/Customers', { method: 'OPTIONS', headers: { Origin: headers.Origin } });
  assert.ok(preflight.headers.get('access-control-allow-methods').includes('DELETE'));
});

test('owner business record routes preserve authority and idempotency keys', async t => {
  const companyId = 'c'.repeat(43), recordId = 'r'.repeat(43), token = 't'.repeat(43), calls = [];
  const business = {
    list: async (...args) => { calls.push(['list', ...args]); return [{ recordId, name: 'A' }]; },
    mutate: async (...args) => { calls.push(['mutate', ...args]); return { recordId, version: 1, replayed: false }; },
  };
  const f = await running(t, { business });
  const auth = { ...headers, Cookie: `__Host-tpc_session=${token}`, 'Idempotency-Key': 'business_record_123' };
  const list = await f.request(`/v1/companies/${companyId}/records/Customers`, { headers: auth });
  assert.equal(list.status, 200); assert.equal((await list.json()).records[0].recordId, recordId);
  const create = await f.request(`/v1/companies/${companyId}/records/Customers`, { method: 'POST', headers: auth,
    body: JSON.stringify({ expectedVersion: 0, values: { name: 'A' } }) });
  assert.equal(create.status, 201);
  assert.deepEqual(calls, [['list', token, companyId, 'Customers'],
    ['mutate', token, companyId, 'Customers', null, 'create', { expectedVersion: 0, values: { name: 'A' } }, 'business_record_123']]);
});
