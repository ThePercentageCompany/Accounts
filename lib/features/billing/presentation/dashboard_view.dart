import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../office/presentation/office_cubit.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/totals.dart';
import 'billing_cubit.dart';

class DashboardView extends StatefulWidget {
  final VoidCallback onNewInvoice;
  final ValueChanged<int> onNavigate;

  const DashboardView({
    super.key,
    required this.onNewInvoice,
    required this.onNavigate,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late String _selectedPeriod;
  late String _cashFlowPeriod;
  int? _hoveredMonthIndex;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedPeriod = 'This Year (${now.year})';
    _cashFlowPeriod = 'This Month';
  }

  void _showDateRangePicker() {
    final now = DateTime.now();
    final periods = [
      'This Month',
      'This Quarter',
      'This Year (${now.year})',
      'Year ${now.year - 1}',
      'Last 12 Months',
      'All Time',
    ];

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Select Reporting Period',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const Divider(),
              for (final p in periods)
                ListTile(
                  title: Text(p),
                  trailing: _selectedPeriod == p
                      ? const Icon(CupertinoIcons.checkmark_alt, color: Color(0xFF10B981))
                      : null,
                  onTap: () {
                    setState(() => _selectedPeriod = p);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCashFlowPicker() {
    final periods = ['This Month', 'Last Month', 'This Quarter', 'This Year'];
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Select Cash Flow Period',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const Divider(),
              for (final p in periods)
                ListTile(
                  title: Text(p),
                  trailing: _cashFlowPeriod == p
                      ? const Icon(CupertinoIcons.checkmark_alt, color: Color(0xFF10B981))
                      : null,
                  onTap: () {
                    setState(() => _cashFlowPeriod = p);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAmount(double val, {bool showDecimals = false}) {
    final formatter = NumberFormat.currency(
      symbol: 'AED ',
      decimalDigits: showDecimals ? 2 : (val % 1 == 0 ? 0 : 2),
    );
    return formatter.format(val);
  }

  bool _isDateInSelectedPeriod(String dateStr, String period) {
    if (dateStr.isEmpty) return false;
    final now = DateTime.now();
    final d = DateTime.tryParse(dateStr);
    if (d == null) return false;

    if (period == 'This Month') {
      return d.year == now.year && d.month == now.month;
    } else if (period == 'This Quarter') {
      final currentQ = ((now.month - 1) ~/ 3) + 1;
      final dateQ = ((d.month - 1) ~/ 3) + 1;
      return d.year == now.year && dateQ == currentQ;
    } else if (period.startsWith('This Year')) {
      return d.year == now.year;
    } else if (period.startsWith('Year')) {
      final y = int.tryParse(period.replaceAll(RegExp(r'[^0-9]'), '')) ?? (now.year - 1);
      return d.year == y;
    } else if (period == 'Last 12 Months') {
      final cutoff = now.subtract(const Duration(days: 365));
      return d.isAfter(cutoff) && d.isBefore(now.add(const Duration(days: 1)));
    }
    return true; // 'All Time'
  }

  int _getSelectedYear() {
    final now = DateTime.now();
    if (_selectedPeriod.startsWith('Year')) {
      return int.tryParse(_selectedPeriod.replaceAll(RegExp(r'[^0-9]'), '')) ?? now.year;
    }
    return now.year;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1100;
    final isTablet = width >= 700 && width < 1100;

    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, billingState) {
        return BlocBuilder<OfficeCubit, OfficeState>(
          builder: (context, officeState) {
            final invoices = billingState.data.invoices;
            final officeData = officeState.data;

            // ---------------------------------------------------------
            // 1. LIVE KPI CALCULATIONS
            // ---------------------------------------------------------
            double liveIncome = 0;
            double liveExpenses = 0;
            double liveReceivables = 0;
            double livePayables = 0;
            double liveOtherIncome = 0;
            double liveOtherExpenses = 0;

            // Invoices: Collections & Receivables
            for (final inv in invoices) {
              final totals = Totals.of(inv);
              if (inv.status == 'issued') {
                liveReceivables += totals.balance / 100.0;
              }
              // Payment receipts in selected period
              for (final p in inv.payments) {
                if (_isDateInSelectedPeriod(p.date, _selectedPeriod)) {
                  liveIncome += p.cents / 100.0;
                }
              }
            }

            // Office Finance entries
            for (final e in officeData.entries) {
              final amount = double.tryParse(e['amount']?.toString() ?? '0') ?? 0;
              final date = e['date']?.toString() ?? (e['paidDate']?.toString() ?? '');
              final isPaid = e['status'] == 'paid';
              final isUnpaid = e['status'] == 'unpaid';

              if (isUnpaid) {
                livePayables += amount;
              }

              if (isPaid && _isDateInSelectedPeriod(date, _selectedPeriod)) {
                if (e['kind'] == 'income') {
                  liveIncome += amount;
                  liveOtherIncome += amount;
                } else if (e['kind'] == 'expense') {
                  liveExpenses += amount;
                  liveOtherExpenses += amount;
                }
              }
            }

            // Payroll payouts
            for (final p in officeData.payroll) {
              final net = (p['netCents'] as num? ?? 0) / 100.0;
              final paidDate = p['paidDate']?.toString() ?? '${p['month']}-01';
              final isPaid = p['status'] == 'paid';
              final isApproved = p['status'] == 'approved';

              if (isApproved) {
                livePayables += net;
              }

              if (isPaid && _isDateInSelectedPeriod(paidDate, _selectedPeriod)) {
                liveExpenses += net;
              }
            }

            final netProfit = liveIncome - liveExpenses;
            final bankBalance = liveIncome - liveExpenses;

            // ---------------------------------------------------------
            // 2. LIVE MONTHLY 12-MONTH DUAL BAR CHART DATA
            // ---------------------------------------------------------
            final targetYear = _getSelectedYear();
            final monthlyData = <Map<String, dynamic>>[];
            double maxMonthVal = 0;

            final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            for (int m = 1; m <= 12; m++) {
              final monthKey = '$targetYear-${m.toString().padLeft(2, '0')}';
              double mIncome = 0;
              double mExpense = 0;

              // Invoice payments in this month
              for (final inv in invoices) {
                for (final p in inv.payments) {
                  if (p.date.startsWith(monthKey)) {
                    mIncome += p.cents / 100.0;
                  }
                }
              }

              // Office entries in this month
              for (final e in officeData.entries) {
                final date = e['paidDate']?.toString() ?? (e['date']?.toString() ?? '');
                if (date.startsWith(monthKey) && e['status'] == 'paid') {
                  final amount = double.tryParse(e['amount']?.toString() ?? '0') ?? 0;
                  if (e['kind'] == 'income') {
                    mIncome += amount;
                  } else if (e['kind'] == 'expense') {
                    mExpense += amount;
                  }
                }
              }

              // Payroll in this month
              for (final p in officeData.payroll) {
                final paidDate = p['paidDate']?.toString() ?? '${p['month']}-01';
                if ((p['month'] == monthKey || paidDate.startsWith(monthKey)) && p['status'] == 'paid') {
                  final net = (p['netCents'] as num? ?? 0) / 100.0;
                  mExpense += net;
                }
              }

              if (mIncome > maxMonthVal) maxMonthVal = mIncome;
              if (mExpense > maxMonthVal) maxMonthVal = mExpense;

              monthlyData.add({
                'month': monthNames[m - 1],
                'income': mIncome,
                'expense': mExpense,
              });
            }

            // ---------------------------------------------------------
            // 3. LIVE RECENT TRANSACTIONS LIST
            // ---------------------------------------------------------
            final liveTransactions = <_LiveTransactionItem>[];

            // Invoices
            for (final inv in invoices) {
              final t = Totals.of(inv);
              final statusStr = inv.status == 'draft'
                  ? 'Draft'
                  : t.balance <= 0
                      ? 'Paid'
                      : 'Unpaid';

              liveTransactions.add(
                _LiveTransactionItem(
                  date: inv.date,
                  description: inv.number.isNotEmpty ? 'Invoice ${inv.number}' : 'Draft Invoice',
                  type: 'Income',
                  customer: inv.customer.name.isNotEmpty ? inv.customer.name : 'Unknown Customer',
                  amount: t.total / 100.0,
                  status: statusStr,
                  sortDate: inv.date,
                ),
              );
            }

            // Office Finance entries
            for (final e in officeData.entries) {
              final amount = double.tryParse(e['amount']?.toString() ?? '0') ?? 0;
              final date = e['date']?.toString() ?? '';
              final isIncome = e['kind'] == 'income';
              final category = e['category']?.toString() ?? '';
              final party = e['party']?.toString() ?? '—';

              liveTransactions.add(
                _LiveTransactionItem(
                  date: date,
                  description: category.isNotEmpty ? category : (isIncome ? 'Income Entry' : 'Expense Entry'),
                  type: isIncome ? 'Income' : 'Expense',
                  customer: party.isNotEmpty ? party : '—',
                  amount: amount,
                  status: e['status'] == 'paid' ? 'Paid' : 'Unpaid',
                  sortDate: date,
                ),
              );
            }

            // Payroll payouts
            for (final p in officeData.payroll) {
              final net = (p['netCents'] as num? ?? 0) / 100.0;
              final date = p['paidDate']?.toString() ?? '${p['month']}-01';
              final empName = p['employeeName']?.toString() ?? 'Staff';

              liveTransactions.add(
                _LiveTransactionItem(
                  date: date,
                  description: 'Salary Payout - $empName',
                  type: 'Expense',
                  customer: empName,
                  amount: net,
                  status: p['status'] == 'paid' ? 'Paid' : 'Approved',
                  sortDate: date,
                ),
              );
            }

            // Sort newest first
            liveTransactions.sort((a, b) => b.sortDate.compareTo(a.sortDate));

            // ---------------------------------------------------------
            // 4. LIVE CASH FLOW CALCULATION
            // ---------------------------------------------------------
            double cfInflows = 0;
            double cfOutflows = 0;

            for (final inv in invoices) {
              for (final p in inv.payments) {
                if (_isDateInSelectedPeriod(p.date, _cashFlowPeriod)) {
                  cfInflows += p.cents / 100.0;
                }
              }
            }

            for (final e in officeData.entries) {
              final date = e['paidDate']?.toString() ?? (e['date']?.toString() ?? '');
              if (e['status'] == 'paid' && _isDateInSelectedPeriod(date, _cashFlowPeriod)) {
                final amount = double.tryParse(e['amount']?.toString() ?? '0') ?? 0;
                if (e['kind'] == 'income') {
                  cfInflows += amount;
                } else if (e['kind'] == 'expense') {
                  cfOutflows += amount;
                }
              }
            }

            for (final p in officeData.payroll) {
              final paidDate = p['paidDate']?.toString() ?? '${p['month']}-01';
              if (p['status'] == 'paid' && _isDateInSelectedPeriod(paidDate, _cashFlowPeriod)) {
                final net = (p['netCents'] as num? ?? 0) / 100.0;
                cfOutflows += net;
              }
            }

            final cfNetMovement = cfInflows - cfOutflows;

            return Container(
              color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
                  vertical: 24,
                ),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildWelcomeHeader(isDark, billingState),
                  const SizedBox(height: 24),
                  _buildKpiGrid(
                    isDark,
                    totalIncome: liveIncome,
                    totalExpenses: liveExpenses,
                    netProfit: netProfit,
                    bankBalance: bankBalance,
                    receivables: liveReceivables,
                    payables: livePayables,
                  ),
                  const SizedBox(height: 24),
                  if (isDesktop) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 62,
                          child: _buildMonthlyChartCard(isDark, monthlyData, maxMonthVal, targetYear),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 38,
                          child: _buildProfitAndLossCard(
                            isDark,
                            totalIncome: liveIncome,
                            totalExpenses: liveExpenses,
                            netProfit: netProfit,
                            otherIncome: liveOtherIncome,
                            otherExpenses: liveOtherExpenses,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 62,
                          child: _buildRecentTransactionsCard(isDark, liveTransactions),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 38,
                          child: _buildCashFlowSummaryCard(
                            isDark,
                            inflows: cfInflows,
                            outflows: cfOutflows,
                            netMovement: cfNetMovement,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    _buildMonthlyChartCard(isDark, monthlyData, maxMonthVal, targetYear),
                    const SizedBox(height: 20),
                    _buildProfitAndLossCard(
                      isDark,
                      totalIncome: liveIncome,
                      totalExpenses: liveExpenses,
                      netProfit: netProfit,
                      otherIncome: liveOtherIncome,
                      otherExpenses: liveOtherExpenses,
                    ),
                    const SizedBox(height: 20),
                    _buildRecentTransactionsCard(isDark, liveTransactions),
                    const SizedBox(height: 20),
                    _buildCashFlowSummaryCard(
                      isDark,
                      inflows: cfInflows,
                      outflows: cfOutflows,
                      netMovement: cfNetMovement,
                    ),
                  ],
                  const SizedBox(height: 36),
                  _buildFooter(isDark),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // 1. Welcome Header
  // -------------------------------------------------------------
  Widget _buildWelcomeHeader(bool isDark, BillingState billingState) {
    String greetingName = 'Business Owner';
    final companyName = billingState.data.company.name;
    if (companyName.isNotEmpty) {
      greetingName = companyName;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;

        final titleAndSubtitle = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $greetingName!',
              style: TextStyle(
                fontSize: isNarrow ? 22 : 28,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Here's what's happening with your business today.",
              style: TextStyle(
                fontSize: isNarrow ? 13 : 14.5,
                fontWeight: FontWeight.w400,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        );

        final periodPickerButton = InkWell(
          onTap: _showDateRangePicker,
          borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.calendar,
                  size: 16,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedPeriod,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleAndSubtitle,
              const SizedBox(height: 14),
              periodPickerButton,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleAndSubtitle),
            periodPickerButton,
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // 2. 6 KPI Stat Cards
  // -------------------------------------------------------------
  Widget _buildKpiGrid(
    bool isDark, {
    required double totalIncome,
    required double totalExpenses,
    required double netProfit,
    required double bankBalance,
    required double receivables,
    required double payables,
  }) {
    final cards = [
      _KpiData(
        title: 'Total Income',
        value: _formatAmount(totalIncome),
        comparison: 'Live revenue & receipts',
        icon: CupertinoIcons.arrow_up,
        iconColor: const Color(0xFF10B981),
        iconBgColor: const Color(0xFFECFDF5),
        iconBgDark: const Color(0xFF064E3B),
      ),
      _KpiData(
        title: 'Total Expenses',
        value: _formatAmount(totalExpenses),
        comparison: 'Paid bills & salaries',
        icon: CupertinoIcons.arrow_down,
        iconColor: const Color(0xFFEF4444),
        iconBgColor: const Color(0xFFFEF2F2),
        iconBgDark: const Color(0xFF7F1D1D),
      ),
      _KpiData(
        title: 'Net Profit',
        value: _formatAmount(netProfit),
        comparison: netProfit >= 0 ? 'Profitable period' : 'Net deficit',
        icon: CupertinoIcons.chart_bar_alt_fill,
        iconColor: netProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        iconBgColor: const Color(0xFFECFDF5),
        iconBgDark: const Color(0xFF064E3B),
      ),
      _KpiData(
        title: 'Cash / Bank Balance',
        value: _formatAmount(bankBalance),
        comparison: 'Active liquidity tracking',
        icon: CupertinoIcons.creditcard_fill,
        iconColor: const Color(0xFF3B82F6),
        iconBgColor: const Color(0xFFEFF6FF),
        iconBgDark: const Color(0xFF1E3A8A),
      ),
      _KpiData(
        title: 'Receivables',
        value: _formatAmount(receivables),
        comparison: 'Unpaid customer invoices',
        icon: CupertinoIcons.person_2_fill,
        iconColor: const Color(0xFFA855F7),
        iconBgColor: const Color(0xFFFAF5FF),
        iconBgDark: const Color(0xFF581C87),
      ),
      _KpiData(
        title: 'Payables',
        value: _formatAmount(payables),
        comparison: 'Pending supplier & staff dues',
        icon: CupertinoIcons.doc_text_fill,
        iconColor: const Color(0xFFF97316),
        iconBgColor: const Color(0xFFFFF7ED),
        iconBgDark: const Color(0xFF7C2D12),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = 3;
        if (constraints.maxWidth < 650) {
          columns = 1;
        } else if (constraints.maxWidth < 1000) {
          columns = 2;
        }

        final double spacing = 16;
        final double itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final kpi in cards)
              SizedBox(
                width: itemWidth,
                child: _buildKpiCardItem(isDark, kpi),
              ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCardItem(bool isDark, _KpiData kpi) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.zohoCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? kpi.iconBgDark : kpi.iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(kpi.icon, size: 18, color: kpi.iconColor),
                ),
              ),
              Text(
                kpi.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kpi.value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kpi.comparison,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 3. Monthly Income vs Expense Bar Chart
  // -------------------------------------------------------------
  Widget _buildMonthlyChartCard(
    bool isDark,
    List<Map<String, dynamic>> monthlyData,
    double maxMonthVal,
    int year,
  ) {
    final scaleMax = max(maxMonthVal * 1.15, 1000.0);
    final yLabels = [
      _formatShortAmount(scaleMax),
      _formatShortAmount(scaleMax * 0.8),
      _formatShortAmount(scaleMax * 0.6),
      _formatShortAmount(scaleMax * 0.4),
      _formatShortAmount(scaleMax * 0.2),
      '0',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.zohoCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with Legend
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Monthly Income vs Expense ($year)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendItem('Income', const Color(0xFF10B981), isDark),
                  const SizedBox(width: 16),
                  _buildLegendItem('Expenses', const Color(0xFFFB923C), isDark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Chart Body
          SizedBox(
            height: 230,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y Axis Labels
                SizedBox(
                  width: 44,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final label in yLabels)
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Bars Area with Gridlines
                Expanded(
                  child: Stack(
                    children: [
                      // Gridlines
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (index) => Divider(
                            height: 1,
                            thickness: 0.8,
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          ),
                        ),
                      ),
                      // Bars for each month
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (int i = 0; i < monthlyData.length; i++)
                              Expanded(
                                child: _buildMonthBarGroup(
                                  i,
                                  monthlyData[i],
                                  scaleMax,
                                  isDark,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // X-Axis Month Labels
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Row(
              children: [
                for (final item in monthlyData)
                  Expanded(
                    child: Center(
                      child: Text(
                        item['month'],
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortAmount(double val) {
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}M';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(0)}K';
    }
    return val.toInt().toString();
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthBarGroup(
    int index,
    Map<String, dynamic> data,
    double maxVal,
    bool isDark,
  ) {
    final income = (data['income'] as num).toDouble();
    final expense = (data['expense'] as num).toDouble();
    final isHovered = _hoveredMonthIndex == index;

    final incomeHeightPercent = (income / maxVal).clamp(0.0, 1.0);
    final expenseHeightPercent = (expense / maxVal).clamp(0.0, 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredMonthIndex = index),
      onExit: (_) => setState(() => _hoveredMonthIndex = null),
      child: Tooltip(
        message: '${data['month']}: Income ${_formatAmount(income)} | Expense ${_formatAmount(expense)}',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Income Bar (Green)
              Flexible(
                child: Container(
                  width: 9,
                  height: max(190 * incomeHeightPercent, income > 0 ? 4.0 : 0.0),
                  decoration: BoxDecoration(
                    color: isHovered ? const Color(0xFF059669) : const Color(0xFF10B981),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
              ),
              const SizedBox(width: 2.5),
              // Expense Bar (Orange)
              Flexible(
                child: Container(
                  width: 9,
                  height: max(190 * expenseHeightPercent, expense > 0 ? 4.0 : 0.0),
                  decoration: BoxDecoration(
                    color: isHovered ? const Color(0xFFEA580C) : const Color(0xFFFB923C),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 4. Profit & Loss Summary Card
  // -------------------------------------------------------------
  Widget _buildProfitAndLossCard(
    bool isDark, {
    required double totalIncome,
    required double totalExpenses,
    required double netProfit,
    required double otherIncome,
    required double otherExpenses,
  }) {
    final profitMargin = totalIncome > 0 ? ((netProfit / totalIncome) * 100) : 0.0;
    final opexMargin = totalIncome > 0 ? ((totalExpenses / totalIncome) * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.zohoCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with link
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Profit & Loss Summary',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: () => widget.onNavigate(9), // Navigate to Reports
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'View Report',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(CupertinoIcons.arrow_right, size: 12, color: Color(0xFF0284C7)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildPnlRow('Total Income', _formatAmount(totalIncome), isDark),
          const SizedBox(height: 10),
          _buildPnlRow('Total Expenses', '(${_formatAmount(totalExpenses)})', isDark, isNegative: true),
          const SizedBox(height: 14),
          // Highlighted Net Profit Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Profit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                  ),
                ),
                Text(
                  _formatAmount(netProfit),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _buildPnlRow('Profit Margin', '${profitMargin.toStringAsFixed(1)}%', isDark),
          const SizedBox(height: 10),
          _buildPnlRow('Operating Expenses', '${opexMargin.toStringAsFixed(1)}%', isDark),
          const SizedBox(height: 10),
          _buildPnlRow('Other Income', _formatAmount(otherIncome), isDark),
          const SizedBox(height: 10),
          _buildPnlRow('Other Expenses', '(${_formatAmount(otherExpenses)})', isDark, isNegative: true),
        ],
      ),
    );
  }

  Widget _buildPnlRow(String title, String value, bool isDark, {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isNegative
                ? const Color(0xFFEF4444)
                : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 5. Recent Transactions Table
  // -------------------------------------------------------------
  Widget _buildRecentTransactionsCard(bool isDark, List<_LiveTransactionItem> transactions) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.zohoCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with link
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: () => widget.onNavigate(1), // Navigate to Invoices
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(CupertinoIcons.arrow_right, size: 12, color: Color(0xFF0284C7)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.creditcard,
                      size: 38,
                      color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No transactions recorded yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create an invoice or add an expense to see live activity.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: widget.onNewInvoice,
                      icon: const Icon(CupertinoIcons.plus, size: 15),
                      label: const Text('Create First Invoice'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final displayItems = transactions.take(6).toList();

                if (constraints.maxWidth < 650) {
                  // Mobile Card List
                  return Column(
                    children: [
                      for (final item in displayItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                width: 0.6,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: item.type == 'Income'
                                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                                        : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      item.type == 'Income'
                                          ? CupertinoIcons.arrow_down_left
                                          : CupertinoIcons.arrow_up_right,
                                      size: 16,
                                      color: item.type == 'Income'
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.description,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.date} • ${item.customer}',
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatAmount(item.amount),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _buildStatusBadge(item.status, isDark),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                }

                // Desktop Clean Table View
                return Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1.2),
                    1: FlexColumnWidth(2.0),
                    2: FlexColumnWidth(1.0),
                    3: FlexColumnWidth(1.8),
                    4: FlexColumnWidth(1.3),
                    5: FlexColumnWidth(1.0),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            width: 1,
                          ),
                        ),
                      ),
                      children: [
                        _buildTableHeader('Date', isDark),
                        _buildTableHeader('Description', isDark),
                        _buildTableHeader('Type', isDark),
                        _buildTableHeader('Customer / Payee', isDark),
                        _buildTableHeader('Amount', isDark),
                        _buildTableHeader('Status', isDark),
                      ],
                    ),
                    for (final row in displayItems)
                      TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                              width: 1,
                            ),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              row.date,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              row.description,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: _buildTypeBadge(row.type, isDark),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              row.customer,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _formatAmount(row.amount),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: _buildStatusBadge(row.status, isDark),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type, bool isDark) {
    final isIncome = type == 'Income';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isIncome
              ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
              : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          type,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    final isPaid = status == 'Paid';
    final isDraft = status == 'Draft';

    Color bgColor;
    Color fgColor;

    if (isPaid) {
      bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
      fgColor = const Color(0xFF10B981);
    } else if (isDraft) {
      bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      fgColor = const Color(0xFF64748B);
    } else {
      bgColor = isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFF7ED);
      fgColor = const Color(0xFFF97316);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: fgColor,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 6. Cash Flow Summary Card
  // -------------------------------------------------------------
  Widget _buildCashFlowSummaryCard(
    bool isDark, {
    required double inflows,
    required double outflows,
    required double netMovement,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.zohoCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with period dropdown
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Cash Flow Summary',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: _showCashFlowPicker,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _cashFlowPeriod,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.chevron_down,
                        size: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildPnlRow('Cash Inflows', _formatAmount(inflows), isDark),
          const SizedBox(height: 12),
          _buildPnlRow('Cash Outflows', '(${_formatAmount(outflows)})', isDark, isNegative: true),
          const SizedBox(height: 16),
          // Highlighted Net Movement Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF083344) : const Color(0xFFECFEFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF0891B2) : const Color(0xFFA5F3FC),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Cash Movement',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490),
                  ),
                ),
                Text(
                  _formatAmount(netMovement),
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0891B2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Insight Notification Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.waveform_path_badge_plus,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    netMovement >= 0 && inflows > 0
                        ? 'Net positive cash flow of ${_formatAmount(netMovement)} tracked for $_cashFlowPeriod.'
                        : netMovement < 0
                            ? 'Net cash outflow of ${_formatAmount(outflows - inflows)} recorded for $_cashFlowPeriod.'
                            : 'No cash movements recorded yet for $_cashFlowPeriod.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                      height: 1.3,
                    ),
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
  // 7. Footer
  // -------------------------------------------------------------
  Widget _buildFooter(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        final copyrightText = Text(
          '© 2024 The Percentage Company. All rights reserved.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
        );

        final links = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFooterLink('Help', isDark),
            _buildFooterSeparator(isDark),
            _buildFooterLink('Privacy', isDark),
            _buildFooterSeparator(isDark),
            _buildFooterLink('Terms', isDark),
          ],
        );

        if (isNarrow) {
          return Column(
            children: [
              copyrightText,
              const SizedBox(height: 8),
              links,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            copyrightText,
            links,
          ],
        );
      },
    );
  }

  Widget _buildFooterLink(String label, bool isDark) {
    return InkWell(
      onTap: () {},
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildFooterSeparator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '|',
        style: TextStyle(
          fontSize: 11,
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final String comparison;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color iconBgDark;

  const _KpiData({
    required this.title,
    required this.value,
    required this.comparison,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.iconBgDark,
  });
}

class _LiveTransactionItem {
  final String date;
  final String description;
  final String type;
  final String customer;
  final double amount;
  final String status;
  final String sortDate;

  const _LiveTransactionItem({
    required this.date,
    required this.description,
    required this.type,
    required this.customer,
    required this.amount,
    required this.status,
    required this.sortDate,
  });
}
