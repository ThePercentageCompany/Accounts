import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from './helpers.js';
import { BusinessService } from '../src/business-service.js';
import { TaskService } from '../src/task-service.js';
import { TABLES } from '../src/company-schema.js';
import { BusinessSheets } from '../src/business-sheets.js';
import { opaque } from '../src/crypto.js';

async function setup() {
  const f = fixture(), token = await f.login();
  const companyId = (await f.service.createCompany(token, { name: 'Tasks' }, 'task_company_0001')).company.companyId;
  await f.registry.transact(s => { s.companies[companyId].stage = 'READY'; });
  const employeeId = opaque(), data = Object.fromEntries(TABLES.map(t => [t.title, []]));
  data.Employees.push({ recordId: employeeId, companyId, fullName: 'Ahmed', employmentStatus: 'ACTIVE', _row: 2 });
  const sheets = {
    table: name => BusinessSheets.prototype.table(name),
    read: async (_id, names) => Object.fromEntries(names.map(n => [n, structuredClone(data[n])])),
    readReferences: async (_id, names) => sheets.read(_id, names),
    write: async (_id, table, row, values) => { const old = data[table].find(r => r._row === row); if (old) Object.assign(old, values); else data[table].push({ ...values, _row: row }); },
    writeBatch: async (id, changes) => { for (const c of changes) await sheets.write(id, c.table, c.row, c.values); },
  };
  const business = new BusinessService({ accounts: f.service, sheets, now: () => Date.parse('2026-10-05T12:00:00+04:00') });
  const values = { title: 'Prepare report', employeeId, status: 'TODO', priority: 'HIGH', dueDate: '2026-10-05', endTime: '16:00', reminder: 'NONE' };
  const create = (input = values, key = 'task_create_0001') => business.mutate(token, companyId, 'Tasks', null, 'create', { expectedVersion: 0, values: input }, key);
  return { ...f, token, companyId, employeeId, data, sheets, business, values, create, tasks: new TaskService({ business }) };
}

test('task creation derives employee name and appends activity atomically; retry does not duplicate', async () => {
  const f = await setup(); let writes = 0; const write = f.sheets.writeBatch;
  f.sheets.writeBatch = async (...args) => { writes++; await write(...args); throw new Error('response lost'); };
  await assert.rejects(f.create({ ...f.values, assigneeName: 'Forged name' }));
  assert.equal(f.data.Tasks.length, 1); assert.equal(f.data.TaskActivity.length, 1);
  assert.equal(f.data.Tasks[0].assigneeName, 'Ahmed');
  await f.create({ ...f.values, assigneeName: 'Forged name' });
  assert.equal(writes, 1); assert.equal(f.data.TaskActivity[0].taskId, f.data.Tasks[0].recordId);
});

test('invalid task state, missing title, impossible date, and inactive assignee cannot be stored', async () => {
  const f = await setup();
  for (const [i, input] of [{ ...f.values, title: '' }, { ...f.values, status: 'BOGUS' }, { ...f.values, dueDate: '2026-02-30' }, { ...f.values, startDate: '2026-10-06' }, { ...f.values, startDate: '2026-10-05', startTime: '17:00', endTime: '16:00' }].entries()) await assert.rejects(f.create(input, 'task_invalid_000' + i));
  f.data.Employees[0].employmentStatus = 'INACTIVE'; await assert.rejects(f.create(), e => e.code === 'TASK_ASSIGNEE_UNAVAILABLE');
  assert.equal(f.data.Tasks.length, 0); assert.equal(f.data.TaskActivity.length, 0);
});

test('tasks retain version conflicts, company isolation and server-only activity writes', async () => {
  const f = await setup(); const result = await f.create();
  await f.business.mutate(f.token, f.companyId, 'Tasks', result.recordId, 'update', { expectedVersion: 1, values: { status: 'IN_PROGRESS' } }, 'task_status_0001');
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'Tasks', result.recordId, 'update', { expectedVersion: 1, values: { status: 'COMPLETED' } }, 'task_status_0002'), e => e.code === 'VERSION_CONFLICT');
  await assert.rejects(f.tasks.list(await f.login('other'), f.companyId, new URLSearchParams()), e => e.status === 404);
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'TaskActivity', null, 'create', { expectedVersion: 0, values: { taskId: result.recordId, action: 'forged' } }, 'task_activity_forged'), e => e.code === 'TABLE_FORBIDDEN');
  assert.equal(f.data.TaskActivity.length, 2);
});

