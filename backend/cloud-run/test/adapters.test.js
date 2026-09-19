import test from 'node:test';
import assert from 'node:assert/strict';
import { GoogleControlStorage } from '../src/google-storage.js';
import { loadConfig } from '../src/config.js';
import { RefreshTokenVault } from '../src/crypto.js';
import { crc32c, readOAuthSecret } from '../src/integrity.js';

test('storage pins generation and writes with compare-and-swap precondition', async () => {
  const calls = [];
  const storage = { bucket: () => ({ file: (name, options) => {
    calls.push({ name, options });
    return {
      getMetadata: async () => [{ generation: '9007199254740993' }],
      download: async () => [Buffer.from('{"schemaVersion":1}')],
      save: async (bytes, options) => calls.push({ bytes, options }),
    };
  } }) };
  const adapter = new GoogleControlStorage(storage, 'private', 'control.json');
  const read = await adapter.read();
  assert.equal(calls[1].options.generation, '9007199254740993');
  await adapter.compareAndSwap(read.generation, read.state);
  assert.equal(calls.at(-1).options.preconditionOpts.ifGenerationMatch, '9007199254740993');
});
test('only missing registry creates empty state; forbidden read fails closed', async () => {
  for (const status of [404, 403, 503]) {
    const adapter = new GoogleControlStorage({ bucket: () => ({ file: () => ({ getMetadata: async () => { throw { code: status }; } }) }) }, 'private', 'registry');
    if (status === 404) assert.equal((await adapter.read()).generation, 0);
    else await assert.rejects(adapter.read());
  }
});
test('only precondition failure triggers CAS retry', async () => {
  for (const status of [412, 403, 503]) {
    const adapter = new GoogleControlStorage({ bucket: () => ({ file: () => ({ save: async () => { throw { code: status }; } }) }) }, 'private', 'registry');
    if (status === 412) assert.equal(await adapter.compareAndSwap(1, {}), false);
    else await assert.rejects(adapter.compareAndSwap(1, {}));
  }
});
test('configuration rejects blanks, insecure origins and URL paths', () => {
  const valid = {
    APP_ORIGIN: 'https://app.test', API_ORIGIN: 'https://api.test', GOOGLE_OAUTH_CLIENT_ID: 'google-client',
    GOOGLE_OAUTH_SECRET_VERSION: 'projects/p/secrets/oauth/versions/1', CONTROL_BUCKET: 'private',
    GOOGLE_REFRESH_KMS_KEY: 'projects/p/locations/l/keyRings/r/cryptoKeys/k',
    SETUP_TASK_QUEUE: 'projects/p/locations/l/queues/setup', SETUP_WORKER_EMAIL: 'setup@project.iam.gserviceaccount.com',
    SETUP_WORKER_ORIGIN: 'https://worker.run.app',
  };
  assert.equal(loadConfig(valid).appOrigin, valid.APP_ORIGIN);
  assert.throws(() => loadConfig({}));
  for (const value of ['http://app.test', 'https://app.test/path', 'https://user:pass@app.test', 'https://app.test/']) {
    assert.throws(() => loadConfig({ ...valid, APP_ORIGIN: value }));
  }
});
test('refresh-token encryption is bound to owner and company', async () => {
  let aad;
  const kms = {
    encrypt: async args => { aad = args.additionalAuthenticatedData; return [{ ciphertext: Buffer.from('encrypted'),
      ciphertextCrc32c: { value: crc32c(Buffer.from('encrypted')) }, verifiedPlaintextCrc32c: true, verifiedAdditionalAuthenticatedDataCrc32c: true }]; },
    decrypt: async args => { assert.deepEqual(args.additionalAuthenticatedData, aad); return [{ plaintext: Buffer.from('private-refresh'),
      plaintextCrc32c: { value: crc32c(Buffer.from('private-refresh')) } }]; },
  };
  const vault = new RefreshTokenVault(kms, 'kms-key');
  const cipher = await vault.encrypt('private-refresh', 'owner', 'company-a');
  assert.ok(!cipher.includes('private-refresh'));
  assert.equal(await vault.decrypt(cipher, 'owner', 'company-a'), 'private-refresh');
  await assert.rejects(vault.decrypt(cipher, 'owner', 'company-b'));
});

test('Secret Manager validates integrity and CRC matches the standard test vector', async () => {
  assert.equal(crc32c(Buffer.from('123456789')), 0xe3069283);
  const bytes = Buffer.from('{"clientSecret":"operator-private"}');
  const client = { accessSecretVersion: async () => [{ payload: { data: bytes, dataCrc32c: crc32c(bytes) } }] };
  assert.equal(await readOAuthSecret(client, 'secret/version'), 'operator-private');
  client.accessSecretVersion = async () => [{ payload: { data: bytes, dataCrc32c: 0 } }];
  await assert.rejects(readOAuthSecret(client, 'secret/version'));
});

test('KMS corrupted responses fail closed', async () => {
  const vault = new RefreshTokenVault({
    encrypt: async () => [{ ciphertext: Buffer.from('ciphertext'), ciphertextCrc32c: { value: 0 },
      verifiedPlaintextCrc32c: true, verifiedAdditionalAuthenticatedDataCrc32c: true }],
    decrypt: async () => [{ plaintext: Buffer.from('refresh'), plaintextCrc32c: { value: 0 } }],
  }, 'kms-key');
  await assert.rejects(vault.encrypt('refresh', 'owner', 'company'));
  await assert.rejects(vault.decrypt('Y2lwaGVydGV4dA==', 'owner', 'company'));
});
