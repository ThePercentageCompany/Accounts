import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/reports/presentation/dashboard_tasks.dart';

void main() {
  testWidgets('dashboard shows full status totals and opens earliest open task',
      (tester) async {
    final company = 'c' * 43;
    String? opened;
    final requests = <String>[];
    final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          requests.add(request.url.path);
          final status = request.url.queryParameters['status'];
          return http.Response(
              jsonEncode({
                'total': status == 'COMPLETED' ? 50 : 10,
                'summary': {'today': 2, 'overdue': 3},
                'records': [
                  {
                    'recordId': status,
                    'title': '$status task',
                    'status': status,
                    'dueDate':
                        status == 'IN_REVIEW' ? '2026-01-01' : '2026-02-01',
                    'endTime': '12:00',
                    'priority': 'HIGH',
                    'assigneeName': 'Alex',
                    'project': 'Site A',
                  }
                ],
              }),
              200);
        }));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: DashboardTasks(
          api: api,
          companyId: company,
          employee: true,
          onTask: (id) => opened = id),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Total: 80'), findsOneWidget);
    expect(find.text('Completed: 50'), findsOneWidget);
    expect(find.text('Due today: 2'), findsOneWidget);
    expect(find.text('Overdue: 3'), findsOneWidget);
    expect(find.text('COMPLETED task'), findsNothing);
    expect(
        requests
            .every((path) => path == '/v1/employee/companies/$company/tasks'),
        true);
    expect(tester.getTopLeft(find.text('IN_REVIEW task')).dy,
        lessThan(tester.getTopLeft(find.text('TODO task')).dy));
    await tester.tap(find.text('IN_REVIEW task'));
    expect(opened, 'IN_REVIEW');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
