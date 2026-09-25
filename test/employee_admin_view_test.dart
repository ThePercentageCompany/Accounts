import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/saas/saas_api.dart';
import 'package:tpc_invoice/core/saas/employee_admin_controller.dart';
import 'package:tpc_invoice/core/saas/employee_admin_view.dart';
import 'package:tpc_invoice/core/widgets/qr_code.dart';

void main() {
  testWidgets('owner issues a QR with separate one-time code', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final company = 'c' * 43, employee = 'e' * 43;
    final link = 'https://app.test/#employee-invite=${'i' * 43}';
    final api = SaasApi(
      origin: 'https://api.test',
      client: MockClient((r) async {
        if (r.method == 'GET')
          return http.Response(
            jsonEncode({
              'employees': [
                {
                  'recordId': employee,
                  'recordVersion': 1,
                  'fullName': 'Alex',
                  'role': 'Staff',
                  'employmentStatus': 'ACTIVE',
                  'email': '',
                  'allowedSections': ['Payroll'],
                },
              ],
            }),
            200,
          );
        expect(
          r.url.path,
          '/v1/companies/$company/employees/$employee/access/issue',
        );
        expect(r.headers['Idempotency-Key'], isNotEmpty);
        return http.Response(
          jsonEncode({
            'qrPayload': link,
            'inviteLink': link,
            'privateCode': 'one-time-test-code',
          }),
          200,
        );
      }),
    );
    final c = EmployeeAdminController(api, prefs, 'owner', company);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EmployeeAdminView(controller: c)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue QR & code'));
    await tester.pumpAndSettle();
    expect(find.text('one-time-test-code'), findsOneWidget);
    expect(tester.widget<QrImageView>(find.byType(QrImageView)).data, link);
    await tester.tap(find.text('I saved the code'));
    await tester.pumpAndSettle();
    expect(find.text('one-time-test-code'), findsNothing);
    expect(prefs.getKeys(), isEmpty);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    api.close();
  });
}
