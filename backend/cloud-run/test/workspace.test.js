import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from './helpers.js';
import { WorkspaceService } from '../src/workspace-service.js';
import { GoogleWorkspace, FOLDER_MIME } from '../src/google-workspace.js';
import { ReconnectRequired } from '../src/google-connection.js';
import { FOLDERS, TABLES } from '../src/company-schema.js';

async function setupFixture() {
  const f = fixture(), token = await f.login();
  const { company } = await f.service.createCompany(token, { name: 'Real Customer' }, 'setup_company_123456');
  const id = company.companyId, files = new Map(), counts = { folder: 0, spreadsheet: 0, schema: 0, verify: 0 };
  const queue = { tasks: [], enqueue: async (...args) => { queue.tasks.push(args); } };
  const connection = {
    authorizationUrl: ({ state }) => `https://accounts.google.com/consent?state=${state}`,
    exchange: async (_code, tx) => ({ sub: tx.googleSub, refreshToken: 'private-refresh-token', scopes: ['drive.file', 'spreadsheets'] }),
    accessToken: async () => 'google-access-token',
  };
  const vault = {
    encrypt: async (value, owner, company) => { assert.equal(value, 'private-refresh-token'); return `ciphertext:${owner}:${company}`; },
    decrypt: async () => 'private-refresh-token',
  };
  const google = {
    generateFolderIds: async (_token, count) => Array.from({ length: count }, (_, i) => `folder-${i}`),
    file: async (_token, id) => structuredClone(files.get(id) || null),
    validateFile: GoogleWorkspace.prototype.validateFile,
    ensureFolder: async (_token, spec) => {
      if (!files.has(spec.id)) {
        counts.folder++;
        files.set(spec.id, { id: spec.id, name: spec.name, ownedByMe: true, mimeType: FOLDER_MIME,
          appProperties: { tpcCompany: spec.companyId, tpcOperation: spec.operation }, parents: spec.parent ? [spec.parent] : [] });
      }
      return files.get(spec.id);
    },
    findSpreadsheet: async (_token, companyId, operation) => [...files.values()].find(f => f.appProperties.tpcCompany === companyId && f.appProperties.tpcOperation === operation) || null,
    createFile: async (_token, spec) => {
      counts.spreadsheet++;
      const file = { id: `sheet-${counts.spreadsheet}`, ownedByMe: true, mimeType: spec.mimeType,
        parents: [spec.parent], appProperties: { tpcCompany: spec.companyId, tpcOperation: spec.operation } };
      files.set(file.id, file); return file;
    },
    ensureSchema: async () => { counts.schema++; },
    verifySchema: async () => { counts.verify++; },
  };
  const workspace = new WorkspaceService({ accounts: f.service, connection, vault, google, queue,
    now: () => f.service.now() });
  async function connect() {
    const start = await workspace.startConnection(token, id);
    const state = new URL(start.authorizationUrl).searchParams.get('state');
    await workspace.finishConnection(token, state, start.binding, 'auth-code');
  }
  async function drain() {
    for (let i = 0; i < 60 && f.storage.state.companies[id].stage !== 'READY'; i++) await workspace.work(id);
    assert.equal(f.storage.state.companies[id].stage, 'READY');
  }
  return { ...f, token, id, files, counts, queue, connection, vault, google, workspace, connect, drain,
    current: () => f.storage.state.companies[id] };
}

