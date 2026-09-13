import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Pure Dart QR Code generator and Canvas widget.
/// Zero external dependencies, fully compatible with Flutter Web, Mobile, and Desktop.

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
  });

  @override
  Widget build(BuildContext context) {
    final matrix = QrCodeGenerator.generate(data);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size - padding * 2, size - padding * 2),
            painter: _QrCanvasPainter(
              matrix: matrix,
              color: foregroundColor,
            ),
          ),
          if (embeddedLogo != null)
            Container(
              width: embeddedLogoSize,
              height: embeddedLogoSize,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(embeddedLogoSize / 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(embeddedLogoSize / 5),
                child: embeddedLogo,
              ),
            ),
        ],
      ),
    );
  }
}

class _QrCanvasPainter extends CustomPainter {
  final List<List<bool>> matrix;
  final Color color;

  _QrCanvasPainter({required this.matrix, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (matrix.isEmpty) return;
    final moduleCount = matrix.length;
    final moduleSize = size.width / moduleCount;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int r = 0; r < moduleCount; r++) {
      for (int c = 0; c < moduleCount; c++) {
        if (matrix[r][c]) {
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(c * moduleSize, r * moduleSize, moduleSize, moduleSize),
            Radius.circular(moduleSize * 0.2),
          );
          canvas.drawRRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrCanvasPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.matrix != matrix;
  }
}

/// Standard QR Code Generator implementing ISO/IEC 18004 Byte Mode with Reed-Solomon Error Correction.
class QrCodeGenerator {
  static List<List<bool>> generate(String text) {
    final bytes = utf8.encode(text);
    // Determine minimum QR version needed
    int version = _findBestVersion(bytes.length);
    return _buildMatrix(version, bytes);
  }

  static int _findBestVersion(int dataLen) {
    // Capacity for ECC level M in Byte mode for versions 1 to 20
    const capacities = [
      14, 26, 42, 62, 84, 106, 122, 152, 180, 213, 251, 287, 331, 362, 412, 480, 520, 600, 700, 800
    ];
    for (int v = 0; v < capacities.length; v++) {
      if (dataLen <= capacities[v]) return v + 1;
    }
    return 10;
  }

  static List<List<bool>> _buildMatrix(int version, List<int> dataBytes) {
    final size = 17 + 4 * version;
    final matrix = List.generate(size, (_) => List.generate(size, (_) => false));
    final isFunction = List.generate(size, (_) => List.generate(size, (_) => false));

    void setFunc(int r, int c, bool val) {
      if (r >= 0 && r < size && c >= 0 && c < size) {
        matrix[r][c] = val;
        isFunction[r][c] = true;
      }
    }

    // 1. Finder Patterns
    void drawFinder(int startR, int startC) {
      for (int r = -1; r <= 7; r++) {
        for (int c = -1; c <= 7; c++) {
          int row = startR + r;
          int col = startC + c;
          if (row < 0 || row >= size || col < 0 || col >= size) continue;
          bool isBlack = false;
          if (r >= 0 && r <= 6 && c >= 0 && c <= 6) {
            if (r == 0 || r == 6 || c == 0 || c == 6 || (r >= 2 && r <= 4 && c >= 2 && c <= 4)) {
              isBlack = true;
            }
          }
          setFunc(row, col, isBlack);
        }
      }
    }

    drawFinder(0, 0);
    drawFinder(0, size - 7);
    drawFinder(size - 7, 0);

    // 2. Alignment Patterns for version >= 2
    if (version >= 2) {
      final pos = _getAlignmentPatternPositions(version);
      for (final r in pos) {
        for (final c in pos) {
          if (isFunction[r][c]) continue;
          for (int dr = -2; dr <= 2; dr++) {
            for (int dc = -2; dc <= 2; dc++) {
              bool isBlack = (dr.abs() == 2 || dc.abs() == 2 || (dr == 0 && dc == 0));
              setFunc(r + dr, c + dc, isBlack);
            }
          }
        }
      }
    }

    // 3. Timing Patterns
    for (int i = 8; i < size - 8; i++) {
      setFunc(6, i, i % 2 == 0);
      setFunc(i, 6, i % 2 == 0);
    }

    // 4. Dark Module
    setFunc(4 * version + 9, 8, true);

    // 5. Reserve Format Information Area
    for (int i = 0; i < 9; i++) {
      if (!isFunction[8][i]) setFunc(8, i, false);
      if (!isFunction[i][8]) setFunc(i, 8, false);
    }
    for (int i = size - 8; i < size; i++) {
      if (!isFunction[8][i]) setFunc(8, i, false);
    }
    for (int i = size - 7; i < size; i++) {
      if (!isFunction[i][8]) setFunc(i, 8, false);
    }

    // 6. Encode Data & ECC Codewords
    final dataCodewords = _encodeData(version, dataBytes);
    final allCodewords = _addErrorCorrection(version, dataCodewords);

    // 7. Place Codewords in Zigzag Pattern
    int byteIdx = 0;
    int bitIdx = 7;
    int col = size - 1;
    bool upward = true;

    while (col > 0) {
      if (col == 6) col--; // Skip timing column
      final rows = upward ? [for (int r = size - 1; r >= 0; r--) r] : [for (int r = 0; r < size; r++) r];

      for (final r in rows) {
        for (int c = col; c >= col - 1; c--) {
          if (!isFunction[r][c]) {
            bool bit = false;
            if (byteIdx < allCodewords.length) {
              bit = ((allCodewords[byteIdx] >> bitIdx) & 1) == 1;
              bitIdx--;
              if (bitIdx < 0) {
                bitIdx = 7;
                byteIdx++;
              }
            }
            // Apply Mask 0: (r + c) % 2 == 0
            if ((r + c) % 2 == 0) {
              bit = !bit;
            }
            matrix[r][c] = bit;
          }
        }
      }
      col -= 2;
      upward = !upward;
    }

    // 8. Write Format Information (ECC Level M + Mask 0 = 0x5412)
    const formatInfo = 0x5412;
    for (int i = 0; i < 15; i++) {
      final bit = ((formatInfo >> i) & 1) == 1;
      // Top-Left
      if (i <= 5) {
        matrix[8][i] = bit;
      } else if (i == 6) {
        matrix[8][7] = bit;
      } else if (i == 7) {
        matrix[8][8] = bit;
      } else if (i == 8) {
        matrix[7][8] = bit;
      } else {
        matrix[14 - i][8] = bit;
      }

      // Bottom-Left & Top-Right
      if (i < 8) {
        matrix[size - 1 - i][8] = bit;
      } else {
        matrix[8][size - 15 + i] = bit;
      }
    }

    return matrix;
  }

  static List<int> _encodeData(int version, List<int> data) {
    final bits = <int>[];
    void writeBits(int val, int count) {
      for (int i = count - 1; i >= 0; i--) {
        bits.add((val >> i) & 1);
      }
    }

    // Mode: Byte (0100)
    writeBits(4, 4);
    // Character count (8 bits for v1-9, 16 for v10+)
    writeBits(data.length, version <= 9 ? 8 : 16);
    // Data
    for (final b in data) {
      writeBits(b, 8);
    }
    // Terminator
    final capacityBits = _getDataCapacity(version) * 8;
    final termLen = min(4, capacityBits - bits.length);
    writeBits(0, termLen);
    // Pad to byte
    while (bits.length % 8 != 0) {
      bits.add(0);
    }
    // Pad bytes
    final bytes = <int>[];
    for (int i = 0; i < bits.length; i += 8) {
      int b = 0;
      for (int j = 0; j < 8; j++) {
        b = (b << 1) | bits[i + j];
      }
      bytes.add(b);
    }
    final targetBytes = _getDataCapacity(version);
    final pad = [0xEC, 0x11];
    int padIdx = 0;
    while (bytes.length < targetBytes) {
      bytes.add(pad[padIdx % 2]);
      padIdx++;
    }
    return bytes;
  }

  static int _getDataCapacity(int version) {
    const capacities = [
      16, 28, 44, 64, 86, 108, 124, 154, 182, 216, 254, 290, 334, 365, 415, 483, 523, 603, 703, 803
    ];
    return version <= capacities.length ? capacities[version - 1] : capacities.last;
  }

  static int _getEccCodewordsPerBlock(int version) {
    const ecc = [
      10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26
    ];
    return version <= ecc.length ? ecc[version - 1] : 26;
  }

  static List<int> _addErrorCorrection(int version, List<int> data) {
    final eccCount = _getEccCodewordsPerBlock(version);
    final generator = _rsGeneratorPolynomial(eccCount);
    final ecc = _rsDivide(data, generator);
    return [...data, ...ecc];
  }

  // Galois Field GF(256) tables with primitive polynomial 0x11D
  static final List<int> _exp = _initExp();
  static final List<int> _log = _initLog();

  static List<int> _initExp() {
    final exp = List.filled(512, 0);
    int x = 1;
    for (int i = 0; i < 255; i++) {
      exp[i] = x;
      exp[i + 255] = x;
      x <<= 1;
      if ((x & 0x100) != 0) x ^= 0x11D;
    }
    return exp;
  }

  static List<int> _initLog() {
    final log = List.filled(256, 0);
    for (int i = 0; i < 255; i++) {
      log[_exp[i]] = i;
    }
    return log;
  }

  static int _gfMul(int x, int y) {
    if (x == 0 || y == 0) return 0;
    return _exp[_log[x] + _log[y]];
  }

  static List<int> _rsGeneratorPolynomial(int degree) {
    List<int> poly = [1];
    for (int i = 0; i < degree; i++) {
      final next = [1, _exp[i]];
      final res = List.filled(poly.length + 1, 0);
      for (int j = 0; j < poly.length; j++) {
        for (int k = 0; k < next.length; k++) {
          res[j + k] ^= _gfMul(poly[j], next[k]);
        }
      }
      poly = res;
    }
    return poly;
  }

  static List<int> _rsDivide(List<int> data, List<int> generator) {
    final msg = [...data, ...List.filled(generator.length - 1, 0)];
    for (int i = 0; i < data.length; i++) {
      final coef = msg[i];
      if (coef != 0) {
        for (int j = 0; j < generator.length; j++) {
          msg[i + j] ^= _gfMul(generator[j], coef);
        }
      }
    }
    return msg.sublist(data.length);
  }

  static List<int> _getAlignmentPatternPositions(int version) {
    if (version == 1) return [];
    final count = version ~/ 7 + 2;
    final step = (version == 32) ? 26 : ((version * 4 + 4) ~/ (count * 2 - 2)) * 2;
    final pos = <int>[6];
    for (int i = count - 1; i > 0; i--) {
      pos.insert(1, (17 + 4 * version) - 7 - (count - 1 - i) * step);
    }
    return pos;
  }
}
