import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from './helpers.js';
import { digest } from '../src/crypto.js';
const key = 'registration_key_1234';
const code = expected => error => error.code === expected;

test('parallel repeated registration commits one company and membership', async () => {
  const f = fixture(), token = await f.login();
  const results = await Promise.all(Array.from({ length: 8 }, () => f.service.createCompany(token, { name: 'Company A' }, key)));
  assert.equal(new Set(results.map(r => r.company.companyId)).size, 1);
  assert.equal(results.filter(r => !r.replayed).length, 1);
  assert.equal(Object.keys(f.storage.state.companies).length, 1);
  assert.equal(Object.keys(f.storage.state.memberships).length, 1);
  assert.equal(results[0].company.stage, 'GOOGLE_CONNECTION_REQUIRED');
  assert.equal(results[0].company.employeeInvitationsEnabled, false);
});
test('idempotency is scoped to owner and rejects changed input', async () => {
  const f = fixture(), a = await f.login(), b = await f.login('owner-b');
  const first = await f.service.createCompany(a, { name: 'A' }, key);
  await assert.rejects(f.service.createCompany(a, { name: 'Changed' }, key), code('IDEMPOTENCY_CONFLICT'));
  const second = await f.service.createCompany(b, { name: 'B' }, key);
  assert.notEqual(first.company.companyId, second.company.companyId);
});
test('owner B cannot obtain owner A company by changing IDs', async () => {
  const f = fixture(), a = await f.login(), b = await f.login('owner-b');
  const { company } = await f.service.createCompany(a, { name: 'Private' }, key);
  await assert.rejects(f.service.companyStatus(b, company.companyId), code('COMPANY_NOT_FOUND'));
  assert.deepEqual(await f.service.listCompanies(b), []);
  assert.equal((await f.service.listCompanies(a)).length, 1);
});
test('unknown authority fields and invalid keys are rejected', async () => {
  const f = fixture(), token = await f.login();
  for (const field of ['companyId', 'spreadsheetId', 'driveFolderId', 'role', 'ownerId', 'allowedSections']) {
    await assert.rejects(f.service.createCompany(token, { name: 'A', [field]: 'attacker' }, key), code('INVALID_COMPANY'));
  }
  await assert.rejects(f.service.createCompany(token, { name: 'A' }, 'short'), code('IDEMPOTENCY_KEY_REQUIRED'));
  await assert.rejects(f.service.createCompany(token, { name: '' }, key), code('INVALID_COMPANY'));
});
test('company responses never disclose internal Google IDs or tokens', async () => {
  const f = fixture(), token = await f.login();
  const { company } = await f.service.createCompany(token, { name: 'A' }, key);
  Object.assign(f.storage.state.companies[company.companyId], { spreadsheetId: 'hidden-sheet', driveFolderId: 'hidden-folder', refreshToken: 'hidden-token' });
  const result = JSON.stringify([await f.service.listCompanies(token), await f.service.companyStatus(token, company.companyId), await f.service.createCompany(token, { name: 'A' }, key)]);
  assert.ok(!result.includes('hidden-'));
});
test('sessions expire, logout revokes one, revoke-all invalidates existing sessions', async () => {
  const f = fixture(), one = await f.login(), two = await f.login();
  assert.ok(!JSON.stringify(f.storage.state).includes(one));
  await f.service.logout(one);
  await assert.rejects(f.service.me(one), code('UNAUTHORIZED'));
  await f.service.me(two);
  const three = await f.login();
  await f.service.logout(two, true);
  await assert.rejects(f.service.me(three), code('UNAUTHORIZED'));
  const four = await f.login();
  f.advance(f.config.sessionMs + 1);
  await assert.rejects(f.service.me(four), code('UNAUTHORIZED'));
});
test('membership removal and disabled owner apply on the next request', async () => {
  const f = fixture(), token = await f.login();
  const { company } = await f.service.createCompany(token, { name: 'A' }, key);
  Object.values(f.storage.state.memberships)[0].status = 'DISABLED';
  await assert.rejects(f.service.companyStatus(token, company.companyId), code('COMPANY_NOT_FOUND'));
  Object.values(f.storage.state.owners)[0].status = 'DISABLED';
  await assert.rejects(f.service.me(token), code('UNAUTHORIZED'));
});
test('OAuth state binds to browser, expires, and is consumed once', async () => {
  const f = fixture();
  const start = await f.service.startSignIn();
  const state = new URL(start.authorizationUrl).searchParams.get('state');
  await assert.rejects(f.service.finishSignIn(state, 'a'.repeat(43), 'owner'), code('OAUTH_STATE_INVALID'));
  await f.service.finishSignIn(state, start.binding, 'owner');
  await assert.rejects(f.service.finishSignIn(state, start.binding, 'owner'), code('OAUTH_STATE_INVALID'));
  const expired = await f.service.startSignIn();
  f.advance(f.config.oauthMs + 1);
  await assert.rejects(f.service.finishSignIn(new URL(expired.authorizationUrl).searchParams.get('state'), expired.binding, 'owner'), code('OAUTH_STATE_INVALID'));
});
test('Google stable subject preserves owner/company through email change', async () => {
  const f = fixture(), token = await f.login();
  const original = await f.service.createCompany(token, { name: 'A' }, key);
  f.identity.exchange = async () => ({ sub: 'owner-a', email: 'changed@example.com', name: 'Changed' });
  const next = await f.login();
  assert.equal((await f.service.me(next)).email, 'changed@example.com');
  assert.equal((await f.service.listCompanies(next))[0].companyId, original.company.companyId);
});
test('lost response after successful registration can be retried without duplication', async () => {
  const f = fixture(), token = await f.login();
  const write = f.storage.compareAndSwap.bind(f.storage);
  let fail = true;
  f.storage.compareAndSwap = async (...args) => {
    const saved = await write(...args);
    if (saved && fail) { fail = false; throw new Error('response lost'); }
    return saved;
  };
  await assert.rejects(f.service.createCompany(token, { name: 'A' }, key));
  assert.equal((await f.service.createCompany(token, { name: 'A' }, key)).replayed, true);
  assert.equal(Object.keys(f.storage.state.companies).length, 1);
});
test('storage outage does not become empty company list or successful mutation', async () => {
  const f = fixture(), token = await f.login();
  f.storage.read = async () => { throw new Error('unavailable'); };
  await assert.rejects(f.service.listCompanies(token));
  await assert.rejects(f.service.createCompany(token, { name: 'A' }, key));
});
test('new sign-in rotates prior session and never stores bearer tokens', async () => {
  const f = fixture(), token = await f.login();
  const start = await f.service.startSignIn();
  const state = new URL(start.authorizationUrl).searchParams.get('state');
  const next = await f.service.finishSignIn(state, start.binding, 'owner-a', token);
  await assert.rejects(f.service.me(token), code('UNAUTHORIZED'));
  assert.ok(f.storage.state.sessions[digest(next.token)]);
  assert.ok(!JSON.stringify(f.storage.state.sessions).includes(next.token));
});
