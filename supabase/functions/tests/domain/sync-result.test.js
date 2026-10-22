import test from 'node:test';
import assert from 'node:assert/strict';
import { BusinessService } from '../../_shared/domain/business-service.js';
import { ApiError } from '../../_shared/domain/errors.js';

function fixture(error) {
  const service = new BusinessService({
    accounts: { registry: { read: async () => ({ state: {} }) } },
    records: { table: () => ({}) },
  });
  service.owner = () => ({ owner: { id: 'owner' } });
  service.values = (_, values) => values;
  service.mutate = async () => { throw error; };
  return service;
}
const operation = { operationId: 'operation_1234567890', table: 'Customers',
  action: 'create', expectedVersion: 0, values: { name: 'Saved locally' } };

test('sync preserves transient HTTP error status inside batch responses', async () => {
  const response = await fixture(new ApiError(503, 'UPSTREAM_TIMEOUT', 'Retry later'))
    .sync('', 'company', { operations: [operation] });
  assert.equal(response.results[0].status, 'FAILED');
  assert.equal(response.results[0].error.status, 503);
  assert.equal(response.results[0].error.code, 'UPSTREAM_TIMEOUT');
});
test('sync preserves conflict classification and does not attempt dependent batch writes', async () => {
  const response = await fixture(new ApiError(409, 'VERSION_CONFLICT', 'Review current version'))
    .sync('', 'company', { operations: [operation, { ...operation, operationId: 'operation_0987654321' }] });
  assert.equal(response.results[0].error.status, 409);
  assert.equal(response.results[1].status, 'NOT_ATTEMPTED');
});
test('unexpected failures remain retryable without leaking internal error details', async () => {
  const response = await fixture(new Error('Private database details'))
    .sync('', 'company', { operations: [operation] });
  assert.equal(response.results[0].error.status, 503);
  assert.equal(response.results[0].error.code, 'SERVICE_UNAVAILABLE');
  assert.doesNotMatch(response.results[0].error.message, /Private/);
});
