import test from 'node:test';
import assert from 'node:assert/strict';
import { fixture } from './helpers.js';
import { BusinessService } from '../src/business-service.js';
import { TABLES } from '../src/company-schema.js';
import { ApiError } from '../src/errors.js';

async function setup(authorizeWrite = async () => {}) {
  const f = fixture(), token = await f.login();
  const registration = await f.service.createCompany(token, { name: 'Documents' }, 'document_company_001');
  const companyId = registration.company.companyId;
  await f.registry.transact(state => { state.companies[companyId].stage = 'READY'; });
  const data = Object.fromEntries(TABLES.map(table => [table.title, []]));
  data.Customers.push({ companyId, recordId: 'c'.repeat(43), name: 'Client', _row: 2 });
  let batches = 0, loseResponse = false;
  const sheets = {
    table: name => TABLES.find(table => table.title === name),
    read: async (id, names) => { assert.equal(id, companyId); return Object.fromEntries(names.map(name => [name, structuredClone(data[name])])); },
    async write(id, table, row, values) {
      assert.equal(id, companyId);
      assert.ok(Object.keys(values).every(key => this.table(table).headers.includes(key)));
      assert.ok(Object.values(values).every(value => ['string', 'number', 'boolean'].includes(typeof value)));
      const previous = data[table].find(value => value._row === row);
      if (previous) Object.assign(previous, values); else data[table].push({ ...values, _row: row });
    },
    async writeBatch(id, changes) {
      batches++;
      for (const change of changes) await this.write(id, change.table, change.row, change.values);
      if (loseResponse) { loseResponse = false; throw new Error('response lost'); }
    },
  };
  const business = new BusinessService({ accounts: f.service, sheets, authorizeWrite });
  return { ...f, token, companyId, data, sheets, business,
    loseResponse: () => { loseResponse = true; }, batches: () => batches };
}

const items = [
  { description: 'Small decimal amount', quantity: 3, unitPrice: 0.1, discount: 0.05, taxRate: 5 },
  { description: 'Design', quantity: 2, unitPrice: 50, discount: 5, taxRate: 5 },
];
const header = { customerId: 'c'.repeat(43), issueDate: '2026-10-04', currency: 'AED' };

async function issuedInvoice() {
  const f = await setup();
  const created = await f.business.mutate(f.token, f.companyId, 'Invoices', null, 'create', {
    expectedVersion: 0, values: { ...header, items: [{ description: 'Design', quantity: 3, unitPrice: 10, discount: 1, taxRate: 5 }] },
  }, 'return_draft_create_01');
  await f.business.mutate(f.token, f.companyId, 'Invoices', created.recordId, 'issue', { expectedVersion: 1 }, 'return_invoice_issue_01');
  return { ...f, invoice: f.data.Invoices[0], line: f.data.InvoiceItems[0] };
}

test('partial returns preserve original invoice and exactly reverse totals across fractional rounding', async () => {
  const f = await issuedInvoice();
  const original = structuredClone(f.invoice);
  for (let i = 0; i < 3; i++) {
    await f.business.mutate(f.token, f.companyId, 'Invoices', f.invoice.recordId, 'invoiceReturn', {
      expectedVersion: Number(f.invoice.recordVersion), values: { date: '2026-10-04', reason: 'Returned item',
        returnItems: [{ invoiceItemId: f.line.recordId, quantity: 1 }] },
    }, `partial_return_number_${i}`);
  }
  assert.equal(f.invoice.status, 'RETURNED');
  assert.equal(f.invoice.total, original.total);
  assert.equal(f.invoice.number, original.number);
  assert.equal(f.invoice.balance, 0);
  assert.equal(f.line.quantity, 3);
  assert.equal(f.data.CreditNotes.reduce((s, n) => s + Math.round(n.total * 100), 0), Math.round(original.total * 100));
  assert.equal(f.data.CreditNotes.reduce((s, n) => s + Math.round(n.taxAmount * 100), 0), Math.round(original.taxAmount * 100));
  for (const journal of f.data.Journals) {
    const lines = f.data.JournalLines.filter(l => l.journalId === journal.recordId);
    assert.equal(lines.reduce((sum, l) => sum + Math.round(l.debit * 100) - Math.round(l.credit * 100), 0), 0);
  }
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'Invoices', f.invoice.recordId, 'update', {
    expectedVersion: f.invoice.recordVersion, values: { notes: 'change' },
  }, 'edit_returned_invoice_1'), { code: 'INVOICE_LOCKED' });
});

