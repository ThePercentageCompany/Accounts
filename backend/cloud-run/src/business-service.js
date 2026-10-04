import { opaque, digest } from './crypto.js';
import { ApiError, requireThat } from './errors.js';
import { validateRelations } from './business-relations.js';
import { validateBusinessValues } from './business-values.js';
import { validateJournal } from './journal-policy.js';
import { cashEntryValues, assertCashEntryEditable } from './cash-entry-policy.js';
import { financialPeriodValues } from './financial-period-policy.js';
import { cashLedgerChanges, reverseCashChanges } from './cash-ledger.js';
import { trialBalance, profitAndLoss, balanceSheet, dashboard, generalLedger } from './ledger-report.js';
import { invoiceChanges } from './invoice-policy.js';
import { receiptChanges, receiptInput } from './receipt-policy.js';
import { quotationChanges } from './quotation-policy.js';
import { payrollChanges } from './payroll-policy.js';
import { assetChanges } from './asset-policy.js';
import { capitalChanges } from './capital-policy.js';
import { draftItems } from './document-draft.js';
import { returnInput } from './invoice-return.js';

const SYSTEM = new Set(['recordId', 'companyId', 'createdAt', 'createdBy', 'updatedAt', 'updatedBy',
  'recordVersion', 'syncStatus', 'isDeleted', 'idempotencyKey']);
const validId = value => typeof value === 'string' && /^[A-Za-z0-9_-]{43}$/.test(value);
const validRecordId = (table, value) => validId(value) || (table === 'CompanyProfile' && value === 'company');
const validKey = value => typeof value === 'string' && /^[A-Za-z0-9_-]{16,128}$/.test(value);
const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';
const publicRecord = row => Object.fromEntries(Object.entries(row).filter(([key]) => key !== '_row' && key !== 'idempotencyKey'));

