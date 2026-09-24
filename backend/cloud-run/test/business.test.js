import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from './helpers.js';
import { BusinessService } from '../src/business-service.js';
import { ApiError } from '../src/errors.js';
import { TABLES } from '../src/company-schema.js';

async function setup() {
  const f = fixture(), token = await f.login(), registration = await f.service.createCompany(token, { name: 'Business' }, 'company_business_123');
  const companyId = registration.company.companyId;
  await f.registry.transact(state => { state.companies[companyId].stage = 'READY'; });
  const data = { Customers: [] };
  const sheets = {
    table(name) { if (name !== 'Customers') throw new ApiError(403, 'TABLE_FORBIDDEN', 'Unavailable');
      return { headers: ['recordId', 'companyId', 'name', 'email'] }; },
    async read(id, names) { assert.equal(id, companyId); return Object.fromEntries(names.map(name => [name, structuredClone(data[name] || [])])); },
    async write(id, table, row, values) {
      assert.equal(id, companyId); const existing = data[table].find(item => item._row === row);
      if (existing) Object.assign(existing, values); else data[table].push({ ...values, _row: row });
    },
  };
  return { ...f, token, companyId, data, sheets, business: new BusinessService({ accounts: f.service, sheets, now: () => 1_800_000_000_000 }) };
}

test('seeded company profile is editable but cannot be duplicated or deleted', async () => {
  const f = await setup();
  f.sheets.table = name => TABLES.find(t => t.title === name);
  f.data.CompanyProfile = [{ recordId: 'company', companyId: f.companyId, recordVersion: 1, name: 'Before', _row: 2 }];
  const result = await f.business.mutate(f.token, f.companyId, 'CompanyProfile', 'company', 'update',
    { expectedVersion: 1, values: { name: 'After' } }, 'company_profile_update_1');
  assert.equal(result.version, 2); assert.equal(f.data.CompanyProfile[0].name, 'After');
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'CompanyProfile', null, 'create',
    { expectedVersion: 0, values: { name: 'Duplicate' } }, 'company_profile_create_1'), e => e.code === 'COMPANY_PROFILE_SINGLETON');
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'CompanyProfile', 'company', 'delete',
    { expectedVersion: 2 }, 'company_profile_delete_1'), e => e.code === 'COMPANY_PROFILE_SINGLETON');
});

test('document links require a completed upload bound to the same record', async () => {
  const f = await setup(), docId = 'd'.repeat(43);
  f.sheets.table = name => TABLES.find(t => t.title === name);
  f.data.CompanyProfile = [{ recordId: 'company', companyId: f.companyId, recordVersion: 1, _row: 2 }];
  const input = { expectedVersion: 1, values: { logoDocumentId: docId } };
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'CompanyProfile', 'company', 'update', input,
    'company_logo_update_001'), e => e.code === 'DOCUMENT_REFERENCE_INVALID');
  await f.registry.transact(state => { state.companies[f.companyId].documents = { [docId]: { status: 'READY', relatedSection: 'CompanyProfile', relatedRecordId: 'company' } }; });
  await f.business.mutate(f.token, f.companyId, 'CompanyProfile', 'company', 'update', input, 'company_logo_update_001');
  assert.equal(f.data.CompanyProfile[0].logoDocumentId, docId);
});

test('business create is tenant-bound, versioned and idempotent', async () => {
  const f = await setup(), key = 'customer_create_123456';
  const created = await f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { name: 'A', email: 'a@example.com' } }, key);
  assert.equal(created.version, 1); assert.equal(f.data.Customers.length, 1);
  const replay = await f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { name: 'A', email: 'a@example.com' } }, key);
  assert.deepEqual(replay, { ...created, replayed: true }); assert.equal(f.data.Customers.length, 1);
  const records = await f.business.list(f.token, f.companyId, 'Customers');
  assert.equal(records[0].name, 'A'); assert.ok(!Object.hasOwn(records[0], 'idempotencyKey'));
  const other = await f.login('owner-b');
  await assert.rejects(() => f.business.list(other, f.companyId, 'Customers'), error => error.code === 'COMPANY_NOT_FOUND');
});

test('business updates enforce expected versions and deletion is soft', async () => {
  const f = await setup();
  const created = await f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { name: 'A' } }, 'customer_create_234567');
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'Customers', created.recordId, 'update',
    { expectedVersion: 7, values: { name: 'wrong' } }, 'customer_update_wrong_1'), error => error.code === 'VERSION_CONFLICT');
  const updated = await f.business.mutate(f.token, f.companyId, 'Customers', created.recordId, 'update',
    { expectedVersion: 1, values: { name: 'B' } }, 'customer_update_234567');
  assert.equal(updated.version, 2); assert.equal(f.data.Customers[0].email ?? '', '');
  const removed = await f.business.mutate(f.token, f.companyId, 'Customers', created.recordId, 'delete',
    { expectedVersion: 2 }, 'customer_delete_234567');
  assert.equal(removed.version, 3); assert.equal((await f.business.list(f.token, f.companyId, 'Customers')).length, 0);
});

