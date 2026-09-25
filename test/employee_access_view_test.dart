import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/saas/employee_access_view.dart';
import 'package:tpc_invoice/core/saas/saas_api.dart';

void main() {
  testWidgets('shared invite requires code and posts only to trusted API', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final invite = 'i' * 43;
    var calls = 0;
    final api = SaasApi(
      origin: 'https://api.example.com',
      client: MockClient((request) async {
        calls++;
        expect(
          request.url.toString(),
          'https://api.example.com/v1/employee/login',
        );
        expect(jsonDecode(request.body), {
          'inviteId': invite,
          'privateCode': 'test-private-code',
        });
        return http.Response(
          jsonEncode({
            'employee': {
              'employeeId': 'e' * 43,
              'companyId': 'c' * 43,
              'name': 'Test Employee',
              'role': 'Staff',
              'allowedSections': ['Payroll'],
            },
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeAccessView(
          api: api,
          appUri: Uri.parse('https://app.example.com/#employee-invite=$invite'),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(calls, 0);
    expect(
      find.text('Enter the private login code from your manager.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).last, 'test-private-code');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Welcome, Test Employee'), findsOneWidget);
    expect(find.text('Payroll'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets('foreign invite cannot send the private code', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final api = SaasApi(
      origin: 'https://api.example.com',
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeAccessView(
          api: api,
          appUri: Uri.parse('https://app.example.com/'),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'https://other.example/#employee-invite=${'i' * 43}',
    );
    await tester.enterText(find.byType(TextField).last, 'test-private-code');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.textContaining('Use a new employee link'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
