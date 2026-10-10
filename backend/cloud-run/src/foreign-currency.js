import { requireThat } from './errors.js';
import { validLedgerDate } from './financial-period-policy.js';
import { minor } from './journal-policy.js';
import { challenge } from './crypto.js';

export const FX_TABLES = ['Invoices', 'Quotations', 'Receipts', 'Income', 'Expenses', 'Payroll'];
export const FX_SCHEMA_TABLES = [...FX_TABLES, 'Employees', 'Customers'];
export const FX_FIELDS = ['currency', 'baseCurrency', 'exchangeRate', 'rateDate', 'rateSource', 'paymentExchangeRate', 'baseAmount', 'preferredCurrency'];
const cache = new Map();
export async function exchangeRate(from, to, date, fetcher = fetch) {
  requireThat(/^[A-Z]{3}$/.test(from) && /^[A-Z]{3}$/.test(to) && validLedgerDate(date), 400, 'INVALID_FX_QUERY', 'Choose valid currency codes and a date.');
  if (from === to) return { currency: from, baseCurrency: to, exchangeRate: 1, rateDate: date, rateSource: 'IDENTITY' };
  const key = `${from}:${to}:${date}`, saved = cache.get(key);
  if (saved && saved.expires > Date.now() && fetcher === fetch) return saved.value;
  try {
    const response = await fetcher(`https://api.frankfurter.dev/v2/rate/${from}/${to}?date=${date}`, { signal: AbortSignal.timeout(8000) });
    requireThat(response.ok, 503, 'FX_UNAVAILABLE', 'Automatic rate unavailable. Enter a manual rate.');
    const data = await response.json();
    requireThat(Number.isFinite(data.rate) && data.rate > 0 && validLedgerDate(data.date) && data.date <= date,
      503, 'FX_UNAVAILABLE', 'Automatic rate unavailable for this date. Enter a manual rate.');
    const value = { currency: from, baseCurrency: to, exchangeRate: Number(data.rate.toFixed(8)), rateDate: data.date, rateSource: 'FRANKFURTER' };
    if (cache.size > 500) cache.clear();
    if (fetcher === fetch) cache.set(key, { value, expires: Date.now() + 3600000 });
    return value;
  } catch (error) {
    if (error.status) throw error;
    requireThat(false, 503, 'FX_UNAVAILABLE', 'Automatic rate unavailable. Enter a manual rate.');
  }
}
export function validRate(rate) {
  requireThat(typeof rate === 'number' && Number.isFinite(rate) && rate > 0 && rate <= 1e8 &&
    Number(rate.toFixed(8)) === rate, 400, 'INVALID_EXCHANGE_RATE', 'Exchange rate must be positive with up to eight decimal places.');
  return rate;
}
export function convert(amount, rate = 1) {
  validRate(rate);
  const [whole, fraction = ''] = rate.toFixed(8).split('.');
  const scaled = BigInt(whole) * 100000000n + BigInt(fraction.padEnd(8, '0'));
  const cents = (minor(amount) * scaled + 50000000n) / 100000000n;
  requireThat(cents <= 100000000000000n, 400, 'FX_AMOUNT_LIMIT', 'Converted amount exceeds supported limits.');
  return Number(cents) / 100;
}
export const recordRate = record => Number(record?.exchangeRate || 1);

export async function currencyValues(sheets, companyId, table, action, old, values) {
  if (!FX_TABLES.includes(table) || !['create', 'update', 'receive'].includes(action)) return values;
  const data = await sheets.read(companyId, ['CompanyProfile']);
  const base = data.CompanyProfile.find(r => r.companyId === companyId && r.isDeleted !== true && r.isDeleted !== 'TRUE')?.currency || 'AED';
  const next = { ...old, ...values }, currency = next.currency || base;
  requireThat(/^[A-Z]{3}$/.test(currency) && (!values.baseCurrency || values.baseCurrency === base), 400, 'INVALID_CURRENCY', 'Choose a valid currency; accounting currency is controlled by the company.');
  let rate = next.exchangeRate;
  // Legacy records remain at their original ledger scale. New foreign records require a rate.
  if (rate === '' || rate == null) rate = currency === base || old ? 1 : null;
  if (rate == null) {
    const date = next.issueDate || next.paymentDate || next.date || `${next.month}-01`;
    const automatic = await exchangeRate(currency, base, date);
    return { ...values, ...automatic };
  }
  validRate(rate);
  requireThat(currency !== base || rate === 1, 400, 'INVALID_EXCHANGE_RATE', 'Same-currency transactions use rate 1.');
  if (next.paymentExchangeRate != null && next.paymentExchangeRate !== '') {
    validRate(next.paymentExchangeRate);
    requireThat(currency !== base || next.paymentExchangeRate === 1, 400, 'INVALID_EXCHANGE_RATE', 'Same-currency payments use rate 1.');
  }
  return { ...values, currency, baseCurrency: base, exchangeRate: rate,
    rateDate: next.rateDate || next.issueDate || next.paymentDate || next.date || `${next.month}-01`, rateSource: next.rateSource || 'MANUAL' };
}

