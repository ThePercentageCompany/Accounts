import 'package:flutter/material.dart';

/// Uses the original transparent brand artwork, tinted for its background.
class TpcLogo extends StatelessWidget {
  const TpcLogo({super.key, this.size = 32, this.brightness});
  final double size;
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/branding/tpc_symbol.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: (brightness ?? Theme.of(context).brightness) == Brightness.dark
            ? Colors.white
            : Colors.black,
        colorBlendMode: BlendMode.srcIn,
        semanticLabel: 'The Percentage logo',
      );
}
