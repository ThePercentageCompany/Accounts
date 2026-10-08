import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/notifications/presentation/notification_center.dart';

void main() {
  testWidgets(
      'notification history connects read endpoint and opens assigned task',
      (tester) async {
    final company = 'c' * 43, task = 't' * 43, id = 'n' * 43;
    final requests = <String>[];
    var read = false;
    String? opened;
    final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.url.path.endsWith('/read')) {
            expect(jsonDecode(request.body), {'id': id, 'read': true});
            read = true;
            return http.Response(jsonEncode({'saved': true}), 200);
          }
          return http.Response(
              jsonEncode({
                'notifications': [
                  {
                    'id': id,
                    'companyId': company,
                    'taskId': task,
                    'title': 'Assigned task',
                    'body': 'Prepare report',
                    'type': 'task-assigned',
                    'createdAt': 1,
                    'readAt': read ? 2 : null
                  }
                ],
                'publicKey': null,
                'pushAvailable': false
              }),
              200);
        }));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NotificationCenter(
                api: api,
                companyId: company,
                employee: true,
                onTask: (value) => opened = value))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Assigned task'), findsOneWidget);
    await tester.tap(find.text('Assigned task'));
    await tester.pumpAndSettle();
    expect(opened, task);
    expect(read, true);
    expect(requests,
        contains('POST /v1/employee/companies/$company/notifications/read'));
    expect(requests,
        contains('GET /v1/employee/companies/$company/notifications'));
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
