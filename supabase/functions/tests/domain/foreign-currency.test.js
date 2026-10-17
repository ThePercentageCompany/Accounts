import test from 'node:test';
import assert from 'node:assert/strict';
import { exchangeRate, convert, convertJournals, currencyValues } from '../../_shared/domain/foreign-currency.js';

test('dated rates validate provider data, identity and manual fallback', async () => {
  assert.equal((await exchangeRate('AED', 'AED', '2026-10-10')).exchangeRate, 1);
  const rate = await exchangeRate('INR', 'AED', '2026-10-10', async url => {
    assert.ok(url.includes('/INR/AED?date=2026-10-10'));
    return new Response(JSON.stringify({ rate: 0.04321, date: '2026-10-09' }));
  });
  assert.equal(rate.rateDate, '2026-10-09');
  await assert.rejects(exchangeRate('GBP', 'AED', '2026-10-10', async () => new Response('{}', { status: 503 })), e => e.code === 'FX_UNAVAILABLE');
  await assert.rejects(exchangeRate('GBP', 'AED', '2026-10-10', async () => new Response(JSON.stringify({ rate: -1, date: '2026-10-11' }))), e => e.code === 'FX_UNAVAILABLE');
  assert.equal(convert(50000, 0.04321), 2160.5);
  assert.equal(convert(0.1, 0.15), 0.02);
  for (const rate of [0, -1, NaN, Infinity, 0.000000001]) assert.throws(() => convert(100, rate));
});

test('server fixes accounting currency and preserves saved rates', async () => {
  const records = { read: async () => ({ CompanyProfile: [{ companyId: 'c', currency: 'AED' }] }) };
  const values = await currencyValues(records, 'c', 'Expenses', 'create', null,
    { currency: 'GBP', exchangeRate: 4.7, date: '2026-10-10' });
  assert.equal(values.baseCurrency, 'AED');
  assert.equal((await currencyValues(records, 'c', 'Expenses', 'update', values, { description: 'Edited' })).exchangeRate, 4.7);
  await assert.rejects(currencyValues(records, 'c', 'Expenses', 'create', null, { currency: 'AED', exchangeRate: 2 }), e => e.code === 'INVALID_EXCHANGE_RATE');
  await assert.rejects(currencyValues(records, 'c', 'Expenses', 'create', null, { currency: 'GBP', baseCurrency: 'USD', exchangeRate: 2 }), e => e.code === 'INVALID_CURRENCY');
});

test('settlement posts historical control balances and exchange gains/losses', () => {
  for (const settlement of [4.65, 4.75]) {
    const writes = [
      { table: 'Journals', row: 2, values: { recordId: 'j', sourceType: 'Receipt', totalDebit: 1000, totalCredit: 1000 } },
      { table: 'JournalLines', row: 2, values: { journalId: 'j', accountId: 'bank', debit: 1000, credit: 0 } },
      { table: 'JournalLines', row: 3, values: { journalId: 'j', accountId: 'accounts_receivable', debit: 0, credit: 1000 } },
    ];
    convertJournals(writes, { exchangeRate: settlement }, null, 4.7);
    assert.equal(writes[2].values.credit, 4700);
    assert.equal(writes[3].values.accountId, settlement < 4.7 ? 'fx_loss' : 'fx_gain');
    assert.equal(writes[0].values.totalDebit, writes[0].values.totalCredit);
  }
});

test('small converted tax components are removed and sub-cent journals are rejected', () => {
  const writes = () => [
    { table: 'Journals', row: 2, values: { recordId: 'j', sourceType: 'Invoice' } },
    { table: 'JournalLines', row: 2, values: { journalId: 'j', accountId: 'accounts_receivable', debit: 1.05, credit: 0 } },
    { table: 'JournalLines', row: 3, values: { journalId: 'j', accountId: 'revenue', debit: 0, credit: 1 } },
    { table: 'JournalLines', row: 4, values: { journalId: 'j', accountId: 'vat', debit: 0, credit: 0.05 } },
  ];
  const converted = convertJournals(writes(), { exchangeRate: 0.038 });
  assert.equal(converted.length, 3);
  assert.equal(converted[0].values.totalDebit, 0.04);
  assert.equal(converted[0].values.totalCredit, 0.04);
  assert.throws(() => convertJournals(writes(), { exchangeRate: 0.0001 }), e => e.code === 'FX_AMOUNT_TOO_SMALL');
});
