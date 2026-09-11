import 'package:flutter/cupertino.dart';

enum DateRangePreset {
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  thisQuarter('This Quarter'),
  thisYear('This Year'),
  previousMonth('Previous Month'),
  previousYear('Previous Year'),
  allTime('All Time'),
  custom('Custom Range');

  final String label;
  const DateRangePreset(this.label);
}

enum AccountingBasis {
  accrual('Accrual Basis'),
  cash('Cash Basis');

  final String label;
  const AccountingBasis(this.label);
}

enum ComparisonMode {
  none('No Comparison'),
  previousPeriod('Previous Period'),
  previousYear('Previous Year');

  final String label;
  const ComparisonMode(this.label);
}

class ReportFilter {
  final DateRangePreset preset;
  final DateTime startDate;
  final DateTime endDate;
  final AccountingBasis basis;
  final ComparisonMode comparison;
  final String? accountFilter;
  final String? customerFilter;
  final String? supplierFilter;
  final String searchQuery;

  ReportFilter({
    this.preset = DateRangePreset.thisYear,
    DateTime? startDate,
    DateTime? endDate,
    this.basis = AccountingBasis.accrual,
    this.comparison = ComparisonMode.none,
    this.accountFilter,
    this.customerFilter,
    this.supplierFilter,
    this.searchQuery = '',
  })  : startDate = startDate ?? _resolveStartDate(preset),
        endDate = endDate ?? _resolveEndDate(preset);

