import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/report_format.dart';
import 'report_grid.dart';

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
                Text(format.date(trends.first['from'])),
                Text(format.date(trends.last['asOf'])),
              ],
            ),
            ExpansionTile(
              title: const Text('View exact trend data'),
              children: [
                ReportGrid(
                  headers: const [
                    'From',
                    'To',
                    'Income',
                    'Expenses',
                    'Net profit',
                  ],
                  numeric: const {2, 3, 4},
                  dense: true,
                  rows: [
                    for (final t in trends)
                      [
                        Text(format.date(t['from'])),
                        Text(format.date(t['asOf'])),
                        Text(format.money(t['income'])),
                        Text(format.money(t['expenses'])),
                        Text(format.money(t['netProfit'])),
                      ],
                  ],
                ),
              ],
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
