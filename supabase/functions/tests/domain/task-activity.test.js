import test from 'node:test';
import assert from 'node:assert/strict';
import { taskActivityChanges, validateTask } from '../../_shared/domain/task-policy.js';
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
        updatedBy: 'updater', updatedAt: 200, authorName: 'Company owner' },
      { taskId: 'task', createdBy: 'owner', createdAt: 100,
        updatedBy: 'owner', updatedAt: 300, authorName: 'Company owner' },
    ],
  };
  const service = new TaskService({ business: {
    list: async (_token, _company, table) => rows[table],
    accounts: { actorName: async id => id === 'owner' ? 'Admin' : 'Unknown user' },
    records: { readReferences: async () => ({ Employees: [
      { recordId: 'creator', fullName: 'Task Creator' },
      { recordId: 'updater', fullName: 'Status Updater' },
    ] }) },
  } });
  const detail = await service.detail('', 'company', 'task');
  assert.equal(detail.activity[0].authorName, 'Status Updater');
  assert.equal(detail.activity[0].createdAt, 200);
  assert.equal(detail.activity[1].authorName, 'Admin');
  assert.equal(detail.comments[0].authorName, 'Task Creator');
  assert.equal(detail.comments[0].createdAt, 100);
});

test('verification requires a completed task and records who verified it', async () => {
  const task = { title: 'Task', employeeId: 'e'.repeat(43), dueDate: '2026-11-30',
    status: 'COMPLETED', priority: 'MEDIUM' };
  const verification = { verified: true };
  const unavailable = error => error.code === 'TASK_VERIFICATION_UNAVAILABLE';
  assert.doesNotThrow(() => validateTask('Tasks', 'update', task, verification));
  assert.throws(() => validateTask('Tasks', 'update', { ...task, status: 'TODO' }, verification), unavailable);
  assert.throws(() => validateTask('Tasks', 'update', { ...task, verified: true }, verification), unavailable);
  assert.throws(() => validateTask('Tasks', 'update', task, { ...verification, title: 'Changed' }), unavailable);
  assert.throws(() => validateTask('Tasks', 'create', null, { ...task, ...verification }), unavailable);
  const [activity] = await taskActivityChanges(
    { read: async () => ({ TaskActivity: [] }) }, 'company', 'Tasks', 'update', task, verification,
    { recordId: 'task', createdBy: 'employee', updatedBy: 'manager', updatedAt: 200 }, 'verify-operation');
  assert.equal(activity.values.summary, 'Task verified');
  assert.equal(activity.values.createdBy, 'manager');
  assert.equal(activity.values.createdAt, 200);
});
