// Castagnoli CRC32C used by Secret Manager and Cloud KMS integrity checks.
export function crc32c(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0x82f63b78 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
export const bytesFromProto = value => typeof value === 'string' ? Buffer.from(value, 'base64') : Buffer.from(value);
export function verifyCrc(bytes, checksum) {
  if (checksum === undefined || checksum === null || crc32c(bytes) !== Number(checksum.value ?? checksum)) {
    throw new Error('Google payload integrity verification failed');
  }
}
export async function readOAuthSecret(client, versionName) {
  const [version] = await client.accessSecretVersion({ name: versionName });
  const bytes = bytesFromProto(version.payload.data);
  verifyCrc(bytes, version.payload.dataCrc32c);
  const secret = JSON.parse(bytes.toString('utf8'));
  if (typeof secret.clientSecret !== 'string' || !secret.clientSecret) throw new Error('OAuth secret is invalid');
  return secret.clientSecret;
}