test('unknown write outcome reconciles marker without duplicate submission', async () => {
  const f = await setup(); let writes = 0;
  const normal = f.sheets.write;
  f.sheets.write = async (...args) => { writes++; await normal(...args); throw new Error('response lost'); };
  const input = { expectedVersion: 0, values: { name: 'A' } }, key = 'customer_uncertain_123';
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'Customers', null, 'create', input, key));
  f.sheets.write = normal;
  const result = await f.business.mutate(f.token, f.companyId, 'Customers', null, 'create', input, key);
  assert.equal(result.replayed, true); assert.equal(writes, 1); assert.equal(f.data.Customers.length, 1);
});

test('batch retry replays completed operations and leaves later edits pending after a conflict', async () => {
  const f = await setup();
  const operations = [{ operationId: 'batch_customer_00001', table: 'Customers', action: 'create', expectedVersion: 0, values: { name: 'A', email: 'a@example.com' } }];
  const first = await f.business.sync(f.token, f.companyId, { operations });
  assert.equal(first.results[0].status, 'APPLIED');
  operations[0].values = { email: 'a@example.com', name: 'A' };
  assert.equal((await f.business.sync(f.token, f.companyId, { operations })).results[0].replayed, true);
  const conflict = { operationId: 'batch_customer_00002', table: 'Customers', recordId: first.results[0].recordId,
    action: 'update', expectedVersion: 9, values: { name: 'B' } };
  const next = { ...operations[0], operationId: 'batch_customer_00003' };
  const result = await f.business.sync(f.token, f.companyId, { operations: [conflict, next] });
  assert.equal(result.results[0].error.code, 'VERSION_CONFLICT');
  assert.equal(result.results[1].status, 'NOT_ATTEMPTED');
  assert.equal(f.data.Customers.length, 1);
});

test('batch validates all input before writing and rejects another tenant', async () => {
  const f = await setup(), op = { operationId: 'batch_customer_00001', table: 'Customers', action: 'create', expectedVersion: 0, values: { name: 'A' } };
  await assert.rejects(() => f.business.sync(f.token, f.companyId, { operations: [op, op] }), e => e.code === 'INVALID_BATCH');
  await assert.rejects(() => f.business.sync(f.token, f.companyId, { operations: [op, { ...op, operationId: 'batch_customer_00002', values: { companyId: 'wrong' } }] }), e => e.code === 'INVALID_RECORD');
  const other = await f.login('other');
  await assert.rejects(() => f.business.sync(other, f.companyId, { operations: [op] }), e => e.code === 'COMPANY_NOT_FOUND');
  assert.equal(f.data.Customers.length, 0);
});

test('a rejected competing request cannot clear a reserved write', async () => {
  const f = await setup(), read = f.sheets.read;
  let release, entered;
  const waiting = new Promise(resolve => { entered = resolve; });
  f.sheets.read = async (...args) => { entered(); await new Promise(resolve => { release = resolve; }); return read(...args); };
  const input = { expectedVersion: 0, values: { name: 'A' } }, key = 'reserved_customer_001';
  const writing = f.business.mutate(f.token, f.companyId, 'Customers', null, 'create', input, key);
  await waiting;
  const other = await f.login('other');
  await assert.rejects(() => f.business.mutate(other, f.companyId, 'Customers', null, 'create', input, key), e => e.code === 'COMPANY_NOT_FOUND');
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'Customers', null, 'create', { ...input, values: { name: 'B' } }, key), e => e.code === 'IDEMPOTENCY_CONFLICT');
  assert.ok(f.storage.state.companies[f.companyId].businessWrite);
  release(); await writing;
  assert.equal(f.data.Customers.length, 1);
});

test('sync downloads include minimal tombstones and recheck revoked sessions after Sheets reads', async () => {
  const f = await setup();
  const created = await f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { name: 'Private customer' } }, 'tombstone_create_001');
  await f.business.mutate(f.token, f.companyId, 'Customers', created.recordId, 'delete',
    { expectedVersion: 1 }, 'tombstone_delete_001');
  const rows = await f.business.list(f.token, f.companyId, 'Customers', { includeDeleted: true });
  assert.equal(rows.length, 1);
  assert.deepEqual(Object.keys(rows[0]).sort(), ['companyId', 'isDeleted', 'recordId', 'recordVersion', 'updatedAt']);
  assert.equal(rows[0].isDeleted, true);
  assert.equal(rows[0].recordVersion, 2);
  const read = f.sheets.read;
  f.sheets.read = async (...args) => { const result = await read(...args); await f.service.logout(f.token); return result; };
  await assert.rejects(() => f.business.list(f.token, f.companyId, 'Customers', { includeDeleted: true }), e => e.code === 'UNAUTHORIZED');
});

test('pending employee changes prevent business writes', async () => {
  const f = await setup();
  await f.registry.transact(state => { state.companies[f.companyId].employeeWrite = 'pending'; });
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { name: 'A' } }, 'blocked_customer_001'), e => e.code === 'EMPLOYEE_UPDATE_PENDING');
  assert.equal(f.data.Customers.length, 0);
});

test('business fields reject system authority and unsupported tables', async () => {
  const f = await setup();
  await assert.rejects(() => f.business.mutate(f.token, f.companyId, 'Customers', null, 'create',
    { expectedVersion: 0, values: { companyId: 'attacker', name: 'A' } }, 'customer_authority_12'), error => error.code === 'INVALID_RECORD');
  await assert.rejects(() => f.business.list(f.token, f.companyId, 'Roles'), error => error.code === 'TABLE_FORBIDDEN');
});
