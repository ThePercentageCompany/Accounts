import test from 'node:test';
import assert from 'node:assert/strict';
import { quotationChanges } from '../src/quotation-policy.js';

const line = { quotationId: 'q', lineNumber: 1, description: 'Service', quantity: 2, unitPrice: 50, discount: 5, taxRate: 5 };
function fixture() {
  const parent = { recordId: 'q', companyId: 'c', customerId: 'u', issueDate: '2026-09-28', validUntil: '2026-10-28',
    currency: 'AED', status: 'DRAFT', subtotal: 100, discount: 5, taxAmount: 4.75, total: 99.75, recordVersion: 2, _row: 2 };
  const data = { Quotations: [parent], QuotationItems: [{ ...line, companyId: 'c', recordId: 'l', taxAmount: 4.75, lineTotal: 99.75 }],
    CompanyProfile: [{ companyId: 'c', quotationPrefix: 'QT' }], Invoices: [], InvoiceItems: [] };
  return { parent, data, sheets: { read: async (_id, names) => Object.fromEntries(names.map(name => [name, data[name] || []])) } };
}
const system = { companyId: 'c', updatedAt: 2, updatedBy: 'owner', idempotencyKey: 'marker', syncStatus: 'SYNCED', isDeleted: false };

test('draft quotation lines update authoritative totals', async () => {
  const f = fixture(); f.data.QuotationItems = [];
  const result = await quotationChanges(f.sheets, 'c', 'QuotationItems', 'l', 'create', null, line, system, 'op');
  assert.equal(result.values.lineTotal, 99.75); assert.equal(result.extra[0].values.total, 99.75);
  assert.equal(result.extra[0].values.recordVersion, 3);
});

test('sending allocates yearly number and locks quotation', async () => {
  const f = fixture(); f.data.Quotations.push({ companyId: 'c', number: 'QT-2026-000004' });
  const sent = await quotationChanges(f.sheets, 'c', 'Quotations', 'q', 'send', f.parent, {}, system, 'op');
  assert.equal(sent.values.number, 'QT-2026-000005'); assert.equal(sent.values.status, 'SENT');
  f.parent.status = 'SENT';
  await assert.rejects(quotationChanges(f.sheets, 'c', 'Quotations', 'q', 'update', f.parent, { notes: 'change' }, system, 'x'),
    error => error.code === 'QUOTATION_LOCKED');
});

test('conversion creates one draft invoice and copied lines atomically', async () => {
  const f = fixture(); f.parent.status = 'SENT'; f.parent.number = 'QT-2026-000001';
  const result = await quotationChanges(f.sheets, 'c', 'Quotations', 'q', 'convert', f.parent, {}, system, 'operation');
  assert.equal(result.values.status, 'CONVERTED'); assert.equal(result.values.convertedInvoiceId.length, 43);
  assert.equal(result.extra[0].table, 'Invoices'); assert.equal(result.extra[0].values.status, 'DRAFT');
  assert.equal(result.extra[1].table, 'InvoiceItems');
  assert.equal(result.extra[1].values.invoiceId, result.values.convertedInvoiceId);
  assert.equal(result.extra[0].values.total, 99.75);
});

test('quotation rejects empty send, stale totals, forged fields and invalid conversion', async () => {
  const f = fixture();
  await assert.rejects(quotationChanges(f.sheets, 'c', 'Quotations', 'q', 'create', null,
    { customerId: 'u', issueDate: '2026-09-28', validUntil: '2026-09-01', currency: 'AED' }, system, 'x'));
  await assert.rejects(quotationChanges(f.sheets, 'c', 'Quotations', 'q', 'update', f.parent, { total: 1 }, system, 'x'),
    error => error.code === 'QUOTATION_DERIVED_FIELD');
  f.data.QuotationItems = [];
  await assert.rejects(quotationChanges(f.sheets, 'c', 'Quotations', 'q', 'send', f.parent, {}, system, 'x'),
    error => error.code === 'QUOTATION_EMPTY');
  f.data.QuotationItems.push({ ...line, companyId: 'c', recordId: 'l', taxAmount: 4.75, lineTotal: 99.75 });
  f.parent.total = 1;
  await assert.rejects(quotationChanges(f.sheets, 'c', 'Quotations', 'q', 'send', f.parent, {}, system, 'x'),
    error => error.code === 'QUOTATION_TOTAL_MISMATCH');
  f.parent.total = 99.75;
  await assert.rejects(quotationChanges(f.sheets, 'c', 'Quotations', 'q', 'convert', f.parent, {}, system, 'x'),
    error => error.code === 'QUOTATION_NOT_CONVERTIBLE');
});
