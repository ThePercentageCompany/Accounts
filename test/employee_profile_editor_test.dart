import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/employees/presentation/employee_profile_editor.dart';

void main() {
  testWidgets('employee profile edit sends only permitted profile fields',
      (tester) async {
    const company = 'ccccccccccccccccccccccccccccccccccccccccccc';
    const id = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    var calls = 0;
    final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          calls++;
          expect(request.method, 'PATCH');
          expect(request.url.path,
              '/v1/employee/companies/$company/employees/$id');
          final values = jsonDecode(request.body) as Map;
          expect(values['fullName'], 'Updated employee');
          expect(values['expectedVersion'], 3);
          expect(values.containsKey('role'), isFalse);
          expect(values.containsKey('writableSections'), isFalse);
          expect(request.headers['Idempotency-Key'], isNotEmpty);
          return http.Response(
              jsonEncode({'employeeId': id, 'version': 4}), 200);
        }));
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => EmployeeProfileEditor(
                                api: api,
                                companyId: company,
                                record: const {
                                  'recordId': id,
                                  'recordVersion': 3,
                                  'fullName': 'Employee'
                                })),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Updated employee');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Edit employee'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });
}
