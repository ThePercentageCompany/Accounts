Map<String, dynamic> defaultReportSettings() => {
  'version': 0,
  'financialYearMonth': 1,
  'financialYearDay': 1,
  'dateFormat': 'yyyy-MM-dd',
  'numberLocale': 'en_AE',
  'parentheses': false,
  'dense': false,
  'accounts': <dynamic>[],
  'views': <dynamic>[],
};

const reportRoles = {
  'Asset': [
    'cash',
    'bank',
    'receivables',
    'inventory',
    'prepayments',
    'current-assets',
    'fixed-assets',
    'accumulated-depreciation',
    'non-current-assets',
  ],
  'Liability': [
    'payables',
    'accruals',
    'tax-payable',
    'short-term-debt',
    'long-term-debt',
    'non-current-liabilities',
  ],
  'Equity': ['capital', 'retained-earnings', 'drawings', 'other-equity'],
  'Income': ['revenue', 'sales-returns', 'discounts', 'other-income'],
  'Expense': [
    'sales-returns',
    'discounts',
    'cogs',
    'operating-expenses',
    'other-expenses',
    'finance-costs',
    'tax-expense',
  ],
};