test('paid invoice return refunds cash, stays idempotent after response loss and prevents overreturn', async () => {
  const f = await issuedInvoice();
  await f.business.mutate(f.token, f.companyId, 'Receipts', null, 'receive', { expectedVersion: 0,
    values: { invoiceId: f.invoice.recordId, customerId: header.customerId, paymentDate: '2026-10-04',
      amount: f.invoice.total, currency: 'AED', paymentAccount: 'Bank' } }, 'return_receipt_receive1');
  const input = { expectedVersion: f.invoice.recordVersion, values: { date: '2026-10-04', reason: 'Customer return', refundAccount: 'Bank',
    returnItems: [{ invoiceItemId: f.line.recordId, quantity: 1 }] } };
  f.loseResponse();
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'Invoices', f.invoice.recordId, 'invoiceReturn', input, 'return_lost_response_1'));
  const replay = await f.business.mutate(f.token, f.companyId, 'Invoices', f.invoice.recordId, 'invoiceReturn', input, 'return_lost_response_1');
  assert.equal(replay.replayed, true);
  assert.equal(f.data.CreditNotes.length, 1);
  assert.equal(f.invoice.balance, 0);
  assert.equal(f.data.CreditNotes[0].refundAmount, f.data.CreditNotes[0].total);
  assert.ok(f.data.JournalLines.some(l => l.accountId === 'bank' && l.credit > 0));
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'Invoices', f.invoice.recordId, 'invoiceReturn', {
    expectedVersion: f.invoice.recordVersion, values: { ...input.values, returnItems: [{ invoiceItemId: f.line.recordId, quantity: 3 }] },
  }, 'return_excess_qty_001'), { code: 'RETURN_QUANTITY_EXCEEDED' });
  assert.equal(f.data.CreditNotes.length, 1);
});

test('partial return leaves balance payable and rejects foreign lines and forged credit note edits', async () => {
  const f = await issuedInvoice();
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'Invoices', f.invoice.recordId, 'invoiceReturn', {
    expectedVersion: f.invoice.recordVersion, values: { date: '2026-10-04', reason: 'Return item', returnItems: [{ invoiceItemId: 'z'.repeat(43), quantity: 1 }] },
  }, 'foreign_return_item01'), { code: 'INVALID_INVOICE_RETURN' });
  await f.business.mutate(f.token, f.companyId, 'Invoices', f.invoice.recordId, 'invoiceReturn', {
    expectedVersion: f.invoice.recordVersion, values: { date: '2026-10-04', reason: 'Return item', returnItems: [{ invoiceItemId: f.line.recordId, quantity: 1 }] },
  }, 'return_before_pay_001');
  await f.business.mutate(f.token, f.companyId, 'Receipts', null, 'receive', { expectedVersion: 0,
    values: { invoiceId: f.invoice.recordId, customerId: header.customerId, paymentDate: '2026-10-04',
      amount: f.invoice.balance, currency: 'AED', paymentAccount: 'Cash' } }, 'return_remaining_paid');
  assert.equal(f.invoice.balance, 0);
  assert.equal(f.invoice.status, 'PARTIALLY_RETURNED');
  await assert.rejects(f.business.mutate(f.token, f.companyId, 'CreditNotes', f.data.CreditNotes[0].recordId, 'update', {
    expectedVersion: 1, values: { total: 0 },
  }, 'forged_credit_update1'), { code: 'CREDIT_NOTE_LOCKED' });
});

