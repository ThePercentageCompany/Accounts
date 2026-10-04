import { trialBalance, profitAndLoss, balanceSheet, dashboard, generalLedger } from './ledger-report.js';
import { reportConfiguration } from './report-configuration.js';
import { requireThat } from './errors.js';
import { validLedgerDate } from './financial-period-policy.js';

const cents = s => BigInt(String(s).replace('.', ''));
const money = n => n < 0n ? `-${money(-n)}` : `${n / 100n}.${String(n % 100n).padStart(2, '0')}`;
const iso = d => d.toISOString().slice(0, 10);
const date = s => new Date(`${s}T00:00:00Z`);
const previousDay = s => iso(new Date(date(s).getTime() - 86400000));
const active = r => r.isDeleted !== true && r.isDeleted !== 'TRUE';
const roundedDivide = (n, d) => {
  const sign = (n < 0n) !== (d < 0n) ? -1n : 1n, a = n < 0n ? -n : n, b = d < 0n ? -d : d;
  return sign * ((a + b / 2n) / b);
};

export function variance(current, previous) {
  const c = cents(current), p = cents(previous), delta = c - p;
  const percent = p === 0n ? (c === 0n ? '0.00' : null) : money(roundedDivide(delta * 10000n, p < 0n ? -p : p));
  return { amount: money(delta), percent };
}

export function movementTrialBalance(companyId, from, asOf, rows) {
  const ledger = generalLedger(companyId, from, asOf, rows);
  const totals = { openingDebit: 0n, openingCredit: 0n, periodDebit: 0n, periodCredit: 0n, debit: 0n, credit: 0n };
  const split = n => [money(n > 0n ? n : 0n), money(n < 0n ? -n : 0n)];
  const accounts = ledger.accounts.map(a => {
    const [openingDebit, openingCredit] = split(cents(a.opening));
    const [debit, credit] = split(cents(a.closing));
    const result = { accountId: a.accountId, accountName: a.accountName, accountGroup: a.accountGroup,
      openingDebit, openingCredit, periodDebit: a.debit, periodCredit: a.credit, debit, credit };
    for (const k of Object.keys(totals)) totals[k] += cents(result[k]);
    return result;
  });
  return { from, asOf, journalCount: ledger.journalCount, accounts, totalDebit: money(totals.debit), totalCredit: money(totals.credit),
    totalOpeningDebit: money(totals.openingDebit), totalOpeningCredit: money(totals.openingCredit),
    totalPeriodDebit: money(totals.periodDebit), totalPeriodCredit: money(totals.periodCredit),
    openingDifference: money(totals.openingDebit - totals.openingCredit),
    periodDifference: money(totals.periodDebit - totals.periodCredit), closingDifference: money(totals.debit - totals.credit),
    balanced: totals.debit === totals.credit };
}

const sectionFor = a => {
  const r = a.reportingRole;
  if (!r) return `${a.accountGroup} · Unclassified`;
  if (a.accountGroup === 'Asset') return ['fixed-assets', 'accumulated-depreciation', 'non-current-assets'].includes(r) ? 'Non-current assets' : 'Current assets';
  if (a.accountGroup === 'Liability') return ['long-term-debt', 'non-current-liabilities'].includes(r) ? 'Non-current liabilities' : 'Current liabilities';
  return ({ capital: 'Capital', 'retained-earnings': 'Retained earnings', drawings: 'Drawings / distributions',
    'other-equity': 'Other equity', revenue: 'Revenue', 'sales-returns': 'Sales returns', discounts: 'Discounts', cogs: 'Cost of goods sold',
    'operating-expenses': 'Operating expenses', 'other-income': 'Other income', 'other-expenses': 'Other expenses',
    'finance-costs': 'Finance costs', 'tax-expense': 'Tax expense' })[r];
};

