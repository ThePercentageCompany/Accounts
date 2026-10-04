import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Horizontally scrolls all columns; the header and footer stay visible while rows scroll.
class ReportGrid extends StatelessWidget {
  const ReportGrid({
    super.key,
    required this.headers,
    required this.rows,
    required this.numeric,
    required this.dense,
    this.footer,
  });
  final List<String> headers;
  final List<List<Widget>> rows;
  final List<Widget>? footer;
  final Set<int> numeric;
  final bool dense;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final widths = [
      for (var i = 0; i < headers.length; i++)
        headers[i] == 'Account' || headers[i] == 'Description'
            ? 240.0
            : headers[i].contains('impact')
            ? 220.0
            : 160.0,
    ];
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = (dense ? 44.0 : 58.0) * math.max(1, textScale);
    Widget row(List<Widget> cells, {bool header = false}) => Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < cells.length; i++)
          Container(
            width: widths[i],
            constraints: BoxConstraints(minHeight: height),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            alignment: numeric.contains(i)
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontWeight: header ? FontWeight.w700 : FontWeight.w400,
              ),
              child: cells[i],
            ),
          ),
      ],
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: widths.fold<double>(0, (a, b) => a + b),
        child: Column(
          children: [
            Container(
              color: colors.surfaceContainerHighest,
              child: row(headers.map((h) => Text(h)).toList(), header: true),
            ),
            SizedBox(
              height: math.min(
                420 * math.max(1, textScale),
                math.max(height, rows.length * height),
              ),
              child: ListView.builder(
                primary: false,
                itemCount: rows.length,
                itemBuilder: (context, index) => DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colors.outlineVariant),
                    ),
                    color: index.isOdd
                        ? colors.surfaceContainerLow
                        : colors.surface,
                  ),
                  child: row(rows[index]),
                ),
              ),
            ),
            if (footer != null)
              Container(
                color: colors.surfaceContainerHighest,
                child: row(footer!, header: true),
              ),
          ],
        ),
      ),
    );
  }
}
