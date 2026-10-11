import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/reports/presentation/employee_dashboard.dart';

void main() {
  for (final canEdit in [false, true]) {
    testWidgets('dashboard task scope follows edit access: $canEdit',
        (tester) async {
      final requests = <Uri>[];
      final api = SaasApi(
          origin: 'https://accounts.thepercentagecompany.com',
          client: MockClient((request) async {
            requests.add(request.url);
            return http.Response(
                jsonEncode({'records': [], 'total': 0, 'summary': {}}), 200,
                headers: {'content-type': 'application/json'});
          }));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: EmployeeDashboard(
        api: api,
        companyId: 'c' * 43,
        employee: {
          'employeeId': 'e' * 43,
          'allowedSections': ['Tasks'],
          'writableSections': canEdit ? ['Tasks'] : []
        },
        onTask: (_) {},
        onSection: (_, __) {},
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Tasks overview'), findsOneWidget);
      expect(requests, hasLength(4));
      for (final request in requests) {
        expect(
            request.queryParameters['employeeId'], canEdit ? isNull : 'e' * 43);
      }
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
  testWidgets(
      'employee dashboard loads only enabled sections and separates currencies',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final paths = <String>[];
    final api = SaasApi(
        origin: 'https://accounts.thepercentagecompany.com',
        client: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
              jsonEncode({
                'records': [
                  {
                    'recordId': 'one',
                    'currency': 'INR',
                    'total': 100,
                    'paymentStatus': 'PAID'
                  },
                  {
                    'recordId': 'two',
                    'currency': 'AED',
                    'total': 10,
                    'paymentStatus': 'UNPAID'
                  },
                ]
              }),
              200,
              headers: {'content-type': 'application/json'});
        }));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EmployeeDashboard(
      api: api,
      companyId: 'c' * 43,
      employee: {
        'employeeId': 'e' * 43,
        'allowedSections': ['Income & Expenses']
      },
      onTask: (_) {},
      onSection: (_, __) {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Income & Expenses'), findsOneWidget);
    expect(find.text('INR: 100.00'), findsWidgets);
    expect(find.text('AED: 10.00'), findsWidgets);
    expect(find.text('Tasks overview'), findsNothing);
    expect(
        paths.every(
            (path) => path.contains('Income') || path.contains('Expenses')),
        isTrue);
    expect(paths.length, 2);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
