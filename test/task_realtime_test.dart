import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/tasks/presentation/task_workspace.dart';
import 'package:tpc_invoice/features/reports/presentation/dashboard_tasks.dart';
import 'package:tpc_invoice/core/offline/offline_store.dart';

class WidgetOfflineStore implements OfflineStore {
  final partitions = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>> read(String scope) async =>
      copyJson(partitions[scope] ?? emptyPartition());
  @override
  Future<Map<String, dynamic>> change(
      String scope, void Function(Map<String, dynamic>) edit) async {
    final data = await read(scope);
    edit(data);
    partitions[scope] = copyJson(data);
    return data;
  }
}

class LiveTestApi extends SaasApi {
  LiveTestApi(http.Client client, {OfflineStore? store})
      : super(
            origin: 'https://api.test',
            client: client,
            offlineStore: store,
            offlineAutomatic: false);
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
  testWidgets('a locally saved task reaches an open dashboard before sync',
      (tester) async {
    var reads = 0;
    final api = LiveTestApi(MockClient((request) async {
      expect(request.method, 'GET');
      reads++;
      final todo = request.url.queryParameters['status'] == 'TODO';
      return http.Response(
          jsonEncode({
            'records': todo ? [task('Original task')] : [],
            'total': todo ? 1 : 0,
            'summary': {}
          }),
          200);
    }), store: WidgetOfflineStore());
    final owner = 'o' * 43;
    api.useVerifiedWorkspace(company, ownerId: owner);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DashboardTasks(
      api: api,
      companyId: company,
      employee: false,
      onTask: (_) {},
    ))));
    await tester.pumpAndSettle();
    expect(reads, 4);
    await api.outbox(owner, company).enqueue(
        'Tasks',
        'create',
        {
          'title': 'Saved locally',
          'status': 'TODO',
          'priority': 'MEDIUM',
          'dueDate': taskDate(taskToday()),
          'employeeId': employee,
        },
        expectedVersion: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Saved locally'), findsOneWidget);
    expect(reads, 4);
    expect(api.outbox(owner, company).pending, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });
  testWidgets('dashboard tasks refresh from Realtime and coalesce events',
      (tester) async {
    var title = 'Original task', reads = 0;
    final api = LiveTestApi(MockClient((request) async {
      reads++;
      final todo = request.url.queryParameters['status'] == 'TODO';
      return http.Response(
          jsonEncode({
            'records': todo ? [task(title)] : [],
            'total': todo ? 1 : 0,
            'summary': {},
          }),
          200);
    }));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DashboardTasks(
      api: api,
      companyId: company,
      employee: false,
      onTask: (_) {},
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Original task'), findsOneWidget);
    expect(reads, 4);
    api.events
        .add(const TaskRealtimeUpdate(companyId: 'other', connected: true));
    await tester.pump(const Duration(milliseconds: 250));
    expect(reads, 4);
    title = 'Updated remotely';
    for (var i = 0; i < 2; i++) {
      api.events
          .add(const TaskRealtimeUpdate(companyId: company, connected: true));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Updated remotely'), findsOneWidget);
    expect(reads, 8);
    await tester.pumpWidget(const SizedBox.shrink());
    api.close();
  });
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
    api.events.add(const TaskRealtimeUpdate(
        companyId: company, connected: true, taskId: 'another-task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Remote comment'), findsNothing);
    api.events
        .add(const TaskRealtimeUpdate(companyId: company, connected: true,
            taskId: taskId));
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
