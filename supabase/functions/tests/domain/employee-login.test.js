import test from 'node:test';
import assert from 'node:assert/strict';
import { employeeLoginCode, employeeLoginPassword } from '../../_shared/domain/employee-login.js';

const secret = 'test-employee-secret-at-least-32-characters';

test('issued codes have four readable characters and retry deterministically', () => {
  const code = employeeLoginCode(secret, 'company', 'employee', 'operation');
  assert.match(code, /^[2-9A-HJ-NP-Z]{4}$/);
  assert.equal(employeeLoginCode(secret, 'company', 'employee', 'operation'), code);
  const codes = new Set(Array.from({ length: 100 }, (_, i) =>
    employeeLoginCode(secret, 'company', 'employee', `operation-${i}`)));
  assert.ok(codes.size > 90);
});

test('short code login uses the same full-length invitation-bound credential', () => {
  const code = employeeLoginCode(secret, 'company', 'employee', 'operation');
  const password = employeeLoginPassword(secret, 'invite', code);
  assert.match(password, /^[A-Za-z0-9_-]{43}$/);
  assert.equal(employeeLoginPassword(secret, 'invite', ` ${code.toLowerCase()} `), password);
  assert.notEqual(employeeLoginPassword(secret, 'other-invite', code), password);
  assert.notEqual(employeeLoginPassword('other-secret', 'invite', code), password);
  assert.notEqual(employeeLoginPassword(secret, 'invite', code === 'AAAA' ? 'BBBB' : 'AAAA'), password);
});

test('existing long codes retain their exact password', () => {
  const old = 'AbCdEf0123456789_-AbCdEf0123456789_-abcdefghij';
  assert.equal(employeeLoginPassword(secret, 'invite', old), old);
});
