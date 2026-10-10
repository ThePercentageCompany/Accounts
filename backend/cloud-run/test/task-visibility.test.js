import test from 'node:test';
import assert from 'node:assert/strict';
import { visible } from '../src/employee-policy.js';
test('task readers only see assignments; editors see company tasks and their children', () => {
 const reader = {companyId:'c',employeeId:'e',permissions:{Tasks:'COMPANY'},writableSections:[]};
 const editor = {...reader,writableSections:['Tasks']};
 const own={companyId:'c',recordId:'own',employeeId:'e'};
 const other={companyId:'c',recordId:'other',employeeId:'x',createdBy:'e'};
 assert.equal(visible(reader,'Tasks',own),true);
 assert.equal(visible(reader,'Tasks',other),false);
 assert.equal(visible(editor,'Tasks',other),true);
 assert.equal(visible(editor,'Tasks',{...other,companyId:'foreign'}),false);
 assert.equal(visible(reader,'TaskComments',{companyId:'c',taskId:'other'},{Tasks:[other]}),false);
 assert.equal(visible(editor,'TaskComments',{companyId:'c',taskId:'other'},{Tasks:[other]}),true);
 assert.equal(visible(reader,'TaskActivity',{companyId:'c',taskId:'own'},{Tasks:[own]}),true);
});
