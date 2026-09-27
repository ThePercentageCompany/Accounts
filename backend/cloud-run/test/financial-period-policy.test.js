import test from 'node:test';
import assert from 'node:assert/strict';
import { financialPeriodValues } from '../src/financial-period-policy.js';

function fixture() {
  const old = { recordId: 'p', companyId: 'c', name: 'September', startDate: '2026-09-01', endDate: '2026-09-30', status: 'OPEN' };
  const periods = [old], journals = [];
  const sheets = { read: async () => ({ FinancialPeriods: periods, Journals: journals }) };
  const change = (values, action = 'update') => financialPeriodValues(sheets, 'c', 'FinancialPeriods', 'p', action, old, values, 'verified-owner', 0);
  return { old, periods, journals, sheets, change };
}
test('closing stamps server identity and time and rejects forged closing metadata', async () => {
  const f = fixture();
  const result = await f.change({ status: 'CLOSED' });
  assert.deepEqual(result, { status: 'CLOSED', closedBy: 'verified-owner', closedAt: '1970-01-01T00:00:00.000Z' });
  for (const field of ['closedBy', 'closedAt']) {
    await assert.rejects(() => f.change({ status: 'CLOSED', [field]: 'forged' }), e => e.code === 'PERIOD_METADATA');
  }
});
test('drafts block closing while posted and deleted/foreign drafts do not', async () => {
  const f = fixture();
  f.journals.push({ companyId: 'c', date: '2026-09-15', status: 'DRAFT' });
  await assert.rejects(() => f.change({ status: 'CLOSED' }), e => e.code === 'PERIOD_HAS_DRAFTS');
  f.journals[0].status = 'POSTED';
  f.journals.push({ companyId: 'other', date: '2026-09-15', status: 'DRAFT' }, { companyId: 'c', date: '2026-09-15', status: 'DRAFT', isDeleted: true });
  await f.change({ status: 'CLOSED' });
});
test('closed periods are immutable and periods with journals cannot be resized/deleted', async () => {
  const f = fixture();
  f.old.status = 'CLOSED';
  await assert.rejects(() => f.change({ status: 'OPEN' }), e => e.code === 'PERIOD_LOCKED');
  await assert.rejects(() => f.change({}, 'delete'), e => e.code === 'PERIOD_LOCKED');
  f.old.status = 'OPEN';
  f.journals.push({ companyId: 'c', date: '2026-09-30', status: 'POSTED' });
  await assert.rejects(() => f.change({ endDate: '2026-09-29' }), e => e.code === 'PERIOD_HAS_JOURNALS');
  await assert.rejects(() => f.change({}, 'delete'), e => e.code === 'PERIOD_HAS_JOURNALS');
});
test('invalid dates and inclusive overlap are rejected', async () => {
  const f = fixture();
  await assert.rejects(() => f.change({ startDate: '2026-02-30' }), e => e.code === 'INVALID_FINANCIAL_PERIOD');
  await assert.rejects(() => f.change({ endDate: '2026-08-31' }), e => e.code === 'INVALID_FINANCIAL_PERIOD');
  f.periods.push({ recordId: 'other', companyId: 'c', startDate: '2026-09-30', endDate: '2026-10-31', status: 'OPEN' });
  await assert.rejects(() => f.change({ name: 'Renamed' }), e => e.code === 'PERIOD_OVERLAP');
  f.periods[1].companyId = 'different-company';
  await f.change({ name: 'Renamed' });
});
