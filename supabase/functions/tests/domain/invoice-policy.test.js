import test from 'node:test';
import assert from 'node:assert/strict';
import { invoiceChanges, invoiceLineValues } from '../../_shared/domain/invoice-policy.js';

const line = { invoiceId: 'invoice', lineNumber: 1, description: 'Service', quantity: 3, unitPrice: 0.1, discount: 0.05, taxRate: 5 };

test('deleting a draft soft-deletes only its active owned lines and locks issued invoices', async () => {
  const f = fixture();
  f.data.InvoiceItems = [
    { ...line, companyId: 'c', _row: 2, recordVersion: 3 },
    { ...line, companyId: 'c', _row: 3, recordVersion: 1, isDeleted: true },
    { ...line, companyId: 'c', _row: 4, invoiceId: 'other' },
    { ...line, companyId: 'other', _row: 5 },
  ];
  const system = { updatedAt: 100, updatedBy: 'owner', idempotencyKey: 'delete-operation' };
  const result = await invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'delete', f.parent, {}, system);
  assert.deepEqual(result.extra, [{ table: 'InvoiceItems', row: 2, values: {
    ...system, recordVersion: 4, syncStatus: 'SYNCED', isDeleted: true,
  } }]);
  f.parent.status = 'ISSUED';
  await assert.rejects(invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'delete', f.parent, {}, system), e => e.code === 'INVOICE_LOCKED');
});
function fixture() {
  const parent = { recordId: 'invoice', companyId: 'c', status: 'DRAFT', recordVersion: 1, _row: 2 };
  const data = { Invoices: [parent], InvoiceItems: [], CompanyProfile: [] };
  return { parent, data, records: { read: async () => data } };
}
test('line calculations use decimal arithmetic with discount before rounded tax', () => {
  assert.deepEqual(invoiceLineValues(line), { gross: 30n, discount: 5n, tax: 1n, total: 26n });
  for (const change of [{ quantity: 0 }, { quantity: 0.001 }, { discount: 0.31 }, { taxRate: 101 }, { lineNumber: 0 }]) {
    assert.throws(() => invoiceLineValues({ ...line, ...change }));
  }
});
test('draft line change returns authoritative parent totals and version in the same batch', async () => {
  const f = fixture();
  const result = await invoiceChanges(f.records, 'c', 'InvoiceItems', 'line', 'create', null, line,
    { updatedAt: 100, updatedBy: 'owner', idempotencyKey: 'operation' });
  assert.equal(result.values.lineTotal, 0.26);
  assert.equal(result.extra[0].values.total, 0.26);
  assert.equal(result.extra[0].values.paidAmount, 0);
  assert.equal(result.extra[0].values.recordVersion, 2);
  f.data.InvoiceItems.push({ ...line, recordId: 'line', companyId: 'c' });
  const deleted = await invoiceChanges(f.records, 'c', 'InvoiceItems', 'line', 'delete', f.data.InvoiceItems[0], {}, {});
  assert.equal(deleted.extra[0].values.total, 0);
});
test('finalized parents, moves, duplicate numbers and forged totals are rejected', async () => {
  const f = fixture();
  f.parent.status = 'ISSUED';
  await assert.rejects(invoiceChanges(f.records, 'c', 'InvoiceItems', 'line', 'create', null, line, {}), e => e.code === 'INVOICE_LOCKED');
  f.parent.status = 'DRAFT';
  await assert.rejects(invoiceChanges(f.records, 'c', 'InvoiceItems', 'line', 'update', line, { invoiceId: 'other' }, {}), e => e.code === 'INVOICE_LOCKED');
  await assert.rejects(invoiceChanges(f.records, 'c', 'InvoiceItems', 'line', 'create', null, { ...line, lineTotal: 0 }, {}), e => e.code === 'INVOICE_TOTAL_MISMATCH');
  f.data.InvoiceItems.push({ ...line, companyId: 'c', recordId: 'other' });
  await assert.rejects(invoiceChanges(f.records, 'c', 'InvoiceItems', 'line', 'create', null, line, {}), e => e.code === 'INVALID_INVOICE_LINE');
});
test('invoice header totals cannot be forged and issuing cannot bypass the posting workflow', async () => {
  const f = fixture(), header = { customerId: 'customer', issueDate: '2026-09-27', currency: 'AED' };
  const result = await invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'create', null, header, {});
  assert.equal(result.values.status, 'DRAFT'); assert.equal(result.values.total, 0);
  assert.equal(result.values.number, 'INV-2026-000001');
  for (const values of [{ ...header, total: 100 }, { ...header, status: 'ISSUED' }, { ...header, dueDate: '2026-09-01' }]) {
    await assert.rejects(invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'create', null, values, {}));
  }
});

