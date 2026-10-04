import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/workspace/presentation/shared_workspace.dart';

void main() {
  testWidgets('compact status menu supports multiple filters and reset', (
    tester,
  ) async {
    final api = SaasApi(
      origin: 'https://api.test',
      client: MockClient(
        (_) async => http.Response(
          '{"records":[{"recordId":"a","name":"Active customer","status":"ACTIVE"},{"recordId":"b","name":"Pending customer","status":"PENDING"},{"recordId":"c","name":"Inactive customer","status":"INACTIVE"}]}',
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SharedWorkspace(
          api: api,
          companyId: 'c' * 43,
          title: 'Workspace',
          onBack: () {},
          employee: const {
            'allowedSections': ['Customers'],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> select(String status) async {
      await tester.tap(find.byTooltip('Filter statuses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(status).last);
      await tester.pumpAndSettle();
    }

    await select('active');
    expect(find.text('Active customer'), findsOneWidget);
    expect(find.text('Pending customer'), findsNothing);
    await select('pending');
    expect(find.text('Active customer'), findsOneWidget);
    expect(find.text('Pending customer'), findsOneWidget);
    expect(find.text('Inactive customer'), findsNothing);
    await select('All statuses');
    expect(find.text('Inactive customer'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
  testWidgets(
    'saved draft displays and expands with the complete document navigation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient(
          (request) async => http.Response(
            request.url.path.endsWith('/Invoices')
                ? '{"records":[{"recordId":"${'i' * 43}","number":"","status":"DRAFT","issueDate":"2026-10-04","currency":"AED","total":"105.00","recordVersion":1}]}'
                : '{"records":[]}',
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SharedWorkspace(
            api: api,
            companyId: 'c' * 43,
            title: 'Workspace',
            onBack: () {},
            preferences: prefs,
            employee: {
              'employeeId': 'e' * 43,
              'allowedSections': ['Invoices'],
              'writableSections': ['Invoices'],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Draft invoice · 2026-10-04'), findsOneWidget);
      await tester.tap(find.text('Draft invoice · 2026-10-04'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(workspaceTables['Invoices'], isNot(contains('InvoiceItems')));
      expect(workspaceTables['Quotations'], isNot(contains('QuotationItems')));
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
  testWidgets(
    'section navigation preserves filter and scroll without refetching',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final requests = <String>[];
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          requests.add(r.url.path);
          return http.Response(
            r.url.path.endsWith('Customers')
                ? '{"records":[${List.generate(40, (i) => '{"recordId":"customer-$i","name":"Customer $i"}').join(',')}]}'
                : '{"records":[]}',
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
            preferences: prefs,
            employee: {
              'employeeId': 'e' * 43,
              'allowedSections': ['Customers', 'Invoices'],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customers').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Customer');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      final before = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position
          .pixels;
      expect(before, greaterThan(0));
      await tester.tap(find.text('Invoices').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customers').last);
      await tester.pumpAndSettle();
      expect(requests.where((p) => p.endsWith('/Customers')).length, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Customer',
      );
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position
            .pixels,
        before,
      );
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
  for (final canEdit in [false, true]) {
    testWidgets('employee customer editor follows admin edit grant: $canEdit', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          expect(r.url.path, '/v1/employee/records/Customers');
          return http.Response('{"records":[]}', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SharedWorkspace(
            api: api,
            companyId: 'c' * 43,
            title: 'Workspace',
            onBack: () {},
            preferences: prefs,
            employee: {
              'employeeId': 'e' * 43,
              'allowedSections': ['Customers'],
              'writableSections': canEdit ? ['Customers'] : [],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Add customer'),
        canEdit ? findsOneWidget : findsNothing,
      );
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