function classified(report, config, kind) {
  const registry = new Map(config.accounts.map(a => [a.accountId, a]));
  const present = new Set((report.accounts || []).map(a => a.accountId));
  for (const a of config.accounts) if (a.active && !present.has(a.accountId) &&
    (kind === 'profit-and-loss' ? ['Income', 'Expense'].includes(a.group) : kind === 'balance-sheet' ? ['Asset', 'Liability', 'Equity'].includes(a.group) : true)) {
    report.accounts.push({ accountId: a.accountId, accountName: a.name, accountGroup: a.group,
      ...(kind === 'profit-and-loss' || kind === 'balance-sheet' ? { amount: '0.00' } : { debit: '0.00', credit: '0.00' }),
      ...(kind === 'general-ledger' ? { opening: '0.00', closing: '0.00', entries: [] } : {}),
      ...(kind === 'trial-balance' && report.from ? { openingDebit: '0.00', openingCredit: '0.00', periodDebit: '0.00', periodCredit: '0.00' } : {}),
    });
  }
  report.accounts = (report.accounts || []).map(a => {
    const mapping = registry.get(a.accountId);
    requireThat(!mapping || mapping.group === a.accountGroup, 409, 'REPORT_CLASSIFICATION_CONFLICT',
      'A configured account group differs from its posted ledger classification.');
    const row = { ...a, accountCode: mapping?.code || a.accountId, reportingRole: mapping?.role || '',
      normalSide: mapping?.normalSide || (['Asset', 'Expense'].includes(a.accountGroup) ? 'Debit' : 'Credit') };
    row.section = sectionFor(row);
    const signed = a.amount ?? a.closing ?? money(cents(a.debit) - cents(a.credit));
    // Statement amounts are normal-positive except for contra accounts, whose reviewed normal side is respected.
    const normalPositive = a.amount !== undefined
      ? row.normalSide === (a.accountGroup === 'Asset' || a.accountGroup === 'Expense' ? 'Debit' : 'Credit')
      : row.normalSide === 'Debit';
    row.abnormal = normalPositive ? cents(signed) < 0n : cents(signed) > 0n;
    return row;
  });
  report.sections = [...new Set(report.accounts.map(a => a.section))].map(name => ({ name,
    amount: money(report.accounts.filter(a => a.section === name).reduce((n, a) => n + cents(a.amount ?? money(cents(a.debit) - cents(a.credit))), 0n)) }));
  return report;
}

function detailedProfit(report) {
  const sum = role => report.accounts.filter(a => a.reportingRole === role).reduce((n, a) => n +
    (a.accountGroup === 'Income' && ['sales-returns', 'discounts'].includes(role) ? -cents(a.amount) : cents(a.amount)), 0n);
  const complete = report.accounts.every(a => a.reportingRole);
  const revenue = sum('revenue') - sum('sales-returns') - sum('discounts');
  const gross = revenue - sum('cogs'), operating = gross - sum('operating-expenses');
  report.classificationComplete = complete;
  if (complete) {
    report.netRevenue = money(revenue); report.grossProfit = money(gross); report.operatingProfit = money(operating);
    report.grossMargin = revenue === 0n ? null : money(roundedDivide(gross * 10000n, revenue));
    report.operatingMargin = revenue === 0n ? null : money(roundedDivide(operating * 10000n, revenue));
    report.netMargin = revenue === 0n ? null : money(roundedDivide(cents(report.netProfit) * 10000n, revenue));
  }
  return report;
}

function calculate(companyId, kind, from, asOf, rows, config) {
  let result;
  if (kind === 'trial-balance') result = from ? movementTrialBalance(companyId, from, asOf, rows) : trialBalance(companyId, asOf, rows);
  else if (kind === 'balance-sheet') result = balanceSheet(companyId, asOf, rows);
  else result = ({ dashboard, 'general-ledger': generalLedger, 'profit-and-loss': profitAndLoss })[kind](companyId, from, asOf, rows);
  if (kind !== 'dashboard') classified(result, config, kind);
  if (kind === 'dashboard') {
    const balances = classified(balanceSheet(companyId, asOf, rows), config, 'balance-sheet').accounts;
    for (const [key, role, aliases] of [['cash', 'cash', ['cash', 'cash_in_hand']], ['bank', 'bank', ['bank', 'bank_account']],
      ['receivables', 'receivables', ['accounts_receivable']], ['payables', 'payables', ['accounts_payable']]]) {
      result[key] = money(balances.filter(a => a.reportingRole === role || (!a.reportingRole && aliases.includes(a.accountId)))
        .reduce((n, a) => n + cents(a.amount), 0n));
    }
    const profit = detailedProfit(classified(profitAndLoss(companyId, from, asOf, rows), config, 'profit-and-loss'));
    result.grossProfit = profit.grossProfit ?? null;
    result.netRevenue = profit.netRevenue ?? null;
  }
  if (kind === 'profit-and-loss') detailedProfit(result);
  if (kind === 'balance-sheet') {
    result.difference = money(cents(result.totalAssets) - cents(result.totalLiabilitiesAndEquity));
    const cutoff = date(asOf);
    let yearStart = iso(new Date(Date.UTC(cutoff.getUTCFullYear(), config.financialYearMonth - 1, config.financialYearDay)));
    if (yearStart > asOf) yearStart = iso(new Date(Date.UTC(cutoff.getUTCFullYear() - 1, config.financialYearMonth - 1, config.financialYearDay)));
    result.financialYearStart = yearStart;
    result.currentYearEarnings = profitAndLoss(companyId, yearStart, asOf, rows).netProfit;
    result.priorYearUnclosedEarnings = money(cents(result.accumulatedEarnings) - cents(result.currentYearEarnings));
    for (const [id, name, amount, start, end] of [
      ['__prior_earnings', 'Prior-year unclosed earnings', result.priorYearUnclosedEarnings, '1900-01-01', previousDay(yearStart)],
      ['__current_earnings', 'Current-year earnings after closing transfers', result.currentYearEarnings, yearStart, asOf],
    ]) result.accounts.push({ accountId: id, accountCode: 'Derived', accountName: name, accountGroup: 'Equity', section: 'Unclosed earnings',
      amount, derived: true, from: start, asOf: end, normalSide: 'Credit', abnormal: false });
  }
  return result;
}

