import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/employees/presentation/payroll_support_view.dart';
import 'package:tpc_invoice/features/reports/presentation/employee_dashboard.dart';

void main() {
  testWidgets('sync baseline reads server versions without using cached rows',
      (tester) async {
    var version = 1;
    final api = SaasApi(
        origin: 'https://api.test',
        cacheStore: MemoryCacheStore(),
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'records': [
                {'recordId': 'p', 'recordVersion': version}
              ],
            }),
            200)));
    api.useVerifiedWorkspace('c' * 43, ownerId: 'owner');
    await api.records('c' * 43, 'Payroll');
    version = 2;
    final baseline = await api.syncBaseline('c' * 43, 'Payroll');
    expect(baseline['records'][0]['recordVersion'], 2);
    expect(
        (await api.records('c' * 43, 'Payroll'))['records'][0]['recordVersion'],
        1);
    api.close();
  });
  testWidgets('payroll opens saved rows without waiting for employee names',
      (tester) async {
    final names = Completer<http.Response>();
    final api = SaasApi(
        origin: 'https://api.test',
        cacheStore: MemoryCacheStore(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/employees')) return names.future;
          return http.Response(
              jsonEncode({
                'records': [
                  {
                    'recordId': 'p',
                    'employeeId': 'e',
                    'month': '2026-10',
                    'status': 'DRAFT',
                    'currency': 'AED',
                    'netSalary': 5000,
                  }
                ]
              }),
              200);
        }));
    api.useVerifiedWorkspace('c' * 43, ownerId: 'owner');
    await api.records('c' * 43, 'Payroll');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PayrollSupportView(
      api: api,
      companyId: 'c' * 43,
      employee: false,
      slips: false,
    ))));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('2026-10'), findsOneWidget);
    expect(find.textContaining('5000.00'),
        findsNothing); // Grouped money is displayed.
    expect(find.textContaining('5,000.00'), findsOneWidget);
    names.complete(http.Response(
        jsonEncode({
          'employees': [
            {'recordId': 'e', 'fullName': 'Aisha'}
          ]
        }),
        200));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aisha'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets(
      'section renders one cached table while another table is still loading',
      (tester) async {
    final slow = Completer<http.Response>();
    final api = SaasApi(
        origin: 'https://api.test',
        cacheStore: MemoryCacheStore(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/Receipts')) return slow.future;
          return http.Response(
              jsonEncode({
                'records': [
                  {'recordId': 'i', 'currency': 'AED', 'total': 125}
                ]
              }),
              200);
        }));
    api.useVerifiedWorkspace('c' * 43, ownerId: 'owner');
    await api.records('c' * 43, 'Invoices');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SectionOverview(
      api: api,
      companyId: 'c' * 43,
      section: 'Invoices',
      tables: const ['Invoices', 'Receipts'],
      employee: false,
      active: true,
      compact: true,
      onSection: (_, __) {},
    ))));
    await tester.pump();
    await tester.pump();
    expect(find.text('AED 125.00'), findsOneWidget);
    slow.complete(http.Response(jsonEncode({'records': []}), 200));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
