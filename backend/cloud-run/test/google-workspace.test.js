import test from 'node:test';
import assert from 'node:assert/strict';
import { GoogleWorkspace, FOLDER_MIME, SHEET_MIME } from '../src/google-workspace.js';
import { TABLES, seedRows } from '../src/company-schema.js';
import { GoogleConnection, DATA_SCOPES, ReconnectRequired } from '../src/google-connection.js';
import { SetupQueue } from '../src/setup-queue.js';

const response = (data, status = 200) => new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
const company = { id: 'company-id', name: '=Dangerous formula', createdAt: 100, resources: { spreadsheetId: 'private-sheet' } };
const owner = { id: 'owner', email: 'owner@example.com', name: 'Owner' };

test('schema initializes dedicated columns and RAW metadata without sample business records', async () => {
  const calls = [];
  const google = new GoogleWorkspace({ fetcher: async (url, options) => {
    calls.push({ url, ...options });
    if (url.includes('?fields=sheets.properties')) return response({ sheets: [{ properties: { title: 'Sheet1', sheetId: 0 } }] });
    if (url.includes('values:batchGet')) {
      const ranges = new URL(url).searchParams.getAll('ranges');
      return response({ valueRanges: ranges.map(() => ({})) });
    }
    return response({});
  } });
  await google.ensureSchema('token', company, owner);
  const sheets = calls.find(c => c.url.includes(':batchUpdate') && !c.url.includes('values:'));
  const requests = JSON.parse(sheets.body).requests;
  assert.equal(requests.length, TABLES.length);
  assert.ok(requests.every(r => r.addSheet));
  const writes = JSON.parse(calls.find(c => c.url.includes('values:batchUpdate')).body);
  assert.equal(writes.valueInputOption, 'RAW');
  assert.equal(writes.data.length, TABLES.length + 3);
  assert.equal(writes.data.find(d => d.range === "'CompanyProfile'!A2").values[0][10], '=Dangerous formula');
  assert.ok(!writes.data.some(d => d.range === "'Invoices'!A2"));
  assert.ok(!writes.data.some(d => d.range === "'EmployeeAccess'!A2"));
  assert.ok(!JSON.stringify(writes).includes('private-sheet'));
});
test('existing matching schema/identity records are not rewritten during recovery', async () => {
  let writes = 0;
  const google = new GoogleWorkspace({ fetcher: async (url, options) => {
    if (options.method !== 'GET') { writes++; return response({}); }
    if (url.includes('?fields=')) return response({ sheets: TABLES.map(t => ({ properties: t })) });
    const ranges = new URL(url).searchParams.getAll('ranges');
    return response({ valueRanges: ranges[0].endsWith('1:1') ? TABLES.map(t => ({ values: [t.headers] })) :
      seedRows(company, owner).map(seed => ({ values: [[...seed.values, 'preserved customer content']] })) });
  } });
  await google.ensureSchema('token', company, owner);
  assert.equal(writes, 0);
});
test('schema mismatch and incomplete reads fail closed', async () => {
  for (const incomplete of [true, false]) {
    let writes = 0;
    const google = new GoogleWorkspace({ fetcher: async (url, options) => {
      if (options.method !== 'GET') writes++;
      if (url.includes('?fields=')) return response({ sheets: TABLES.map(t => ({ properties: t })) });
      return response({ valueRanges: incomplete ? [] : TABLES.map(() => ({ values: [['wrong schema']] })) });
    } });
    await assert.rejects(google.ensureSchema('token', company, owner));
    assert.equal(writes, 0);
  }
});
test('schema verifier checks company identity and schema version', async () => {
  let wrongCompany = false;
  const google = new GoogleWorkspace({ fetcher: async url => {
    const ranges = new URL(url).searchParams.getAll('ranges');
    if (ranges[0].endsWith('1:1')) return response({ valueRanges: TABLES.map(t => ({ values: [t.headers] })) });
    return response({ valueRanges: seedRows(company, owner).map(s => {
      const values = s.values.slice(); if (wrongCompany) values[1] = 'other-company';
      return { values: [values] };
    }) });
  } });
  await google.verifySchema('token', company);
  wrongCompany = true;
  await assert.rejects(google.verifySchema('token', company), e => e.code === 'SCHEMA_MISMATCH');
});
test('folder retry uses saved ID and validates ownership, tenant tags and parent', async () => {
  let saved, createCount = 0;
  const spec = { id: 'fixed-folder', name: 'Invoices', companyId: 'a', operation: 'op', parent: 'root' };
  const google = new GoogleWorkspace({ fetcher: async (_url, options) => {
    if (options.method === 'POST') {
      createCount++; const input = JSON.parse(options.body);
      assert.equal(input.id, spec.id);
      saved = { ...input, ownedByMe: true };
      throw new Error('response lost');
    }
    return saved ? response(saved) : response({}, 404);
  } });
  await assert.rejects(google.ensureFolder('token', spec));
  assert.equal((await google.ensureFolder('token', spec)).id, spec.id);
  assert.equal(createCount, 1);
  saved.parents = ['another-root'];
  await assert.rejects(google.ensureFolder('token', spec), e => e.code === 'RESOURCE_MISMATCH');
});
test('spreadsheet search detects duplicate/tagged trashed resources and never treats them as absent', async () => {
  let files = [{ id: 'existing', trashed: true }];
  const google = new GoogleWorkspace({ fetcher: async () => response({ files }) });
  assert.equal((await google.findSpreadsheet('token', 'a', 'op')).id, 'existing');
  files = [{ id: 'one' }, { id: 'two' }];
  await assert.rejects(google.findSpreadsheet('token', 'a', 'op'), e => e.code === 'RESOURCE_AMBIGUOUS');
});
test('HTTP authorization failures request reconnect; quota does not erase authorization', async () => {
  const unauthorized = new GoogleWorkspace({ fetcher: async () => response({}, 401) });
  await assert.rejects(unauthorized.generateFolderIds('token', 1), e => e instanceof ReconnectRequired && e.definitelyRejected);
  const quota = new GoogleWorkspace({ fetcher: async () => response({}, 403) });
  await assert.rejects(quota.generateFolderIds('token', 1), e => e.googleStatus === 403 && !(e instanceof ReconnectRequired));
  const scopes = new GoogleWorkspace({ fetcher: async () => response({ error: { details: [{ reason: 'ACCESS_TOKEN_SCOPE_INSUFFICIENT' }] } }, 403) });
  await assert.rejects(scopes.generateFolderIds('token', 1), e => e instanceof ReconnectRequired);
});
test('offline consent is separate from identity and requires all scopes, matching sub and refresh token', async () => {
  const connection = new GoogleConnection({ clientId: 'client', apiOrigin: 'https://api.test' }, 'private-secret');
  const url = new URL(connection.authorizationUrl({ state: 'state', nonce: 'nonce', challenge: 'pkce', email: 'owner@example.com' }));
  assert.equal(url.searchParams.get('access_type'), 'offline');
  assert.ok(url.searchParams.get('prompt').includes('consent'));
  assert.equal(url.searchParams.get('redirect_uri'), 'https://api.test/v1/google/callback');
  assert.ok(DATA_SCOPES.every(s => url.searchParams.get('scope').includes(s)));
  let claims = { sub: 'owner-sub', nonce: 'nonce', email_verified: true, iss: 'https://accounts.google.com' };
  let tokens = { id_token: 'signed-token', scope: DATA_SCOPES.join(' '), refresh_token: 'refresh' };
  connection.client = () => ({ getToken: async () => ({ tokens }), verifyIdToken: async () => ({ getPayload: () => claims }) });
  const tx = { googleSub: 'owner-sub', nonce: 'nonce', verifier: 'verifier' };
  assert.equal((await connection.exchange('code', tx)).refreshToken, 'refresh');
  claims = { ...claims, sub: 'attacker' };
  await assert.rejects(connection.exchange('code', tx), e => e.code === 'GOOGLE_ACCOUNT_MISMATCH');
  claims.sub = 'owner-sub'; tokens.scope = DATA_SCOPES[0];
  await assert.rejects(connection.exchange('code', tx), e => e.code === 'GOOGLE_SCOPES_REQUIRED');
  tokens.scope = DATA_SCOPES.join(' '); delete tokens.refresh_token;
  await assert.rejects(connection.exchange('code', tx), e => e.code === 'OFFLINE_ACCESS_REQUIRED');
});
test('invalid_grant marks reconnect, transient refresh errors remain retryable', async () => {
  const connection = new GoogleConnection({}, 'secret');
  connection.client = () => ({ setCredentials() {}, getAccessToken: async () => { throw { response: { data: { error: 'invalid_grant' } } }; } });
  await assert.rejects(connection.accessToken('refresh'), e => e instanceof ReconnectRequired);
  connection.client = () => ({ setCredentials() {}, getAccessToken: async () => { throw new Error('network'); } });
  await assert.rejects(connection.accessToken('refresh'), e => e.code === 'GOOGLE_UNAVAILABLE');
});
test('task queue uses deterministic names and authenticated opaque-ID-only deliveries', async () => {
  const sent = [];
  const config = { taskQueue: 'projects/p/locations/l/queues/q', workerOrigin: 'https://worker.run.app', workerEmail: 'worker@project.iam.gserviceaccount.com' };
  const queue = new SetupQueue({ createTask: async task => sent.push(task) }, {}, config);
  await queue.enqueue('company', 3); await queue.enqueue('company', 3);
  assert.equal(sent[0].task.name, sent[1].task.name);
  assert.equal(sent[0].task.httpRequest.oidcToken.audience, config.workerOrigin);
  assert.equal(sent[0].task.httpRequest.url, `${config.workerOrigin}/internal/setup`);
  assert.deepEqual(JSON.parse(Buffer.from(sent[0].task.httpRequest.body, 'base64')), { companyId: 'company' });
  const already = new SetupQueue({ createTask: async () => { throw { code: 6 }; } }, {}, config);
  await already.enqueue('company', 3);
  const failed = new SetupQueue({ createTask: async () => { throw { code: 7 }; } }, {}, config);
  await assert.rejects(failed.enqueue('company', 3), e => e.code === 'SETUP_QUEUE_UNAVAILABLE');
});
test('worker authorization requires verified Google token with configured audience and service account', async () => {
  const config = { workerOrigin: 'https://worker.run.app', workerEmail: 'worker@project.iam.gserviceaccount.com' };
  let email = config.workerEmail;
  const identity = { verifyIdToken: async options => {
    assert.equal(options.audience, config.workerOrigin);
    return { getPayload: () => ({ email, email_verified: true, iss: 'https://accounts.google.com' }) };
  } };
  const queue = new SetupQueue({}, identity, config);
  await queue.authorize('Bearer signed-token');
  await assert.rejects(queue.authorize(undefined), e => e.code === 'WORKER_UNAUTHORIZED');
  email = 'customer@example.com';
  await assert.rejects(queue.authorize('Bearer signed-token'), e => e.code === 'WORKER_UNAUTHORIZED');
});