export function financialReport(companyId, kind, from, asOf, rows, company, options = {}, now = Date.now()) {
  requireThat(['dashboard', 'general-ledger', 'trial-balance', 'profit-and-loss', 'balance-sheet'].includes(kind), 400, 'INVALID_REPORT', 'Invalid report.');
  requireThat(validLedgerDate(asOf) && (!from || (validLedgerDate(from) && from <= asOf)), 400, 'INVALID_REPORT_DATE', 'Supply ordered report dates.');
  const config = reportConfiguration(company);
  // Activity reports also validate postings before the selected period.
  trialBalance(companyId, asOf, rows);
  const profile = (rows.CompanyProfile || []).find(r => r.companyId === companyId && active(r));
  const result = calculate(companyId, kind, from, asOf, rows, config);
  result.metadata = { companyName: profile?.name || company.name, currency: profile?.currency || 'AED', accountingBasis: 'Accrual · posted journals',
    generatedAt: new Date(now).toISOString(), configurationVersion: config.version, financialYearMonth: config.financialYearMonth,
    financialYearDay: config.financialYearDay, dateFormat: config.dateFormat, numberLocale: config.numberLocale,
    dense: config.dense, parentheses: config.parentheses };
  if (options.compareAsOf) {
    requireThat(validLedgerDate(options.compareAsOf) && (!options.compareFrom ||
      (validLedgerDate(options.compareFrom) && options.compareFrom <= options.compareAsOf)), 400, 'INVALID_REPORT_DATE', 'Supply ordered comparison dates.');
    const previous = calculate(companyId, kind, options.compareFrom || null, options.compareAsOf, rows, config);
    result.comparison = { from: options.compareFrom || null, asOf: options.compareAsOf, totals: {}, accounts: previous.accounts || [] };
    for (const [key, value] of Object.entries(result)) {
      if (typeof value === 'string' && /^-?\d+\.\d{2}$/.test(value) && typeof previous[key] === 'string')
        result.comparison.totals[key] = { previous: previous[key], ...variance(value, previous[key]) };
    }
    const previousAccounts = new Map((previous.accounts || []).map(a => [a.accountId, a]));
    const currentAccounts = new Map((result.accounts || []).map(a => [a.accountId, a]));
    // Include comparison-only accounts so discontinued balances remain visible.
    if (kind !== 'dashboard') {
      for (const a of previous.accounts) if (!currentAccounts.has(a.accountId)) {
        const empty = { ...a, amount: a.amount === undefined ? undefined : '0.00', debit: '0.00', credit: '0.00', closing: '0.00', opening: '0.00', entries: [],
          openingDebit: '0.00', openingCredit: '0.00', periodDebit: '0.00', periodCredit: '0.00', abnormal: false };
        result.accounts.push(empty);
      }
      for (const a of result.accounts) {
        const p = previousAccounts.get(a.accountId);
        const value = a.amount ?? a.closing ?? money(cents(a.debit) - cents(a.credit));
        const old = p ? p.amount ?? p.closing ?? money(cents(p.debit) - cents(p.credit)) : '0.00';
        a.comparison = { previous: old, ...variance(value, old) };
        if (['Income', 'Expense'].includes(a.accountGroup)) a.comparison.favorable =
          cents(a.comparison.amount) === 0n ? null : a.accountGroup === 'Expense' ? cents(a.comparison.amount) < 0n : cents(a.comparison.amount) > 0n;
      }
    }
  }
  if (['dashboard', 'profit-and-loss'].includes(kind)) {
    result.trends = [];
    let cursor = from;
    while (cursor <= asOf && result.trends.length < 120) {
      const d = date(cursor), next = iso(new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1)));
      const end = previousDay(next) < asOf ? previousDay(next) : asOf;
      const p = detailedProfit(classified(profitAndLoss(companyId, cursor, end, rows), config, 'profit-and-loss'));
      result.trends.push({ from: cursor, asOf: end, income: p.totalIncome, expenses: p.totalExpenses, netProfit: p.netProfit });
      cursor = next;
    }
    result.trendsTruncated = cursor <= asOf;
  }
  return result;
}
