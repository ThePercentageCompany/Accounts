import { requireThat } from './errors.js';
import { validLedgerDate } from './financial-period-policy.js';

// Decimal currency amounts are converted from their textual representation,
// avoiding floating-point multiplication when rounding tax to minor units.
function hundredths(value, field, maximum) {
  requireThat(typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= maximum,
    400, 'INVALID_MONEY', `${field} must be a nonnegative amount within supported limits.`);
  const match = /^(\d+)(?:\.(\d{1,2}))?$/.exec(String(value));
  requireThat(match, 400, 'INVALID_MONEY', `${field} supports at most two decimal places.`);
  return BigInt(match[1]) * 100n + BigInt((match[2] || '').padEnd(2, '0'));
}

export async function assertCashEntryEditable(sheets, companyId, table, recordId, action) {
  if (!['Income', 'Expenses'].includes(table) || action === 'create') return;
  const sourceTypes = table === 'Income' ? ['Income', 'finance_income'] : ['Expenses', 'expense', 'supplier_bill'];
  const { Journals: journals } = await sheets.read(companyId, ['Journals']);
  requireThat(!journals.some(j => j.companyId === companyId && j.sourceId === recordId &&
    sourceTypes.includes(j.sourceType) && j.isDeleted !== true && j.isDeleted !== 'TRUE'),
  409, 'CASH_ENTRY_LINKED', 'This entry has a linked journal. A coordinated accounting correction is required.');
}

export function cashEntryValues(table, action, old, values) {
  if (!['Income', 'Expenses'].includes(table) || action === 'delete') return values;
  const record = { ...old, ...values };
  requireThat(validLedgerDate(record.date), 400, 'INVALID_CASH_ENTRY', 'Enter a valid entry date.');
  requireThat(typeof record.description === 'string' && record.description.trim().length > 0,
    400, 'INVALID_CASH_ENTRY', 'Enter a description.');
  requireThat(['PAID', 'UNPAID'].includes(record.paymentStatus), 400, 'INVALID_CASH_ENTRY', 'Choose paid or unpaid.');
  requireThat(record.paymentStatus !== 'PAID' || validLedgerDate(record.paidDate),
    400, 'INVALID_CASH_ENTRY', 'Paid entries require a payment date.');
  const amount = hundredths(record.amount, 'amount', 1e12);
  requireThat(amount > 0n, 400, 'INVALID_MONEY', 'Amount must be greater than zero.');
  const rate = hundredths(record.taxRate ?? 0, 'taxRate', 100);
  const tax = (amount * rate + 5000n) / 10000n;
  const total = amount + tax;
  requireThat(total <= 100000000000000n, 400, 'INVALID_MONEY', 'Total exceeds the supported limit.');
  // Only explicitly supplied totals are checked; inherited totals are recalculated
  // when a partial update changes amount/rate.
  for (const [field, expected] of [['taxAmount', tax], ['total', total]]) {
    if (Object.hasOwn(values, field)) {
      requireThat(hundredths(values[field], field, 1e12) === expected,
        400, 'CASH_TOTAL_MISMATCH', `${field} does not match the entry amount and tax rate.`);
    }
  }
  return { ...values, amount: Number(amount) / 100, taxRate: Number(rate) / 100,
    taxAmount: Number(tax) / 100, total: Number(total) / 100,
    paidDate: record.paymentStatus === 'PAID' ? record.paidDate : '' };
}
