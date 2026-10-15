import 'dart:math' as math;
import 'package:flutter/material.dart';

const overviewPalette = [
  Color(0xffb7420b),
  Color(0xffbe9c72),
  Color(0xff788ac0),
  Color(0xffa481a9),
  Color(0xff8ba992),
  Color(0xffc37e74)
];

class OverviewDatum {
  const OverviewDatum(this.label, this.value, {this.display, this.onTap});
  final String label;
  final double value;
  final String? display;
  final VoidCallback? onTap;
}

class OverviewPanel extends StatelessWidget {
  const OverviewPanel(
      {super.key,
      required this.title,
      required this.child,
      this.subtitle,
      this.action});
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600))),
              if (action != null) action!
            ]),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)
            ],
            const SizedBox(height: 20),
            child,
          ])));
}

/// Exact values and navigation remain available independently of the animation.
class OverviewBars extends StatelessWidget {
  const OverviewBars({super.key, required this.data});
  final List<OverviewDatum> data;
  @override
  Widget build(BuildContext context) {
    final valid = data.where((point) => point.value.isFinite).toList();
    if (valid.isEmpty) return const Text('No data available yet.');
    final maxValue = valid.fold<double>(
        0, (value, point) => math.max(value, point.value.abs()));
    final signed = valid.any((point) => point.value < 0);
    return Column(children: [
      for (var i = 0; i < valid.length; i++)
        Semantics(
            label: '${valid[i].label}: ${valid[i].display ?? valid[i].value}',
            child: InkWell(
                onTap: valid[i].onTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: Text(valid[i].label)),
                        const SizedBox(width: 12),
                        Flexible(
                            child: Text(
                                valid[i].display ??
                                    valid[i].value.toStringAsFixed(0),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontFeatures: [
                                  FontFeature.tabularFigures()
                                ])))
                      ]),
                      const SizedBox(height: 8),
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                            begin: 0,
                            end: maxValue == 0 ? 0 : valid[i].value / maxValue),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => SizedBox(
                            height: 7,
                            width: double.infinity,
                            child: CustomPaint(
                                painter: _BarPainter(
                                    value,
                                    signed,
                                    overviewPalette[i % overviewPalette.length],
                                    Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest))),
                      ),
                    ]))))
    ]);
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.value, this.signed, this.color, this.track);
  final double value;
  final bool signed;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5)),
        Paint()..color = track);
    final zero = signed ? size.width / 2 : 0.0;
    final end = zero + value * (signed ? size.width / 2 : size.width);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(
                math.min(zero, end), 0, math.max(zero, end), size.height),
            const Radius.circular(5)),
        Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.value != value ||
      old.signed != signed ||
      old.color != color ||
      old.track != track;
}

class OverviewDonut extends StatelessWidget {
  const OverviewDonut(
      {super.key,
      required this.data,
      this.centerLabel = 'Total',
      this.totalLabel});
  final List<OverviewDatum> data;
  final String centerLabel;
  final String? totalLabel;
  @override
  Widget build(BuildContext context) {
    if (data.any((point) => !point.value.isFinite || point.value < 0)) {
      return const Text(
          'Composition is unavailable for negative or missing balances. See the exact amounts in the overview.');
    }
    final total = data.fold<double>(0, (sum, point) => sum + point.value);
    final ring = SizedBox(
        width: 150,
        height: 150,
        child: Semantics(
            label: '$centerLabel: ${totalLabel ?? total.toStringAsFixed(0)}',
            child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CustomPaint(
                      painter: _DonutPainter(
                          data.map((point) => point.value).toList(),
                          value,
                          Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest),
                      child: Center(
                          child: Padding(
                              padding: const EdgeInsets.all(25),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                        child: Text(
                                            totalLabel ??
                                                total.toStringAsFixed(0),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700))),
                                    Text(
                                        total == 0
                                            ? 'No activity'
                                            : centerLabel,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ]))),
                    ))));
    final legend = Column(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < data.length; i++)
        InkWell(
            onTap: data[i].onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: overviewPalette[i % overviewPalette.length])),
                  const SizedBox(width: 9),
                  Expanded(child: Text(data[i].label)),
                  const SizedBox(width: 8),
                  Flexible(
                      child: Text(
                          data[i].display ?? data[i].value.toStringAsFixed(0),
                          textAlign: TextAlign.right)),
                  if (data[i].onTap != null)
                    const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.arrow_outward, size: 13)),
                ])))
    ]);
    return LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 360
            ? Row(children: [
                ring,
                const SizedBox(width: 20),
                Expanded(child: legend)
              ])
            : Column(children: [ring, const SizedBox(height: 16), legend]));
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.progress, this.track);
  final List<double> values;
  final double progress;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawOval(rect, paint);
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total == 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2 * progress;
      paint.color = overviewPalette[i % overviewPalette.length];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.values.length != values.length ||
      List.generate(values.length, (i) => i)
          .any((i) => old.values[i] != values[i]);
}
