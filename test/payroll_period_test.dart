import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/reports/data/payroll_period.dart';

void main() {
  final records = [
    {'month': '2025-12', 'netSalary': 100, 'createdAt': 9999999999999},
    {'month': '2026-01', 'netSalary': 200},
    {'month': '2026-02', 'netSalary': 300},
  ];
  test('all, year and month filter the same payroll amounts and details', () {
    List<Map<String, Object>> selected(String scope) => records
        .where((row) =>
            payrollMatchesPeriod(row, scope: scope, year: 2026, month: 2))
        .toList();
    expect(selected('all'), hasLength(3));
    expect(selected('year'), hasLength(2));
    expect(selected('month').single['month'], '2026-02');
    expect(
        selected('year')
            .fold<int>(0, (total, row) => total + (row['netSalary'] as int)),
        500);
    expect(
        selected('month')
            .fold<int>(0, (total, row) => total + (row['netSalary'] as int)),
        300);
  });
  test('invalid salary months are excluded from date filters, retained in All',
      () {
    for (final month in ['', '2026-13', '2026-00', '2026-2']) {
      expect(
          payrollMatchesPeriod({'month': month},
              scope: 'year', year: 2026, month: 2),
          false);
      expect(
          payrollMatchesPeriod({'month': month},
              scope: 'all', year: 2026, month: 2),
          true);
    }
  });
}
