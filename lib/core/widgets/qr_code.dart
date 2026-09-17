import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr/qr.dart' as qr;

/// A QR image with a four-module quiet zone and crisp, square modules.
class QrImageView extends StatelessWidget {
  final String data;
  final double size;
  final Color foregroundColor;
  final Color backgroundColor;
  final double padding;
  final Widget? embeddedLogo;
  final double embeddedLogoSize;

  const QrImageView({
    super.key,
    required this.data,
    this.size = 200,
    this.foregroundColor = const Color(0xFF0F172A),
    this.backgroundColor = Colors.white,
    this.padding = 12.0,
    this.embeddedLogo,
    this.embeddedLogoSize = 40.0,
  })  : assert(size > 0),
        assert(padding >= 0),
        assert(embeddedLogoSize >= 0);

  @override
  Widget build(BuildContext context) {
    final matrix = QrCodeGenerator.generate(
      data,
      errorCorrectLevel: embeddedLogo == null
          ? qr.QrErrorCorrectLevel.M
          : qr.QrErrorCorrectLevel.H,
    );
    final pixelRatio = View.of(context).devicePixelRatio;

    return SizedBox.square(
      dimension: size,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableSize = constraints.biggest;
          final moduleSize = _moduleSize(
            availableSize,
            matrix.length,
            padding,
            pixelRatio,
          );
          // Keep logos small even when the payload requires a denser symbol.
          final logoSize = math.min(
            embeddedLogoSize,
            matrix.length * moduleSize * 0.15,
          );

          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              CustomPaint(
                painter: _QrCanvasPainter(
                  matrix: matrix,
                  color: foregroundColor,
                  backgroundColor: backgroundColor,
                  padding: padding,
                  pixelRatio: pixelRatio,
                ),
              ),
              if (embeddedLogo != null)
                Center(
                  child: Container(
                    width: logoSize,
                    height: logoSize,
                    color: backgroundColor,
                    padding: const EdgeInsets.all(2),
                    child: embeddedLogo,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

double _moduleSize(Size size, int count, double padding, double pixelRatio) {
  final side = size.shortestSide;
  // The requested padding is a minimum; the symbol always has four blank
  // modules on each side, including when padding is zero.
  final available = math.min(
    side / (count + 8),
    math.max(0.0, side - padding * 2) / count,
  );
  final physicalPixels = (available * pixelRatio).floor();
  return physicalPixels > 0 ? physicalPixels / pixelRatio : available;
}

class _QrCanvasPainter extends CustomPainter {
  final List<List<bool>> matrix;
  final Color color;
  final Color backgroundColor;
  final double padding;
  final double pixelRatio;

  _QrCanvasPainter({
    required this.matrix,
    required this.color,
    required this.backgroundColor,
    required this.padding,
    required this.pixelRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    final count = matrix.length;
    final moduleSize = _moduleSize(size, count, padding, pixelRatio);
    final origin = Offset(
      ((size.width - count * moduleSize) * pixelRatio / 2).floor() / pixelRatio,
      ((size.height - count * moduleSize) * pixelRatio / 2).floor() /
          pixelRatio,
    );
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;

    for (var row = 0; row < count; row++) {
      for (var column = 0; column < count; column++) {
        if (matrix[row][column]) {
          canvas.drawRect(
            Rect.fromLTWH(
              origin.dx + column * moduleSize,
              origin.dy + row * moduleSize,
              moduleSize,
              moduleSize,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrCanvasPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.padding != padding ||
        oldDelegate.pixelRatio != pixelRatio ||
        oldDelegate.matrix != matrix;
  }
}

/// Encodes complete QR symbols, including version information and interleaved
/// Reed-Solomon blocks for longer employee sign-in links.
class QrCodeGenerator {
  static List<List<bool>> generate(
    String text, {
    int errorCorrectLevel = qr.QrErrorCorrectLevel.M,
  }) {
    final image = qr.QrImage(
      qr.QrCode.fromData(data: text, errorCorrectLevel: errorCorrectLevel),
    );
    return List.generate(
      image.moduleCount,
      (row) => List.generate(
        image.moduleCount,
        (column) => image.isDark(row, column),
        growable: false,
      ),
      growable: false,
    );
  }
}