test('offline connection persists only ciphertext, queues setup and reaches READY with exact folder structure', async () => {
  const f = await setupFixture();
  await f.connect();
  assert.ok(!JSON.stringify(f.storage.state).includes('private-refresh-token'));
  assert.equal(f.queue.tasks.length, 1);
  await f.drain();
  assert.equal(f.counts.folder, FOLDERS.length + 1);
  assert.equal(f.counts.spreadsheet, 1);
  assert.deepEqual(Object.keys(f.current().resources.folders), FOLDERS);
  assert.equal(f.current().schemaVersion, 1);
  assert.ok(TABLES.some(t => t.title === 'InvoiceItems'));
  assert.ok(TABLES.some(t => t.title === 'ReceiptAllocations'));
  assert.ok(TABLES.every(t => t.headers.includes('recordVersion') && t.headers.includes('companyId')));
  const status = await f.service.companyStatus(f.token, f.id);
  assert.equal(status.employeeInvitationsEnabled, true);
  assert.ok(!JSON.stringify(status).includes('ciphertext'));
  assert.ok(!JSON.stringify(status).includes('sheet-1'));
});
test('durable setup continues while owner is signed out', async () => {
  const f = await setupFixture(); await f.connect();
  await f.service.logout(f.token);
  await f.drain();
  assert.equal(f.current().stage, 'READY');
});
test('unrelated owner cannot connect or retry another company', async () => {
  const f = await setupFixture(), other = await f.login('other-owner');
  await assert.rejects(f.workspace.startConnection(other, f.id), e => e.code === 'COMPANY_NOT_FOUND');
  await assert.rejects(f.workspace.retry(other, f.id), e => e.code === 'COMPANY_NOT_FOUND');
  assert.equal(f.queue.tasks.length, 0);
});
test('connection callback is session-bound, single-use and rejects superseded attempts', async () => {
  const f = await setupFixture();
  const old = await f.workspace.startConnection(f.token, f.id);
  const newer = await f.workspace.startConnection(f.token, f.id);
  const oldState = new URL(old.authorizationUrl).searchParams.get('state');
  const newState = new URL(newer.authorizationUrl).searchParams.get('state');
  await assert.rejects(f.workspace.finishConnection(f.token, oldState, old.binding, 'code'), e => e.code === 'CONNECTION_SUPERSEDED');
  const other = await f.login();
  await assert.rejects(f.workspace.finishConnection(other, newState, newer.binding, 'code'), e => e.code === 'OAUTH_STATE_INVALID');
  await f.workspace.finishConnection(f.token, newState, newer.binding, 'code');
  await assert.rejects(f.workspace.finishConnection(f.token, newState, newer.binding, 'code'), e => e.code === 'OAUTH_STATE_INVALID');
});
test('connection OAuth state cannot be used for owner sign-in', async () => {
  const f = await setupFixture(), start = await f.workspace.startConnection(f.token, f.id);
  await assert.rejects(f.service.finishSignIn(new URL(start.authorizationUrl).searchParams.get('state'), start.binding, 'code'),
    e => e.code === 'OAUTH_STATE_INVALID');
});
test('queue outage after connection can be retried without losing the saved grant', async () => {
  const f = await setupFixture(), enqueue = f.queue.enqueue;
  f.queue.enqueue = async () => { throw new Error('queue down'); };
  await assert.rejects(f.connect());
  assert.ok(f.current().connection.ciphertext);
  f.queue.enqueue = enqueue;
  await f.workspace.retry(f.token, f.id);
  await f.drain();
});
test('lost spreadsheet creation response is reconciled without a second create', async () => {
  const f = await setupFixture(); await f.connect();
  const create = f.google.createFile;
  let lost = true;
  f.google.createFile = async (...args) => {
    const result = await create(...args);
    if (lost) { lost = false; throw new Error('response lost'); }
    return result;
  };
  for (let i = 0; i < 1 + 1 + FOLDERS.length; i++) await f.workspace.work(f.id);
  await assert.rejects(f.workspace.work(f.id));
  assert.equal(f.current().stage, 'RECOVERABLE_FAILURE');
  assert.equal(f.counts.spreadsheet, 1);
  await f.drain();
  assert.equal(f.counts.spreadsheet, 1);
});
test('uncertain create never retries a non-idempotent spreadsheet POST blindly', async () => {
  const f = await setupFixture(); await f.connect();
  let attempts = 0;
  f.google.createFile = async () => { attempts++; throw new Error('request outcome unknown'); };
  for (let i = 0; i < 2 + FOLDERS.length; i++) await f.workspace.work(f.id);
  await assert.rejects(f.workspace.work(f.id));
  await assert.rejects(f.workspace.work(f.id), e => e.code === 'RESOURCE_CONFIRMATION_PENDING');
  assert.equal(attempts, 1);
});
test('explicit rejected spreadsheet create can retry the same operation safely', async () => {
  const f = await setupFixture(); await f.connect();
  const create = f.google.createFile;
  let rejected = true;
  f.google.createFile = async (...args) => {
    if (rejected) { rejected = false; throw Object.assign(new Error('quota'), { googleStatus: 429 }); }
    return create(...args);
  };
  for (let i = 0; i < 2 + FOLDERS.length; i++) await f.workspace.work(f.id);
  await assert.rejects(f.workspace.work(f.id));
  assert.equal(f.current().spreadsheetSubmitted, false);
  await f.drain(); assert.equal(f.counts.spreadsheet, 1);
});
test('reconnect preserves partial workspace IDs and completes without duplicate resources', async () => {
  const f = await setupFixture(); await f.connect();
  for (let i = 0; i < 5; i++) await f.workspace.work(f.id);
  const before = structuredClone(f.current().resources), folderCount = f.counts.folder;
  f.connection.accessToken = async () => { throw new ReconnectRequired(); };
  await f.workspace.work(f.id);
  assert.equal(f.current().stage, 'RECONNECT_REQUIRED');
  assert.deepEqual(f.current().resources, before);
  assert.equal((await f.service.companyStatus(f.token, f.id)).nextAction, 'RECONNECT_GOOGLE');
  await assert.rejects(f.workspace.retry(f.token, f.id), e => e.code === 'RECONNECT_REQUIRED');
  f.connection.accessToken = async () => 'new-token';
  await f.connect(); await f.drain();
  assert.equal(f.current().resources.rootFolderId, before.rootFolderId);
  assert.equal(f.counts.folder, FOLDERS.length + 1);
  assert.ok(folderCount > 0);
});
test('reconnecting an established workspace verifies rather than recreates or reseeds', async () => {
  const f = await setupFixture(); await f.connect(); await f.drain();
  const resources = structuredClone(f.current().resources), counts = { ...f.counts };
  await f.connect(); await f.drain();
  assert.deepEqual(f.current().resources, resources);
  assert.equal(f.counts.folder, counts.folder);
  assert.equal(f.counts.spreadsheet, counts.spreadsheet);
  assert.equal(f.counts.schema, counts.schema);
  assert.equal(f.counts.verify, counts.verify + 1);
});
test('missing existing resources fail closed on reconnect without replacement', async () => {
  const f = await setupFixture(); await f.connect(); await f.drain();
  f.files.delete(f.current().resources.rootFolderId);
  await f.connect();
  await assert.rejects(f.workspace.work(f.id), e => e.code === 'RESOURCE_MISMATCH');
  assert.equal(f.current().stage, 'RECOVERABLE_FAILURE');
  assert.equal(f.counts.folder, FOLDERS.length + 1);
});
test('parallel setup workers are fenced and repeated READY dispatches do nothing', async () => {
  const f = await setupFixture(); await f.connect();
  let release;
  const generated = f.google.generateFolderIds;
  f.google.generateFolderIds = async (...args) => { await new Promise(resolve => { release = resolve; }); return generated(...args); };
  const one = f.workspace.work(f.id);
  while (!release) await new Promise(resolve => setImmediate(resolve));
  await assert.rejects(f.workspace.work(f.id), e => e.code === 'SETUP_BUSY');
  release(); await one; await f.drain();
  const before = { ...f.counts };
  await Promise.all([f.workspace.work(f.id), f.workspace.work(f.id)]);
  assert.deepEqual(f.counts, before);
});
test('expired worker cannot overwrite a newer worker checkpoint', async () => {
  const f = await setupFixture(); await f.connect();
  let release;
  f.google.generateFolderIds = async () => new Promise(resolve => { release = resolve; });
  const first = f.workspace.work(f.id);
  while (!release) await new Promise(resolve => setImmediate(resolve));
  f.advance(151000);
  f.google.generateFolderIds = async (_t, count) => Array.from({ length: count }, (_, i) => `new-${i}`);
  await f.workspace.work(f.id);
  release(Array.from({ length: FOLDERS.length + 1 }, (_, i) => `stale-${i}`));
  await assert.rejects(first, e => e.code === 'SETUP_SUPERSEDED');
  assert.equal(f.current().folderPlan.root, 'new-0');
});
