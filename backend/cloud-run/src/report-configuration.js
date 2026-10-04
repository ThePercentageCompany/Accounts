import { requireThat } from './errors.js';
import { validLedgerDate } from './financial-period-policy.js';

export const REPORT_ROLES = Object.freeze({
  Asset: ['cash', 'bank', 'receivables', 'inventory', 'prepayments', 'current-assets', 'fixed-assets', 'accumulated-depreciation', 'non-current-assets'],
  Liability: ['payables', 'accruals', 'tax-payable', 'short-term-debt', 'long-term-debt', 'non-current-liabilities'],
  Equity: ['capital', 'retained-earnings', 'drawings', 'other-equity'],
  Income: ['revenue', 'sales-returns', 'discounts', 'other-income'],
  Expense: ['sales-returns', 'discounts', 'cogs', 'operating-expenses', 'other-expenses', 'finance-costs', 'tax-expense'],
});

export function reportConfiguration(company) {
  return company.reporting || { version: 0, financialYearMonth: 1, financialYearDay: 1,
    dateFormat: 'yyyy-MM-dd', numberLocale: 'en_AE', parentheses: false, dense: false, accounts: [], views: [] };
}

export function validateReportConfiguration(input) {
  requireThat(input && Object.keys(input).every(k => ['expectedVersion', 'settings'].includes(k)) &&
    Number.isSafeInteger(input.expectedVersion) && input.expectedVersion >= 0,
  400, 'INVALID_REPORT_SETTINGS', 'Supply the settings version.');
  const s = input.settings;
  requireThat(s && Object.keys(s).every(k => ['financialYearMonth', 'financialYearDay', 'dateFormat', 'numberLocale', 'parentheses', 'dense', 'accounts', 'views'].includes(k)) &&
    Number.isInteger(s.financialYearMonth) && s.financialYearMonth >= 1 && s.financialYearMonth <= 12 &&
    Number.isInteger(s.financialYearDay) && s.financialYearDay >= 1 && s.financialYearDay <= 28 &&
    ['yyyy-MM-dd', 'dd/MM/yyyy', 'MM/dd/yyyy'].includes(s.dateFormat) && ['en_AE', 'en_US', 'en_IN', 'de_DE'].includes(s.numberLocale) &&
    typeof s.parentheses === 'boolean' && typeof s.dense === 'boolean' && Array.isArray(s.accounts) && s.accounts.length <= 1000 &&
    Array.isArray(s.views) && s.views.length <= 50,
  400, 'INVALID_REPORT_SETTINGS', 'Supply valid report preferences, at most 1000 accounts and 50 views.');
  const ids = new Set(), codes = new Set();
  for (const a of s.accounts) {
    requireThat(a && Object.keys(a).every(k => ['accountId', 'code', 'name', 'group', 'role', 'normalSide', 'active'].includes(k)) &&
      typeof a.accountId === 'string' && /^[A-Za-z0-9_-]{1,100}$/.test(a.accountId) && !ids.has(a.accountId) &&
      typeof a.code === 'string' && /^[A-Za-z0-9.-]{1,24}$/.test(a.code) && !codes.has(a.code) &&
      typeof a.name === 'string' && a.name.trim().length > 0 && a.name.length <= 200 &&
      Object.hasOwn(REPORT_ROLES, a.group) && (a.role === '' || REPORT_ROLES[a.group].includes(a.role)) &&
      ['Debit', 'Credit'].includes(a.normalSide) && typeof a.active === 'boolean',
    400, 'INVALID_REPORT_ACCOUNT', 'Account IDs/codes must be unique and classifications must match the account group.');
    ids.add(a.accountId); codes.add(a.code);
  }
  const viewIds = new Set();
  for (const v of s.views) {
    requireThat(v && Object.keys(v).every(k => ['id', 'name', 'kind', 'from', 'asOf', 'comparison', 'compareFrom', 'compareAsOf', 'search', 'hideZero', 'fullTrial', 'dense', 'parentheses', 'accountId', 'transactionSearch', 'sourceFilter', 'ledgerColumns'].includes(k)) &&
      typeof v.id === 'string' && /^[A-Za-z0-9_-]{16,64}$/.test(v.id) && !viewIds.has(v.id) &&
      typeof v.name === 'string' && v.name.trim().length > 0 && v.name.length <= 100 &&
      ['dashboard', 'general-ledger', 'trial-balance', 'profit-and-loss', 'balance-sheet'].includes(v.kind) &&
      ['none', 'previous-period', 'previous-year', 'custom'].includes(v.comparison) &&
      ['from', 'asOf', 'compareFrom', 'compareAsOf'].every(k => validLedgerDate(v[k])) && v.from <= v.asOf && v.compareFrom <= v.compareAsOf &&
      typeof v.search === 'string' && v.search.length <= 200 &&
      (v.accountId === undefined || v.accountId === null || (typeof v.accountId === 'string' && /^[A-Za-z0-9_-]{1,100}$/.test(v.accountId))) &&
      ['transactionSearch', 'sourceFilter'].every(k => v[k] === undefined || (typeof v[k] === 'string' && v[k].length <= 200)) &&
      (v.ledgerColumns === undefined || (Array.isArray(v.ledgerColumns) && v.ledgerColumns.length <= 7 &&
        ['date', 'debit', 'credit'].every(k => v.ledgerColumns.includes(k)) &&
        v.ledgerColumns.every(k => ['date', 'number', 'description', 'sourceType', 'debit', 'credit', 'balance'].includes(k)))) &&
      ['hideZero', 'fullTrial', 'dense', 'parentheses'].every(k => typeof v[k] === 'boolean'),
    400, 'INVALID_REPORT_VIEW', 'Supply valid saved report settings.');
    viewIds.add(v.id);
  }
  return structuredClone(s);
}
