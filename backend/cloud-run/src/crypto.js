import { createHash, randomBytes } from 'node:crypto';
import { crc32c, bytesFromProto, verifyCrc } from './integrity.js';
export const opaque = () => randomBytes(32).toString('base64url');
export const digest = value => createHash('sha256').update(value).digest('hex');
export const challenge = value => createHash('sha256').update(value).digest('base64url');

// Phase 2 uses this boundary for refresh-token storage. AAD prevents swapping
// ciphertext between owners/companies. Neither keys nor plaintext go to clients.
export class RefreshTokenVault {
  constructor(kms, keyName) { this.kms = kms; this.keyName = keyName; }
  context(ownerId, companyId) { return Buffer.from(JSON.stringify(['tpc-refresh-v1', ownerId, companyId])); }
  async encrypt(token, ownerId, companyId) {
    const plaintext = Buffer.from(token), aad = this.context(ownerId, companyId);
    const [result] = await this.kms.encrypt({ name: this.keyName, plaintext, plaintextCrc32c: { value: crc32c(plaintext) },
      additionalAuthenticatedData: aad, additionalAuthenticatedDataCrc32c: { value: crc32c(aad) } });
    if (!result.ciphertext || !result.verifiedPlaintextCrc32c || !result.verifiedAdditionalAuthenticatedDataCrc32c) {
      throw new Error('KMS encryption integrity verification failed');
    }
    const ciphertext = bytesFromProto(result.ciphertext);
    verifyCrc(ciphertext, result.ciphertextCrc32c);
    return ciphertext.toString('base64');
  }
  async decrypt(ciphertext, ownerId, companyId) {
    const bytes = Buffer.from(ciphertext, 'base64'), aad = this.context(ownerId, companyId);
    const [result] = await this.kms.decrypt({ name: this.keyName, ciphertext: bytes,
      ciphertextCrc32c: { value: crc32c(bytes) }, additionalAuthenticatedData: aad,
      additionalAuthenticatedDataCrc32c: { value: crc32c(aad) } });
    if (!result.plaintext) throw new Error('KMS did not return plaintext');
    const plaintext = bytesFromProto(result.plaintext);
    verifyCrc(plaintext, result.plaintextCrc32c);
    return plaintext.toString('utf8');
  }
}
