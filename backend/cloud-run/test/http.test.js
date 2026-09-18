import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createApi } from '../src/http.js';
import { fixture } from './helpers.js';

async function running(t) {
  const f = fixture(), logs = [];
  const server = createApi(f.service, f.config, { log: value => logs.push(value) });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  t.after(() => new Promise(resolve => { server.closeAllConnections(); server.close(resolve); }));
  const base = `http://127.0.0.1:${server.address().port}`;
  return { ...f, logs, request: (path, options) => fetch(base + path, options) };
}
const headers = { Origin: 'https://app.test', 'Content-Type': 'application/json', 'X-TPC-CSRF': '1' };
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
test('CSRF and foreign-origin calls are rejected, trusted preflight works', async t => {
  const f = await running(t);
  for (const altered of [{}, { ...headers, Origin: 'https://evil.test' }, { Origin: headers.Origin, 'Content-Type': 'application/json' }]) {
    assert.equal((await f.request('/v1/auth/google/start', { method: 'POST', headers: altered, body: '{}' })).status, 403);
  }
  const preflight = await f.request('/v1/companies', { method: 'OPTIONS', headers: { Origin: headers.Origin } });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), headers.Origin);
  assert.equal(preflight.headers.get('access-control-allow-credentials'), 'true');
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