// All generated journals are in company currency; source document totals remain local.
export function convertJournals(changes, record, settlementRate = null, controlRate = null, controlAmounts = {}) {
  const journals = changes.filter(c => c.table === 'Journals');
  let row = Math.max(1, ...changes.filter(c => c.table === 'JournalLines').map(c => c.row)) + 1;
  for (const journal of journals) {
    const lines = changes.filter(c => c.table === 'JournalLines' && c.values.journalId === journal.values.recordId);
    const payment = ['Receipt', 'PayrollPayment', 'IncomePayment', 'ExpensesPayment'].includes(journal.values.sourceType);
    const rate = payment ? settlementRate ?? recordRate(record) : recordRate(record);
    const carry = controlRate ?? recordRate(record);
    for (const line of lines) {
      const control = ['accounts_receivable', 'accounts_payable', 'salary_payable'].includes(line.values.accountId);
      const use = payment && control ? carry : rate;
      line.values.debit = convert(line.values.debit || 0, use);
      line.values.credit = convert(line.values.credit || 0, use);
      if (payment && control && controlAmounts[line.values.accountId] != null) {
        const side = line.values.debit > 0 ? 'debit' : 'credit';
        line.values[side] = controlAmounts[line.values.accountId];
      }
    }
    // A small tax component can round to zero in company currency. Do not persist
    // zero-sided journal lines, which the ledger correctly treats as invalid.
    for (let i = lines.length - 1; i >= 0; i--) {
      if (lines[i].values.debit === 0 && lines[i].values.credit === 0) {
        changes.splice(changes.indexOf(lines[i]), 1);
        lines.splice(i, 1);
      }
    }
    requireThat(lines.length >= 2, 400, 'FX_AMOUNT_TOO_SMALL', 'The converted amount is below company-currency precision.');
    let debit = lines.reduce((s, l) => s + minor(l.values.debit), 0n), credit = lines.reduce((s, l) => s + minor(l.values.credit), 0n);
    const difference = debit - credit;
    if (difference !== 0n && payment) {
      const loss = difference < 0n, amount = Number(loss ? -difference : difference) / 100;
      const meta = lines[0].values;
      changes.push({ table: 'JournalLines', row: row++, values: { ...meta,
        recordId: challenge(`${journal.values.recordId}:fx`), lineNumber: lines.length + 1,
        accountId: loss ? 'fx_loss' : 'fx_gain', accountName: loss ? 'Exchange Loss' : 'Exchange Gain',
        accountGroup: loss ? 'Expense' : 'Income', debit: loss ? amount : 0, credit: loss ? 0 : amount } });
      if (loss) debit -= difference; else credit += difference;
    } else if (difference !== 0n) {
      // Round component lines to the converted document total without an artificial FX gain.
      const side = difference > 0n ? 'credit' : 'debit';
      const line = lines.find(l => l.values[side] > 0);
      line.values[side] = Number(minor(line.values[side]) + (difference > 0n ? difference : -difference)) / 100;
      if (difference > 0n) credit = debit; else debit = credit;
    }
    journal.values.totalDebit = Number(debit) / 100;
    journal.values.totalCredit = Number(credit) / 100;
    requireThat(debit > 0n && debit === credit, 400, 'FX_AMOUNT_TOO_SMALL', 'The converted journal must have a positive balanced total.');
    if (!payment) for (const line of lines) {
      if (['accounts_receivable', 'accounts_payable', 'salary_payable'].includes(line.values.accountId)) {
        controlAmounts[line.values.accountId] = line.values.debit || line.values.credit;
      }
    }
  }
  return changes;
}
