import { createHash } from 'node:crypto';
import { requireThat } from './errors.js';

export const MAX_DOCUMENT_BYTES = 5 * 1024 * 1024;
export const contentHash = bytes => createHash('sha256').update(bytes).digest('hex');
export function validateContent(bytes, mimeType) {
  requireThat(Buffer.isBuffer(bytes) && bytes.length > 0 && bytes.length <= MAX_DOCUMENT_BYTES,
    413, 'DOCUMENT_SIZE', 'Documents must contain between 1 byte and 5 MiB.');
  const matches = mimeType === 'image/png' ? bytes.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')) :
    mimeType === 'image/jpeg' ? bytes.length >= 4 && bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255 &&
      bytes.subarray(-2).equals(Buffer.from([255, 217])) :
    mimeType === 'application/pdf' ? bytes.subarray(0, 5).toString() === '%PDF-' && bytes.subarray(-1024).includes(Buffer.from('%%EOF')) : false;
  requireThat(matches, 415, 'DOCUMENT_TYPE', 'Upload a PNG, JPEG or PDF with matching content.');
  // This is format identification, not malware scanning or a full decoder.
}
export function decodeContent(input) {
  requireThat(typeof input === 'string' && input.length <= Math.ceil(MAX_DOCUMENT_BYTES / 3) * 4 &&
    input.length % 4 === 0 && /^[A-Za-z0-9+/]*={0,2}$/.test(input),
  400, 'INVALID_DOCUMENT', 'Use canonical base64 document data.');
  const bytes = Buffer.from(input, 'base64');
  requireThat(bytes.toString('base64') === input, 400, 'INVALID_DOCUMENT', 'Invalid document data.');
  return bytes;
}
