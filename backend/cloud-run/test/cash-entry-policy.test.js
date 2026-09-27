import test from 'node:test';
import assert from 'node:assert/strict';
import { cashEntryValues, assertCashEntryEditable } from '../src/cash-entry-policy.js';

test('linked source edits and deletion require coordinated correction, including drafts', async () => {
  for (const [table, sourceType] of [['Income', 'Income'], ['Income', 'finance_income'],
    ['Expenses', 'Expenses'], ['Expenses', 'expense'], ['Expenses', 'supplier_bill']]) {
    for (const status of ['DRAFT', 'POSTED', 'UNKNOWN']) {
      const sheets = { read: async () => ({ Journals: [{ companyId: 'c', sourceId: 'r', sourceType, status }] }) };
      for (const action of ['update', 'delete']) {
        await assert.rejects(assertCashEntryEditable(sheets, 'c', table, 'r', action), e => e.code === 'CASH_ENTRY_LINKED');
      }
    }
  }
});

test('source protection is scoped to active matching journals in the same company', async () => {
  const base = { companyId: 'c', sourceId: 'r', sourceType: 'Income', status: 'POSTED' };
  for (const change of [{ companyId: 'other' }, { sourceId: 'other' }, { sourceType: 'Expenses' },
    { isDeleted: true }, { isDeleted: 'TRUE' }]) {
    await assertCashEntryEditable({ read: async () => ({ Journals: [{ ...base, ...change }] }) }, 'c', 'Income', 'r', 'update');
  }
  const unavailable = { read: async () => { throw new Error('unavailable'); } };
  await assert.rejects(assertCashEntryEditable(unavailable, 'c', 'Income', 'r', 'update'));
  await assertCashEntryEditable(unavailable, 'c', 'Customers', 'r', 'update');
  await assertCashEntryEditable(unavailable, 'c', 'Income', 'r', 'create');
});

const entry = { date: '2026-09-26', description: 'Office supplies', amount: 10.1, taxRate: 5, paymentStatus: 'UNPAID' };
test('income and expense tax uses exact minor-unit half-up rounding', () => {
  for (const table of ['Income', 'Expenses']) {
    const result = cashEntryValues(table, 'create', null, entry);
    assert.equal(result.taxAmount, 0.51);
    assert.equal(result.total, 10.61);
    assert.equal(result.paidDate, '');
  }
});
test('partial updates recalculate inherited totals and clear unpaid payment dates', () => {
  const old = { ...entry, taxAmount: 0.51, total: 10.61, paidDate: '2026-09-26', paymentStatus: 'PAID' };
  const result = cashEntryValues('Expenses', 'update', old, { amount: 20, paymentStatus: 'UNPAID' });
  assert.equal(result.taxAmount, 1);
  assert.equal(result.total, 21);
  assert.equal(result.paidDate, '');
  assert.equal(result.description, undefined); // preserves patch semantics
});
test('forged totals, invalid money, dates and payment state are rejected', () => {
  for (const values of [{ total: 10 }, { taxAmount: 0.5 }, { amount: -1 }, { amount: 0 },
    { amount: 0.001 }, { taxRate: 100.01 }, { date: '2026-02-30' },
    { paymentStatus: 'PARTIAL' }, { paymentStatus: 'PAID' }, { description: '' }]) {
    assert.throws(() => cashEntryValues('Income', 'create', null, { ...entry, ...values }));
  }
});
test('unrelated records and deletions retain their original values', () => {
  const value = {};
  assert.equal(cashEntryValues('Customers', 'create', null, value), value);
  assert.equal(cashEntryValues('Expenses', 'delete', null, value), value);
});
