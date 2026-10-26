import { requireThat } from './errors.js';

export function notificationInput(action, input) {
  requireThat(input && typeof input === 'object' && !Array.isArray(input), 400, 'INVALID_NOTIFICATION', 'Supply notification settings.');
  const fields = {
    settings: ['expectedVersion', 'sound', 'volume', 'deadlineCutoff', 'dailyReminderTime'],
    preferences: ['assignmentEnabled', 'updatesEnabled', 'deadlineEnabled', 'overdueEnabled', 'pushEnabled', 'quietStart', 'quietEnd'],
    register: ['token', 'installationId'], unregister: ['installationId'], read: ['id', 'read'],
  }[action];
  requireThat(fields && Object.keys(input).every(k => fields.includes(k)), 400, 'INVALID_NOTIFICATION', 'Unsupported notification fields.');
  const time = s => typeof s === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(s);
  if (action === 'settings') requireThat(Number.isSafeInteger(input.expectedVersion) && input.expectedVersion >= 0 &&
    ['none', 'chime', 'bell', 'alert'].includes(input.sound) && typeof input.volume === 'number' && Number.isFinite(input.volume) &&
    input.volume >= 0 && input.volume <= 1 && time(input.deadlineCutoff) && time(input.dailyReminderTime),
  400, 'INVALID_NOTIFICATION', 'Choose sound, volume and valid local reminder times.');
  if (action === 'preferences') requireThat(fields.slice(0, 5).every(k => typeof input[k] === 'boolean') &&
    ((input.quietStart === '' && input.quietEnd === '') || time(input.quietStart) && time(input.quietEnd)),
  400, 'INVALID_NOTIFICATION', 'Choose categories and either both quiet-hour times or neither.');
  if (['register', 'unregister'].includes(action)) requireThat(typeof input.installationId === 'string' &&
    /^[A-Za-z0-9_-]{16,80}$/.test(input.installationId), 400, 'INVALID_NOTIFICATION', 'Invalid browser installation.');
  if (action === 'register') requireThat(typeof input.token === 'string' && /^[A-Za-z0-9:_-]{20,4096}$/.test(input.token),
    400, 'INVALID_NOTIFICATION', 'Invalid push registration.');
  if (action === 'read') requireThat((input.id === 'all' || /^[A-Za-z0-9_-]{43}$/.test(input.id)) && typeof input.read === 'boolean',
    400, 'INVALID_NOTIFICATION', 'Choose a notification and read state.');
  return input;
}

export function pushOutcome(status, body) {
  const code = body?.error?.details?.find(d => d['@type']?.endsWith('FcmError'))?.errorCode;
  if (code === 'UNREGISTERED') return 'INVALID';
  if (status >= 200 && status < 300) return 'DELIVERED';
  // Configuration errors and throttling must not deactivate valid registrations.
  if ([401, 403, 429].includes(status) || status >= 500) return 'RETRY';
  return 'FAILED';
}
