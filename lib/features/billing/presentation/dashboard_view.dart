import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../office/presentation/office_cubit.dart';
import '../domain/models.dart';
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
  String _selectedPeriod = '1 Jan 2024 - 31 Dec 2024';
  String _cashFlowPeriod = 'This Month';
  int? _hoveredMonthIndex;

  // 12 Months default mockup data (in thousands of dollars/AED)
  final List<Map<String, dynamic>> _defaultMonthlyData = [
    {'month': 'Jan', 'income': 15.0, 'expense': 8.5},
    {'month': 'Feb', 'income': 17.0, 'expense': 11.2},
    {'month': 'Mar', 'income': 21.5, 'expense': 10.0},
    {'month': 'Apr', 'income': 16.5, 'expense': 7.8},
    {'month': 'May', 'income': 17.5, 'expense': 7.5},
    {'month': 'Jun', 'income': 12.5, 'expense': 9.2},
    {'month': 'Jul', 'income': 15.5, 'expense': 10.0},
    {'month': 'Aug', 'income': 15.2, 'expense': 8.5},
    {'month': 'Sep', 'income': 15.3, 'expense': 9.8},
    {'month': 'Oct', 'income': 15.8, 'expense': 10.2},
    {'month': 'Nov', 'income': 17.8, 'expense': 10.8},
    {'month': 'Dec', 'income': 21.0, 'expense': 12.5},
  ];

  // Default transactions from mockup
  final List<Map<String, dynamic>> _defaultTransactions = [
    {
      'date': '14 Apr 2024',
      'description': 'Consulting Services',
      'type': 'Income',
      'customer': 'BrightMind Ltd',
      'amount': '\$2,400',
      'status': 'Paid',
    },
    {
      'date': '12 Apr 2024',
      'description': 'Website Redesign',
      'type': 'Income',
      'customer': 'Summit Marketing',
      'amount': '\$3,200',
      'status': 'Paid',
    },
    {
      'date': '10 Apr 2024',
      'description': 'Office Rent',
      'type': 'Expense',
      'customer': 'City Properties',
      'amount': '\$1,200',
      'status': 'Paid',
    },
    {
      'date': '08 Apr 2024',
      'description': 'Staff Salaries',
      'type': 'Expense',
      'customer': '—',
      'amount': '\$4,500',
      'status': 'Paid',
    },
    {
      'date': '05 Apr 2024',
      'description': 'Business Consulting',
      'type': 'Income',
      'customer': 'Horizon Group',
      'amount': '\$5,000',
      'status': 'Unpaid',
    },
  ];

  void _showDateRangePicker() {
    final periods = [
      'This Month',
      'This Quarter',
      '1 Jan 2024 - 31 Dec 2024',
      '1 Jan 2025 - 31 Dec 2025',
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

  String _formatAmount(double val) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    return formatter.format(val);
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
            final hasRealData = invoices.isNotEmpty;

            // Compute live figures if available
            double totalIncome = 124580.0;
            double totalExpenses = 52340.0;
            double netProfit = 72240.0;
            double bankBalance = 96780.0;
            double receivables = 18420.0;
            double payables = 9150.0;

            if (hasRealData) {
              double livePaid = 0;
              double liveUnpaid = 0;

              for (final inv in invoices) {
                try {
                  final t = Totals.of(inv);
                  livePaid += t.paid / 100.0;
                  liveUnpaid += t.balance / 100.0;
                } catch (_) {}
              }

              // Office finance records
              final financeList = officeState.data.entries;
              double liveFinanceExpenses = 0;
              double liveFinanceIncome = 0;
              for (final f in financeList) {
                final kind = f['kind']?.toString();
                final amount = double.tryParse(f['amount']?.toString() ?? '0') ?? 0;
                if (kind == 'expense') {
                  liveFinanceExpenses += amount;
                } else if (kind == 'income') {
                  liveFinanceIncome += amount;
                }
              }

              if (livePaid > 0 || liveFinanceIncome > 0) {
                totalIncome = livePaid + liveFinanceIncome;
              }
              if (liveFinanceExpenses > 0) {
                totalExpenses = liveFinanceExpenses;
              }
              netProfit = totalIncome - totalExpenses;
              receivables = liveUnpaid > 0 ? liveUnpaid : receivables;
            }

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
                    isDesktop,
                    isTablet,
                    totalIncome: totalIncome,
                    totalExpenses: totalExpenses,
                    netProfit: netProfit,
                    bankBalance: bankBalance,
                    receivables: receivables,
                    payables: payables,
                  ),
                  const SizedBox(height: 24),
                  if (isDesktop) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 62,
                          child: _buildMonthlyChartCard(isDark),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 38,
                          child: _buildProfitAndLossCard(
                            isDark,
                            totalIncome: totalIncome,
                            totalExpenses: totalExpenses,
                            netProfit: netProfit,
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
                          child: _buildRecentTransactionsCard(isDark, invoices),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 38,
                          child: _buildCashFlowSummaryCard(isDark),
                        ),
                      ],
                    ),
                  ] else ...[
                    _buildMonthlyChartCard(isDark),
                    const SizedBox(height: 20),
                    _buildProfitAndLossCard(
                      isDark,
                      totalIncome: totalIncome,
                      totalExpenses: totalExpenses,
                      netProfit: netProfit,
                    ),
                    const SizedBox(height: 20),
                    _buildRecentTransactionsCard(isDark, invoices),
                    const SizedBox(height: 20),
                    _buildCashFlowSummaryCard(isDark),
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
    String greetingName = 'Sarah';
    final companyName = billingState.data.company.name;
    if (companyName.isNotEmpty) {
      final parts = companyName.split(' ');
      if (parts.isNotEmpty) greetingName = parts.first;
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
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
    bool isDark,
    bool isDesktop,
    bool isTablet, {
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
        comparison: '↑ 12% vs. previous period',
        isPositive: true,
        icon: CupertinoIcons.arrow_up,
        iconColor: const Color(0xFF10B981),
        iconBgColor: const Color(0xFFECFDF5),
        iconBgDark: const Color(0xFF064E3B),
      ),
      _KpiData(
        title: 'Total Expenses',
        value: _formatAmount(totalExpenses),
        comparison: '↓ 8% vs. previous period',
        isPositive: true, // down in expenses is favorable
        icon: CupertinoIcons.arrow_down,
        iconColor: const Color(0xFFEF4444),
        iconBgColor: const Color(0xFFFEF2F2),
        iconBgDark: const Color(0xFF7F1D1D),
      ),
      _KpiData(
        title: 'Net Profit',
        value: _formatAmount(netProfit),
        comparison: '↑ 28% vs. previous period',
        isPositive: true,
        icon: CupertinoIcons.chart_bar_alt_fill,
        iconColor: const Color(0xFF10B981),
        iconBgColor: const Color(0xFFECFDF5),
        iconBgDark: const Color(0xFF064E3B),
      ),
      _KpiData(
        title: 'Cash / Bank Balance',
        value: _formatAmount(bankBalance),
        comparison: '↑ 6% vs. previous period',
        isPositive: true,
        icon: CupertinoIcons.creditcard_fill,
        iconColor: const Color(0xFF3B82F6),
        iconBgColor: const Color(0xFFEFF6FF),
        iconBgDark: const Color(0xFF1E3A8A),
      ),
      _KpiData(
        title: 'Receivables',
        value: _formatAmount(receivables),
        comparison: '↑ 14% vs. previous period',
        isPositive: true,
        icon: CupertinoIcons.person_2_fill,
        iconColor: const Color(0xFFA855F7),
        iconBgColor: const Color(0xFFFAF5FF),
        iconBgDark: const Color(0xFF581C87),
      ),
      _KpiData(
        title: 'Payables',
        value: _formatAmount(payables),
        comparison: '↓ 22% vs. previous period',
        isPositive: true,
        icon: CupertinoIcons.doc_text_fill,
        iconColor: const Color(0xFFF97316),
        iconBgColor: const Color(0xFFFFF7ED),
        iconBgDark: const Color(0xFF7C2D12),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = 3;
        if (constraints.maxWidth < 600) {
          columns = 1;
        } else if (constraints.maxWidth < 960) {
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                  shape: BoxShape.circle,
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
          Text(
            kpi.value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kpi.comparison.split(' vs.').first,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
                Text(
                  ' vs. previous period',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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
  // 3. Monthly Income vs Expense Bar Chart
  // -------------------------------------------------------------
  Widget _buildMonthlyChartCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                'Monthly Income vs Expense',
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                const maxVal = 25.0; // 25K max scale
                final yLabels = ['25K', '20K', '15K', '10K', '5K', '0'];

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Y Axis Labels
                    SizedBox(
                      width: 32,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final label in yLabels)
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                                for (int i = 0; i < _defaultMonthlyData.length; i++)
                                  Expanded(
                                    child: _buildMonthBarGroup(
                                      i,
                                      _defaultMonthlyData[i],
                                      maxVal,
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
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // X-Axis Month Labels
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Row(
              children: [
                for (final item in _defaultMonthlyData)
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

    final incomeHeightPercent = (income / maxVal).clamp(0.05, 1.0);
    final expenseHeightPercent = (expense / maxVal).clamp(0.05, 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredMonthIndex = index),
      onExit: (_) => setState(() => _hoveredMonthIndex = null),
      child: Tooltip(
        message: '${data['month']}: Income \$${(income * 1000).toInt()} | Expense \$${(expense * 1000).toInt()}',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Income Bar (Green)
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      width: 9,
                      height: 190 * incomeHeightPercent,
                      decoration: BoxDecoration(
                        color: isHovered ? const Color(0xFF059669) : const Color(0xFF10B981),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 2.5),
              // Expense Bar (Orange)
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      width: 9,
                      height: 190 * expenseHeightPercent,
                      decoration: BoxDecoration(
                        color: isHovered ? const Color(0xFFEA580C) : const Color(0xFFFB923C),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    );
                  },
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
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
          _buildPnlRow('Profit Margin', '58.0%', isDark),
          const SizedBox(height: 10),
          _buildPnlRow('Operating Expenses', '42.0%', isDark),
          const SizedBox(height: 10),
          _buildPnlRow('Other Income', '\$2,150', isDark),
          const SizedBox(height: 10),
          _buildPnlRow('Other Expenses', '(\$3,620)', isDark, isNegative: true),
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
  Widget _buildRecentTransactionsCard(bool isDark, List<Invoice> invoices) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 650) {
                // Mobile Card List
                return Column(
                  children: [
                    for (final item in _defaultTransactions)
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
                                  color: item['type'] == 'Income'
                                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                                      : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Icon(
                                    item['type'] == 'Income'
                                        ? CupertinoIcons.arrow_down_left
                                        : CupertinoIcons.arrow_up_right,
                                    size: 16,
                                    color: item['type'] == 'Income'
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
                                      item['description'],
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item['date']} • ${item['customer']}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item['amount'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildStatusBadge(item['status'], isDark),
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
                  4: FlexColumnWidth(1.1),
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
                  for (final row in _defaultTransactions)
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
                            row['date'],
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            row['description'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _buildTypeBadge(row['type'], isDark),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            row['customer'],
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            row['amount'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _buildStatusBadge(row['status'], isDark),
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isPaid
              ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
              : (isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFF7ED)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF97316),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 6. Cash Flow Summary Card
  // -------------------------------------------------------------
  Widget _buildCashFlowSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
          _buildPnlRow('Opening Balance', '\$82,430', isDark),
          const SizedBox(height: 12),
          _buildPnlRow('Cash Inflows', '\$18,250', isDark),
          const SizedBox(height: 12),
          _buildPnlRow('Cash Outflows', '(\$11,900)', isDark, isNegative: true),
          const SizedBox(height: 16),
          // Highlighted Closing Balance Row
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
                  'Closing Balance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF67E8F9) : const Color(0xFF0E7490),
                  ),
                ),
                Text(
                  '\$88,780',
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
                    'Your cash balance has increased by 7% compared to last month.',
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
  final bool isPositive;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color iconBgDark;

  const _KpiData({
    required this.title,
    required this.value,
    required this.comparison,
    required this.isPositive,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.iconBgDark,
  });
}
