import { requireThat } from './errors.js';

const active = row => row && row.isDeleted !== true && row.isDeleted !== 'TRUE';
export function validLedgerDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(value);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

export async function assertOpenLedgerDate(sheets, companyId, date) {
  requireThat(validLedgerDate(date), 400, 'INVALID_JOURNAL_DATE', 'Posting requires a valid journal date.');
  const { FinancialPeriods: periods } = await sheets.read(companyId, ['FinancialPeriods']);
  for (const period of periods.filter(p => p.companyId === companyId && active(p))) {
    requireThat(validLedgerDate(period.startDate) && validLedgerDate(period.endDate) && period.startDate <= period.endDate,
      409, 'INVALID_FINANCIAL_PERIOD', 'Correct the financial period dates before posting.');
    if (period.startDate <= date && date <= period.endDate) {
      requireThat(period.status === 'OPEN', 409, 'PERIOD_CLOSED', 'The journal date is in a closed or unavailable financial period.');
    }
  }
}

export async function financialPeriodValues(sheets, companyId, table, recordId, action, old, values, actor, now) {
  if (table !== 'FinancialPeriods') return values;
  requireThat(!old || old.status === 'OPEN', 409, 'PERIOD_LOCKED', 'Closed or unknown-state periods cannot be changed through record editing.');
  requireThat(!Object.hasOwn(values, 'closedBy') && !Object.hasOwn(values, 'closedAt'),
    400, 'PERIOD_METADATA', 'Period closing metadata is assigned by the server.');
  const next = { ...old, ...values };
  if (action !== 'delete') {
    requireThat(validLedgerDate(next.startDate) && validLedgerDate(next.endDate) && next.startDate <= next.endDate,
      400, 'INVALID_FINANCIAL_PERIOD', 'Enter an ordered start and end date.');
    requireThat(typeof next.name === 'string' && next.name.trim().length > 0 && ['OPEN', 'CLOSED'].includes(next.status),
      400, 'INVALID_FINANCIAL_PERIOD', 'Enter a period name and valid status.');
    requireThat(action !== 'create' || next.status === 'OPEN', 400, 'INVALID_FINANCIAL_PERIOD', 'Create a period as open before closing it.');
    const { FinancialPeriods: periods } = await sheets.read(companyId, ['FinancialPeriods']);
    requireThat(!periods.some(p => p.companyId === companyId && p.recordId !== recordId && active(p) &&
      p.startDate <= next.endDate && next.startDate <= p.endDate),
    409, 'PERIOD_OVERLAP', 'Financial periods cannot overlap.');
  }
  const { Journals: journals } = await sheets.read(companyId, ['Journals']);
  const contained = journals.filter(j => j.companyId === companyId && active(j) && old && old.startDate <= j.date && j.date <= old.endDate);
  if (old && (action === 'delete' || next.startDate !== old.startDate || next.endDate !== old.endDate)) {
    requireThat(contained.length === 0, 409, 'PERIOD_HAS_JOURNALS', 'A period containing journals cannot be deleted or resized.');
  }
  if (action !== 'delete' && next.status === 'CLOSED') {
    requireThat(!journals.some(j => j.companyId === companyId && active(j) && next.startDate <= j.date && j.date <= next.endDate && j.status !== 'POSTED'),
      409, 'PERIOD_HAS_DRAFTS', 'Post or remove draft journals before closing this period.');
    return { ...values, closedBy: actor, closedAt: new Date(now).toISOString() };
  }
  return values;
}
