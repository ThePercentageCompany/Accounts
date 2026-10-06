import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/reports/data/report_format.dart';

void main() {
  test('unsupported metadata pattern retains the date instead of throwing', () {
    const format = ReportFormat(datePattern: 'yyyy-MM-dd EEEEEE');
    expect(format.date('2026-01-01'), '2026-01-01');
    expect(format.date(null), '\u2014');
    expect(format.date('invalid'), '\u2014');
  });

  test('valid patterns and signed money retain their displayed values', () {
    const format = ReportFormat(datePattern: 'MMMM d, yyyy');
    expect(format.date('2026-01-01'), 'January 1, 2026');
    expect(format.money('-1234.56'), '-1,234.56');
    expect(format.money(null), '\u2014');
    expect(format.money('NaN'), '\u2014');
    expect(format.money('Infinity'), '\u2014');
  });
}
