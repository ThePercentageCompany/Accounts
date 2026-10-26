import 'package:flutter/material.dart';
import '../data/report_format.dart';
import 'overview_charts.dart';
import 'report_trends.dart';

class WorkspaceDashboard extends StatelessWidget {
  const WorkspaceDashboard(
      {super.key,
      required this.data,
      this.format = const ReportFormat(),
      this.onReportSelected,
      this.taskOverview});
  final Widget? taskOverview;
  final Map<String, dynamic> data;
  final ReportFormat format;
  final ValueChanged<String>? onReportSelected;
  String amount(String key) => format.money(key == 'availableFunds' && data[key] == null
      ? (value('cash') + value('bank')).toStringAsFixed(2) : data[key]);
  double value(String key) => double.tryParse('${data[key]}') ?? double.nan;
  VoidCallback? report(String kind) =>
      onReportSelected == null ? null : () => onReportSelected!(kind);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000
          ? 4
          : constraints.maxWidth >= 480
              ? 2
              : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      Widget metric(String key, String label, String destination, IconData icon,
              int index) =>
          SizedBox(
              width: width,
              child: Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                      onTap: report(destination),
                      child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Icon(icon,
                                      size: 19,
                                      color: overviewPalette[
                                          index % overviewPalette.length]),
                                  const Spacer(),
                                  if (onReportSelected != null)
                                    Icon(Icons.arrow_outward,
                                        size: 16,
                                        color: colors.onSurfaceVariant)
                                ]),
                                const SizedBox(height: 16),
                                Text(label, style: theme.textTheme.bodySmall),
                                const SizedBox(height: 6),
                                Text(amount(key),
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ])),
                                if (data['comparison']?['totals']?[key]
                                    is Map) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                      'Previous ${format.money(data['comparison']['totals'][key]['previous'])}',
                                      style: theme.textTheme.bodySmall),
                                ],
                              ])))));
      Widget pair(Widget first, Widget second) => LayoutBuilder(
          builder: (context, size) => size.maxWidth >= 800
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: first),
                  const SizedBox(width: 12),
                  Expanded(child: second)
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [first, const SizedBox(height: 12), second]));
      OverviewDatum datum(String key, String label, String destination) =>
          OverviewDatum(label, value(key),
              display: amount(key), onTap: report(destination));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Financial overview',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                    '${data['from'] ?? 'Inception'} — ${data['asOf'] ?? 'Today'} · ${data['metadata']?['currency'] ?? 'Company currency'}',
                    style: theme.textTheme.bodySmall),
              ])),
          if (data['balanced'] is bool)
            Tooltip(
                message: data['balanced'] == true
                    ? 'Ledger balanced'
                    : 'Ledger needs review',
                child: Icon(
                    data['balanced'] == true
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 19,
                    color: colors.primary))
        ]),
        if (data['provisional'] == true)
          Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text((data['pendingCalculation'] as num? ?? 0) > 0
                  ? 'Pending financial changes · ${data['pendingCalculation']} operation(s) awaiting server calculation.'
                  : 'Provisional · includes local changes pending sync')),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          metric('totalIncome', 'Period income', 'profit-and-loss',
              Icons.north_east, 0),
          metric('totalExpenses', 'Period expenses', 'profit-and-loss',
              Icons.south_east, 1),
          metric('netProfit', 'Net profit / loss', 'profit-and-loss',
              Icons.show_chart, 2),
          metric('availableFunds', 'Available funds', 'general-ledger',
              Icons.account_balance_wallet_outlined, 3),
        ]),
        const SizedBox(height: 16),
        if (data['trends'] is List) ...[
          TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 550),
              builder: (context, progress, child) =>
                  Opacity(opacity: progress, child: child),
              child: ReportTrends(
                  trends: (data['trends'] as List)
                      .map((row) => Map<String, dynamic>.from(row as Map))
                      .toList(),
                  format: format)),
          if (data['trendsTruncated'] == true)
            const Text(
                'Showing the first 120 months; totals include the full period.'),
          const SizedBox(height: 12),
        ],
        pair(
          OverviewPanel(
              title: 'Income & expenses',
              subtitle: 'Period totals · tap a bar to explore',
              child: OverviewBars(data: [
                datum('totalIncome', 'Income', 'profit-and-loss'),
                datum('totalExpenses', 'Expenses', 'profit-and-loss'),
                datum('netProfit', 'Net profit / loss', 'profit-and-loss')
              ])),
          OverviewPanel(
              title: 'Available funds',
              subtitle: 'Cash + bank after paid receipts and payments',
              child: OverviewDonut(
                  data: [
                    datum('cash', 'Cash', 'general-ledger'),
                    datum('bank', 'Bank', 'general-ledger')
                  ],
                  centerLabel: 'Cash & bank',
                  totalLabel: value('cash').isFinite && value('bank').isFinite
                      ? amount('availableFunds') : null)),
        ),
        const SizedBox(height: 12),
        pair(
          OverviewPanel(
              title: 'Financial position',
              subtitle: 'Closing balances',
              child: OverviewBars(data: [
                datum('totalAssets', 'Assets', 'balance-sheet'),
                datum('totalLiabilities', 'Liabilities', 'balance-sheet'),
                datum('totalEquity', 'Equity', 'balance-sheet')
              ])),
          OverviewPanel(
              title: 'Outstanding balances',
              subtitle: 'Amounts to collect and pay',
              child: OverviewBars(data: [
                datum('receivables', 'Receivables', 'balance-sheet'),
                datum('payables', 'Payables', 'balance-sheet')
              ])),
        ),
        if (data.containsKey('payrollLiabilities')) ...[
          const SizedBox(height: 12),
          OverviewPanel(
              title: 'Liabilities still owed',
              subtitle: 'Posted unpaid balances; draft entries are excluded',
              child: OverviewBars(data: [
                datum('payables', 'Suppliers / expenses', 'balance-sheet'),
                datum('payrollLiabilities', 'Payroll / withholding', 'balance-sheet'),
                datum('loanLiabilities', 'Loans', 'balance-sheet'),
                datum('otherLiabilities', 'Other liabilities', 'balance-sheet'),
              ])),
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final entry in const {
            'profit-and-loss': 'Profit & Loss',
            'balance-sheet': 'Balance Sheet',
            'trial-balance': 'Trial Balance',
            'general-ledger': 'General Ledger',
          }.entries)
            ActionChip(
                label: Text(entry.value),
                avatar: const Icon(Icons.arrow_outward, size: 15),
                onPressed: report(entry.key))
        ]),
        if (taskOverview != null) ...[
          const SizedBox(height: 20),
          taskOverview!
        ],
      ]);
    });
  }
}
