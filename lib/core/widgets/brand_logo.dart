import 'package:flutter/material.dart';

class TpcBrandLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showBackground;
  final Color? backgroundColor;

  const TpcBrandLogo({
    super.key,
    this.size = 36,
    this.borderRadius = 10,
    this.showBackground = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget image = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: Text(
            '%',
            style: TextStyle(
              color: isDark ? Colors.black : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.58,
              height: 1,
            ),
          ),
        ),
      ),
    );

    if (!showBackground) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? const Color(0xFF2C2C2E) : Colors.white),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.12),
      child: image,
    );
  }
}
