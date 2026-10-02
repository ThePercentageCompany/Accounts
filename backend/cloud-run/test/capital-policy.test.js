import test from 'node:test';
import assert from 'node:assert/strict';
import { capitalChanges } from '../src/capital-policy.js';

function fixture() {
  const data = { CapitalTransactions: [], FinancialPeriods: [], Journals: [], JournalLines: [] };
  return { data, sheets: { read: async (_id, names) => Object.fromEntries(names.map(name => [name, data[name] || []])) } };
}
const system = { companyId: 'c', updatedAt: 1, updatedBy: 'owner', idempotencyKey: 'marker', isDeleted: false, syncStatus: 'SYNCED' };
const shareholderId = 's'.repeat(43);
const input = { date: '2026-09-29', capitalAccountId: '', shareholderId, kind: 'CAPITAL_CONTRIBUTION', amount: 25000,
  method: 'PAID', destinationAccount: 'Bank', assetId: '', reference: 'CAP-001' };

test('shareholder input is normalized and validated', async () => {
  const f = fixture();
  const result = await capitalChanges(f.sheets, 'c', 'Shareholders', 's', 'create', null,
    { name: ' Founder ', email: '', phone: '', role: 'Founder', status: 'ACTIVE', agreedCapital: 25000, investmentDate: '2026-09-29' }, system, 'op');
  assert.equal(result.values.name, 'Founder');
  await assert.rejects(capitalChanges(f.sheets, 'c', 'Shareholders', 's', 'create', null,
    { name: '', status: 'ACTIVE', agreedCapital: 0, investmentDate: '' }, system, 'bad'), e => e.code === 'INVALID_SHAREHOLDER');
});

test('capital drafts derive status and reject duplicate references', async () => {
  const f = fixture();
  const result = await capitalChanges(f.sheets, 'c', 'CapitalTransactions', 't', 'create', null, input, system, 'op');
  assert.equal(result.values.status, 'DRAFT');
  f.data.CapitalTransactions.push({ companyId: 'c', recordId: 'other', ...input, status: 'DRAFT' });
  await assert.rejects(capitalChanges(f.sheets, 'c', 'CapitalTransactions', 't', 'create', null, input, system, 'other'), e => e.code === 'CAPITAL_REFERENCE_DUPLICATE');
});

test('posting contribution creates balanced cash-to-equity journal and locks record', async () => {
  const f = fixture(), old = { companyId: 'c', recordId: 't', ...input, status: 'DRAFT' };
  const result = await capitalChanges(f.sheets, 'c', 'CapitalTransactions', 't', 'capitalPost', old, {}, system, 'post');
  assert.equal(result.values.status, 'POSTED'); assert.equal(result.extra[0].values.sourceType, 'CapitalContribution');
  assert.equal(result.extra[1].values.accountId, 'bank'); assert.equal(result.extra[1].values.debit, 25000);
  assert.equal(result.extra[2].values.accountId, 'shareholder_equity'); assert.equal(result.extra[2].values.credit, 25000);
  await assert.rejects(capitalChanges(f.sheets, 'c', 'CapitalTransactions', 't', 'update', { ...old, status: 'POSTED' }, input, system, 'edit'), e => e.code === 'CAPITAL_LOCKED');
});

test('capital transaction rejects forged status and unsupported forms', async () => {
  const f = fixture();
  await assert.rejects(capitalChanges(f.sheets, 'c', 'CapitalTransactions', 't', 'create', null, { ...input, status: 'POSTED' }, system, 'x'), e => e.code === 'CAPITAL_DERIVED_FIELD');
  await assert.rejects(capitalChanges(f.sheets, 'c', 'CapitalTransactions', 't', 'create', null, { ...input, method: 'PROMISE' }, system, 'x'), e => e.code === 'INVALID_CAPITAL_TRANSACTION');
});

test('shareholder loan receipt and repayment create balanced liability journals', async () => {
  const f = fixture();
  const draftInput = { shareholderId, date: '2026-09-01', kind: 'LOAN_TO_COMPANY', principal: 10000,
    interestRate: 0, dueDate: '2027-09-01', paymentAccount: 'Bank', reference: 'LOAN-1' };
  const draft = await capitalChanges(f.sheets, 'c', 'ShareholderLoans', 'l', 'create', null, draftInput, system, 'create');
  assert.equal(draft.values.status, 'DRAFT'); assert.equal(draft.values.outstandingBalance, 10000);
  const postedRow = { companyId: 'c', recordId: 'l', ...draftInput, ...draft.values };
  const posted = await capitalChanges(f.sheets, 'c', 'ShareholderLoans', 'l', 'loanPost', postedRow, {}, system, 'post');
  assert.equal(posted.values.status, 'ACTIVE'); assert.equal(posted.extra[1].values.debit, 10000);
  assert.equal(posted.extra[2].values.accountId, 'shareholder_loan');
  const repaid = await capitalChanges(f.sheets, 'c', 'ShareholderLoans', 'l', 'loanRepay',
    { ...postedRow, status: 'ACTIVE' }, { lastRepaymentDate: '2026-10-01', paymentAccount: 'Cash', paymentReference: 'PAY-1' }, system, 'repay');
  assert.equal(repaid.values.status, 'REPAID'); assert.equal(repaid.values.outstandingBalance, 0);
  assert.equal(repaid.extra[1].values.accountId, 'shareholder_loan'); assert.equal(repaid.extra[2].values.accountId, 'cash');
});

test('shareholder loans reject interest, forged balances and invalid transitions', async () => {
  const f = fixture(), base = { shareholderId, date: '2026-09-01', kind: 'LOAN_TO_COMPANY', principal: 100,
    interestRate: 0, dueDate: '', paymentAccount: 'Bank', reference: '' };
  await assert.rejects(capitalChanges(f.sheets, 'c', 'ShareholderLoans', 'l', 'create', null,
    { ...base, interestRate: 5 }, system, 'interest'), e => e.code === 'INVALID_SHAREHOLDER_LOAN');
  await assert.rejects(capitalChanges(f.sheets, 'c', 'ShareholderLoans', 'l', 'create', null,
    { ...base, outstandingBalance: 1 }, system, 'forged'), e => e.code === 'SHAREHOLDER_LOAN_DERIVED_FIELD');
  await assert.rejects(capitalChanges(f.sheets, 'c', 'ShareholderLoans', 'l', 'loanRepay',
    { ...base, status: 'DRAFT', outstandingBalance: 100 }, { lastRepaymentDate: '2026-10-01', paymentAccount: 'Bank' }, system, 'bad'),
  e => e.code === 'SHAREHOLDER_LOAN_NOT_REPAYABLE');
});