for (const [table, child, parent] of [['Invoices', 'InvoiceItems', 'invoiceId'], ['Quotations', 'QuotationItems', 'quotationId']]) {
  const values = { ...header, ...(table === 'Quotations' ? { validUntil: '2026-11-04' } : {}), items };
  test(`${table}: complete draft saves in one batch and lost response replays without duplication`, async () => {
    const f = await setup();
    f.loseResponse();
    const operation = { operationId: 'document_create_001', table, action: 'create', expectedVersion: 0, values };
    const failed = await f.business.sync(f.token, f.companyId, { operations: [operation] });
    assert.equal(failed.results[0].status, 'FAILED');
    const replay = await f.business.sync(f.token, f.companyId, { operations: [operation] });
    assert.equal(replay.results[0].status, 'APPLIED');
    assert.equal(f.batches(), 1);
    assert.equal(f.data[table].length, 1); assert.equal(f.data[child].length, 2);
    const record = f.data[table][0];
    assert.equal(record.total, 100.01); assert.equal(record.taxAmount, 4.76);
    assert.equal(record.discount, 5.05); assert.equal(record.subtotal, 100.3);
    assert.equal(record.status, 'DRAFT'); assert.equal(record.number ?? '', '');
    assert.ok(f.data[child].every(line => line[parent] === record.recordId && line.recordVersion === 1));
    assert.equal(f.data[child][0].lineTotal, 0.26);
    await assert.rejects(f.business.mutate(f.token, f.companyId, table, null, 'create',
      { expectedVersion: 0, values: { ...values, notes: 'Changed' } }, operation.operationId), e => e.code === 'IDEMPOTENCY_CONFLICT');
  });

  test(`${table}: replacing lines is atomic and stale versions cannot overwrite separate line edits`, async () => {
    const f = await setup();
    const created = await f.business.mutate(f.token, f.companyId, table, null, 'create',
      { expectedVersion: 0, values }, 'document_create_002');
    const oldLine = f.data[child][0];
    await f.business.mutate(f.token, f.companyId, child, oldLine.recordId, 'update',
      { expectedVersion: 1, values: { description: 'Edited separately' } }, 'document_line_edit_01');
    await assert.rejects(f.business.mutate(f.token, f.companyId, table, created.recordId, 'update',
      { expectedVersion: 1, values }, 'document_stale_001'), e => e.code === 'VERSION_CONFLICT');
    f.loseResponse();
    const input = { expectedVersion: 2, values: { ...values, items: [items[1]], notes: 'Revised' } };
    await assert.rejects(f.business.mutate(f.token, f.companyId, table, created.recordId, 'update', input, 'document_update_001'));
    const count = f.batches();
    await f.business.mutate(f.token, f.companyId, table, created.recordId, 'update', input, 'document_update_001');
    assert.equal(f.batches(), count);
    assert.equal(f.data[table][0].recordVersion, 3);
    assert.equal(f.data[table][0].total, 99.75);
    assert.equal(f.data[child].filter(line => !line.isDeleted).length, 1);
    assert.equal(f.data[child].filter(line => line.isDeleted).length, 2);
  });

  test(`${table}: invalid or forged lines never save a partial header`, async () => {
    const f = await setup();
    for (const bad of [[], Array(101).fill(items[0]), [{ ...items[0], total: 100 }],
      [{ ...items[0], companyId: 'foreign' }], [{ ...items[0], taxRate: 101 }],
      [{ ...items[0], description: '' }], [{ ...items[0], discount: 100 }],
      [{ ...items[0], quantity: 0.001 }]]) {
      await assert.rejects(f.business.mutate(f.token, f.companyId, table, null, 'create',
        { expectedVersion: 0, values: { ...values, items: bad } }, 'document_invalid_001'));
      assert.equal(f.data[table].length, 0); assert.equal(f.data[child].length, 0);
    }
  });

  test(`${table}: complete documents recheck child table write permission`, async () => {
    const f = await setup(async (_token, _company, name) => {
      if (name === child) throw new ApiError(403, 'WRITE_FORBIDDEN', 'Denied');
    });
    await assert.rejects(f.business.mutate(f.token, f.companyId, table, null, 'create',
      { expectedVersion: 0, values }, 'document_forbidden_01'), e => e.code === 'WRITE_FORBIDDEN');
    assert.equal(f.data[table].length, 0); assert.equal(f.batches(), 0);
  });

  test(`${table}: 100 lines fit one atomic batch and product references remain tenant-scoped`, async () => {
    const f = await setup();
    const productId = 'p'.repeat(43);
    f.data.ProductsServices.push({ recordId: productId, companyId: 'foreign', _row: 2 });
    const input = { expectedVersion: 0, values: { ...values, items: Array(100).fill({ ...items[0], productId }) } };
    await assert.rejects(f.business.mutate(f.token, f.companyId, table, null, 'create', input, 'document_products_01'),
      e => e.code === 'INVALID_DOCUMENT_ITEMS');
    assert.equal(f.data[table].length, 0);
    f.data.ProductsServices[0].companyId = f.companyId;
    await f.business.mutate(f.token, f.companyId, table, null, 'create', input, 'document_products_02');
    assert.equal(f.batches(), 1);
    assert.equal(f.data[child].length, 100);
    assert.ok(f.data[child].every(line => line.productId === productId));
    assert.equal(f.data[child][99].lineNumber, 100);
    assert.equal(f.data[table][0].total, 26);
  });
}
