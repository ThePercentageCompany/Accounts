import test from 'node:test';
import assert from 'node:assert/strict';
import { receiptChanges, receiptInput } from '../src/receipt-policy.js';

const customerId = 'c'.repeat(43), invoiceId = 'i'.repeat(43);
const input = { invoiceId, customerId, paymentDate: '2026-09-28', amount: 40.25, currency: 'AED', paymentAccount: 'Bank', reference: 'Transfer' };
function fixture() {
  const data = {
    Customers: [{ companyId: 'tenant', recordId: customerId }],
    Invoices: [{ companyId: 'tenant', recordId: invoiceId, customerId, issueDate: '2026-09-27', currency: 'AED',
      total: 100.5, paidAmount: 0, balance: 100.5, status: 'ISSUED', recordVersion: 3, _row: 2 }],
    Receipts: [], ReceiptAllocations: [], Journals: [], JournalLines: [], FinancialPeriods: [],
  };
  return { data, sheets: { read: async (_company, names) => Object.fromEntries(names.map(name => [name, data[name] || []])) } };
}
const system = { companyId: 'tenant', updatedAt: 1, updatedBy: 'owner', idempotencyKey: 'marker', isDeleted: false, syncStatus: 'SYNCED' };

test('receipt input accepts only bounded payment fields', () => {
  assert.equal(receiptInput(input).reference, 'Transfer');
  for (const bad of [{ ...input, amount: 0 }, { ...input, amount: 1.001 }, { ...input, currency: 'aed' },
    { ...input, paymentAccount: 'Card' }, { ...input, invoiceId: 'short' }, { ...input, authority: 'owner' }]) {
    assert.throws(() => receiptInput(bad));
  }
});

test('receipt atomically allocates payment, updates invoice and posts balanced journal', async () => {
  const f = fixture();
  const result = await receiptChanges(f.sheets, 'tenant', 'Receipts', 'r'.repeat(43), 'receive', null, input, system, 'operation');
  assert.equal(result.values.number, 'REC-2026-000001');
  assert.equal(result.values.status, 'POSTED');
  assert.equal(result.extra[0].table, 'ReceiptAllocations');
  assert.equal(result.extra[1].values.paidAmount, 40.25);
  assert.equal(result.extra[1].values.balance, 60.25);
  assert.equal(result.extra[1].values.status, 'PARTIALLY_PAID');
  const lines = result.extra.filter(change => change.table === 'JournalLines').map(change => change.values);
  assert.equal(lines.reduce((sum, line) => sum + line.debit, 0), 40.25);
  assert.equal(lines.reduce((sum, line) => sum + line.credit, 0), 40.25);
  assert.equal(lines[0].accountId, 'bank');

  f.data.Invoices[0].paidAmount = 60.25; f.data.Invoices[0].balance = 40.25; f.data.Invoices[0].status = 'PARTIALLY_PAID';
  f.data.Receipts.push({ companyId: 'tenant', number: 'REC-2026-000009' });
  const final = await receiptChanges(f.sheets, 'tenant', 'Receipts', 's'.repeat(43), 'receive', null, input, system, 'other');
  assert.equal(final.values.number, 'REC-2026-000010');
  assert.equal(final.extra[1].values.status, 'PAID');
  assert.equal(final.extra[1].values.balance, 0);
});

test('receipt rejects overpayment, mismatches, closed periods and direct edits', async () => {
  const f = fixture();
  const receive = values => receiptChanges(f.sheets, 'tenant', 'Receipts', 'r'.repeat(43), 'receive', null, values, system, 'operation');
  await assert.rejects(receive({ ...input, amount: 100.51 }), error => error.code === 'RECEIPT_OVERPAYMENT');
  await assert.rejects(receive({ ...input, currency: 'USD' }), error => error.code === 'RECEIPT_CURRENCY_MISMATCH');
  await assert.rejects(receive({ ...input, customerId: 'x'.repeat(43) }), error => error.code === 'RECEIPT_CUSTOMER_INVALID');
  await assert.rejects(receive({ ...input, paymentDate: '2026-09-01' }), error => error.code === 'INVALID_PAYMENT_DATE');
  f.data.FinancialPeriods.push({ companyId: 'tenant', startDate: '2026-09-01', endDate: '2026-09-30', status: 'CLOSED' });
  await assert.rejects(receive(input), error => error.code === 'PERIOD_CLOSED');
  await assert.rejects(receiptChanges(f.sheets, 'tenant', 'Receipts', 'r'.repeat(43), 'update', {}, {}, system, 'operation'),
    error => error.code === 'RECEIPT_LOCKED');
  await assert.rejects(receiptChanges(f.sheets, 'tenant', 'ReceiptAllocations', 'a'.repeat(43), 'create', null, {}, system, 'operation'),
    error => error.code === 'RECEIPT_LOCKED');
});

test('receipt reversal restores invoice balance and posts the opposite journal', async () => {
  const f = fixture(), receiptId = 'r'.repeat(43);
  Object.assign(f.data.Invoices[0], { paidAmount: 40.25, balance: 60.25, status: 'PARTIALLY_PAID', recordVersion: 4 });
  f.data.ReceiptAllocations.push({ companyId: 'tenant', recordId: 'a', receiptId, invoiceId, amount: 40.25 });
  f.data.Journals.push({ companyId: 'tenant', recordId: 'j', sourceType: 'Receipt', sourceId: receiptId, status: 'POSTED' });
  const old = { companyId: 'tenant', recordId: receiptId, number: 'REC-2026-000001', paymentDate: input.paymentDate,
    paymentAccount: 'Bank', amount: 40.25, status: 'POSTED' };
  const result = await receiptChanges(f.sheets, 'tenant', 'Receipts', receiptId, 'receiptReverse', old,
    { reversalDate: '2026-10-01', reversalReason: 'Payment returned' }, system, 'reverse');
  assert.equal(result.values.status, 'REVERSED'); assert.equal(result.extra[0].values.paidAmount, 0);
  assert.equal(result.extra[0].values.balance, 100.5); assert.equal(result.extra[0].values.status, 'ISSUED');
  assert.equal(result.extra[1].values.sourceType, 'ReceiptReversal');
  assert.equal(result.extra[2].values.accountId, 'accounts_receivable'); assert.equal(result.extra[2].values.debit, 40.25);
  assert.equal(result.extra[3].values.accountId, 'bank'); assert.equal(result.extra[3].values.credit, 40.25);
  f.data.Journals.push({ companyId: 'tenant', sourceType: 'ReceiptReversal', sourceId: receiptId });
  await assert.rejects(receiptChanges(f.sheets, 'tenant', 'Receipts', receiptId, 'receiptReverse', old,
    { reversalDate: '2026-10-01', reversalReason: 'Again' }, system, 'again'), e => e.code === 'RECEIPT_NOT_REVERSIBLE');
});
