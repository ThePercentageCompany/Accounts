import { digest, opaque } from './crypto.js';
import { requireThat } from './errors.js';
import { principalFromRows, visible } from './employee-policy.js';
const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';
const leads = { AT_DUE: 0, '15_MIN': 15, '30_MIN': 30, '1_HOUR': 60, '2_HOURS': 120, '1_DAY': 1440 };
const publicItem = ({id, title, body, type, taskId, companyId, createdAt, readAt}) =>
  ({id, title, body, type, taskId, companyId, createdAt, readAt});

export class NotificationService {
  constructor({ accounts, employees, business, config, sendPush, queue, now = Date.now }) {
    Object.assign(this, {accounts, employees, business, config, sendPush, queue, now});
    this.registry = accounts.registry;
  }
  async principal(token, companyId, employee, context = {}) {
    if (employee) {
      const p = await this.employees.principal(token);
      this.employees.verifyContext(p, {...context, companyId});
      return {user: p.employeeId, principal: p};
    }
    const {owner} = this.business.owner((await this.registry.read()).state, token, companyId);
    return {user: owner.id};
  }
  async list(token, companyId, employee, context) {
    const p = await this.principal(token, companyId, employee, context);
    const tasks = (await this.business.sheets.read(companyId, ['Tasks'])).Tasks;
    const fresh = await this.principal(token, companyId, employee, context);
    const company = (await this.registry.read()).state.companies[companyId];
    const notifications = Object.values(company.notifications || {})
      .filter(n => n.user === p.user && tasks.some(t => t.recordId === n.taskId && active(t) &&
        (!fresh.principal || visible(fresh.principal, 'Tasks', t))))
      .sort((a, b) => b.createdAt - a.createdAt).slice(0, 100).map(publicItem);
    return {notifications, unread: notifications.filter(n => !n.readAt).length,
      pushAvailable: !!this.sendPush, publicKey: this.sendPush ? this.config.pushPublicKey : null};
  }
  async read(token, companyId, input, employee, context) {
    const {user} = await this.principal(token, companyId, employee, context);
    requireThat(input && Object.keys(input).every(k => ['id', 'read'].includes(k)) &&
      (input.id === 'all' || /^[A-Za-z0-9_-]{43}$/.test(input.id)) && typeof input.read === 'boolean',
      400, 'INVALID_NOTIFICATION', 'Choose a notification and read state.');
    await this.registry.transact(state => {
      for (const n of Object.values(state.companies[companyId]?.notifications || {})) {
        if (n.user === user && (input.id === 'all' || input.id === n.id)) n.readAt = input.read ? this.now() : null;
      }
    });
    return {saved: true};
  }
  async subscribe(token, companyId, input, employee, context) {
    requireThat(this.sendPush, 503, 'PUSH_NOT_CONFIGURED', 'Push notifications are not enabled by the administrator yet.');
    const {user} = await this.principal(token, companyId, employee, context);
    const subscription = input?.subscription;
    let endpoint; try {endpoint = new URL(subscription?.endpoint);} catch (_) {}
    // Prevent subscription endpoints from turning the backend into an SSRF relay.
    const host = endpoint?.hostname;
    requireThat(endpoint?.protocol === 'https:' && !endpoint.username && !endpoint.password &&
      !endpoint.port && (host === 'fcm.googleapis.com' || host === 'web.push.apple.com' ||
        host === 'updates.push.services.mozilla.com' || host?.endsWith('.notify.windows.com')) &&
      endpoint.href.length <= 2048 && /^[A-Za-z0-9_-]{80,100}$/.test(subscription?.keys?.p256dh) &&
      /^[A-Za-z0-9_-]{20,30}$/.test(subscription?.keys?.auth),
      400, 'INVALID_PUSH_SUBSCRIPTION', 'This browser push subscription is invalid.');
    const id = digest(subscription.endpoint);
    await this.registry.transact(state => {
      // A browser endpoint belongs to only one authenticated account/workspace.
      for (const c of Object.values(state.companies)) if (c.pushSubscriptions?.[id]) delete c.pushSubscriptions[id];
      const c = state.companies[companyId]; c.pushSubscriptions ??= {};
      requireThat(Object.values(c.pushSubscriptions).filter(s => s.user === user).length < 5,
        409, 'PUSH_DEVICE_LIMIT', 'Notification device limit reached. Disable notifications on an older device.');
      c.pushSubscriptions[id] = {user, employee, subscription: {endpoint: endpoint.href,
        keys: {p256dh: subscription.keys.p256dh, auth: subscription.keys.auth}}, createdAt: this.now()};
    });
    return {subscribed: true};
  }
  async unsubscribe(token, companyId, input, employee, context) {
    const {user} = await this.principal(token, companyId, employee, context);
    await this.registry.transact(state => {
      const c = state.companies[companyId];
      for (const [id, value] of Object.entries(c.pushSubscriptions || {})) {
        if (value.user === user && (!input?.endpoint || value.subscription.endpoint === input.endpoint)) delete c.pushSubscriptions[id];
      }
    });
    return {subscribed: false};
  }
  async scanCompany(companyId) {
    const company = (await this.registry.read()).state.companies[companyId];
    if (!company || company.stage !== 'READY' || company.deleted) return;
    const rows = await this.employees.sheets.read(companyId, ['Employees', 'Roles', 'RolePermissions', 'Tasks']);
    const now = this.now();
    const allowed = task => {
      if (company.employeeAccess?.[task.employeeId]?.status !== 'ACTIVE') return false;
      try {return visible(principalFromRows(companyId, task.employeeId, rows, now), 'Tasks', task);} catch (_) {return false;}
    };
    await this.registry.transact(state => {
      const c = state.companies[companyId];
      if (!c || c.stage !== 'READY') return;
      c.taskWatch ??= {}; c.notifications ??= {};
      for (const task of rows.Tasks.filter(active)) {
        const previous = c.taskWatch[task.recordId];
        const put = (key, type, title, body) => {
          const id = digest(key);
          if (!c.notifications[id]) c.notifications[id] = {id, user: task.employeeId,
            employee: true, companyId, taskId: task.recordId, title, body, type,
            createdAt: now, readAt: null, deliveries: {}, ...(type === 'task-due' ? {deadlineKey: key} : {})};
        };
        if (allowed(task) && previous?.employeeId !== task.employeeId) {
          put(`assigned:${companyId}:${task.recordId}:${task.recordVersion}`, 'task-assigned',
            'New task assigned', `You have been assigned: ${String(task.title).slice(0, 160)}`);
        }
        let reminderKey = previous?.reminderKey;
        if (allowed(task) && task.status !== 'COMPLETED' && Object.hasOwn(leads, task.reminder)) {
          const due = Date.parse(`${task.dueDate}T${task.endTime || '23:59'}:00+04:00`);
          const key = `due:${companyId}:${task.recordId}:${due}:${task.reminder}`;
          if (reminderKey !== key && Number.isFinite(due) && now >= due - leads[task.reminder] * 60000 && now < due + 60000) {
            put(key, 'task-due',
              'Task deadline reminder', `${String(task.title).slice(0, 160)} is due ${task.dueDate} at ${task.endTime || '23:59'} (Dubai time).`);
            reminderKey = key;
          }
        }
        c.taskWatch[task.recordId] = {employeeId: task.employeeId, version: task.recordVersion, reminderKey};
      }
      const live = new Set(rows.Tasks.filter(active).map(t => t.recordId));
      for (const id of Object.keys(c.taskWatch)) if (!live.has(id)) delete c.taskWatch[id];
      // Bounded history. Deduplication is kept separately for the current task deadline.
      const ordered = Object.values(c.notifications).sort((a,b) => b.createdAt-a.createdAt);
      for (const n of ordered.slice(500)) delete c.notifications[n.id];
    });
    if (!this.sendPush) return;
    const latest = (await this.registry.read()).state.companies[companyId];
    for (const n of Object.values(latest.notifications || {}).filter(n => now - n.createdAt < 86400000)) {
      const task = rows.Tasks.find(t => t.recordId === n.taskId);
      if (!task || task.employeeId !== n.user || !allowed(task) || latest.employeeAccess?.[n.user]?.status !== 'ACTIVE') continue;
      if (n.type === 'task-due' && (task.status === 'COMPLETED' ||
          n.deadlineKey !== `due:${companyId}:${task.recordId}:${Date.parse(`${task.dueDate}T${task.endTime || '23:59'}:00+04:00`)}:${task.reminder}`)) continue;
      for (const [device, subscription] of Object.entries(latest.pushSubscriptions || {})) {
        if (subscription.user !== n.user || !subscription.employee || n.deliveries[device]?.sent) continue;
        const lease = opaque();
        const claimed = await this.registry.transact(state => {
          const item = state.companies[companyId]?.notifications?.[n.id];
          if (!item || item.deliveries[device]?.sent || item.deliveries[device]?.until > now) return false;
          item.deliveries[device] = {lease, until: now + 120000}; return true;
        });
        if (!claimed) continue;
        try {
          await this.sendPush(subscription.subscription, publicItem(n));
          await this.registry.transact(state => {
            const item = state.companies[companyId]?.notifications?.[n.id];
            if (item?.deliveries[device]?.lease === lease) item.deliveries[device] = {sent: true};
          });
        } catch (error) {
          await this.registry.transact(state => {
            const c = state.companies[companyId];
            if ([404,410].includes(error.statusCode)) delete c.pushSubscriptions[device];
            const item = c.notifications?.[n.id];
            if (item?.deliveries[device]?.lease === lease) item.deliveries[device] = {until: now + 300000};
          });
        }
      }
    }
  }
  async run() {
    const {state} = await this.registry.read();
    const failures = [];
    for (const c of Object.values(state.companies)) {
      if (c.stage !== 'READY' || c.deleted) continue;
      try {
        if (this.queue) await this.queue.enqueueNotifications(c.id);
        else await this.scanCompany(c.id);
      } catch (_) {failures.push(c.id);}
    }
    requireThat(!failures.length, 503, 'NOTIFICATION_RETRY', 'Notification processing will retry.');
  }
  async revokeSubscriptions(token, employee) {
    if (typeof token !== 'string') return;
    await this.registry.transact(state => {
      const session = employee ? state.employeeSessions?.[digest(token)] : state.sessions[digest(token)];
      const user = session?.[employee ? 'employeeId' : 'ownerId'];
      if (!user) return;
      for (const c of Object.values(state.companies)) {
        for (const [id, subscription] of Object.entries(c.pushSubscriptions || {})) {
          if (subscription.user === user && subscription.employee === employee) delete c.pushSubscriptions[id];
        }
      }
    });
  }
}