test('draft creation assigns the next yearly number with the configured prefix', async () => {
  const f = fixture(), header = { customerId: 'customer', issueDate: '2026-09-27', currency: 'AED' };
  f.data.CompanyProfile.push({ companyId: 'c', invoicePrefix: 'TPC' });
  f.data.Invoices.push({ companyId: 'c', recordId: 'previous', number: 'TPC-2026-000009' });
  const result = await invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'create', null, header, {});
  assert.equal(result.values.number, 'TPC-2026-000010');
  await assert.rejects(
    invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'create', null, { ...header, number: 'TPC-2026-999999' }, {}),
    e => e.code === 'INVOICE_DERIVED_FIELD');
});

test('cash sales save an optional walk-in name instead of a customer account', async () => {
  const f = fixture();
  const cash = { customerId: '', cashCustomerName: '  Walk-in customer  ', issueDate: '2026-09-27', currency: 'AED' };
  const result = await invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'create', null, cash, {});
  assert.equal(result.values.number, 'INV-2026-000001');
  assert.equal(result.values.cashCustomerName, 'Walk-in customer');
  await assert.rejects(invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'create', null,
    { ...cash, customerId: 'customer' }), e => e.code === 'INVALID_CASH_CUSTOMER');
  await assert.rejects(invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'create', null,
    { ...cash, cashCustomerName: 'x'.repeat(201) }), e => e.code === 'INVALID_CASH_CUSTOMER');
});

test('issuing assigns the next yearly number and balanced immutable journal', async () => {
  const f = fixture();
  f.parent.issueDate = '2026-09-27'; f.parent.currency = 'AED'; f.parent.customerId = 'customer';
  f.parent.subtotal = 0.3; f.parent.discount = 0.05; f.parent.taxAmount = 0.01; f.parent.total = 0.26;
  f.data.InvoiceItems.push({ ...line, companyId: 'c', recordId: 'line' });
  f.data.CompanyProfile = [{ companyId: 'c', invoicePrefix: 'TPC' }];
  f.data.Invoices.push({ companyId: 'c', recordId: 'previous', number: 'TPC-2026-000009' });
  f.data.Journals = []; f.data.JournalLines = []; f.data.FinancialPeriods = [];
  const result = await invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'issue', f.parent, {},
    { companyId: 'c', updatedAt: 1, updatedBy: 'owner', idempotencyKey: 'marker', isDeleted: false, syncStatus: 'SYNCED' }, 'operation');
  assert.equal(result.values.number, 'TPC-2026-000010'); assert.equal(result.values.status, 'ISSUED');
  assert.equal(result.extra[0].values.sourceType, 'Invoice');
  const journalId = result.extra[0].values.recordId;
  const lines = result.extra.slice(1).map(change => change.values);
  assert.ok(lines.every(entry => entry.journalId === journalId));
  assert.equal(lines.reduce((sum, entry) => sum + Math.round(entry.debit * 100), 0), 26);
  assert.equal(lines.reduce((sum, entry) => sum + Math.round(entry.credit * 100), 0), 26);
});

test('cash invoices issue with an empty customer account', async () => {
  const f = fixture();
  Object.assign(f.parent, { customerId: '', cashCustomerName: 'Walk-in', number: 'INV-2026-000001',
    issueDate: '2026-09-27', currency: 'AED', subtotal: 0.3, discount: 0.05, taxAmount: 0.01, total: 0.26 });
  f.data.InvoiceItems.push({ ...line, companyId: 'c', recordId: 'line' });
  f.data.CompanyProfile = [{ companyId: 'c', invoicePrefix: 'INV' }];
  f.data.Journals = []; f.data.JournalLines = []; f.data.FinancialPeriods = [];
  const result = await invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'issue', f.parent, {},
    { companyId: 'c', updatedAt: 1, updatedBy: 'owner', idempotencyKey: 'marker', isDeleted: false, syncStatus: 'SYNCED' }, 'operation');
  assert.equal(result.values.status, 'ISSUED'); assert.equal(result.values.number, 'INV-2026-000001');
});

test('issuing keeps the number assigned when the draft was created', async () => {
  const f = fixture();
  f.parent.issueDate = '2026-09-27'; f.parent.currency = 'AED'; f.parent.customerId = 'customer';
  f.parent.subtotal = 0.3; f.parent.discount = 0.05; f.parent.taxAmount = 0.01; f.parent.total = 0.26;
  f.parent.number = 'TPC-2026-000004';
  f.data.InvoiceItems.push({ ...line, companyId: 'c', recordId: 'line' });
  f.data.CompanyProfile = [{ companyId: 'c', invoicePrefix: 'TPC' }];
  f.data.Invoices.push({ companyId: 'c', recordId: 'previous', number: 'TPC-2026-000009' });
  f.data.Journals = []; f.data.JournalLines = []; f.data.FinancialPeriods = [];
  const result = await invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'issue', f.parent, {},
    { companyId: 'c', updatedAt: 1, updatedBy: 'owner', idempotencyKey: 'marker', isDeleted: false, syncStatus: 'SYNCED' }, 'operation');
  assert.equal(result.values.number, 'TPC-2026-000004'); assert.equal(result.values.status, 'ISSUED');
});

