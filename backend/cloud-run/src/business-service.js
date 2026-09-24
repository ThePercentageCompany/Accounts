import { opaque, digest } from './crypto.js';
import { ApiError, requireThat } from './errors.js';
import { validateRelations } from './business-relations.js';
import { validateBusinessValues } from './business-values.js';
import { validateJournal } from './journal-policy.js';

const SYSTEM = new Set(['recordId', 'companyId', 'createdAt', 'createdBy', 'updatedAt', 'updatedBy',
  'recordVersion', 'syncStatus', 'isDeleted', 'idempotencyKey']);
const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{43}$/.test(value);
const validRecordId = (table, value) => validId(value) || (table === 'CompanyProfile' && value === 'company');
const validKey = value => typeof value === 'string' && /^[A-Za-z0-9_-]{16,128}$/.test(value);
const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';
const publicRecord = row => Object.fromEntries(Object.entries(row).filter(([key]) => key !== '_row' && key !== 'idempotencyKey'));

export class BusinessService {
  constructor({ accounts, sheets, now = Date.now }) { Object.assign(this, { accounts, sheets, now }); this.registry = accounts.registry; }
  owner(state, token, companyId, allowPending = false) {
    const owner = this.accounts.companyOwner(state, token, companyId), company = state.companies[companyId];
    requireThat(company.stage === 'READY', 409, company.stage === 'RECONNECT_REQUIRED' ? 'RECONNECT_REQUIRED' : 'WORKSPACE_NOT_READY', 'Company workspace is not ready.');
    requireThat(!company.employeeWrite, 409, 'EMPLOYEE_UPDATE_PENDING', 'Confirm the pending employee update first.');
    requireThat(!company.documentWrite, 409, 'DOCUMENT_WRITE_PENDING', 'Confirm the pending document upload first.');
    requireThat(allowPending || !company.businessWrite, 409, 'BUSINESS_WRITE_PENDING', 'A business update is being confirmed. Retry shortly.');
    return { owner, company };
  }
  values(tableName, input) {
    const table = this.sheets.table(tableName);
    requireThat(input && typeof input === 'object' && !Array.isArray(input), 400, 'INVALID_RECORD', 'Record values are required.');
    const allowed = new Set(table.headers.filter(key => !SYSTEM.has(key)));
    requireThat(Object.keys(input).length > 0 && Object.keys(input).every(key => allowed.has(key)),
      400, 'INVALID_RECORD', 'Record contains unsupported fields.');
    for (const value of Object.values(input)) requireThat(['string', 'number', 'boolean'].includes(typeof value) &&
      (typeof value !== 'number' || Number.isFinite(value)) && (typeof value !== 'string' || value.length <= 10000),
    400, 'INVALID_RECORD', 'Record fields must be bounded scalar values.');
    validateBusinessValues(input);
    return Object.fromEntries(Object.keys(input).sort().map(key => [key, input[key]]));
  }
  async sync(token, companyId, input) {
    this.owner((await this.registry.read()).state, token, companyId, true);
    requireThat(input && !Array.isArray(input) && Object.keys(input).length === 1 &&
      Array.isArray(input.operations) && input.operations.length > 0 && input.operations.length <= 20,
    400, 'INVALID_BATCH', 'Supply between 1 and 20 operations.');
    const seen = new Set();
    for (const op of input.operations) {
      requireThat(op && !Array.isArray(op) && Object.keys(op).every(k =>
        ['operationId', 'table', 'recordId', 'action', 'expectedVersion', 'values'].includes(k)) &&
        validKey(op.operationId) && !seen.has(op.operationId) && ['create', 'update', 'delete'].includes(op.action) &&
        Number.isSafeInteger(op.expectedVersion) && (op.action === 'create' ?
          op.expectedVersion === 0 && op.recordId === undefined : op.expectedVersion > 0 && validRecordId(op.table, op.recordId)),
      400, 'INVALID_BATCH', 'Invalid or duplicate operation.');
      this.sheets.table(op.table);
      if (op.action === 'delete') requireThat(!Object.hasOwn(op, 'values'), 400, 'INVALID_BATCH', 'Delete accepts no values.');
      else this.values(op.table, op.values);
      seen.add(op.operationId);
    }
    const results = [];
    let stopped = false;
    for (const op of input.operations) {
      if (stopped) { results.push({ operationId: op.operationId, status: 'NOT_ATTEMPTED' }); continue; }
      try {
        const value = await this.mutate(token, companyId, op.table, op.recordId ?? null, op.action,
          { expectedVersion: op.expectedVersion, ...(op.action === 'delete' ? {} : { values: op.values }) }, op.operationId);
        results.push({ operationId: op.operationId, status: 'APPLIED', ...value });
      } catch (error) {
        results.push({ operationId: op.operationId, status: 'FAILED',
          error: { code: error instanceof ApiError ? error.code : 'SERVICE_UNAVAILABLE',
            message: error instanceof ApiError ? error.message : 'Retry with the same operation IDs.' } });
        stopped = true;
      }
    }
    return { results };
  }
  async list(token, companyId, tableName, { includeDeleted = false } = {}) {
    this.sheets.table(tableName);
    this.owner((await this.registry.read()).state, token, companyId);
    const rows = (await this.sheets.read(companyId, [tableName]))[tableName];
    this.owner((await this.registry.read()).state, token, companyId);
    return rows.filter(row => includeDeleted || active(row)).map(row =>
      active(row) ? publicRecord(row) : { recordId: row.recordId, companyId,
        recordVersion: row.recordVersion, updatedAt: row.updatedAt, isDeleted: true });
  }
  async mutate(token, companyId, tableName, recordId, action, input, key) {
    this.sheets.table(tableName);
    requireThat(validKey(key), 400, 'IDEMPOTENCY_KEY_REQUIRED', 'Use one stable Idempotency-Key for each intended change.');
    requireThat(['create', 'update', 'delete'].includes(action), 400, 'INVALID_RECORD', 'Invalid record action.');
    const expectedVersion = input?.expectedVersion;
    requireThat(Number.isSafeInteger(expectedVersion) && expectedVersion >= 0 &&
      (action === 'create' ? recordId === null && expectedVersion === 0 : validRecordId(tableName, recordId) && expectedVersion > 0),
    400, 'INVALID_RECORD', 'Supply the correct record ID and expectedVersion.');
    const values = action === 'delete' ? {} : this.values(tableName, input.values);
    requireThat(tableName !== 'CompanyProfile' || (action === 'update' && recordId === 'company'),
      409, 'COMPANY_PROFILE_SINGLETON', 'Update the existing company profile. It cannot be created or deleted here.');
    requireThat(input && Object.keys(input).every(k => ['expectedVersion', 'values'].includes(k)) &&
      (action === 'delete' ? !Object.hasOwn(input, 'values') : true), 400, 'INVALID_RECORD', 'Unsupported mutation fields.');
    const proposedId = recordId || opaque(), fingerprint = digest(JSON.stringify({ tableName, recordId, action, expectedVersion, values }));
    const opKey = digest(`business:${companyId}:${key}`), marker = `business:${opKey}`, now = this.now(), reservation = opaque();
    try {
      let op = await this.registry.transact(state => {
        const { company } = this.owner(state, token, companyId, true); company.businessOps ??= {};
        const previous = company.businessOps[opKey];
        if (previous) { requireThat(previous.fingerprint === fingerprint, 409, 'IDEMPOTENCY_CONFLICT', 'This key was used for a different change.'); return structuredClone(previous); }
        requireThat(!company.businessWrite, 409, 'BUSINESS_WRITE_PENDING', 'Confirm the previous business update first.');
        company.businessWrite = opKey;
        return structuredClone(company.businessOps[opKey] = { tableName, recordId: proposedId, action, expectedVersion,
          resultVersion: expectedVersion + 1, fingerprint, reservation, submitted: false, completed: false, at: now });
      });
      if (op.completed) return { recordId: op.recordId, version: op.resultVersion, replayed: true };
      const rows = (await this.sheets.read(companyId, [tableName]))[tableName], old = rows.find(row => row.recordId === op.recordId);
      const confirmed = old?.idempotencyKey === marker && Number(old.recordVersion) === op.resultVersion;
      if (!confirmed) {
        requireThat(!op.submitted, 409, 'BUSINESS_WRITE_CONFIRMATION_PENDING', 'Confirming the previous write. Retry with the same key.');
        requireThat((Number(old?.recordVersion) || 0) === expectedVersion &&
          (action === 'create' ? !old : active(old)), 409, 'VERSION_CONFLICT', 'Record changed. Refresh before editing.');
        await validateRelations(this.sheets, companyId, tableName, op.recordId, action, { ...old, ...values });
        await validateJournal(this.sheets, companyId, tableName, op.recordId, action, old, values);
        const { state } = await this.registry.read(), actor = this.owner(state, token, companyId, true).owner.id;
        for (const field of ['documentId', 'logoDocumentId']) {
          if (!Object.hasOwn(values, field) || values[field] === '') continue;
          const document = state.companies[companyId].documents?.[values[field]];
          const targetTable = tableName === 'ExpenseAttachments' ? 'Expenses' : tableName;
          const targetId = tableName === 'ExpenseAttachments' ? (values.expenseId ?? old?.expenseId) : op.recordId;
          requireThat(document?.status === 'READY' && document.relatedSection === targetTable && document.relatedRecordId === targetId,
            409, 'DOCUMENT_REFERENCE_INVALID', 'Upload the document for this record before attaching it.');
        }
        const system = { recordId: op.recordId, companyId, createdAt: old?.createdAt || now, createdBy: old?.createdBy || actor,
          updatedAt: now, updatedBy: actor, recordVersion: op.resultVersion, syncStatus: 'SYNCED',
          isDeleted: action === 'delete', idempotencyKey: marker };
        const row = old?._row || Math.max(1, ...rows.map(item => item._row)) + 1;
        await this.registry.transact(state => { const { company } = this.owner(state, token, companyId, true);
          requireThat(company.businessWrite === opKey && company.businessOps[opKey]?.reservation === op.reservation && !company.businessOps[opKey].submitted, 409, 'BUSINESS_WRITE_PENDING', 'Business update changed.');
          company.businessOps[opKey].submitted = true; });
        try { await this.sheets.write(companyId, tableName, row, { ...system, ...values }); }
        catch (error) { if (error.definitelyNotSubmitted || error.definitelyRejected || (error.googleStatus >= 400 && error.googleStatus < 500))
          await this.registry.transact(state => { const company = state.companies[companyId]; if (company?.businessWrite === opKey) company.businessOps[opKey].submitted = false; });
          throw error; }
      }
      await this.registry.transact(state => { const { company } = this.owner(state, token, companyId, true), pending = company.businessOps[opKey];
        if (!pending.completed) { requireThat(company.businessWrite === opKey, 409, 'BUSINESS_WRITE_PENDING', 'Business update changed.'); pending.completed = true; delete company.businessWrite; } });
      return { recordId: op.recordId, version: op.resultVersion, replayed: confirmed };
    } catch (error) {
      await this.registry.transact(state => { const company = state.companies[companyId], op = company?.businessOps?.[opKey];
        if (company?.businessWrite === opKey && op?.reservation === reservation && !op.submitted && !op.completed) { delete company.businessWrite; delete company.businessOps[opKey]; } });
      throw error;
    }
  }
}
