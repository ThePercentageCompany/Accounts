import test from 'node:test';
import assert from 'node:assert/strict';
import { invoiceChanges, invoiceLineValues } from '../src/invoice-policy.js';

const line = { invoiceId: 'invoice', lineNumber: 1, description: 'Service', quantity: 3, unitPrice: 0.1, discount: 0.05, taxRate: 5 };
function fixture() {
  const parent = { recordId: 'invoice', companyId: 'c', status: 'DRAFT', recordVersion: 1, _row: 2 };
  const data = { Invoices: [parent], InvoiceItems: [] };
  return { parent, data, sheets: { read: async () => data } };
}
test('line calculations use decimal arithmetic with discount before rounded tax', () => {
  assert.deepEqual(invoiceLineValues(line), { gross: 30n, discount: 5n, tax: 1n, total: 26n });
  for (const change of [{ quantity: 0 }, { quantity: 0.001 }, { discount: 0.31 }, { taxRate: 101 }, { lineNumber: 0 }]) {
    assert.throws(() => invoiceLineValues({ ...line, ...change }));
  }
});
test('draft line change returns authoritative parent totals and version in the same batch', async () => {
  const f = fixture();
  const result = await invoiceChanges(f.sheets, 'c', 'InvoiceItems', 'line', 'create', null, line,
    { updatedAt: 100, updatedBy: 'owner', idempotencyKey: 'operation' });
  assert.equal(result.values.lineTotal, 0.26);
  assert.equal(result.extra[0].values.total, 0.26);
  assert.equal(result.extra[0].values.paidAmount, 0);
  assert.equal(result.extra[0].values.recordVersion, 2);
  f.data.InvoiceItems.push({ ...line, recordId: 'line', companyId: 'c' });
  const deleted = await invoiceChanges(f.sheets, 'c', 'InvoiceItems', 'line', 'delete', f.data.InvoiceItems[0], {}, {});
  assert.equal(deleted.extra[0].values.total, 0);
});
test('finalized parents, moves, duplicate numbers and forged totals are rejected', async () => {
  const f = fixture();
  f.parent.status = 'ISSUED';
  await assert.rejects(invoiceChanges(f.sheets, 'c', 'InvoiceItems', 'line', 'create', null, line, {}), e => e.code === 'INVOICE_LOCKED');
  f.parent.status = 'DRAFT';
  await assert.rejects(invoiceChanges(f.sheets, 'c', 'InvoiceItems', 'line', 'update', line, { invoiceId: 'other' }, {}), e => e.code === 'INVOICE_LOCKED');
  await assert.rejects(invoiceChanges(f.sheets, 'c', 'InvoiceItems', 'line', 'create', null, { ...line, lineTotal: 0 }, {}), e => e.code === 'INVOICE_TOTAL_MISMATCH');
  f.data.InvoiceItems.push({ ...line, companyId: 'c', recordId: 'other' });
  await assert.rejects(invoiceChanges(f.sheets, 'c', 'InvoiceItems', 'line', 'create', null, line, {}), e => e.code === 'INVALID_INVOICE_LINE');
});
test('invoice header totals cannot be forged and issuing cannot bypass the posting workflow', async () => {
  const f = fixture(), header = { customerId: 'customer', issueDate: '2026-09-27', currency: 'AED' };
  const result = await invoiceChanges(f.sheets, 'c', 'Invoices', 'invoice', 'create', null, header, {});
  assert.equal(result.values.status, 'DRAFT'); assert.equal(result.values.total, 0);
  for (const values of [{ ...header, total: 100 }, { ...header, status: 'ISSUED' }, { ...header, dueDate: '2026-09-01' }]) {
    await assert.rejects(invoiceChanges(f.sheets, 'c', 'Invoices', 'invoice', 'create', null, values, {}));
  }
});

test('issuing assigns the next yearly number and balanced immutable journal', async () => {
  const f = fixture();
  f.parent.issueDate = '2026-09-27'; f.parent.currency = 'AED'; f.parent.customerId = 'customer';
  f.parent.subtotal = 0.3; f.parent.discount = 0.05; f.parent.taxAmount = 0.01; f.parent.total = 0.26;
  f.data.InvoiceItems.push({ ...line, companyId: 'c', recordId: 'line' });
  f.data.CompanyProfile = [{ companyId: 'c', invoicePrefix: 'TPC' }];
  f.data.Invoices.push({ companyId: 'c', recordId: 'previous', number: 'TPC-2026-000009' });
  f.data.Journals = []; f.data.JournalLines = []; f.data.FinancialPeriods = [];
  const result = await invoiceChanges(f.sheets, 'c', 'Invoices', 'invoice', 'issue', f.parent, {},
    { companyId: 'c', updatedAt: 1, updatedBy: 'owner', idempotencyKey: 'marker', isDeleted: false, syncStatus: 'SYNCED' }, 'operation');
  assert.equal(result.values.number, 'TPC-2026-000010'); assert.equal(result.values.status, 'ISSUED');
  assert.equal(result.extra[0].values.sourceType, 'Invoice');
  const journalId = result.extra[0].values.recordId;
  const lines = result.extra.slice(1).map(change => change.values);
  assert.ok(lines.every(entry => entry.journalId === journalId));
  assert.equal(lines.reduce((sum, entry) => sum + Math.round(entry.debit * 100), 0), 26);
  assert.equal(lines.reduce((sum, entry) => sum + Math.round(entry.credit * 100), 0), 26);
});

test('issuing rejects empty, stale, closed-period and invalid-prefix invoices', async () => {
  const f = fixture();
  Object.assign(f.parent, { issueDate: '2026-09-27', currency: 'AED', customerId: 'customer', subtotal: 0, discount: 0, taxAmount: 0, total: 0 });
  Object.assign(f.data, { CompanyProfile: [{ companyId: 'c', invoicePrefix: 'INV' }], Journals: [], JournalLines: [], FinancialPeriods: [] });
  const issue = () => invoiceChanges(f.sheets, 'c', 'Invoices', 'invoice', 'issue', f.parent, {}, {}, 'operation');
  await assert.rejects(issue(), e => e.code === 'INVOICE_EMPTY');
  f.data.InvoiceItems.push({ ...line, companyId: 'c', recordId: 'line' });
  await assert.rejects(issue(), e => e.code === 'INVOICE_TOTAL_MISMATCH');
  Object.assign(f.parent, { subtotal: 0.3, discount: 0.05, taxAmount: 0.01, total: 0.26 });
  f.data.FinancialPeriods.push({ companyId: 'c', startDate: '2026-09-01', endDate: '2026-09-30', status: 'CLOSED' });
  await assert.rejects(issue(), e => e.code === 'PERIOD_CLOSED');
  f.data.FinancialPeriods.length = 0; f.data.CompanyProfile[0].invoicePrefix = 'bad prefix';
  await assert.rejects(issue(), e => e.code === 'INVALID_INVOICE_PREFIX');
});
