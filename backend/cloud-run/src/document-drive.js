import { randomUUID } from 'node:crypto';
import { GoogleRequestError } from './google-workspace.js';
import { ReconnectRequired } from './google-connection.js';
import { requireThat } from './errors.js';
import { MAX_DOCUMENT_BYTES, contentHash } from './document-content.js';

export class DocumentDrive {
  constructor(google) { this.google = google; }
  async response(token, url, options = {}) {
    const response = await this.google.fetcher(url, { ...options, redirect: 'error', signal: AbortSignal.timeout(20_000),
      headers: { ...options.headers, Authorization: `Bearer ${token}` } });
    if (response.status === 401) throw new ReconnectRequired();
    if (response.status === 403) {
      const denied = await response.json().catch(() => ({}));
      const reasons = [...(denied.error?.errors || []), ...(denied.error?.details || [])].map(item => item.reason);
      if (reasons.includes('insufficientPermissions') || reasons.includes('ACCESS_TOKEN_SCOPE_INSUFFICIENT')) throw new ReconnectRequired();
    }
    if (!response.ok) throw new GoogleRequestError(response.status);
    return response;
  }
  async ensure(token, companyId, document, bytes) {
    let file = await this.google.file(token, document.fileId);
    if (!file) {
      const boundary = `tpc_${randomUUID()}`;
      const metadata = { id: document.fileId, name: document.name, mimeType: document.mimeType, parents: [document.folderId],
        appProperties: { tpcCompany: companyId, tpcOperation: document.id, tpcContentHash: document.hash } };
      const body = Buffer.concat([Buffer.from(`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(metadata)}\r\n--${boundary}\r\nContent-Type: ${document.mimeType}\r\n\r\n`),
        bytes, Buffer.from(`\r\n--${boundary}--\r\n`)]);
      try {
        await this.response(token, 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
          { method: 'POST', headers: { 'Content-Type': `multipart/related; boundary=${boundary}` }, body });
      } catch (error) { if (error.googleStatus !== 409) throw error; }
      file = await this.google.file(token, document.fileId);
    }
    this.validate(file, companyId, document);
  }
  validate(file, companyId, document) {
    this.google.validateFile(file, companyId, document.id, document.mimeType, document.folderId);
    requireThat(file.id === document.fileId && file.appProperties.tpcContentHash === document.hash,
      409, 'DOCUMENT_CHANGED', 'The stored document identity has changed.');
  }
  async download(token, companyId, document) {
    this.validate(await this.google.file(token, document.fileId), companyId, document);
    const response = await this.response(token, `https://www.googleapis.com/drive/v3/files/${encodeURIComponent(document.fileId)}?alt=media`);
    const reader = response.body.getReader(), chunks = []; let size = 0;
    try {
      for (;;) {
        const { done, value } = await reader.read(); if (done) break;
        size += value.byteLength;
        requireThat(size <= MAX_DOCUMENT_BYTES && size <= document.byteLength, 409, 'DOCUMENT_CHANGED', 'The stored document size has changed.');
        chunks.push(Buffer.from(value));
      }
    } finally { await reader.cancel(); }
    const bytes = Buffer.concat(chunks);
    requireThat(size === document.byteLength && contentHash(bytes) === document.hash,
      409, 'DOCUMENT_CHANGED', 'The stored document content has changed.');
    return bytes;
  }
}
