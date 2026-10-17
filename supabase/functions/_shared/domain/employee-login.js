import { createHmac } from 'node:crypto';

const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

export function employeeLoginCode(secret, companyId, employeeId, operationKey) {
  const bytes = createHmac('sha256', secret)
    .update(JSON.stringify(['employee-code-v1', companyId, employeeId, operationKey]))
    .digest();
  return Array.from(bytes.subarray(0, 4), byte => alphabet[byte % alphabet.length]).join('');
}

export function employeeLoginPassword(secret, inviteId, code) {
  const normalized = code.trim().toUpperCase();
  // Preserve existing invitations, whose long code is the Auth password.
  if (!/^[A-Z0-9]{4}$/.test(normalized)) return code;
  // Auth receives a full-length credential bound to this invitation.
  return createHmac('sha256', secret)
    .update(JSON.stringify(['employee-password-v1', inviteId, normalized]))
    .digest('base64url');
}
