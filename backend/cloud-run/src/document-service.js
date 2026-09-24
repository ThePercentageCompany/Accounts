import { opaque, digest } from './crypto.js';
import { requireThat } from './errors.js';
import { TABLES } from './company-schema.js';
import { BusinessSheets } from './business-sheets.js';
import { decodeContent, validateContent, contentHash } from './document-content.js';

const FOLDERS = { CompanyProfile: 'Company Logo', Invoices: 'Invoices', Receipts: 'Receipts', Quotations: 'Quotations',
  Expenses: 'Expenses', Employees: 'Employee Documents', Payslips: 'Payslips', Assets: 'Assets' };
const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';
export class DocumentSheets extends BusinessSheets {
  table(name) {
    requireThat(name === 'DocumentRegistry', 403, 'TABLE_FORBIDDEN', 'Only document metadata is available.');
    return TABLES.find(t => t.title === name);
  }
}
export class DocumentService {
  constructor({ accounts, business, employees, workspace, google, drive, sheets, now = Date.now }) {
    Object.assign(this, { accounts, business, employees, workspace, google, drive, sheets, now }); this.registry = accounts.registry;
  }
  owner(state, token, companyId, operation) {
    this.accounts.companyOwner(state, token, companyId);
    const c = state.companies[companyId];
    requireThat(c.stage === 'READY', 409, 'WORKSPACE_NOT_READY', 'The company workspace is not ready.');
    requireThat(!c.businessWrite && !c.employeeWrite && (!c.documentWrite || c.documentWrite === operation),
      409, 'DOCUMENT_WRITE_PENDING', 'Confirm the pending company update first.');
    return c;
  }
  async target(companyId, table, id) {
    const rows = await this.business.sheets.readReferences(companyId, [table]);
    requireThat(rows[table].some(row => row.recordId === id && row.companyId === companyId && active(row)),
      404, 'DOCUMENT_RECORD_NOT_FOUND', 'The document record is unavailable.');
  }
  async upload(token, companyId, input, key) {
    this.owner((await this.registry.read()).state, token, companyId, digest(`document:${key}`));
    requireThat(typeof key === 'string' && /^[A-Za-z0-9_-]{16,128}$/.test(key), 400, 'IDEMPOTENCY_KEY_REQUIRED', 'Use a stable upload key.');
    requireThat(input && Object.keys(input).length === 5 && ['name', 'mimeType', 'relatedSection', 'relatedRecordId', 'data'].every(k => Object.hasOwn(input, k)) &&
      Object.hasOwn(FOLDERS, input.relatedSection) && typeof input.name === 'string' && input.name.length > 0 && input.name.length <= 160 &&
      !/[\x00-\x1f\x7f/\\]/.test(input.name) && typeof input.relatedRecordId === 'string' &&
      (/^[A-Za-z0-9_-]{43}$/.test(input.relatedRecordId) || (input.relatedSection === 'CompanyProfile' && input.relatedRecordId === 'company')),
    400, 'INVALID_DOCUMENT', 'Supply a name, MIME type, related record and data.');
    const bytes = decodeContent(input.data); validateContent(bytes, input.mimeType);
    requireThat(input.relatedSection !== 'CompanyProfile' || input.mimeType.startsWith('image/'), 415, 'DOCUMENT_TYPE', 'Company logos must be PNG or JPEG.');
    const operation = digest(`document:${key}`), hash = contentHash(bytes), id = opaque();
    const metadata = { name: input.name, mimeType: input.mimeType, relatedSection: input.relatedSection,
      relatedRecordId: input.relatedRecordId, byteLength: bytes.length, hash };
    const fingerprint = digest(JSON.stringify(metadata));
    await this.target(companyId, input.relatedSection, input.relatedRecordId);
    let doc = await this.registry.transact(state => {
      const c = this.owner(state, token, companyId, operation); c.documentOps ??= {}; c.documents ??= {};
      const previous = c.documentOps[operation];
      if (previous) {
        requireThat(previous.fingerprint === fingerprint, 409, 'IDEMPOTENCY_CONFLICT', 'This key belongs to a different upload.');
        return structuredClone(c.documents[previous.id]);
      }
      const folderId = c.resources.folders[FOLDERS[input.relatedSection]];
      requireThat(folderId, 409, 'WORKSPACE_NOT_READY', 'The document folder is unavailable.');
      c.documentWrite = operation; c.documentOps[operation] = { id, fingerprint };
      return structuredClone(c.documents[id] = { ...metadata, id, folderId, createdAt: this.now(),
        createdBy: this.accounts.companyOwner(state, token, companyId).id, status: 'PENDING' });
    });
    if (doc.status === 'READY') return { documentId: doc.id, replayed: true };
    // The target could have changed between the first read and acquiring the
    // company write reservation. Re-read while competing mutations are blocked.
    try { await this.target(companyId, doc.relatedSection, doc.relatedRecordId); }
    catch (error) {
      await this.registry.transact(state => {
        const c = state.companies[companyId], current = c?.documents?.[doc.id];
        if (c?.documentWrite === operation && current && !current.fileId) {
          delete c.documentWrite; delete c.documentOps[operation]; delete c.documents[doc.id];
        }
      });
      throw error;
    }
    if (!doc.fileId) {
      const [fileId] = await this.workspace.withGoogle(companyId, access => this.google.generateFolderIds(access, 1));
      doc = await this.registry.transact(state => {
        const c = this.owner(state, token, companyId, operation), current = c.documents[doc.id];
        current.fileId ??= fileId; return structuredClone(current);
      });
    }
    await this.workspace.withGoogle(companyId, access => this.drive.ensure(access, companyId, doc, bytes));
    if (!doc.row) {
      const rows = (await this.sheets.read(companyId, ['DocumentRegistry'])).DocumentRegistry;
      const row = Math.max(1, ...rows.map(r => r._row)) + 1;
      doc = await this.registry.transact(state => {
        const c = this.owner(state, token, companyId, operation), current = c.documents[doc.id];
        current.row ??= row; return structuredClone(current);
      });
    }
    // Identical retries target one durable row and one pre-generated Drive ID.
    await this.sheets.write(companyId, 'DocumentRegistry', doc.row, { recordId: doc.id, companyId,
      createdAt: doc.createdAt, createdBy: doc.createdBy, updatedAt: doc.createdAt, updatedBy: doc.createdBy,
      recordVersion: 1, syncStatus: 'SYNCED', isDeleted: false, idempotencyKey: `document:${operation}`,
      kind: FOLDERS[doc.relatedSection], name: doc.name, mimeType: doc.mimeType, byteLength: doc.byteLength,
      relatedSection: doc.relatedSection, relatedRecordId: doc.relatedRecordId, status: 'READY' });
    await this.registry.transact(state => {
      const c = this.owner(state, token, companyId, operation); c.documents[doc.id].status = 'READY';
      if (c.documentWrite === operation) delete c.documentWrite;
    });
    return { documentId: doc.id, replayed: false };
  }
  async download(token, companyId, documentId, employee = false) {
    const authorize = async () => {
      const state = (await this.registry.read()).state;
      if (employee) requireThat((await this.employees.principal(token)).companyId === companyId, 403, 'DOCUMENT_FORBIDDEN', 'Document unavailable.');
      else this.owner(state, token, companyId);
      const doc = state.companies[companyId]?.documents?.[documentId];
      requireThat(doc?.status === 'READY', 404, 'DOCUMENT_NOT_FOUND', 'Document unavailable.');
      if (employee) requireThat((await this.employees.records(token, doc.relatedSection)).some(r => r.recordId === doc.relatedRecordId),
        403, 'DOCUMENT_FORBIDDEN', 'Document unavailable.');
      else await this.target(companyId, doc.relatedSection, doc.relatedRecordId);
      const row = (await this.sheets.read(companyId, ['DocumentRegistry'])).DocumentRegistry.find(r => r.recordId === documentId);
      requireThat(active(row) && row.status === 'READY' && row.relatedSection === doc.relatedSection && row.relatedRecordId === doc.relatedRecordId,
        404, 'DOCUMENT_NOT_FOUND', 'Document unavailable.');
      return doc;
    };
    const doc = await authorize();
    const bytes = await this.workspace.withGoogle(companyId, access => this.drive.download(access, companyId, doc));
    await authorize();
    return { bytes, mimeType: doc.mimeType, name: doc.name };
  }
}
