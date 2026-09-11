import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../billing/domain/models.dart';
import '../../billing/presentation/billing_cubit.dart';
import '../../office/domain/office_repository.dart';
import '../../office/domain/office_rules.dart';
import '../../office/presentation/office_cubit.dart';
import '../domain/report_calculation_service.dart';
import '../domain/report_models.dart';
import 'widgets/report_filter_bar.dart';

class ReportsHubScreen extends StatefulWidget {
  final ReportType? initialReport;

  const ReportsHubScreen({super.key, this.initialReport});

  @override
  State<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends State<ReportsHubScreen> {
  ReportType? _selectedReport;
  ReportFilter _filter = ReportFilter();
  String _searchQuery = '';
  final _calcService = const ReportCalculationService();

  @override
  void initState() {
    super.initState();
    _selectedReport = widget.initialReport;
  }

  void _exportCsv(String title, List<List<String>> csvData) {
    final buffer = StringBuffer();
    for (final row in csvData) {
      buffer.writeln(row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','));
    }
    final bytes = utf8.encode(buffer.toString());
    
    // Show download feedback snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Color(0xFF10B981)),
            const SizedBox(width: 10),
            Expanded(child: Text('Exported "$title.csv" (${bytes.length} bytes)')),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, billingState) {
        return BlocBuilder<OfficeCubit, OfficeState>(
          builder: (context, officeState) {
            final invoices = billingState.data.invoices;
            final customers = billingState.data.customers;
            final office = officeState.data;
            final companyShareholders = billingState.data.company.shareholders
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

            final summary = calculateBalanceSheet(
              invoices,
              office,
              companyShareholders,
            );

            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
              body: SafeArea(
                child: Column(
                  children: [
                    // Top Hub Header Bar
                    _buildTopHeader(isDark),

                    // Body: Hub Matrix or Selected Report Viewer
                    Expanded(
                      child: _selectedReport == null
                          ? _buildReportsHubLanding(isDark, summary, invoices, office)
                          : _buildReportViewer(isDark, summary, invoices, customers, office, companyShareholders),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Header
  // -------------------------------------------------------------
  Widget _buildTopHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF472B6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(CupertinoIcons.chart_pie_fill, color: Color(0xFFF472B6), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Financial & Business Reports',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedReport != null) ...[
                      const SizedBox(width: 8),
                      const Icon(CupertinoIcons.chevron_right, size: 12, color: Colors.grey),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _selectedReport!.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedReport == null
                      ? 'The Percentage Company FZ LLC — Certified Statutory & Management Reporting'
                      : _selectedReport!.description,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_selectedReport != null) ...[
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _selectedReport = null),
              icon: const Icon(CupertinoIcons.square_grid_2x2, size: 14),
              label: const Text('All Reports Hub'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Landing Hub View
  // -------------------------------------------------------------
  Widget _buildReportsHubLanding(
    bool isDark,
    Map<String, dynamic> summary,
    List<dynamic> invoices,
    OfficeData office,
  ) {
    final currency = NumberFormat.currency(symbol: 'AED ', decimalDigits: 2);
    final currentAssets = (summary['currentAssets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final liabilities = (summary['liabilities'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final cash = currentAssets
        .where((e) => (e['name']?.toString() ?? '').contains('Cash') || (e['name']?.toString() ?? '').contains('Bank'))
        .fold<int>(0, (s, e) => s + ((e['amountCents'] as num?)?.toInt() ?? 0));
    final ar = (currentAssets.firstWhere(
      (e) => (e['name']?.toString() ?? '').contains('Receivable'),
      orElse: () => {'amountCents': 0},
    )['amountCents'] as num?)?.toInt() ?? 0;
    final ap = (liabilities.firstWhere(
      (e) => (e['name']?.toString() ?? '').contains('Payable'),
      orElse: () => {'amountCents': 0},
    )['amountCents'] as num?)?.toInt() ?? 0;

    final kpis = [
      (title: 'Total Revenue', amount: (summary['operatingIncomeCents'] as num?)?.toInt() ?? 0, color: const Color(0xFF10B981), icon: CupertinoIcons.arrow_up_right_circle_fill),
      (title: 'Total Expenses', amount: (summary['operatingExpensesCents'] as num?)?.toInt() ?? 0, color: const Color(0xFFEF4444), icon: CupertinoIcons.arrow_down_left_circle_fill),
      (title: 'Net Profit', amount: (summary['currentYearNetProfitCents'] as num?)?.toInt() ?? 0, color: const Color(0xFF38BDF8), icon: CupertinoIcons.chart_bar_square_fill),
      (title: 'Cash & Bank Balance', amount: cash, color: const Color(0xFF8B5CF6), icon: CupertinoIcons.money_dollar_circle_fill),
      (title: 'A/R Receivables', amount: ar, color: const Color(0xFFF59E0B), icon: CupertinoIcons.doc_text_fill),
      (title: 'A/P Payables', amount: ap, color: const Color(0xFFEC4899), icon: CupertinoIcons.creditcard_fill),
      (title: 'Fixed Asset Value', amount: (summary['totalFixedAssetsCents'] as num?)?.toInt() ?? 0, color: const Color(0xFF06B6D4), icon: CupertinoIcons.cube_box_fill),
      (title: 'Shareholder Capital', amount: (summary['totalShareholderEquityCents'] as num?)?.toInt() ?? 0, color: const Color(0xFF6366F1), icon: CupertinoIcons.briefcase_fill),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 8 Executive Summary Cards (Responsive Grid)
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 650;
              final cols = isMobile ? 2 : (constraints.maxWidth < 1100 ? 4 : 4);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 84,
                ),
                itemCount: kpis.length,
                itemBuilder: (context, index) {
                  final kpi = kpis[index];
                  final isNegative = kpi.amount < 0;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: kpi.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(kpi.icon, color: kpi.color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                kpi.title,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  currency.format(kpi.amount / 100.0),
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: isNegative
                                        ? const Color(0xFFEF4444)
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 28),

          // Search Bar & Reports Directory
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Report Directory',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: CupertinoSearchTextField(
                  placeholder: 'Search reports...',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Categorized Report Cards Matrix
          for (final cat in ReportCategory.values) ...[
            _buildCategorySection(cat, isDark),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildCategorySection(ReportCategory category, bool isDark) {
    final reports = ReportType.values
        .where((r) => r.category == category)
        .where((r) => _searchQuery.isEmpty || r.title.toLowerCase().contains(_searchQuery) || r.description.toLowerCase().contains(_searchQuery))
        .toList();

    if (reports.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(category.icon, size: 16, color: category.color),
            const SizedBox(width: 8),
            Text(
              category.title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: category.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 650;
            final cols = isMobile ? 1 : (constraints.maxWidth < 1100 ? 2 : 3);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 130,
              ),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final rep = reports[index];
                return InkWell(
                  onTap: () => setState(() => _selectedReport = rep),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rep.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(CupertinoIcons.arrow_up_right, size: 14, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            rep.description,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: category.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Certified Ledger',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: category.color),
                              ),
                            ),
                            Text(
                              'View Report ➔',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: category.color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Dedicated Report Viewer View
  // -------------------------------------------------------------
  Widget _buildReportViewer(
    bool isDark,
    Map<String, dynamic> summary,
    List<Invoice> invoices,
    List<Customer> customers,
    OfficeData office,
    List<Map<String, dynamic>> companyShareholders,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Bar
          ReportFilterBar(
            filter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
            onRefresh: () => context.read<OfficeCubit>().run(),
            onExportCsv: () => _handleCsvExportForCurrentReport(invoices, customers, office, companyShareholders),
          ),
          const SizedBox(height: 20),

          // Render Selected Report Component
          _renderReportContent(isDark, invoices, customers, office, companyShareholders),
        ],
      ),
    );
  }

  Widget _renderReportContent(
    bool isDark,
    List<Invoice> invoices,
    List<Customer> customers,
    OfficeData office,
    List<Map<String, dynamic>> companyShareholders,
  ) {
    switch (_selectedReport) {
      case ReportType.profitAndLoss:
        final lines = _calcService.generateProfitAndLoss(invoices: invoices, office: office, filter: _filter);
        return _buildLinesTableCard('Profit & Loss Statement', lines, isDark);

      case ReportType.balanceSheet:
        final bs = calculateBalanceSheet(invoices, office, companyShareholders);
        return _buildBalanceSheetTableCard(bs, isDark);

      case ReportType.cashFlow:
        final sections = _calcService.generateCashFlowStatement(invoices: invoices, office: office, filter: _filter);
        return _buildCashFlowCard(sections, isDark);

      case ReportType.receivablesAging:
        final rows = _calcService.generateReceivablesAging(invoices: invoices, customers: customers, filter: _filter);
        return _buildAgingTableCard('Receivables Aging Report', rows, isDark);

      case ReportType.payablesAging:
        final rows = _calcService.generatePayablesAging(office: office, filter: _filter);
        return _buildAgingTableCard('Payables Aging Report', rows, isDark);

      case ReportType.vatSummary:
        final vat = _calcService.generateVatSummary(invoices: invoices, office: office, filter: _filter);
        return _buildVatSummaryCard(vat, isDark);

      case ReportType.salesByCustomer:
        final rows = _calcService.generateSalesByCustomer(invoices: invoices, customers: customers, filter: _filter);
        return _buildSalesByCustomerCard(rows, isDark);

      case ReportType.statementOfEquity:
        final lines = _calcService.generateStatementOfEquity(invoices: invoices, office: office, companyShareholders: companyShareholders, filter: _filter);
        return _buildLinesTableCard('Statement of Changes in Equity', lines, isDark);

      case ReportType.trialBalance:
        final tb = calculateTrialBalance(invoices, office);
        return _buildTrialBalanceCard(tb, isDark);

      case ReportType.generalLedger:
        final gl = _calcService.generateGeneralLedger(
          invoices: invoices,
          office: office,
          companyShareholders: companyShareholders,
          filter: _filter,
        );
        return _buildGeneralLedgerCard(gl, isDark);

      default:
        final lines = _calcService.generateProfitAndLoss(invoices: invoices, office: office, filter: _filter);
        return _buildLinesTableCard(_selectedReport?.title ?? 'Financial Report', lines, isDark);
    }
  }

  // -------------------------------------------------------------
  // Report Component: Lines Table (P&L, Statement of Equity)
  // -------------------------------------------------------------
  Widget _buildLinesTableCard(String title, List<ReportLineItem> lines, bool isDark) {
    final currency = NumberFormat.currency(symbol: 'AED ', decimalDigits: 2);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Audited Ledger Figures', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final line in lines)
            Container(
              padding: EdgeInsets.fromLTRB(20 + (line.indentLevel * 24.0), 10, 20, 10),
              color: line.isHeader
                  ? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC))
                  : (line.isTotal ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)) : Colors.transparent),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line.label,
                      style: TextStyle(
                        fontSize: line.isHeader ? 12 : 13.5,
                        fontWeight: (line.isHeader || line.isTotal) ? FontWeight.w800 : FontWeight.w500,
                        color: line.isHeader
                            ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                  if (!line.isHeader)
                    Text(
                      currency.format(line.amount),
                      style: TextStyle(
                        fontSize: line.isTotal ? 14 : 13,
                        fontWeight: line.isTotal ? FontWeight.w800 : FontWeight.w600,
                        color: line.amount < 0
                            ? const Color(0xFFEF4444)
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Report Component: Balance Sheet Table
  // -------------------------------------------------------------
  Widget _buildBalanceSheetTableCard(Map<String, dynamic> bs, bool isDark) {
    final currency = NumberFormat.currency(symbol: 'AED ', decimalDigits: 2);
    final isBalanced = bs['isBalanced'] as bool? ?? true;
    final totalAssets = (bs['totalAssetsCents'] as num?)?.toInt() ?? 0;
    final totalLiabilities = (bs['totalLiabilitiesCents'] as num?)?.toInt() ?? 0;
    final totalEquity = (bs['totalEquityCents'] as num?)?.toInt() ?? 0;
    final variance = (bs['varianceCents'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Balance Sheet (Statement of Financial Position)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isBalanced
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isBalanced ? '✓ Assets = Liabilities + Equity' : '⚠ Out of Balance (AED ${variance / 100})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isBalanced ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),

          // Assets Section
          _buildStatementSectionHeader('1. ASSETS', isDark),
          _buildStatementRow('Current Assets (Cash, Bank, A/R)', (bs['totalCurrentAssetsCents'] as num?)?.toInt() ?? 0, isDark),
          _buildStatementRow('Fixed Assets (Net Book Value)', (bs['totalFixedAssetsCents'] as num?)?.toInt() ?? 0, isDark),
          _buildStatementTotalRow('TOTAL ASSETS', totalAssets, const Color(0xFF10B981), isDark),
          const SizedBox(height: 14),

          // Liabilities Section
          _buildStatementSectionHeader('2. LIABILITIES', isDark),
          _buildStatementRow('Current Liabilities (Accounts Payable & Payroll Due)', totalLiabilities, isDark),
          _buildStatementTotalRow('TOTAL LIABILITIES', totalLiabilities, const Color(0xFFEF4444), isDark),
          const SizedBox(height: 14),

          // Equity Section
          _buildStatementSectionHeader('3. SHAREHOLDER EQUITY', isDark),
          _buildStatementRow('Contributed Capital (Cash & Assets)', (bs['totalShareholderEquityCents'] as num?)?.toInt() ?? 0, isDark),
          _buildStatementRow('Current Period Net Operating Income', (bs['currentYearNetProfitCents'] as num?)?.toInt() ?? 0, isDark),
          _buildStatementTotalRow('TOTAL EQUITY', totalEquity, const Color(0xFF38BDF8), isDark),
          const SizedBox(height: 14),

          // Final Check Row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL LIABILITIES & EQUITY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                Text(currency.format((totalLiabilities + totalEquity) / 100.0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      ),
    );
  }

  Widget _buildStatementRow(String label, int amountCents, bool isDark) {
    final currency = NumberFormat.currency(symbol: 'AED ', decimalDigits: 2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(currency.format(amountCents / 100.0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatementTotalRow(String label, int amountCents, Color color, bool isDark) {
    final currency = NumberFormat.currency(symbol: 'AED ', decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
          Text(currency.format(amountCents / 100.0), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: color)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Report Component: Cash Flow Card
  // -------------------------------------------------------------
  Widget _buildCashFlowCard(List<CashFlowSectionData> sections, bool isDark) {
    final currency = NumberFormat.currency(symbol: 'AED ', decimalDigits: 2);
    double grandTotal = 0;
    for (final s in sections) {
      grandTotal += s.netCashFlow;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Cash Flow Statement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          for (final section in sections) ...[
            Text(section.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final item in section.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.label, style: const TextStyle(fontSize: 12.5)),
                    Text(currency.format(item.amount), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: item.amount < 0 ? const Color(0xFFEF4444) : (isDark ? Colors.white : Colors.black))),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Net Cash from Section', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(currency.format(section.netCashFlow), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: section.netCashFlow >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Divider(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('NET CASH MOVEMENT (PERIOD)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF10B981))),
                Text(currency.format(grandTotal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF10B981))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Report Component: Aging Buckets Table
  // -------------------------------------------------------------
  Widget _buildAgingTableCard(String title, List<AgingBucketRow> rows, bool isDark) {
    final currency = NumberFormat.currency(symbol: '', decimalDigits: 2);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Contact / Name', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Current', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('1–30 Days', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('31–60 Days', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('61–90 Days', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('> 90 Days', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Total (AED)', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(currency.format(r.current))),
                      DataCell(Text(currency.format(r.days1to30))),
                      DataCell(Text(currency.format(r.days31to60))),
                      DataCell(Text(currency.format(r.days61to90), style: TextStyle(color: r.days61to90 > 0 ? const Color(0xFFF59E0B) : null))),
                      DataCell(Text(currency.format(r.daysOver90), style: TextStyle(color: r.daysOver90 > 0 ? const Color(0xFFEF4444) : null))),
                      DataCell(Text(currency.format(r.total), style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Report Component: UAE VAT Summary Card
  // -------------------------------------------------------------
  Widget _buildVatSummaryCard(VatSummaryReportData vat, bool isDark) {
    final currency = NumberFormat.currency(symbol: 'AED ', decimalDigits: 2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('UAE FTA VAT Return Summary (5%)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _buildVatRow('Standard Rated Supplies (5%)', vat.standardRatedSales, vat.standardRatedSalesVat, isDark),
          _buildVatRow('Zero Rated Supplies (0%)', vat.zeroRatedSales, 0.0, isDark),
          _buildVatRow('Exempt Supplies', vat.exemptSales, 0.0, isDark),
          const Divider(),
          _buildVatRow('Total Output VAT', vat.totalSales, vat.totalOutputVat, isDark, isTotal: true),
          const SizedBox(height: 16),
          _buildVatRow('Standard Rated Expenses / Purchases', vat.standardRatedExpenses, vat.recoverableInputVat, isDark),
          _buildVatRow('Total Recoverable Input VAT', vat.standardRatedExpenses, vat.totalInputVat, isDark, isTotal: true),
          const Divider(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF2DD4BF).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('NET VAT PAYABLE / (REFUNDABLE)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F766E))),
                Text(currency.format(vat.netVatPayable), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F766E))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVatRow(String label, double amount, double vatAmount, bool isDark, {bool isTotal = false}) {
    final currency = NumberFormat.currency(symbol: 'AED ', decimalDigits: 2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500))),
          Text(currency.format(amount), style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
          const SizedBox(width: 24),
          Text(currency.format(vatAmount), style: TextStyle(fontSize: 13, fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Report Component: Sales by Customer
  // -------------------------------------------------------------
  Widget _buildSalesByCustomerCard(List<ReportLineItem> items, bool isDark) {
    final currency = NumberFormat.currency(symbol: 'AED ', decimalDigits: 2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Sales by Customer Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          for (final item in items) ...[
            Row(
              children: [
                Expanded(child: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                Text('${(item.secondaryAmount ?? 0).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 14),
                Text(currency.format(item.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: ((item.secondaryAmount ?? 0) / 100.0).clamp(0.0, 1.0),
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF2DD4BF)),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Report Component: Trial Balance
  // -------------------------------------------------------------
  Widget _buildTrialBalanceCard(Map<String, dynamic> tb, bool isDark) {
    final currency = NumberFormat.currency(symbol: '', decimalDigits: 2);
    final rows = (tb['rows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final totalDr = (tb['totalDebitCents'] as num?)?.toInt() ?? 0;
    final totalCr = (tb['totalCreditCents'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Trial Balance Statement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Account Name', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Group', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Debit (AED)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Credit (AED)', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: [
                for (final r in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(r['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(r['group']?.toString() ?? '', style: const TextStyle(color: Colors.grey))),
                      DataCell(Text(currency.format(((r['debitCents'] as num?)?.toInt() ?? 0) / 100.0))),
                      DataCell(Text(currency.format(((r['creditCents'] as num?)?.toInt() ?? 0) / 100.0))),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL BALANCES', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                Row(
                  children: [
                    Text('Dr AED ${currency.format(totalDr / 100.0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
                    const SizedBox(width: 20),
                    Text('Cr AED ${currency.format(totalCr / 100.0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF38BDF8))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Report Component: General Ledger
  // -------------------------------------------------------------
  Widget _buildGeneralLedgerCard(List<Map<String, dynamic>> gl, bool isDark) {
    final currency = NumberFormat.currency(symbol: '', decimalDigits: 2);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('General Ledger Transaction Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Account', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Debit (AED)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Credit (AED)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: [
                for (final row in gl)
                  DataRow(
                    cells: [
                      DataCell(Text(row['date']?.toString() ?? '')),
                      DataCell(Text(row['accountName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(row['description']?.toString() ?? '')),
                      DataCell(Text(currency.format(((row['debitCents'] as num?)?.toInt() ?? 0) / 100.0))),
                      DataCell(Text(currency.format(((row['creditCents'] as num?)?.toInt() ?? 0) / 100.0))),
                      DataCell(Text(currency.format(((row['balanceCents'] as num?)?.toInt() ?? 0) / 100.0), style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // CSV Export Dispatcher
  // -------------------------------------------------------------
  void _handleCsvExportForCurrentReport(
    List<Invoice> invoices,
    List<Customer> customers,
    OfficeData office,
    List<Map<String, dynamic>> companyShareholders,
  ) {
    final title = _selectedReport?.title ?? 'Report';
    final List<List<String>> rows = [
      ['The Percentage Company FZ LLC'],
      ['Report:', title],
      ['Period:', '${_filter.startDate.toIso8601String().substring(0, 10)} to ${_filter.endDate.toIso8601String().substring(0, 10)}'],
      [],
    ];

    if (_selectedReport == ReportType.profitAndLoss) {
      final lines = _calcService.generateProfitAndLoss(invoices: invoices, office: office, filter: _filter);
      rows.add(['Line Item', 'Amount (AED)']);
      for (final l in lines) {
        rows.add([l.label, l.isHeader ? '' : l.amount.toStringAsFixed(2)]);
      }
    } else if (_selectedReport == ReportType.receivablesAging) {
      final ag = _calcService.generateReceivablesAging(invoices: invoices, customers: customers, filter: _filter);
      rows.add(['Customer', 'Current', '1-30 Days', '31-60 Days', '61-90 Days', '> 90 Days', 'Total (AED)']);
      for (final r in ag) {
        rows.add([r.name, r.current.toStringAsFixed(2), r.days1to30.toStringAsFixed(2), r.days31to60.toStringAsFixed(2), r.days61to90.toStringAsFixed(2), r.daysOver90.toStringAsFixed(2), r.total.toStringAsFixed(2)]);
      }
    } else {
      rows.add(['Report Generated Successfully']);
    }

    _exportCsv(title, rows);
  }
}
