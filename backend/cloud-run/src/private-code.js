import { scrypt, randomBytes, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { ApiError } from './errors.js';
const derive = promisify(scrypt);
const options = { N: 131072, r: 8, p: 1, maxmem: 192 * 1024 * 1024 };
// Bounds per-instance memory use; distributed attempt budgets live in the registry.
let active = 0;
async function hash(value, salt) {
  if (active >= 2) throw new ApiError(503, 'LOGIN_BUSY', 'Please try signing in again shortly.');
  active++;
  try { return await derive(value, salt, 32, options); } finally { active--; }
}
export class PrivateCode {
  async create() {
    const code = randomBytes(18).toString('base64url'), salt = randomBytes(32).toString('base64url');
    return { code, credential: { algorithm: 'scrypt-131072-8-1', salt, hash: (await hash(code, salt)).toString('base64') } };
  }
  async verify(code, credential) {
    if (credential?.algorithm !== 'scrypt-131072-8-1' || typeof code !== 'string' || code.length > 128) return false;
    const expected = Buffer.from(credential.hash, 'base64');
    const actual = await hash(code, credential.salt);
    return expected.length === actual.length && timingSafeEqual(expected, actual);
  }
}
