import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/reports/presentation/employee_dashboard.dart';

class _PayrollApi extends SaasApi {
  _PayrollApi() : super(offlineAutomatic: false);
  @override
  Future<Map<String, dynamic>> records(String companyId, String table,
          {bool employee = false, bool force = false}) async =>
      {
        'records': [
          for (final entry in [
            ('2025-12', 100),
            ('2026-01', 200),
            ('2026-02', 300)
          ])
            {
              'recordId': entry.$1,
              'month': entry.$1,
              'netSalary': entry.$2,
              'currency': 'AED',
              'status': 'APPROVED',
              'employeeName': 'Amina',
              'employeeCode': 'EMP-1'
            },
        ]
      };
}

void main() {
  for (final compact in [false, true]) {
    testWidgets(
        'payroll period changes dashboard counts and amounts (compact=$compact)',
        (tester) async {
      final api = _PayrollApi();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: SectionOverview(
            api: api,
            companyId: 'c' * 43,
            section: 'Payroll',
            tables: const ['Payroll'],
            active: true,
            compact: compact,
            onSection: (_, __) {}),
      ))));
      await tester.pumpAndSettle();
      expect(find.textContaining('600.00'), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('payroll-filter-Payroll period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Year').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payroll-filter-Year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('500.00'), findsOneWidget);
      expect(find.text(compact ? '2' : '2 records'), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('payroll-filter-Payroll period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Month').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payroll-filter-Month')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('February').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('February').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('300.00'), findsOneWidget);
      expect(find.text(compact ? '1' : '1 records'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('payroll-filter-Year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('AED${compact ? ' ' : ': '}0.00'),
          findsOneWidget);
      expect(find.text(compact ? '0' : '0 records'), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('payroll-filter-Payroll period')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('600.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
}
