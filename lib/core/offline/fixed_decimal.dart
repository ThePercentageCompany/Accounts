/// Exact decimal parsing for provisional calculations. Excess precision is an
/// error rather than a silently truncated financial amount. Scientific notation
/// is accepted because JSON numbers can stringify small exchange rates that way.
BigInt decimalUnits(Object? value, {int scale = 2}) {
  final text = '${value ?? 0}';
  final match = RegExp(
    r'^([+-]?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$',
  ).firstMatch(text);
  if (match == null || text.length > 128 || scale < 0 || scale > 18) {
    throw FormatException('Invalid decimal amount', text);
  }
  final fraction = match[3] ?? '';
  final exponent = int.tryParse(match[4] ?? '0');
  if (exponent == null || exponent.abs() > 100) {
    throw FormatException('Decimal exponent out of range', text);
  }
  var units = BigInt.parse('${match[2]}$fraction');
  final shift = scale + exponent - fraction.length;
  if (shift >= 0) {
    units *= BigInt.from(10).pow(shift);
  } else {
    final divisor = BigInt.from(10).pow(-shift);
    if (units % divisor != BigInt.zero) {
      throw FormatException('Unsupported decimal precision', text);
    }
    units ~/= divisor;
  }
  return match[1] == '-' ? -units : units;
}

BigInt divideRounded(BigInt numerator, BigInt denominator) {
  if (denominator <= BigInt.zero) {
    throw ArgumentError.value(denominator, 'denominator');
  }
  final rounded = (numerator.abs() + denominator ~/ BigInt.two) ~/ denominator;
  return numerator.isNegative ? -rounded : rounded;
}

BigInt convertMinor(Object? amount, Object? rate) {
  final scaledRate = decimalUnits(rate, scale: 8);
  if (scaledRate <= BigInt.zero || scaledRate > BigInt.from(100000000).pow(2)) {
    throw const FormatException('Exchange rate out of range');
  }
  return divideRounded(
    decimalUnits(amount) * scaledRate,
    BigInt.from(100000000),
  );
}
