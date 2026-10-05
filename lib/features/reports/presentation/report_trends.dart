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
                    const Text('Income'),
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
                    const Text('Expenses'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
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
    final values = [
      for (final t in trends)
        for (final k in ['income', 'expenses']) double.tryParse('${t[k]}') ?? 0,
    ];
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
        final value = double.tryParse('${trends[i][key]}') ?? 0;
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

/// An eagerly laid out native table avoids a lazy viewport inside the
/// expansion animation. Each scroll axis owns its controller and scrollbar.
class _ExactTrendTable extends StatefulWidget {
  const _ExactTrendTable({required this.trends, required this.format});
  final List<Map<String, dynamic>> trends;
  final ReportFormat format;
  @override
  State<_ExactTrendTable> createState() => _ExactTrendTableState();
}

class _ExactTrendTableState extends State<_ExactTrendTable> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  @override
  void dispose() {
    _vertical.dispose();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = math.min(
          420 * scale,
          (56 + math.max(1, widget.trends.length) * 64) * scale,
        );
        return SizedBox(
          key: const Key('exact-trend-table'),
          width: constraints.maxWidth,
          height: viewportHeight,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: Scrollbar(
              controller: _vertical,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.vertical,
              child: SingleChildScrollView(
                key: const Key('exact-trend-vertical-scroll'),
                controller: _vertical,
                primary: false,
                child: Scrollbar(
                  controller: _horizontal,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    key: const Key('exact-trend-horizontal-scroll'),
                    controller: _horizontal,
                    primary: false,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: math.max(800, constraints.maxWidth),
                      ),
                      child: DataTable(
                        headingRowColor: WidgetStatePropertyAll(
                          colors.surfaceContainerHighest,
                        ),
                        headingRowHeight: 56 * scale,
                        dataRowMinHeight: 48 * scale,
                        dataRowMaxHeight: 88 * scale,
                        horizontalMargin: 16,
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text('From')),
                          DataColumn(label: Text('To')),
                          DataColumn(label: Text('Income'), numeric: true),
                          DataColumn(label: Text('Expenses'), numeric: true),
                          DataColumn(label: Text('Net profit'), numeric: true),
                        ],
                        rows: [
                          for (var i = 0; i < widget.trends.length; i++)
                            DataRow(
                              color: WidgetStatePropertyAll(
                                i.isOdd
                                    ? colors.surfaceContainerLow
                                    : colors.surface,
                              ),
                              cells: [
                                DataCell(
                                  Text(
                                    widget.format.date(
                                      widget.trends[i]['from'],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    widget.format.date(
                                      widget.trends[i]['asOf'],
                                    ),
                                  ),
                                ),
                                for (final key in [
                                  'income',
                                  'expenses',
                                  'netProfit',
                                ])
                                  DataCell(
                                    Text(
                                      widget.format.money(
                                        widget.trends[i][key],
                                      ),
                                      style: const TextStyle(
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
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
