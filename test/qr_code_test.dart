import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr/qr.dart' as qr;
import 'package:tpc_invoice/core/widgets/qr_code.dart';

void main() {
  test('encodes the complete known-good version 1 symbol', () {
    // Reference matrix for the byte-mode payload, ECC M, from qr 3.0.2's
    // published test vectors. This catches malformed format bits as well as
    // data placement errors; finder-pattern-only checks cannot do that.
    const expected = [
      '111111100110101111111',
      '100000100111101000001',
      '101110100000001011101',
      '101110100001101011101',
      '101110100000101011101',
      '100000101111101000001',
      '111111101010101111111',
      '000000000001100000000',
      '100101101110010100000',
      '011001000010001101111',
      '000000101010110000101',
      '001001011111000001000',
      '111111100100101010001',
      '000000001101000101011',
      '111111100110010010110',
      '100000101101110000001',
      '101110100011001000001',
      '101110101101000111111',
      '101110100100100110001',
      '100000100010011100000',
      '111111101111100101010',
    ];

    final matrix = QrCodeGenerator.generate('shanna!');
    expect(
      matrix.map((row) => row.map((dark) => dark ? '1' : '0').join()),
      expected,
    );
  });

  test('long links select the correct version and include version metadata',
      () {
    // Previously payloads over 800 bytes fell back to version 10 and lost data.
    final matrix = QrCodeGenerator.generate('x' * 1000);
    expect(matrix.length, 121); // Version 26, ECC M.

    var topRightVersionBits = 0;
    var bottomLeftVersionBits = 0;
    for (var bit = 0; bit < 18; bit++) {
      if (matrix[bit ~/ 3][matrix.length - 11 + bit % 3]) {
        topRightVersionBits |= 1 << bit;
      }
      if (matrix[matrix.length - 11 + bit % 3][bit ~/ 3]) {
        bottomLeftVersionBits |= 1 << bit;
      }
    }
    expect(topRightVersionBits, 0x1afab); // Version 26 BCH code.
    expect(bottomLeftVersionBits, topRightVersionBits);
  });

  test('rejects oversized input instead of emitting a truncated symbol', () {
    expect(
      () => QrCodeGenerator.generate('x' * 2400),
      throwsA(isA<qr.InputTooLongException>()),
    );
  });

  for (final pixelRatio in [1.0, 1.25, 3.0]) {
    testWidgets('preserves a quiet zone with zero padding at DPR $pixelRatio', (
      tester,
    ) async {
      tester.view.devicePixelRatio = pixelRatio;
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: const QrImageView(
                data: 'shanna!',
                size: 190,
                padding: 0,
                foregroundColor: Colors.black,
              ),
            ),
          ),
        ),
      );
      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        try {
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final modulePixels = (190 * pixelRatio / 29).floor();
          final quietPixels = modulePixels * 4;
          var darkPixels = 0;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              final offset = (y * image.width + x) * 4;
              final red = pixels.getUint8(offset);
              final alpha = pixels.getUint8(offset + 3);
              // Fractional display scales can leave a partial white pixel at
              // the outer canvas edge; the QR modules must stay fully opaque.
              if (alpha != 255) {
                expect(x == image.width - 1 || y == image.height - 1, isTrue);
                expect(red, alpha);
                continue;
              }
              // Pixel alignment prevents gray seams between black modules.
              expect(red, anyOf(0, 255));
              if (red == 0) darkPixels++;
              if (x < quietPixels ||
                  x >= image.width - quietPixels ||
                  y < quietPixels ||
                  y >= image.height - quietPixels) {
                expect(red, 255);
              }
            }
          }
          expect(darkPixels, greaterThan(0));
        } finally {
          image.dispose();
        }
      });
    });
  }
}
