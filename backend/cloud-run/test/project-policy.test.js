import test from 'node:test';
import assert from 'node:assert/strict';
import { validateProject } from '../src/project-policy.js';
const sheets = { read: async () => ({ Projects: [{recordId: 'p', name: 'Site A', status: 'ACTIVE'}], Tasks: [{project: 'Site A'}] }) };
test('project names are unique and referenced projects cannot be renamed or deleted', async () => {
  await assert.rejects(validateProject(sheets, 'c', 'Projects', 'create', undefined, {name: 'site a', status: 'ACTIVE'}), {code: 'PROJECT_EXISTS'});
  await assert.rejects(validateProject(sheets, 'c', 'Projects', 'delete', {recordId: 'p', name: 'Site A'}, {}), {code: 'PROJECT_REFERENCED'});
  await assert.rejects(validateProject(sheets, 'c', 'Projects', 'update', {recordId: 'p', name: 'Site A'}, {name: 'Site B', status: 'ACTIVE'}), {code: 'PROJECT_REFERENCED'});
});
test('task selection must resolve to an active project but legacy unchanged values remain editable', async () => {
  await validateProject(sheets, 'c', 'Tasks', 'create', undefined, {project: 'Site A'});
  await assert.rejects(validateProject(sheets, 'c', 'Tasks', 'create', undefined, {project: 'Unknown'}), {code: 'PROJECT_NOT_FOUND'});
  await validateProject(sheets, 'c', 'Tasks', 'update', {project: 'Legacy'}, {project: 'Legacy'});
});
