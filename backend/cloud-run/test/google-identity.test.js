import test from 'node:test';
import assert from 'node:assert/strict';
import { GoogleIdentity } from '../src/google-identity.js';

const config = { apiOrigin: 'https://api.test', clientId: 'expected-client' };
const claims = { sub: '123', email: 'owner@example.com', email_verified: true,
  iss: 'https://accounts.google.com', nonce: 'expected-nonce', name: 'Owner' };

test('Google sign-in requests identity only with state, nonce and PKCE', () => {
  const identity = new GoogleIdentity(config, 'test-only-secret');
  const url = new URL(identity.authorizationUrl({ state: 'state', nonce: 'nonce', challenge: 'challenge' }));
  assert.equal(url.origin, 'https://accounts.google.com');
  assert.deepEqual(url.searchParams.get('scope').split(' '), ['openid', 'email', 'profile']);
  assert.equal(url.searchParams.get('access_type'), 'online');
  assert.equal(url.searchParams.get('state'), 'state');
  assert.equal(url.searchParams.get('nonce'), 'nonce');
  assert.equal(url.searchParams.get('code_challenge_method'), 'S256');
  assert.equal(url.searchParams.get('code_challenge'), 'challenge');
  assert.equal(url.searchParams.get('redirect_uri'), 'https://api.test/v1/auth/google/callback');
  assert.ok(!url.toString().includes('test-only-secret'));
});
test('exchange passes verifier and requires Google signature/audience validation', async () => {
  const identity = new GoogleIdentity(config, 'test-only-secret');
  identity.client = {
    getToken: async options => {
      assert.deepEqual(options, { code: 'auth-code', codeVerifier: 'verifier' });
      return { tokens: { id_token: 'signed-id-token', access_token: 'discard', refresh_token: 'discard' } };
    },
    verifyIdToken: async options => {
      assert.deepEqual(options, { idToken: 'signed-id-token', audience: config.clientId });
      return { getPayload: () => claims };
    },
  };
  const result = await identity.exchange('auth-code', { verifier: 'verifier', nonce: claims.nonce });
  assert.deepEqual(result, { sub: '123', email: 'owner@example.com', name: 'Owner' });
});
test('identity validation fails closed for invalid claims or verification failure', async () => {
  for (const invalid of [undefined, { ...claims, nonce: 'wrong' }, { ...claims, email_verified: false },
    { ...claims, iss: 'https://attacker.test' }, { ...claims, sub: '' }]) {
    const identity = new GoogleIdentity(config, 'secret');
    identity.client = { getToken: async () => ({ tokens: { id_token: 'token' } }),
      verifyIdToken: async () => ({ getPayload: () => invalid }) };
    await assert.rejects(identity.exchange('code', { nonce: claims.nonce }), error => error.code === 'GOOGLE_IDENTITY_INVALID');
  }
  const identity = new GoogleIdentity(config, 'secret');
  identity.client = { getToken: async () => ({ tokens: { id_token: 'forged' } }),
    verifyIdToken: async () => { throw new Error('bad signature or expired token'); } };
  await assert.rejects(identity.exchange('code', {}), error => error.code === 'GOOGLE_SIGN_IN_FAILED');
});
