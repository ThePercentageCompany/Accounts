import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/saas/saas_api.dart';
import 'package:tpc_invoice/core/saas/shared_workspace.dart';

void main() {
  for (final canEdit in [false, true]) {
    testWidgets('employee customer editor follows admin edit grant: $canEdit',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = SaasApi(
          origin: 'https://api.test',
          client: MockClient((r) async {
            expect(r.url.path, '/v1/employee/records/Customers');
            return http.Response('{"records":[]}', 200);
          }));
      await tester.pumpWidget(MaterialApp(
          home: SharedWorkspace(
        api: api,
        companyId: 'c' * 43,
        title: 'Workspace',
        onBack: () {},
        preferences: prefs,
        employee: {
          'employeeId': 'e' * 43,
          'allowedSections': ['Customers'],
          'writableSections': canEdit ? ['Customers'] : []
        },
      )));
      await tester.pumpAndSettle();
      expect(
          find.text('Add customer'), canEdit ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }

  testWidgets(
    'employee workspace reads only granted sections through employee endpoint',
    (tester) async {
      final paths = <String>[];
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          paths.add(r.url.path);
          return http.Response(
            '{"records":[{"month":"2026-09","netSalary":1200}]}',
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SharedWorkspace(
            api: api,
            companyId: 'c' * 43,
            title: 'Workspace',
            onBack: () {},
            employee: const {
              'allowedSections': ['Payroll'],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(paths, ['/v1/employee/records/Payroll']);
      expect(find.text('Employees'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('2026-09'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