  ReportFilter copyWith({
    DateRangePreset? preset,
    DateTime? startDate,
    DateTime? endDate,
    AccountingBasis? basis,
    ComparisonMode? comparison,
    String? accountFilter,
    String? customerFilter,
    String? supplierFilter,
    String? searchQuery,
  }) {
    return ReportFilter(
      preset: preset ?? this.preset,
      startDate: startDate ?? (preset != null ? _resolveStartDate(preset) : this.startDate),
      endDate: endDate ?? (preset != null ? _resolveEndDate(preset) : this.endDate),
      basis: basis ?? this.basis,
      comparison: comparison ?? this.comparison,
      accountFilter: accountFilter ?? this.accountFilter,
      customerFilter: customerFilter ?? this.customerFilter,
      supplierFilter: supplierFilter ?? this.supplierFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  static DateTime _resolveStartDate(DateRangePreset preset) {
    final now = DateTime.now();
    switch (preset) {
      case DateRangePreset.today:
        return DateTime(now.year, now.month, now.day);
      case DateRangePreset.thisWeek:
        return now.subtract(Duration(days: now.weekday - 1));
      case DateRangePreset.thisMonth:
        return DateTime(now.year, now.month, 1);
      case DateRangePreset.thisQuarter:
        final qMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return DateTime(now.year, qMonth, 1);
      case DateRangePreset.thisYear:
        return DateTime(now.year, 1, 1);
      case DateRangePreset.previousMonth:
        return DateTime(now.year, now.month - 1, 1);
      case DateRangePreset.previousYear:
        return DateTime(now.year - 1, 1, 1);
      case DateRangePreset.allTime:
        return DateTime(2020, 1, 1);
      case DateRangePreset.custom:
        return DateTime(now.year, 1, 1);
    }
  }

  static DateTime _resolveEndDate(DateRangePreset preset) {
    final now = DateTime.now();
    switch (preset) {
      case DateRangePreset.today:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case DateRangePreset.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      case DateRangePreset.thisMonth:
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        return nextMonth.subtract(const Duration(seconds: 1));
      case DateRangePreset.thisQuarter:
        final qEndMonth = ((now.month - 1) ~/ 3) * 3 + 3;
        final nextQuarter = DateTime(now.year, qEndMonth + 1, 1);
        return nextQuarter.subtract(const Duration(seconds: 1));
      case DateRangePreset.thisYear:
        return DateTime(now.year, 12, 31, 23, 59, 59);
      case DateRangePreset.previousMonth:
        final thisMonth = DateTime(now.year, now.month, 1);
        return thisMonth.subtract(const Duration(seconds: 1));
      case DateRangePreset.previousYear:
        return DateTime(now.year - 1, 12, 31, 23, 59, 59);
      case DateRangePreset.allTime:
        return DateTime(now.year + 5, 12, 31, 23, 59, 59);
      case DateRangePreset.custom:
        return DateTime(now.year, 12, 31, 23, 59, 59);
    }
  }
}

enum ReportCategory {
  financials('Financial Statements', CupertinoIcons.chart_pie_fill, Color(0xFF10B981)),
  receivablesPayables('Receivables & Payables', CupertinoIcons.arrow_right_arrow_left_circle_fill, Color(0xFF38BDF8)),
  salesVat('Sales & UAE VAT', CupertinoIcons.doc_text_fill, Color(0xFF2DD4BF)),
  expenses('Expenses & Outflows', CupertinoIcons.creditcard_fill, Color(0xFFF59E0B)),
  assetsCapital('Assets & Equity', CupertinoIcons.briefcase_fill, Color(0xFF8B5CF6)),
  hrPayroll('HR & Payroll', CupertinoIcons.person_3_fill, Color(0xFFEC4899));

  final String title;
  final IconData icon;
  final Color color;
  const ReportCategory(this.title, this.icon, this.color);
}

enum ReportType {
  // Financial Statements
  financialOverview('Financial Overview', 'Executive summary of key metrics and financial health ratios', ReportCategory.financials),
  profitAndLoss('Profit & Loss (Income Statement)', 'Operating revenue, direct costs, operating expenses, and net profit', ReportCategory.financials),
  balanceSheet('Balance Sheet', 'Statement of financial position verifying Assets = Liabilities + Equity', ReportCategory.financials),
  cashFlow('Cash Flow Statement', 'Cash movements categorized into Operating, Investing, and Financing flows', ReportCategory.financials),
  trialBalance('Trial Balance', 'Summary of all account debits and credits with zero-variance validation', ReportCategory.financials),
  generalLedger('General Ledger Report', 'Detailed audit trail of all posted double-entry journal lines', ReportCategory.financials),

  // Receivables & Payables
  customerBalances('Customer Balances', 'Summary of total invoiced, payments received, and outstanding amounts per client', ReportCategory.receivablesPayables),
  receivablesAging('Receivables Aging Report', 'Outstanding customer balances grouped into Current, 1-30, 31-60, 61-90, 90+ days', ReportCategory.receivablesPayables),
  supplierBalances('Supplier Balances', 'Vendor bill totals, disbursements, and unpaid supplier liabilities', ReportCategory.receivablesPayables),
  payablesAging('Payables Aging Report', 'Unpaid vendor invoices grouped by aging duration from due date', ReportCategory.receivablesPayables),

  // Sales & VAT
  salesByCustomer('Sales by Customer', 'Revenue contribution and invoice breakdown per customer', ReportCategory.salesVat),
  salesByService('Sales by Service / Item', 'Product and service category performance analysis', ReportCategory.salesVat),
  vatSummary('UAE FTA VAT Summary', 'Standard-rated 5% supplies, zero-rated, recoverable input VAT & net tax liability', ReportCategory.salesVat),

  // Expenses
  expensesByCategory('Expenses by Category', 'Operating expenses breakdown across operational categories', ReportCategory.expenses),
  expensesBySupplier('Expenses by Supplier', 'Vendor spending distribution and purchase frequency', ReportCategory.expenses),

  // Assets & Capital
  assetDepreciationSchedule('Fixed Asset Depreciation Schedule', 'Original cost, useful life, monthly depreciation, and current book value', ReportCategory.assetsCapital),
  shareholderCapital('Shareholder Capital Summary', 'Partner equity, agreed capital, cash/asset contributions, and pending equity', ReportCategory.assetsCapital),
  statementOfEquity('Statement of Changes in Equity', 'Shareholder contributions, retained earnings, net income, and closing equity', ReportCategory.assetsCapital),

  // HR & Payroll
  payrollSummary('Payroll Summary Report', 'Basic pay, allowances, overtime, deductions, net salary, and payment status', ReportCategory.hrPayroll),
  attendanceSummary('Attendance & Leave Summary', 'Working days, attendance rate, sick leave, unpaid leave, and overtime hours', ReportCategory.hrPayroll);

  final String title;
  final String description;
  final ReportCategory category;
  const ReportType(this.title, this.description, this.category);
}

class ReportLineItem {
  final String label;
  final String? code;
  final double amount;
  final double? secondaryAmount;
  final bool isHeader;
  final bool isTotal;
  final int indentLevel;
  final List<ReportLineItem> children;
  final Map<String, dynamic>? metadata;

  const ReportLineItem({
    required this.label,
    this.code,
    required this.amount,
    this.secondaryAmount,
    this.isHeader = false,
    this.isTotal = false,
    this.indentLevel = 0,
    this.children = const [],
    this.metadata,
  });
}

class AgingBucketRow {
  final String name;
  final String reference;
  final double current;
  final double days1to30;
  final double days31to60;
  final double days61to90;
  final double daysOver90;
  final double total;

  const AgingBucketRow({
    required this.name,
    this.reference = '',
    required this.current,
    required this.days1to30,
    required this.days31to60,
    required this.days61to90,
    required this.daysOver90,
    required this.total,
  });
}

class VatSummaryReportData {
  final double standardRatedSales;
  final double standardRatedSalesVat;
  final double zeroRatedSales;
  final double exemptSales;
  final double totalSales;
  final double totalOutputVat;

  final double standardRatedExpenses;
  final double recoverableInputVat;
  final double totalInputVat;

  final double netVatPayable;

  const VatSummaryReportData({
    required this.standardRatedSales,
    required this.standardRatedSalesVat,
    required this.zeroRatedSales,
    required this.exemptSales,
    required this.totalSales,
    required this.totalOutputVat,
    required this.standardRatedExpenses,
    required this.recoverableInputVat,
    required this.totalInputVat,
    required this.netVatPayable,
  });
}

class CashFlowSectionData {
  final String title;
  final List<ReportLineItem> items;
  final double netCashFlow;

  const CashFlowSectionData({
    required this.title,
    required this.items,
    required this.netCashFlow,
  });
}
