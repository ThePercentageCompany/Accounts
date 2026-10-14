import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/tasks/presentation/task_workspace.dart';

class LiveTestApi extends SaasApi {
  LiveTestApi(http.Client client)
      : super(origin: 'https://api.test', client: client);
  final events = StreamController<TaskRealtimeUpdate>.broadcast();
  @override
  Stream<TaskRealtimeUpdate> get taskUpdates => events.stream;
  @override
  bool get taskRealtimeConnected => true;
  @override
  void close() {
    events.close();
    super.close();
  }
}

const company = 'ccccccccccccccccccccccccccccccccccccccccccc';
const taskId = 'ttttttttttttttttttttttttttttttttttttttttttt';
const employee = 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
Map<String, dynamic> task(String title) => {
      'recordId': taskId,
      'companyId': company,
      'recordVersion': 1,
      'title': title,
      'description': 'Task brief',
      'employeeId': employee,
      'assigneeName': 'Employee',
      'priority': 'MEDIUM',
      'status': 'TODO',
      'dueDate': taskDate(taskToday()),
      'startDate': '',
      'startTime': '',
      'endTime': '',
      'project': '',
      'tags': '',
      'reminder': 'NONE',
      'createdAt': 0,
      'updatedAt': 0
    };

void main() {
  for (final calendar in [false, true]) {
    testWidgets(
        'Realtime refreshes ${calendar ? 'calendar' : 'task list'}, coalesces bursts and ignores another entity',
        (tester) async {
      var title = 'Original task', reads = 0;
      final api = LiveTestApi(MockClient((_) async {
        reads++;
        return http.Response(
            jsonEncode({
              'records': [task(title)],
              'total': 1,
              'summary': {},
              'dateCounts': {},
              'nextOffset': null
            }),
            200);
      }));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: TaskWorkspace(
                  calendar: calendar,
                  api: api,
                  companyId: company,
                  employee: {
            'employeeId': employee,
            'writableSections': []
          }))));
      await tester.pumpAndSettle();
      expect(find.text('Original task'), findsWidgets);
      expect(reads, 1);
      api.events
          .add(const TaskRealtimeUpdate(companyId: 'other', connected: true));
      await tester.pump(const Duration(milliseconds: 250));
      expect(reads, 1);
      title = 'Updated remotely';
      api.events
          .add(const TaskRealtimeUpdate(companyId: company, connected: true));
      api.events
          .add(const TaskRealtimeUpdate(companyId: company, connected: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Updated remotely'), findsWidgets);
      expect(reads, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    });
  }
  testWidgets('open task details receive comments without losing typed input',
      (tester) async {
    var title = 'Original task', comment = '';
    final api = LiveTestApi(MockClient((_) async => http.Response(
        jsonEncode({
          'task': task(title),
          'comments': comment.isEmpty
              ? []
              : [
                  {
                    'recordId': 'm' * 43,
                    'taskId': taskId,
                    'body': comment,
                    'authorName': 'Colleague',
                    'createdAt': 0
                  }
                ],
          'activity': []
        }),
        200)));
    await tester.pumpWidget(MaterialApp(
        home: TaskDetails(
            api: api,
            companyId: company,
            employee: true,
            employeeId: employee,
            manage: false,
            task: task(title),
            onWrite: (table, row, values, {operationId}) async {},
            onEdit: (_) async {})));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Unsaved reply');
    title = 'Updated remotely';
    comment = 'Remote comment';
    api.events
        .add(const TaskRealtimeUpdate(companyId: company, connected: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Updated remotely'), findsWidgets);
    expect(find.text('Remote comment'), findsOneWidget);
    expect(find.text('Unsaved reply'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });
}
