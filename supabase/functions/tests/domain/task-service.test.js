import test from 'node:test';
import assert from 'node:assert/strict';
import { TaskService } from '../../_shared/domain/task-service.js';

function fixture() {
  let taskReads = 0, actorReads = 0;
  const rows = {
    Tasks: [{recordId:'task', title:'Task'}],
    TaskComments: Array.from({length:10}, (_, i) => ({recordId:`c${i}`,taskId:'task',createdBy:'owner',body:'Comment'})),
    TaskActivity: Array.from({length:10}, (_, i) => ({recordId:`a${i}`,taskId:'task',updatedBy:'owner',createdBy:'other'})),
  };
  const service = new TaskService({business:{
    taskQueries:{records:async table => { if(table === 'Tasks')taskReads++; return rows[table]; }},
    records:{readReferences:async () => ({Employees:[]})},
    accounts:{actorName:async () => {actorReads++; return 'Owner name';}},
  }});
  return {service,rows,counts:() => ({taskReads,actorReads})};
}

test('task detail resolves a shared author once across comments and activity', async () => {
  const {service,counts} = fixture();
  const result = await service.detail('', 'company', 'task');
  assert.equal(result.comments.length, 10);
  assert.equal(result.activity.length, 10);
  assert.ok([...result.comments,...result.activity].every(row => row.authorName === 'Owner name'));
  assert.deepEqual(counts(), {taskReads:2,actorReads:1});
});

test('task detail revalidates access after resolving dependent data', async () => {
  const {service,rows} = fixture();
  service.business.accounts.actorName = async () => { rows.Tasks = []; return 'Owner'; };
  await assert.rejects(service.detail('', 'company', 'task'), error => error.code === 'TASK_NOT_FOUND');
});
