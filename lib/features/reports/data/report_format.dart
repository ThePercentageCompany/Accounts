import 'dart:developer' as developer;
import 'package:intl/intl.dart';

BigInt? reportMinor(Object? value) {
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch('$value');
  if (match == null) return null;
  final amount =
      BigInt.parse(match[2]!) * BigInt.from(100) +
      BigInt.parse((match[3] ?? '').padRight(2, '0'));
  return match[1] == '-' ? -amount : amount;
}

String reportDecimal(BigInt n) {
  final a = n.abs();
  return '${n.isNegative ? '-' : ''}${a ~/ BigInt.from(100)}.${(a % BigInt.from(100)).toString().padLeft(2, '0')}';
}

class ReportFormat {
  const ReportFormat({
    this.locale = 'en_AE',
    this.parentheses = false,
    this.datePattern = 'yyyy-MM-dd',
  });
  final String locale, datePattern;
  final bool parentheses;
  String money(Object? value) {
    final minor = reportMinor(value);
    if (minor == null) return '\u2014';
    final text = (minor.abs() ~/ BigInt.from(100)).toString();
    final chunks = <String>[];
    var end = text.length;
    var size = 3;
    while (end > 0) {
      final start = (end - size).clamp(0, end);
      chunks.insert(0, text.substring(start, end));
      end = start;
      if (locale == 'en_IN') size = 2;
    }
    final separator = locale == 'de_DE' ? '.' : ',';
    final decimal = locale == 'de_DE' ? ',' : '.';
    final number =
        '${chunks.join(separator)}$decimal${(minor.abs() % BigInt.from(100)).toString().padLeft(2, '0')}';
    return minor.isNegative ? (parentheses ? '($number)' : '-$number') : number;
  }

  String date(Object? value) {
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return '\u2014';
    try {
      return DateFormat(datePattern).format(parsed);
    } on UnsupportedError catch (error, stack) {
      // Metadata can contain a pattern unsupported by intl (e.g. EEEEEE).
      // Retain the date and report the configuration failure, rather than
      // letting one display preference prevent the entire report from building.
      developer.log(
        'Unsupported report date pattern: $datePattern',
        name: 'ReportFormat',
        error: error,
        stackTrace: stack,
        level: 900,
      );
      return DateFormat('yyyy-MM-dd').format(parsed);
    } on FormatException catch (error, stack) {
      developer.log(
        'Invalid report date pattern: $datePattern',
        name: 'ReportFormat',
        error: error,
        stackTrace: stack,
        level: 900,
      );
      return DateFormat('yyyy-MM-dd').format(parsed);
    }
  }
}

DateTime financialYearStart(DateTime date, int month, int day) {
  final start = DateTime(date.year, month, day);
  return date.isBefore(start) ? DateTime(date.year - 1, month, day) : start;
}

DateTime previousYearDate(DateTime value) {
  final last = DateTime(value.year - 1, value.month + 1, 0).day;
  return DateTime(value.year - 1, value.month, value.day.clamp(1, last));
}
