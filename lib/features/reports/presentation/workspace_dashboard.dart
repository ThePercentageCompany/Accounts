import 'package:flutter/material.dart';
import '../data/report_format.dart';
import 'report_trends.dart';

class WorkspaceDashboard extends StatelessWidget {
  const WorkspaceDashboard({
    super.key,
    required this.data,
    this.format = const ReportFormat(),
    this.onReportSelected,
  });
  final Map<String, dynamic> data;
  final ReportFormat format;
  final ValueChanged<String>? onReportSelected;

  String amount(String key) {
    return format.money(data[key]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
        8,
        MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
        24,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 4
              : constraints.maxWidth >= 300 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 18
              ? 2
              : 1;
          final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
          Widget metric(
            String key,
            String label,
            IconData icon,
            Color accent,
            String note,
          ) {
            if (Theme.of(context).brightness == Brightness.dark) {
              accent = colors.onSurface;
            }
            return SizedBox(
              width: width,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(width < 240 ? 12 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: accent, size: 22),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.insights_outlined,
                            color: colors.onSurfaceVariant,
                            size: 18,
                          ),
                        ],
                      ),
                      SizedBox(height: width < 240 ? 8 : 12),
                      Text(
                        label,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        amount(key),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: width < 240 ? 20 : 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.7,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (data['comparison']?['totals']?[key] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Previous: ${format.money(data['comparison']['totals'][key]['previous'])}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(
                          'Change: ${format.money(data['comparison']['totals'][key]['amount'])} · ${data['comparison']['totals'][key]['percent'] ?? 'Not defined'}${data['comparison']['totals'][key]['percent'] == null ? '' : '%'}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        if (key == 'totalExpenses')
                          const Text(
                            'Expense increases are unfavorable.',
                            style: TextStyle(fontSize: 11),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance overview',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (data['balanced'] is bool)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        data['balanced'] == true
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data['balanced'] == true
                              ? 'Ledger balanced'
                              : 'Ledger needs review',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'A clear snapshot of performance, liquidity and outstanding balances.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const {
                    'profit-and-loss': 'Profit & Loss',
                    'balance-sheet': 'Balance Sheet',
                    'trial-balance': 'Trial Balance',
                    'general-ledger': 'General Ledger',
                  }.entries)
                    OutlinedButton.icon(
                      onPressed: onReportSelected == null
                          ? null
                          : () => onReportSelected!(entry.key),
                      icon: const Icon(Icons.arrow_outward, size: 16),
                      label: Text(entry.value),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  metric(
                    'totalIncome',
                    'Period income',
                    Icons.trending_up,
                    const Color(0xFF16A085),
                    'Reporting period: ${data['from'] ?? 'start'} to ${data['asOf'] ?? 'end'}',
                  ),
                  metric(
                    'totalExpenses',
                    'Period expenses',
                    Icons.trending_down,
                    const Color(0xFFE09037),
                    'Reporting period: ${data['from'] ?? 'start'} to ${data['asOf'] ?? 'end'}',
                  ),
                  metric(
                    'netProfit',
                    'Period profit / loss',
                    Icons.insights,
                    colors.primary,
                    'Income less expenses',
                  ),
                  if (data.containsKey('grossProfit'))
                    metric(
                      'grossProfit',
                      'Gross profit',
                      Icons.show_chart,
                      colors.primary,
                      data['grossProfit'] == null
                          ? 'Review revenue and COGS classifications'
                          : 'Net revenue less cost of goods sold',
                    ),
                  metric(
                    'receivables',
                    'Receivables',
                    Icons.receipt_long_outlined,
                    const Color(0xFF8B6BD6),
                    'As of ${data['asOf'] ?? 'selected end date'}',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (data['trends'] is List &&
                  (data['trends'] as List).isNotEmpty) ...[
                ReportTrends(
                  trends: List<Map<String, dynamic>>.from(
                    (data['trends'] as List).map(
                      (t) => Map<String, dynamic>.from(t),
                    ),
                  ),
                  format: format,
                ),
                if (data['trendsTruncated'] == true)
                  const Text(
                    'Trend chart shows the first 120 months. Report totals include the full selected period.',
                  ),
                const SizedBox(height: 20),
              ],
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: constraints.maxWidth >= 760
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth,
                    child: _graph(context, 'Income & spending', const {
                      'totalIncome': 'Income',
                      'totalExpenses': 'Expenses',
                    }, 'Period totals (not a historical trend)'),
                  ),
                  SizedBox(
                    width: constraints.maxWidth >= 760
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth,
                    child: _graph(context, 'Cash & bank', const {
                      'cash': 'Cash',
                      'bank': 'Bank',
                    }, 'Balances at end date'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Cash & financial position',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  metric(
                    'cash',
                    'Cash',
                    Icons.wallet_outlined,
                    colors.primary,
                    'As of ${data['asOf'] ?? 'selected end date'}',
                  ),
                  metric(
                    'bank',
                    'Bank',
                    Icons.account_balance_outlined,
                    colors.primary,
                    'As of ${data['asOf'] ?? 'selected end date'}',
                  ),
                  metric(
                    'payables',
                    'Payables',
                    Icons.payments_outlined,
                    const Color(0xFFE09037),
                    'As of ${data['asOf'] ?? 'selected end date'}',
                  ),
                  metric(
                    'totalAssets',
                    'Assets',
                    Icons.business_outlined,
                    colors.primary,
                    'As of ${data['asOf'] ?? 'selected end date'}',
                  ),
                  metric(
                    'totalLiabilities',
                    'Liabilities',
                    Icons.balance_outlined,
                    const Color(0xFF8B6BD6),
                    'As of ${data['asOf'] ?? 'selected end date'}',
                  ),
                  metric(
                    'totalEquity',
                    'Equity',
                    Icons.pie_chart_outline,
                    const Color(0xFF16A085),
                    'As of ${data['asOf'] ?? 'selected end date'}',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _graph(
    BuildContext context,
    String title,
    Map<String, String> entries,
    String caption,
  ) {
    final colors = Theme.of(context).colorScheme;
    final values = entries.keys
        .map((key) => double.tryParse('${data[key]}'))
        .toList();
    final valid = values.every((value) => value != null && value.isFinite);
    final maximum = valid
        ? values
              .map((value) => value!.abs())
              .fold<double>(0, (a, b) => a > b ? a : b)
        : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (!valid)
              const Text('Graph unavailable for this report.')
            else
              for (final entry in entries.entries) ...[
                Semantics(
                  label: '${entry.value}: ${amount(entry.key)}',
                  child: Text(entry.value),
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: maximum == 0
                        ? 0
                        : (double.parse('${data[entry.key]}').abs() / maximum)
                              .clamp(0, 1),
                  ),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 400),
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: colors.surfaceContainerHighest,
                    color: entry.key == entries.keys.first
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            Text(
              'Bars show absolute amounts; signed balances appear in the summary.',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
