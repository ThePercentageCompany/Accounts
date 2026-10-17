import test from 'node:test';
import assert from 'node:assert/strict';
import { ledgerStatus } from '../../_shared/domain/ledger-status.js';

const row = { recordId: 'record' };
const journal = { companyId: 'company', sourceId: 'record', status: 'POSTED', sourceType: 'Invoice' };

test('financial sections require an actual posted source journal', () => {
  const sections = { Invoices: 'Invoice', Receipts: 'Receipt', Income: 'Income',
    Expenses: 'Expenses', Payroll: 'Payroll', Assets: 'AssetAcquisition',
    CapitalTransactions: 'CapitalContribution', ShareholderLoans: 'ShareholderLoanReceipt',
    MoneyTransfers: 'MoneyTransfer', CreditNotes: 'InvoiceReturn' };
  for (const [table, sourceType] of Object.entries(sections)) {
    const entry = { ...journal, sourceType };
    assert.equal(ledgerStatus(table, row, [], 'company'), 'UNPOSTED');
    assert.equal(ledgerStatus(table, row, [entry], 'company'), 'LINKED');
    for (const override of [{ status: 'DRAFT' }, { isDeleted: true }, { isDeleted: 'TRUE' },
      { companyId: 'other' }, { sourceId: 'other' }, { sourceType: 'Unrelated' }]) {
      assert.equal(ledgerStatus(table, row, [{ ...entry, ...override }], 'company'), 'UNPOSTED');
    }
  }
});

test('reversals take precedence while invoice returns preserve the original posting', () => {
  assert.equal(ledgerStatus('Invoices', row, [journal, { ...journal, sourceType: 'InvoiceVoid' }], 'company'), 'REVERSED');
  assert.equal(ledgerStatus('Invoices', row, [journal, { ...journal, sourceType: 'InvoiceReturn' }], 'company'), 'LINKED');
  assert.equal(ledgerStatus('Payroll', row, [{ ...journal, sourceType: 'PayrollReversal' }], 'company'), 'REVERSED');
});

test('quotations are not ledger records and journals show their own posting state', () => {
  assert.equal(ledgerStatus('Quotations', row, [], 'company'), 'NOT_APPLICABLE');
  assert.equal(ledgerStatus('Journals', { ...row, status: 'POSTED' }, [], 'company'), 'LINKED');
  assert.equal(ledgerStatus('Journals', { ...row, status: 'DRAFT' }, [], 'company'), 'UNPOSTED');
  assert.equal(ledgerStatus('Customers', row, [], 'company'), undefined);
});
