import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from './helpers.js';
import { DocumentService } from '../src/document-service.js';
import { contentHash, decodeContent, validateContent, MAX_DOCUMENT_BYTES } from '../src/document-content.js';
import { DocumentDrive } from '../src/document-drive.js';

const bytes = Buffer.from('%PDF-1.7\nDocument\n%%EOF');
const input = { name: 'invoice.pdf', mimeType: 'application/pdf', relatedSection: 'Invoices', relatedRecordId: 'r'.repeat(43), data: bytes.toString('base64') };
async function setup() {
  const f = fixture(), token = await f.login();
  const companyId = (await f.service.createCompany(token, { name: 'Docs' }, 'company_documents_001')).company.companyId;
  await f.registry.transact(state => { Object.assign(state.companies[companyId], { stage: 'READY', resources: { folders: { Invoices: 'private-folder' } } }); });
  const rows = [], files = new Map(); let ids = 0, writes = 0;
  const business = { sheets: { async readReferences(id, names) { assert.equal(id, companyId); return { [names[0]]: [{ recordId: input.relatedRecordId, companyId }] }; } } };
  const sheets = { async read() { return { DocumentRegistry: structuredClone(rows) }; }, async write(id, table, row, values) {
    assert.equal(id, companyId); assert.equal(table, 'DocumentRegistry'); writes++;
    rows[row - 2] = { ...values, _row: row };
  } };
  const workspace = { async withGoogle(id, fn) { assert.equal(id, companyId); return fn('google-token'); } };
  const google = { async generateFolderIds() { return [`file-${++ids}`]; } };
  const drive = { async ensure(access, id, doc, data) { assert.equal(id, companyId); files.set(doc.fileId, data); },
    async download(access, id, doc) { return files.get(doc.fileId); } };
  const employees = { async principal() { return { companyId }; }, async records() { return [{ recordId: input.relatedRecordId }]; } };
  const documents = new DocumentService({ accounts: f.service, business, employees, workspace, google, drive, sheets });
  return { ...f, token, companyId, documents, drive, files, rows, sheets, employees, stats: () => ({ ids, writes }) };
}
test('document upload returns opaque identity, persists metadata and replays without new files', async () => {
  const f = await setup(), key = 'document_upload_0001';
  const result = await f.documents.upload(f.token, f.companyId, input, key);
  assert.match(result.documentId, /^[A-Za-z0-9_-]{43}$/);
  assert.deepEqual(await f.documents.upload(f.token, f.companyId, input, key), { ...result, replayed: true });
  assert.deepEqual(f.stats(), { ids: 1, writes: 1 });
  assert.equal(f.rows[0].relatedRecordId, input.relatedRecordId);
  assert.equal(f.rows[0].driveFileId, undefined);
  assert.equal(f.files.size, 1);
  const downloaded = await f.documents.download(f.token, f.companyId, result.documentId);
  assert.deepEqual(downloaded.bytes, bytes);
  await assert.rejects(() => f.documents.upload(f.token, f.companyId, { ...input, name: 'other.pdf' }, key), e => e.code === 'IDEMPOTENCY_CONFLICT');
});
test('uncertain Drive and Sheets outcomes reuse durable file and row identities', async () => {
  const f = await setup(), key = 'document_upload_0002', original = f.drive.ensure;
  f.drive.ensure = async (...args) => { await original(...args); throw Error('lost upload response'); };
  await assert.rejects(() => f.documents.upload(f.token, f.companyId, input, key));
  assert.equal(f.files.size, 1);
  f.drive.ensure = original;
  const write = f.sheets.write;
  f.sheets.write = async (...args) => { await write(...args); throw Error('lost metadata response'); };
  await assert.rejects(() => f.documents.upload(f.token, f.companyId, input, key));
  f.sheets.write = write;
  await f.documents.upload(f.token, f.companyId, input, key);
  assert.equal(f.rows.length, 1); assert.equal(f.files.size, 1); assert.equal(f.stats().ids, 1);
  assert.equal(f.storage.state.companies[f.companyId].documentWrite, undefined);
});
test('document access rejects other owners, other tenants, removed records and changed permissions', async () => {
  const f = await setup(), other = await f.login('other');
  await assert.rejects(() => f.documents.upload(other, f.companyId, input, 'document_upload_0003'), e => e.code === 'COMPANY_NOT_FOUND');
  const result = await f.documents.upload(f.token, f.companyId, input, 'document_upload_0003');
  await assert.rejects(() => f.documents.download(other, f.companyId, result.documentId), e => e.code === 'COMPANY_NOT_FOUND');
  f.employees.principal = async () => ({ companyId: 'other' });
  await assert.rejects(() => f.documents.download('employee', f.companyId, result.documentId, true), e => e.code === 'DOCUMENT_FORBIDDEN');
  f.employees.principal = async () => ({ companyId: f.companyId });
  f.employees.records = async () => [];
  await assert.rejects(() => f.documents.download('employee', f.companyId, result.documentId, true), e => e.code === 'DOCUMENT_FORBIDDEN');
  f.rows[0].isDeleted = true;
  await assert.rejects(() => f.documents.download(f.token, f.companyId, result.documentId), e => e.code === 'DOCUMENT_NOT_FOUND');
});
test('download rechecks authorization after fetching private content', async () => {
  const f = await setup(), result = await f.documents.upload(f.token, f.companyId, input, 'document_upload_0004');
  f.drive.download = async () => { await f.service.logout(f.token); return bytes; };
  await assert.rejects(() => f.documents.download(f.token, f.companyId, result.documentId));
});
test('content parsing rejects unsupported formats, malformed base64 and oversized files', () => {
  validateContent(bytes, 'application/pdf');
  assert.throws(() => validateContent(bytes, 'image/png'));
  assert.throws(() => validateContent(Buffer.from('<svg/>'), 'image/svg+xml'));
  assert.throws(() => decodeContent('%%%=')); assert.throws(() => decodeContent('AB=='));
  const large = Buffer.alloc(MAX_DOCUMENT_BYTES); large.write('%PDF-'); large.write('%%EOF', large.length - 5);
  assert.deepEqual(decodeContent(large.toString('base64')), large);
  assert.throws(() => validateContent(Buffer.alloc(MAX_DOCUMENT_BYTES + 1), 'application/pdf'));
});
test('Drive download detects changed bytes and bounds streamed content', async () => {
  const doc = { fileId: 'file-1', id: 'document', mimeType: 'application/pdf', folderId: 'folder', hash: contentHash(bytes), byteLength: bytes.length };
  const file = { id: doc.fileId, appProperties: { tpcContentHash: doc.hash } };
  let data = bytes;
  const google = { async file() { return file; }, validateFile() {}, async fetcher() { return new Response(data); } };
  const drive = new DocumentDrive(google);
  assert.deepEqual(await drive.download('token', 'company', doc), bytes);
  data = Buffer.alloc(bytes.length, 1);
  await assert.rejects(() => drive.download('token', 'company', doc), e => e.code === 'DOCUMENT_CHANGED');
  data = Buffer.alloc(bytes.length + 1);
  await assert.rejects(() => drive.download('token', 'company', doc), e => e.code === 'DOCUMENT_CHANGED');
});
