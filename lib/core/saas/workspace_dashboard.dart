import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WorkspaceDashboard extends StatelessWidget {
  const WorkspaceDashboard({super.key, required this.data});
  final Map<String, dynamic> data;

  String amount(String key) {
    final value = data[key];
    final number = num.tryParse('$value');
    return number == null ? '—' : NumberFormat('#,##0.00').format(number);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 12 : 24),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 300 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 18
                ? 2
                : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        Widget metric(String key, String label, IconData icon, Color accent,
                String note) =>
            SizedBox(
              width: width,
              child: Card(
                  child: Padding(
                      padding: EdgeInsets.all(width < 240 ? 12 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: accent.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Icon(icon, color: accent, size: 22)),
                            const Spacer(),
                            Icon(Icons.insights_outlined,
                                color: colors.onSurfaceVariant, size: 18)
                          ]),
                          SizedBox(height: width < 240 ? 8 : 20),
                          Text(label,
                              style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text(amount(key),
                              style: TextStyle(
                                  fontSize: width < 240 ? 20 : 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.7)),
                          const SizedBox(height: 10),
                          Text(note,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant)),
                        ],
                      ))),
            );
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Financial quick view',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              'A clear snapshot of performance, liquidity and outstanding balances.',
              style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 20),
          Wrap(spacing: 16, runSpacing: 16, children: [
            metric('totalIncome', 'Period income', Icons.trending_up,
                const Color(0xFF16A085), 'Selected reporting period'),
            metric('totalExpenses', 'Period expenses', Icons.trending_down,
                const Color(0xFFE09037), 'Selected reporting period'),
            metric('netProfit', 'Period profit / loss', Icons.insights,
                colors.primary, 'Income less expenses'),
            metric('receivables', 'Receivables', Icons.receipt_long_outlined,
                const Color(0xFF8B6BD6), 'Cumulative outstanding balance'),
          ]),
          const SizedBox(height: 28),
          Text('Cash & financial position',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(spacing: 16, runSpacing: 16, children: [
            metric('cash', 'Cash', Icons.wallet_outlined, colors.primary,
                'Cumulative balance'),
            metric('bank', 'Bank', Icons.account_balance_outlined,
                colors.primary, 'Cumulative balance'),
            metric('payables', 'Payables', Icons.payments_outlined,
                const Color(0xFFE09037), 'Cumulative outstanding balance'),
            metric('totalAssets', 'Assets', Icons.business_outlined,
                colors.primary, 'Cumulative balance'),
            metric('totalLiabilities', 'Liabilities', Icons.balance_outlined,
                const Color(0xFF8B6BD6), 'Cumulative balance'),
            metric('totalEquity', 'Equity', Icons.pie_chart_outline,
                const Color(0xFF16A085), 'Cumulative balance'),
          ]),
        ]);
      }),
    );
  }
}
