import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/saas/saas_api.dart';
import 'package:tpc_invoice/core/saas/shared_workspace.dart';

void main() {
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
