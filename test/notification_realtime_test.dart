import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/notifications/presentation/notification_center.dart';

void main() {
  testWidgets(
      'notification invalidation refreshes new alerts and read state immediately',
      (tester) async {
    const company = 'ccccccccccccccccccccccccccccccccccccccccccc';
    const employee = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    var count = 1, read = false, calls = 0;
    final paths = <String>[];
    final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          calls++;
          paths.add(request.url.path);
          return http.Response(
              jsonEncode({
                'notifications': [
                  for (var i = 0; i < count; i++)
                    {
                      'id': 'alert-$i',
                      'title': 'Task assigned',
                      'readAt': read ? 123 : null
                    }
                ]
              }),
              200);
        }));
    api.useVerifiedWorkspace(company, employee: {
      'employeeId': employee,
      'role': 'Staff',
      'allowedSections': ['Tasks'],
      'writableSections': []
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NotificationCenter(
      api: api,
      companyId: company,
      employee: true,
      onTask: (_) {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    final firstCalls = calls;
    count = 2;
    api.cache.invalidate((path) => path.endsWith('/notifications'),
        broadcast: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(firstCalls));
    expect(find.text('2'), findsOneWidget);
    read = true;
    api.cache.invalidate((path) => path.endsWith('/notifications'),
        broadcast: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    expect(tester.takeException(), isNull);
    expect(
        paths.every(
            (path) => path == '/v1/employee/companies/$company/notifications'),
        isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });
}
