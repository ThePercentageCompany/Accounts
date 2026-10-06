import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/report_format.dart';

class ReportTrends extends StatelessWidget {
  const ReportTrends({super.key, required this.trends, required this.format});
  final List<Map<String, dynamic>> trends;
  final ReportFormat format;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (trends.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No trend data for this period.'),
        ),
      );
    }
    final chartAvailable = trends.every(
      (row) => ['income', 'expenses'].every((key) {
        if (row[key] == null) return true;
        final value = double.tryParse('${row[key]}');
        return value != null && value.isFinite;
      }),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Revenue & expense trend',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${format.date(trends.first['from'])} to ${format.date(trends.last['asOf'])} · Monthly posted activity',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 12, color: colors.primary),
                    const SizedBox(width: 6),
                    const Flexible(child: Text('Income')),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.square,
                      size: 12,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    const Flexible(child: Text('Expenses')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!chartAvailable)
              const Text('Graph unavailable for this report.')
            else
              Semantics(
                label:
                    'Monthly income and expenses. Exact signed values are available in the trend data table.',
                child: SizedBox(
                  height: 200,
                  child: CustomPaint(
                    painter: _TrendPainter(
                      trends,
                      colors.primary,
                      colors.onSurfaceVariant,
                      colors.outlineVariant,
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(format.date(trends.first['from']))),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    format.date(trends.last['asOf']),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            ExpansionTile(
              key: const PageStorageKey('exact-trend-expansion'),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              title: const Text('View exact trend data'),
              children: [_ExactTrendTable(trends: trends, format: format)],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.trends, this.income, this.expense, this.grid);
  final List<Map<String, dynamic>> trends;
  final Color income, expense, grid;
  @override
  void paint(Canvas canvas, Size size) {
    final rawValues = [
      for (final t in trends)
        for (final k in ['income', 'expenses']) double.tryParse('${t[k]}') ?? 0,
    ];
    // Normalize drawing coordinates before subtracting extrema: two finite
    // amounts near double's limit can otherwise produce an infinite range.
    final magnitude = rawValues.fold<double>(1, (m, v) => math.max(m, v.abs()));
    final values = rawValues.map((v) => v / magnitude).toList();
    final min = values.fold<double>(0, math.min),
        max = values.fold<double>(0, math.max);
    final range = max - min == 0 ? 1.0 : max - min;
    final top = 12.0, bottom = size.height - 12;
    double y(double value) => bottom - (value - min) / range * (bottom - top);
    final line = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final at = top + (bottom - top) * i / 4;
      canvas.drawLine(Offset(0, at), Offset(size.width, at), line);
    }
    canvas.drawLine(
      Offset(0, y(0)),
      Offset(size.width, y(0)),
      Paint()
        ..color = grid
        ..strokeWidth = 2,
    );
    for (final key in ['income', 'expenses']) {
      final paint = Paint()
        ..color = key == 'income' ? income : expense
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < trends.length; i++) {
        final value = (double.tryParse('${trends[i][key]}') ?? 0) / magnitude;
        final point = Offset(
          trends.length == 1
              ? size.width / 2
              : 6 + (size.width - 12) * i / (trends.length - 1),
          y(value),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
        final marker = Paint()..color = paint.color;
        if (key == 'income') {
          canvas.drawCircle(point, 3, marker);
        } else {
          canvas.drawRect(
            Rect.fromCenter(center: point, width: 6, height: 6),
            marker,
          );
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.trends != trends ||
      old.income != income ||
      old.expense != expense ||
      old.grid != grid;
}

/// The table owns horizontal scrolling; rows grow naturally in the report's
/// existing vertical scroll view. No estimated row heights or nested vertical
/// viewport are needed, including during ExpansionTile's height animation.
class _ExactTrendTable extends StatefulWidget {
  const _ExactTrendTable({required this.trends, required this.format});
  final List<Map<String, dynamic>> trends;
  final ReportFormat format;
  @override
  State<_ExactTrendTable> createState() => _ExactTrendTableState();
}

class _ExactTrendTableState extends State<_ExactTrendTable> {
  final _horizontal = ScrollController();
  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );
    Widget cell(String value, {bool numeric = false, bool heading = false}) =>
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            value,
            textAlign: numeric ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontWeight: heading ? FontWeight.w600 : null,
              fontFeatures: numeric
                  ? const [FontFeature.tabularFigures()]
                  : null,
            ),
          ),
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        // The report and tile provide finite width, but unbounded vertical space.
        // Supply a finite content width to Table's flex columns inside the
        // horizontal scroller; let Table measure its own height.
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return SizedBox(
          key: const Key('exact-trend-table'),
          width: width,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: Scrollbar(
              controller: _horizontal,
              notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                key: const PageStorageKey('exact-trend-horizontal-scroll'),
                controller: _horizontal,
                primary: false,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(800 * scale, width),
                  child: Table(
                    defaultColumnWidth: const FlexColumnWidth(),
                    border: TableBorder(
                      horizontalInside: BorderSide(
                        color: colors.outlineVariant,
                      ),
                    ),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                        ),
                        children: [
                          for (final title in [
                            'From',
                            'To',
                            'Income',
                            'Expenses',
                            'Net profit',
                          ])
                            cell(
                              title,
                              heading: true,
                              numeric: !['From', 'To'].contains(title),
                            ),
                        ],
                      ),
                      for (var i = 0; i < widget.trends.length; i++)
                        TableRow(
                          decoration: BoxDecoration(
                            color: i.isOdd
                                ? colors.surfaceContainerLow
                                : colors.surface,
                          ),
                          children: [
                            cell(widget.format.date(widget.trends[i]['from'])),
                            cell(widget.format.date(widget.trends[i]['asOf'])),
                            for (final key in [
                              'income',
                              'expenses',
                              'netProfit',
                            ])
                              cell(
                                widget.format.money(widget.trends[i][key]),
                                numeric: true,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
