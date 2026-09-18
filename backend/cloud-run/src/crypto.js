import { createHash, randomBytes } from 'node:crypto';
export const opaque = () => randomBytes(32).toString('base64url');
export const digest = value => createHash('sha256').update(value).digest('hex');
export const challenge = value => createHash('sha256').update(value).digest('base64url');

// Phase 2 uses this boundary for refresh-token storage. AAD prevents swapping
// ciphertext between owners/companies. Neither keys nor plaintext go to clients.
export class RefreshTokenVault {
  constructor(kms, keyName) { this.kms = kms; this.keyName = keyName; }
  context(ownerId, companyId) { return Buffer.from(JSON.stringify(['tpc-refresh-v1', ownerId, companyId])); }
  async encrypt(token, ownerId, companyId) {
    const [result] = await this.kms.encrypt({ name: this.keyName, plaintext: Buffer.from(token),
      additionalAuthenticatedData: this.context(ownerId, companyId) });
    if (!result.ciphertext) throw new Error('KMS did not return ciphertext');
    return Buffer.from(result.ciphertext).toString('base64');
  }
  async decrypt(ciphertext, ownerId, companyId) {
    const [result] = await this.kms.decrypt({ name: this.keyName, ciphertext: Buffer.from(ciphertext, 'base64'),
      additionalAuthenticatedData: this.context(ownerId, companyId) });
    if (!result.plaintext) throw new Error('KMS did not return plaintext');
    return Buffer.from(result.plaintext).toString('utf8');
  }
}
