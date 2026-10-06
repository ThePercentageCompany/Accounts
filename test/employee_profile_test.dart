import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/employees/presentation/cubit/employee_admin_controller.dart';
import 'package:tpc_invoice/features/employees/presentation/employee_admin_view.dart';
import 'support/form_input.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('employee profile saves and reopens with salary at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final company = 'c' * 43;
      Map<String, dynamic>? saved;
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'employees': [
                  if (saved != null)
                    {...saved!, 'recordId': 'e' * 43, 'recordVersion': 1},
                ],
              }),
              200,
            );
          }
          expect(request.url.path, '/v1/companies/$company/employees');
          expect(request.headers['Idempotency-Key'], isNotEmpty);
          saved = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          return http.Response(
            jsonEncode({'employeeId': 'e' * 43, 'version': 1}),
            201,
          );
        }),
      );
      final controller = EmployeeAdminController(api, prefs, 'owner', company);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: EmployeeAdminView(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add employee'));
      await tester.pumpAndSettle();
      Finder field(String label) => find.ancestor(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == label,
        ),
        matching: find.byType(TextFormField),
      );
      for (final entry in {
        'Full name': 'Alex',
        'Phone (optional)': '+971500000000',
        'Employee code (optional)': 'EMP-001',
        'Department (optional)': 'Accounts',
        'Job title (optional)': 'Accountant',
        'Joining date (optional)': '2026-09-01',
        'Basic salary': '5000.25',
        'Monthly allowances': '500',
        'Bank name (optional)': 'Bank',
        'IBAN (optional)': 'AE123',
      }.entries) {
        await tester.ensureVisible(field(entry.key));
        await fillFormField(tester, field(entry.key), entry.value);
      }
      await tester.tap(find.text('Save employee'));
      await tester.pumpAndSettle();
      expect(saved?['basicSalary'], 5000.25);
      expect(saved?['allowances'], 500);
      expect(saved?['joinDate'], '2026-09-01');
      expect(saved?['department'], 'Accounts');
      expect(saved?['iban'], 'AE123');
      expect(prefs.getKeys(), isEmpty);
      await tester.ensureVisible(find.text('Edit employee'));
      await tester.tap(find.text('Edit employee'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field('Basic salary')).controller!.text,
        '5000.25',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      api.close();
    });
  }
}
