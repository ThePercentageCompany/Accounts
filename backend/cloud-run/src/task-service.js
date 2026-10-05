import { requireThat } from './errors.js';
import { TASK_STATUSES, TASK_PRIORITIES } from './task-policy.js';
const clean = row => Object.fromEntries(Object.entries(row).filter(([k]) => !['_row', 'idempotencyKey'].includes(k)));
const date = value => /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value;
export class TaskService {
  constructor({ business, employees }) { Object.assign(this, { business, employees }); }
  async records(token, companyId, table, employee, context) {
    if (employee) {
      requireThat(!context.companyId || context.companyId === companyId, 409, 'WORKSPACE_CHANGED', 'Workspace context changed.');
      return this.employees.records(token, table, { ...context, companyId });
    }
    return this.business.list(token, companyId, table);
  }
  async list(token, companyId, query, employee = false, context = {}) {
    const allowed = ['search', 'employeeId', 'status', 'priority', 'project', 'from', 'to', 'offset', 'limit', 'sort', 'overdue'];
    requireThat([...query.keys()].every(k => allowed.includes(k) && query.getAll(k).length === 1), 400, 'INVALID_QUERY', 'Unsupported task filter.');
    const q = Object.fromEntries(query), offset = Number(q.offset ?? 0), limit = Number(q.limit ?? 40);
    requireThat(Number.isSafeInteger(offset) && offset >= 0 && Number.isSafeInteger(limit) && limit >= 1 && limit <= 100 &&
      (!q.search || q.search.length <= 200) && (!q.status || TASK_STATUSES.includes(q.status)) &&
      (!q.priority || TASK_PRIORITIES.includes(q.priority)) && (!q.from || date(q.from)) && (!q.to || date(q.to)) &&
      (!q.from || !q.to || q.from <= q.to) && (!q.sort || ['due', 'priority', 'updated'].includes(q.sort)) && (!q.overdue || q.overdue === 'true'),
      400, 'INVALID_QUERY', 'Invalid task filters or page size.');
    const all = await this.records(token, companyId, 'Tasks', employee, context);
    let rows = all.filter(r => (!q.overdue || r.status !== 'COMPLETED') && (!q.search || (r.title + ' ' + r.description + ' ' + r.project + ' ' + r.tags).toLowerCase().includes(q.search.toLowerCase())) &&
      ['employeeId', 'status', 'priority', 'project'].every(k => !q[k] || r[k] === q[k]) &&
      (!q.from || r.dueDate >= q.from) && (!q.to || r.dueDate <= q.to));
    rows.sort((a, b) => (q.sort === 'priority' ? TASK_PRIORITIES.indexOf(b.priority) - TASK_PRIORITIES.indexOf(a.priority) :
      q.sort === 'updated' ? Number(b.updatedAt) - Number(a.updatedAt) : String(a.dueDate + a.endTime).localeCompare(String(b.dueDate + b.endTime))) || a.recordId.localeCompare(b.recordId));
    const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Dubai', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date(this.business.now()));
    const summaryRows = employee ? all.filter(r => r.employeeId === context.employeeId) : all;
    const upcoming = {};
    for (const r of summaryRows) if (r.status !== 'COMPLETED' && r.dueDate > today) upcoming[r.dueDate] = (upcoming[r.dueDate] || 0) + 1;
    const lead = { AT_DUE: 0, '15_MIN': 15, '1_HOUR': 60, '1_DAY': 1440 };
    const reminders = summaryRows.filter(r => r.status !== 'COMPLETED' && Object.hasOwn(lead, r.reminder) &&
      Date.parse(r.dueDate + 'T' + (r.endTime || '23:59') + ':00+04:00') - lead[r.reminder] * 60000 <= this.business.now() && r.dueDate >= today)
      .map(r => ({ recordId: r.recordId, title: r.title, dueDate: r.dueDate, endTime: r.endTime, reminder: r.reminder }));
    const dateCounts = {};
    for (const row of rows) dateCounts[row.dueDate] = (dateCounts[row.dueDate] || 0) + 1;
    return { dateCounts, summary: { todo: summaryRows.filter(r => r.status === 'TODO').length,
      inProgress: summaryRows.filter(r => r.status === 'IN_PROGRESS').length,
      today: summaryRows.filter(r => r.dueDate === today && r.status !== 'COMPLETED').length,
      overdue: summaryRows.filter(r => r.dueDate < today && r.status !== 'COMPLETED').length,
      upcoming: Object.entries(upcoming).sort(([a], [b]) => a.localeCompare(b)).slice(0, 7).map(([date, count]) => ({ date, count })) }, reminders,
      records: rows.slice(offset, offset + limit).map(clean), total: rows.length,
      nextOffset: offset + limit < rows.length ? offset + limit : null };
  }
  async detail(token, companyId, id, employee = false, context = {}) {
    const tasks = await this.records(token, companyId, 'Tasks', employee, context);
    const task = tasks.find(t => t.recordId === id);
    requireThat(task, 404, 'TASK_NOT_FOUND', 'Task is unavailable.');
    const comments = await this.records(token, companyId, 'TaskComments', employee, context);
    const activity = await this.records(token, companyId, 'TaskActivity', employee, context);
    // Revalidate visibility after reading dependent data.
    requireThat((await this.records(token, companyId, 'Tasks', employee, context)).some(t => t.recordId === id),
      404, 'TASK_NOT_FOUND', 'Task is unavailable.');
    const names = (await this.business.sheets.readReferences(companyId, ['Employees'])).Employees;
    const author = row => ({ ...clean(row), authorName: names.find(e => e.recordId === row.createdBy)?.fullName || 'Company owner' });
    requireThat((await this.records(token, companyId, 'Tasks', employee, context)).some(t => t.recordId === id),
      404, 'TASK_NOT_FOUND', 'Task is unavailable.');
    return { task: clean(task), comments: comments.filter(c => c.taskId === id).map(author), activity: activity.filter(a => a.taskId === id).map(author) };
  }
  async assignees(token, companyId, employee = false, context = {}, query = new URLSearchParams()) {
    requireThat([...query.keys()].every(k => ['search', 'offset', 'limit'].includes(k) && query.getAll(k).length === 1),
      400, 'INVALID_QUERY', 'Unsupported employee filter.');
    const search = query.get('search') || '', offset = Number(query.get('offset') || 0), limit = Number(query.get('limit') || 40);
    requireThat(search.length <= 200 && Number.isSafeInteger(offset) && offset >= 0 && Number.isSafeInteger(limit) && limit >= 1 && limit <= 100,
      400, 'INVALID_QUERY', 'Invalid employee search or page size.');
    if (employee) {
      const p = await this.employees.principal(token); this.employees.verifyContext(p, context);
      requireThat(p.companyId === companyId && p.writableSections.includes('Tasks'), 403, 'WRITE_FORBIDDEN', 'Task assignment is unavailable.');
    } else this.business.owner((await this.business.registry.read()).state, token, companyId);
    const rows = await this.business.sheets.readReferences(companyId, ['Employees']);
    if (employee) {
      const p = await this.employees.principal(token);
      requireThat(p.companyId === companyId && p.writableSections.includes('Tasks'), 403, 'WRITE_FORBIDDEN', 'Task assignment is unavailable.');
    } else this.business.owner((await this.business.registry.read()).state, token, companyId);
    const employees = rows.Employees.filter(e => e.isDeleted !== true && e.isDeleted !== 'TRUE' && e.employmentStatus === 'ACTIVE' &&
      (!search || (e.fullName + ' ' + e.department).toLowerCase().includes(search.toLowerCase()))).sort((a, b) => a.fullName.localeCompare(b.fullName) || a.recordId.localeCompare(b.recordId));
    return { employees: employees.slice(offset, offset + limit).map(e => ({ recordId: e.recordId, fullName: e.fullName, department: e.department })),
      nextOffset: offset + limit < employees.length ? offset + limit : null };
  }
}
