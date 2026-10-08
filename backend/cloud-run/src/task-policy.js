import { requireThat } from './errors.js';
import { digest } from './crypto.js';
export const TASK_STATUSES = ['TODO', 'IN_PROGRESS', 'IN_REVIEW', 'COMPLETED'];
export const TASK_PRIORITIES = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];
export function validateTask(table, action, old, input) {
  if (!['Tasks', 'TaskComments'].includes(table)) return;
  requireThat(['create', 'update', 'delete'].includes(action), 400, 'INVALID_TASK', 'Unsupported task action.');
  if (table === 'TaskComments') {
    requireThat(action === 'create' && typeof input.body === 'string' && input.body.trim().length > 0 && input.body.length <= 5000,
      400, 'INVALID_COMMENT', 'Comments must contain between 1 and 5000 characters and cannot be edited.');
    return;
  }
  if (action === 'delete') return;
  const value = { ...old, ...input };
  requireThat(typeof value.title === 'string' && value.title.trim().length > 0 && value.title.length <= 200 &&
    TASK_STATUSES.includes(value.status) && TASK_PRIORITIES.includes(value.priority) &&
    typeof value.employeeId === 'string' && value.employeeId.length === 43 && typeof value.dueDate === 'string' && value.dueDate !== '',
    400, 'INVALID_TASK', 'Supply a title, employee, valid status, priority and due date.');
  for (const key of ['startTime', 'endTime']) requireThat(!value[key] || /^([01]\d|2[0-3]):[0-5]\d$/.test(value[key]),
    400, 'INVALID_TASK', 'Times must use HH:mm.');
  requireThat(!value.startDate || value.startDate <= value.dueDate, 400, 'INVALID_TASK', 'Start date cannot follow the due date.');
  requireThat(!value.startTime || !value.endTime || value.startDate !== value.dueDate || value.startTime <= value.endTime,
    400, 'INVALID_TASK', 'End time cannot precede start time.');
  for (const key of ['project', 'tags', 'assigneeName']) requireThat(!value[key] || value[key].length <= 300,
    400, 'INVALID_TASK', 'Task metadata is too long.');
  requireThat(!value.reminder || ['NONE', 'AT_DUE', '15_MIN', '30_MIN', '1_HOUR', '2_HOURS', '1_DAY'].includes(value.reminder),
    400, 'INVALID_TASK', 'Select a supported reminder.');
}
export async function taskActivityChanges(sheets, companyId, table, action, old, values, system, key) {
  if (table !== 'Tasks') return [];
  const rows = (await sheets.read(companyId, ['TaskActivity'])).TaskActivity;
  const changed = Object.keys(values).filter(k => values[k] !== old?.[k]);
  return [{ table: 'TaskActivity', row: Math.max(1, ...rows.map(r => r._row)) + 1,
    values: { ...system, recordId: digest('task-activity:' + key), isDeleted: false,
      taskId: system.recordId, action, summary: action === 'create' ? 'Task created' : action === 'delete' ? 'Task deleted' :
        changed.map(k => k === 'status' ? 'Status: ' + values[k] : k === 'employeeId' ? 'Employee reassigned' : k + ' updated').join(', ') || 'Task saved' } }];
}