test('issuing rejects empty, stale, closed-period and invalid-prefix invoices', async () => {
  const f = fixture();
  Object.assign(f.parent, { issueDate: '2026-09-27', currency: 'AED', customerId: 'customer', subtotal: 0, discount: 0, taxAmount: 0, total: 0 });
  Object.assign(f.data, { CompanyProfile: [{ companyId: 'c', invoicePrefix: 'INV' }], Journals: [], JournalLines: [], FinancialPeriods: [] });
  const issue = () => invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'issue', f.parent, {}, {}, 'operation');
  await assert.rejects(issue(), e => e.code === 'INVOICE_EMPTY');
  f.data.InvoiceItems.push({ ...line, companyId: 'c', recordId: 'line' });
  await assert.rejects(issue(), e => e.code === 'INVOICE_TOTAL_MISMATCH');
  Object.assign(f.parent, { subtotal: 0.3, discount: 0.05, taxAmount: 0.01, total: 0.26 });
  f.data.FinancialPeriods.push({ companyId: 'c', startDate: '2026-09-01', endDate: '2026-09-30', status: 'CLOSED' });
  await assert.rejects(issue(), e => e.code === 'PERIOD_CLOSED');
  f.data.FinancialPeriods.length = 0; f.data.CompanyProfile[0].invoicePrefix = 'bad prefix';
  await assert.rejects(issue(), e => e.code === 'INVALID_INVOICE_PREFIX');
});

test('voiding an unpaid invoice reverses its exact posting and preserves history', async () => {
  const f = fixture();
  Object.assign(f.parent, { status: 'ISSUED', number: 'INV-2026-000001', issueDate: '2026-09-01', total: 105, paidAmount: 0, balance: 105 });
  Object.assign(f.data, {
    FinancialPeriods: [], Receipts: [], ReceiptAllocations: [],
    Journals: [{ companyId: 'c', recordId: 'issue-journal', _row: 2, status: 'POSTED', sourceType: 'Invoice', sourceId: 'invoice' }],
    JournalLines: [
      { companyId: 'c', recordId: 'l1', _row: 2, journalId: 'issue-journal', lineNumber: 1, accountId: 'ar', accountName: 'Accounts Receivable', accountGroup: 'Asset', debit: 105, credit: 0 },
      { companyId: 'c', recordId: 'l2', _row: 3, journalId: 'issue-journal', lineNumber: 2, accountId: 'revenue', accountName: 'Revenue', accountGroup: 'Income', debit: 0, credit: 100 },
      { companyId: 'c', recordId: 'l3', _row: 4, journalId: 'issue-journal', lineNumber: 3, accountId: 'vat', accountName: 'Output VAT', accountGroup: 'Liability', debit: 0, credit: 5 },
    ],
  });
  const result = await invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'invoiceVoid', f.parent,
    { voidDate: '2026-09-30', voidReason: 'Customer order cancelled' },
    { companyId: 'c', updatedAt: 1, updatedBy: 'owner', idempotencyKey: 'void', isDeleted: false, syncStatus: 'SYNCED' }, 'void-op');
  assert.equal(result.values.status, 'VOID'); assert.equal(result.values.balance, 0);
  assert.equal(result.extra[0].values.sourceType, 'InvoiceVoid');
  const reversed = result.extra.slice(1).map(change => change.values);
  assert.deepEqual(reversed.map(row => [row.debit, row.credit]), [[0, 105], [100, 0], [5, 0]]);
  assert.equal(reversed.reduce((sum, row) => sum + Math.round(row.debit * 100), 0), 10500);
  assert.equal(reversed.reduce((sum, row) => sum + Math.round(row.credit * 100), 0), 10500);
});

test('invoice void requires zero payment activity and valid ledger history', async () => {
  const f = fixture();
  Object.assign(f.parent, { status: 'ISSUED', number: 'INV-1', issueDate: '2026-09-01', total: 100, paidAmount: 10, balance: 90 });
  Object.assign(f.data, { FinancialPeriods: [], Receipts: [], ReceiptAllocations: [], Journals: [], JournalLines: [] });
  const voidInvoice = values => invoiceChanges(f.records, 'c', 'Invoices', 'invoice', 'invoiceVoid', f.parent, values, {}, 'void');
  await assert.rejects(voidInvoice({ voidDate: '2026-09-30', voidReason: 'Cancelled order' }), e => e.code === 'INVOICE_VOID_NOT_AVAILABLE');
  Object.assign(f.parent, { paidAmount: 0, balance: 100 });
  await assert.rejects(voidInvoice({ voidDate: '2026-08-31', voidReason: 'Cancelled order' }), e => e.code === 'INVALID_INVOICE_VOID');
  await assert.rejects(voidInvoice({ voidDate: '2026-09-30', voidReason: 'Cancelled order', total: 0 }), e => e.code === 'INVALID_INVOICE_VOID');
  await assert.rejects(voidInvoice({ voidDate: '2026-09-30', voidReason: 'Cancelled order' }), e => e.code === 'INVOICE_LEDGER_MISMATCH');
});