export class BusinessService {
  constructor({ accounts, sheets, now = Date.now, authorizeWrite = async () => {} }) { Object.assign(this, { accounts, sheets, now, authorizeWrite }); this.registry = accounts.registry; }
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
    if (['Invoices', 'Quotations'].includes(tableName) && Object.hasOwn(input, 'items')) {
      const { items, ...header } = input;
      // Normalize and validate the complete document before reserving a write.
      return { ...this.values(tableName, header), items: draftItems(items).map(({ lineNumber, ...line }) => line) };
    }
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
        validKey(op.operationId) && !seen.has(op.operationId) && ['create', 'update', 'delete', 'post', 'pay', 'reverse', 'issue', 'invoiceVoid', 'invoiceReturn', 'receive', 'receiptReverse', 'send', 'convert', 'approve', 'payrollPay', 'payrollReverse', 'capitalize', 'depreciate', 'assetDispose', 'capitalPost', 'loanPost', 'loanRepay'].includes(op.action) &&
        Number.isSafeInteger(op.expectedVersion) && (['create', 'receive'].includes(op.action) ?
          op.expectedVersion === 0 && op.recordId === undefined : op.expectedVersion > 0 && validRecordId(op.table, op.recordId)),
      400, 'INVALID_BATCH', 'Invalid or duplicate operation.');
      this.sheets.table(op.table);
      if (['delete', 'post', 'issue', 'send', 'convert', 'approve', 'capitalize', 'capitalPost', 'loanPost'].includes(op.action)) requireThat(!Object.hasOwn(op, 'values') &&
        (op.action !== 'post' || ['Income', 'Expenses'].includes(op.table)), 400, 'INVALID_BATCH', 'Invalid posting or deletion.');
      else if (op.action === 'receive') receiptInput(op.values);
      else if (op.action === 'invoiceReturn') returnInput(op.values);
      else this.values(op.table, op.values);
      seen.add(op.operationId);
    }
    const results = [];
    let stopped = false;
    for (const op of input.operations) {
      if (stopped) { results.push({ operationId: op.operationId, status: 'NOT_ATTEMPTED' }); continue; }
      try {
        const value = await this.mutate(token, companyId, op.table, op.recordId ?? null, op.action,
          { expectedVersion: op.expectedVersion, ...(['delete', 'post', 'issue', 'send', 'convert', 'approve', 'capitalize', 'capitalPost', 'loanPost'].includes(op.action) ? {} : { values: op.values }) }, op.operationId);
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
    const journals = ['Income', 'Expenses'].includes(tableName) ?
      (await this.sheets.read(companyId, ['Journals'])).Journals : [];
    const invoiceParents = tableName === 'InvoiceItems' ?
      (await this.sheets.read(companyId, ['Invoices'])).Invoices : [];
    const quotationParents = tableName === 'QuotationItems' ?
      (await this.sheets.read(companyId, ['Quotations'])).Quotations : [];
    const types = tableName === 'Income' ? ['Income', 'finance_income'] : ['Expenses', 'expense', 'supplier_bill'];
    this.owner((await this.registry.read()).state, token, companyId);
    return rows.filter(row => includeDeleted || active(row)).map(row =>
      active(row) ? { ...publicRecord(row), ...(tableName === 'InvoiceItems' ? {
        parentStatus: invoiceParents.find(invoice => invoice.recordId === row.invoiceId && active(invoice))?.status ?? 'UNAVAILABLE',
      } : tableName === 'QuotationItems' ? {
        parentStatus: quotationParents.find(quotation => quotation.recordId === row.quotationId && active(quotation))?.status ?? 'UNAVAILABLE',
      } : {}), ...(['Income', 'Expenses'].includes(tableName) ? {
        ledgerStatus: journals.some(j => j.companyId === companyId && active(j) &&
          j.sourceId === row.recordId && j.sourceType === `${tableName}Reversal`) ? 'REVERSED' : journals.some(j => j.companyId === companyId && active(j) &&
          j.sourceId === row.recordId && types.includes(j.sourceType)) ? 'LINKED' : 'UNPOSTED',
      } : {}) } : { recordId: row.recordId, companyId,
        recordVersion: row.recordVersion, updatedAt: row.updatedAt, isDeleted: true });
  }
  async trialBalance(token, companyId, asOf) {
    this.owner((await this.registry.read()).state, token, companyId);
    const data = await this.sheets.read(companyId, ['Journals', 'JournalLines']);
    this.owner((await this.registry.read()).state, token, companyId);
    return trialBalance(companyId, asOf, data);
  }
  async report(token, companyId, kind, from, asOf) {
    this.owner((await this.registry.read()).state, token, companyId);
    const data = await this.sheets.read(companyId, ['Journals', 'JournalLines']);
    this.owner((await this.registry.read()).state, token, companyId);
    return (kind === 'dashboard' ? dashboard : generalLedger)(companyId, from, asOf, data);
  }
  async balanceSheet(token, companyId, asOf) {
    this.owner((await this.registry.read()).state, token, companyId);
    const data = await this.sheets.read(companyId, ['Journals', 'JournalLines']);
    this.owner((await this.registry.read()).state, token, companyId);
    return balanceSheet(companyId, asOf, data);
  }
  async profitAndLoss(token, companyId, from, asOf) {
    this.owner((await this.registry.read()).state, token, companyId);
    const data = await this.sheets.read(companyId, ['Journals', 'JournalLines']);
    this.owner((await this.registry.read()).state, token, companyId);
    return profitAndLoss(companyId, from, asOf, data);
  }
  async mutate(token, companyId, tableName, recordId, action, input, key) {
    requireThat(!['CreditNotes', 'CreditNoteItems'].includes(tableName), 409,
      'CREDIT_NOTE_LOCKED', 'Credit notes are created only through an issued invoice return.');
    this.sheets.table(tableName);
    await this.authorizeWrite(token, companyId, tableName);
    requireThat(validKey(key), 400, 'IDEMPOTENCY_KEY_REQUIRED', 'Use one stable Idempotency-Key for each intended change.');
    requireThat(['create', 'update', 'delete', 'post', 'pay', 'reverse', 'issue', 'invoiceVoid', 'invoiceReturn', 'receive', 'receiptReverse', 'send', 'convert', 'approve', 'payrollPay', 'payrollReverse', 'capitalize', 'depreciate', 'assetDispose', 'capitalPost', 'loanPost', 'loanRepay'].includes(action) &&
      (!['post', 'pay', 'reverse'].includes(action) || ['Income', 'Expenses'].includes(tableName)), 400, 'INVALID_RECORD', 'Invalid record action.');
    const expectedVersion = input?.expectedVersion;
    requireThat(Number.isSafeInteger(expectedVersion) && expectedVersion >= 0 &&
      (['create', 'receive'].includes(action) ? recordId === null && expectedVersion === 0 : validRecordId(tableName, recordId) && expectedVersion > 0),
    400, 'INVALID_RECORD', 'Supply the correct record ID and expectedVersion.');
    requireThat(action !== 'issue' || tableName === 'Invoices', 400, 'INVALID_RECORD', 'Only invoices can be issued.');
    requireThat(!['invoiceVoid', 'invoiceReturn'].includes(action) || tableName === 'Invoices', 400, 'INVALID_RECORD', 'Only invoices can be voided.');
    requireThat(action !== 'receive' || tableName === 'Receipts', 400, 'INVALID_RECORD', 'Only receipts can record a payment.');
    requireThat(action !== 'receiptReverse' || tableName === 'Receipts', 400, 'INVALID_RECORD', 'Only receipts support receipt reversal.');
    requireThat(!['send', 'convert'].includes(action) || tableName === 'Quotations', 400, 'INVALID_RECORD', 'Only quotations support this action.');
    requireThat(!['approve', 'payrollPay', 'payrollReverse'].includes(action) || tableName === 'Payroll', 400, 'INVALID_RECORD', 'Only payroll supports this action.');
    requireThat(!['capitalize', 'depreciate', 'assetDispose'].includes(action) || tableName === 'Assets', 400, 'INVALID_RECORD', 'Only assets support this action.');
    requireThat(action !== 'capitalPost' || tableName === 'CapitalTransactions', 400, 'INVALID_RECORD', 'Only capital contributions support this action.');
    requireThat(!['loanPost', 'loanRepay'].includes(action) || tableName === 'ShareholderLoans', 400, 'INVALID_RECORD', 'Only shareholder loans support this action.');
    const values = ['delete', 'post', 'issue', 'send', 'convert', 'approve', 'capitalize', 'capitalPost', 'loanPost'].includes(action) ? {} : action === 'receive' ? receiptInput(input.values) : action === 'invoiceReturn' ? returnInput(input.values) : this.values(tableName, input.values);
    if (Object.hasOwn(values, 'items')) {
      requireThat(['create', 'update'].includes(action), 400, 'INVALID_DOCUMENT_ITEMS', 'Only draft creation or editing accepts lines.');
      await this.authorizeWrite(token, companyId, tableName === 'Invoices' ? 'InvoiceItems' : 'QuotationItems');
    }
    if (action === 'reverse') requireThat(Object.keys(values).every(k => ['date', 'description'].includes(k)) &&
      typeof values.date === 'string' && typeof values.description === 'string' &&
      values.description.trim().length > 0 && values.description.length <= 500,
    400, 'INVALID_REVERSAL', 'Supply a reversal date and reason of up to 500 characters.');
    if (action === 'pay') requireThat(Object.keys(values).every(k => ['paidDate', 'account', 'reference'].includes(k)) &&
      typeof values.paidDate === 'string' && typeof values.account === 'string',
    400, 'INVALID_PAYMENT', 'Supply only the payment date, Cash/Bank account and optional reference.');
    requireThat(tableName !== 'CompanyProfile' || (action === 'update' && recordId === 'company'),
      409, 'COMPANY_PROFILE_SINGLETON', 'Update the existing company profile. It cannot be created or deleted here.');
    requireThat(input && Object.keys(input).every(k => ['expectedVersion', 'values'].includes(k)) &&
      (['delete', 'post', 'issue', 'send', 'convert', 'approve', 'capitalize', 'capitalPost', 'loanPost'].includes(action) ? !Object.hasOwn(input, 'values') : true), 400, 'INVALID_RECORD', 'Unsupported mutation fields.');
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
          (['create', 'receive'].includes(action) ? !old : active(old)), 409, 'VERSION_CONFLICT', 'Record changed. Refresh before editing.');
        if (tableName === 'CompanyProfile') {
          const profile = { ...old, ...values };
          requireThat(typeof profile.name === 'string' && profile.name.trim().length > 0 && profile.name.length <= 200 &&
            ['invoicePrefix', 'quotationPrefix'].every(k => !profile[k] || /^[A-Z0-9-]{1,12}$/.test(profile[k])) &&
            (!profile.email || /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(profile.email)),
          400, 'INVALID_COMPANY_PROFILE', 'Supply a company name, valid email and uppercase document prefixes.');
          if (Object.hasOwn(values, 'currency') && values.currency !== old.currency && old.currency) {
            const data = await this.sheets.read(companyId, ['Journals']);
            requireThat(!data.Journals.some(j => j.companyId === companyId && active(j) && j.status === 'POSTED'),
              409, 'COMPANY_CURRENCY_LOCKED', 'Accounting currency cannot change after posting journals.');
          }
        }
        await validateRelations(this.sheets, companyId, tableName, op.recordId, action, { ...old, ...values });
        if (values.items?.some(item => item.productId)) {
          const products = (await this.sheets.read(companyId, ['ProductsServices'])).ProductsServices;
          requireThat(values.items.every(item => !item.productId || products.some(product =>
            product.companyId === companyId && product.recordId === item.productId && active(product))),
          400, 'INVALID_DOCUMENT_ITEMS', 'A referenced product is missing or deleted in this company.');
        }
        await validateJournal(this.sheets, companyId, tableName, op.recordId, action, old, values);
        if (!['pay', 'reverse'].includes(action)) await assertCashEntryEditable(this.sheets, companyId, tableName, op.recordId, action);
        if (action === 'pay') requireThat(old.paymentStatus === 'UNPAID', 409, 'PAYMENT_NOT_AVAILABLE', 'Only an unpaid posted entry can be paid.');
        let writeValues = action === 'reverse' ? {} : cashEntryValues(tableName, action, old, action === 'pay' ? { ...values, paymentStatus: 'PAID' } : values);
        if (action === 'pay') requireThat(old.total === writeValues.total && old.taxAmount === writeValues.taxAmount,
          409, 'PAYMENT_NOT_AVAILABLE', 'The saved totals need reconciliation before payment.');
        const { state } = await this.registry.read(), actor = this.owner(state, token, companyId, true).owner.id;
        writeValues = await financialPeriodValues(this.sheets, companyId, tableName, op.recordId, action, old, writeValues, actor, now);
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
        const invoice = await invoiceChanges(this.sheets, companyId, tableName, op.recordId, action, old, writeValues, system, opKey);
        writeValues = invoice.values;
        const receipt = await receiptChanges(this.sheets, companyId, tableName, op.recordId, action, old, writeValues, system, opKey);
        writeValues = receipt.values;
        const quotation = await quotationChanges(this.sheets, companyId, tableName, op.recordId, action, old, writeValues, system, opKey);
        writeValues = quotation.values;
        const payroll = await payrollChanges(this.sheets, companyId, tableName, op.recordId, action, old, writeValues, system, opKey);
        writeValues = payroll.values;
        const asset = await assetChanges(this.sheets, companyId, tableName, op.recordId, action, old, writeValues, system, opKey);
        writeValues = asset.values;
        const capital = await capitalChanges(this.sheets, companyId, tableName, op.recordId, action, old, writeValues, system, opKey);
        writeValues = capital.values;
        const ledger = action === 'reverse' ? await reverseCashChanges(this.sheets, companyId, tableName,
          old, { ...system, createdAt: now, createdBy: actor }, opKey, values) : ['post', 'pay'].includes(action) ? await cashLedgerChanges(this.sheets, companyId, tableName,
          { ...old, ...writeValues }, { ...system, createdAt: now, createdBy: actor }, opKey, action === 'pay') : null;
        await this.authorizeWrite(token, companyId, tableName);
        if (Object.hasOwn(values, 'items')) await this.authorizeWrite(token, companyId,
          tableName === 'Invoices' ? 'InvoiceItems' : 'QuotationItems');
        await this.registry.transact(state => { const { company } = this.owner(state, token, companyId, true);
          requireThat(company.businessWrite === opKey && company.businessOps[opKey]?.reservation === op.reservation && !company.businessOps[opKey].submitted, 409, 'BUSINESS_WRITE_PENDING', 'Business update changed.');
          company.businessOps[opKey].submitted = true; });
        try {
          if (ledger) await this.sheets.writeBatch(companyId, [{ table: tableName, row, values: { ...system, ...writeValues } }, ...ledger]);
          else if (invoice.extra.length || receipt.extra.length || quotation.extra.length || payroll.extra.length || asset.extra.length || capital.extra.length) await this.sheets.writeBatch(companyId, [{ table: tableName, row, values: { ...system, ...writeValues } }, ...invoice.extra, ...receipt.extra, ...quotation.extra, ...payroll.extra, ...asset.extra, ...capital.extra]);
          else await this.sheets.write(companyId, tableName, row, { ...system, ...writeValues });
        }
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
