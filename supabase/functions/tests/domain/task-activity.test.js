import test from 'node:test';
import assert from 'node:assert/strict';
import { taskActivityChanges } from '../../_shared/domain/task-policy.js';
import { TaskService } from '../../_shared/domain/task-service.js';

test('status activity records updater and change time instead of task creator', async () => {
  const changes = await taskActivityChanges(
    { read: async () => ({ TaskActivity: [] }) }, 'company', 'Tasks', 'update',
    { status: 'TODO' }, { status: 'COMPLETED' },
    { recordId: 'task', createdBy: 'owner', createdAt: 100,
      updatedBy: 'employee', updatedAt: 200 }, 'operation');
  assert.equal(changes[0].values.createdBy, 'employee');
  assert.equal(changes[0].values.createdAt, 200);
  assert.equal(changes[0].values.taskId, 'task');
  assert.equal(changes[0].values.summary, 'Status: COMPLETED');
});

test('history resolves actual updater for older entries and preserves comment author', async () => {
  const rows = {
    Tasks: [{ recordId: 'task' }],
    TaskComments: [{ taskId: 'task', createdBy: 'creator', createdAt: 100 }],
    TaskActivity: [
      { taskId: 'task', createdBy: 'creator', createdAt: 100,
        updatedBy: 'updater', updatedAt: 200 },
      { taskId: 'task', createdBy: 'owner', createdAt: 100,
        updatedBy: 'owner', updatedAt: 300 },
    ],
  };
  const service = new TaskService({ business: {
    list: async (_token, _company, table) => rows[table],
    accounts: { actorName: async id => id === 'owner' ? 'Alex Admin' : 'Unknown user' },
    records: { readReferences: async () => ({ Employees: [
      { recordId: 'creator', fullName: 'Task Creator' },
      { recordId: 'updater', fullName: 'Status Updater' },
    ] }) },
  } });
  const detail = await service.detail('', 'company', 'task');
  assert.equal(detail.activity[0].authorName, 'Status Updater');
  assert.equal(detail.activity[0].createdAt, 200);
  assert.equal(detail.activity[1].authorName, 'Alex Admin');
  assert.equal(detail.comments[0].authorName, 'Task Creator');
  assert.equal(detail.comments[0].createdAt, 100);
});
