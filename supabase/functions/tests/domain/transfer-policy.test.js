import test from 'node:test';
import assert from 'node:assert/strict';
import { transferChanges } from '../../_shared/domain/transfer-policy.js';

const input = { date: '2026-10-10', fromAccount: 'cash', toAccount: 'bank', amount: 1000.25, description: 'Cash deposit', reference: 'DEP-1' };
const system = { companyId: 'c', updatedAt: 100, updatedBy: 'owner' };
function fixture() {
  const data = { FinancialPeriods: [], Journals: [], JournalLines: [] };
  return { data, records: { async read(_, names) { return Object.fromEntries(names.map(n => [n, data[n]])); } } };
}
test('drafts reject forged metadata, identical accounts and invalid amounts', async () => {
  const f = fixture();
  const run = v => transferChanges(f.records, 'c', 'MoneyTransfers', 't', 'create', null, v, system, 'op');
  assert.equal((await run(input)).values.status, 'DRAFT');
  for (const values of [{ ...input, status: 'POSTED' }, { ...input, bankStatus: 'CLEARED' }, { ...input, toAccount: 'cash' }, { ...input, amount: 0 }, { ...input, amount: 0.001 }, { ...input, date: '2026-02-30' }]) await assert.rejects(run(values));
});
test('deposits and withdrawals post balanced asset movements and respect closed periods', async () => {
  const f = fixture();
  for (const fromAccount of ['cash', 'bank']) {
    const old = { ...input, fromAccount, toAccount: fromAccount === 'cash' ? 'bank' : 'cash', status: 'DRAFT' };
    const result = await transferChanges(f.records, 'c', 'MoneyTransfers', 't', 'transferPost', old, {}, system, 'post');
    assert.equal(result.values.status, 'POSTED');
    const [journal, debit, credit] = result.extra.map(w => w.values);
    assert.equal(journal.totalDebit, journal.totalCredit);
    assert.equal(debit.debit, input.amount); assert.equal(credit.credit, input.amount);
    assert.equal(debit.accountId, fromAccount === 'cash' ? 'bank_account' : 'cash_in_hand');
    assert.equal(credit.accountId, fromAccount === 'cash' ? 'cash_in_hand' : 'bank_account');
  }
  f.data.FinancialPeriods.push({ companyId: 'c', startDate: '2026-10-01', endDate: '2026-10-31', status: 'CLOSED' });
  await assert.rejects(transferChanges(f.records, 'c', 'MoneyTransfers', 't', 'transferPost', { ...input, status: 'DRAFT' }, {}, system, 'p'), e => e.code === 'PERIOD_CLOSED');
});
test('statement matching changes no journals; posted transfers are locked and reversals swap sides', async () => {
  const f = fixture(), old = { ...input, status: 'POSTED' };
  const match = await transferChanges(f.records, 'c', 'MoneyTransfers', 't', 'transferMatch', old, { bankStatus: 'CLEARED', statementDate: '2026-10-11', statementReference: 'BANK-1' }, system, 'match');
  assert.deepEqual(match.extra, []);
  await assert.rejects(transferChanges(f.records, 'c', 'MoneyTransfers', 't', 'update', old, { amount: 2 }, system, 'edit'), e => e.code === 'TRANSFER_LOCKED');
  const result = await transferChanges(f.records, 'c', 'MoneyTransfers', 't', 'transferReverse', old, { reversalDate: '2026-10-11', reversalReason: 'Wrong amount' }, system, 'reverse');
  assert.equal(result.values.status, 'REVERSED'); assert.equal(result.extra[1].values.accountId, 'cash_in_hand');
  await assert.rejects(transferChanges(f.records, 'c', 'MoneyTransfers', 't', 'transferReverse', { ...old, status: 'REVERSED' }, { reversalDate: '2026-10-11', reversalReason: 'Again' }, system, 'again'));
});