test('task list applies filters before pagination, validates queries, and returns month counts', async () => {
  const f = await setup();
  for (let i = 0; i < 5; i++) await f.create({ ...f.values, title: 'Report ' + i, priority: i === 4 ? 'LOW' : 'HIGH', dueDate: i < 3 ? '2026-10-04' : '2026-10-05', status: i === 0 ? 'COMPLETED' : 'TODO' }, 'task_page_create_' + i);
  const data = await f.tasks.list(f.token, f.companyId, new URLSearchParams('limit=2&overdue=true&to=2026-10-04'));
  assert.equal(data.total, 2); assert.equal(data.nextOffset, null); assert.equal(data.summary.overdue, 2);
  assert.equal(data.dateCounts['2026-10-04'], 2);
  const page = await f.tasks.list(f.token, f.companyId, new URLSearchParams('limit=2&offset=2&priority=HIGH'));
  assert.equal(page.records.length, 2); assert.equal(page.total, 4);
  for (const query of ['limit=1000', 'status=NO', 'from=2026-02-30', 'limit=1&limit=2', 'companyId=other']) await assert.rejects(f.tasks.list(f.token, f.companyId, new URLSearchParams(query)), e => e.code === 'INVALID_QUERY');
});

test('comments require an existing task, nonblank bounded text, and cannot be edited', async () => {
  const f = await setup(), task = await f.create();
  const add = body => f.business.mutate(f.token, f.companyId, 'TaskComments', null, 'create', { expectedVersion: 0, values: { taskId: task.recordId, body } }, 'task_comment_add_' + body.length);
  await assert.rejects(add('   ')); await assert.rejects(add('x'.repeat(5001)));
  const comment = await add('Ready for review');
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'TaskComments', comment.recordId, 'update', { expectedVersion: 1, values: { body: 'edited' } }, 'task_comment_edit'), e => e.code === 'INVALID_COMMENT');
  const details = await f.tasks.detail(f.token, f.companyId, task.recordId); assert.equal(details.comments.length, 1); assert.equal(details.activity.length, 1);
});
test('task deletion retains comments and activity but hides the task from board and calendar', async () => {
  const f = await setup(), task = await f.create();
  await f.business.mutate(f.token, f.companyId, 'TaskComments', null, 'create', { expectedVersion: 0, values: { taskId: task.recordId, body: 'Keep history' } }, 'task_comment_history');
  await f.business.mutate(f.token, f.companyId, 'Tasks', task.recordId, 'delete', { expectedVersion: 1 }, 'task_delete_history');
  assert.equal((await f.tasks.list(f.token, f.companyId, new URLSearchParams())).total, 0);
  assert.equal(f.data.TaskComments.length, 1); assert.equal(f.data.TaskActivity.length, 2);
  await assert.rejects(f.tasks.detail(f.token, f.companyId, task.recordId), e => e.code === 'TASK_NOT_FOUND');
});

test('assignee endpoint returns only searchable paged public employee labels', async () => {
  const f = await setup();
  for (let i = 0; i < 80; i++) f.data.Employees.push({ recordId: opaque(), companyId: f.companyId, fullName: 'Employee ' + i, department: 'Sales', employmentStatus: i === 0 ? 'INACTIVE' : 'ACTIVE', basicSalary: 50000, iban: 'private', _row: i + 3 });
  const page = await f.tasks.assignees(f.token, f.companyId, false, {}, new URLSearchParams('search=Sales&limit=20'));
  assert.equal(page.employees.length, 20); assert.equal(page.nextOffset, 20);
  assert.deepEqual(Object.keys(page.employees[0]).sort(), ['department', 'fullName', 'recordId']);
  assert.equal((await f.tasks.assignees(f.token, f.companyId, false, {}, new URLSearchParams('search=Ahmed'))).employees.length, 1);
});

test('project create, replay, list and update use the business table allowlist', async () => {
  const f = await setup();
  const input = {expectedVersion: 0, values: {name: 'Site A', description: 'New site', status: 'ACTIVE'}};
  const created = await f.business.mutate(f.token, f.companyId, 'Projects', null, 'create', input, 'project_create_0001');
  await f.business.mutate(f.token, f.companyId, 'Projects', null, 'create', input, 'project_create_0001');
  assert.equal(f.data.Projects.length, 1);
  assert.equal((await f.business.list(f.token, f.companyId, 'Projects'))[0].name, 'Site A');
  await f.business.mutate(f.token, f.companyId, 'Projects', created.recordId, 'update',
    {expectedVersion: 1, values: {description: 'Updated site'}}, 'project_update_0001');
  assert.equal(f.data.Projects[0].description, 'Updated site');
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'Projects', null, 'create', input, 'project_duplicate_01'), {code: 'PROJECT_EXISTS'});
});
