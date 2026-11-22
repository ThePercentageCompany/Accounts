import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';
import 'package:tpc_invoice/core/cache/read_cache.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/tasks/presentation/task_workspace.dart';
import 'package:tpc_invoice/features/reports/presentation/dashboard_tasks.dart';
import 'package:tpc_invoice/features/notifications/presentation/notification_center.dart';

class _TaskApi extends SaasApi {
  _TaskApi() : super(offlineAutomatic: false) {
    cache.configure(scope: 'tasks-test', account: 'owner');
  }

  final _cache = ReadCache(store: MemoryCacheStore(), automatic: false);
  @override
  ReadCache get cache => _cache;
  final updates = StreamController<TaskRealtimeUpdate>.broadcast();
  int requests = 0;
  String title = 'Initial task';
  bool connected = true;
  int notificationRequests = 0;
  List<Map<String, dynamic>> notices = [];
  int? unreadNoticeCount;
  Future<void>? taskResponseGate;
  List<Map<String, dynamic>>? taskRecords;
  final taskQueries = <Map<String, String>>[];

  @override
  bool get workspaceRealtimeConnected => connected;

  @override
  Future<Map<String, dynamic>> notifications(String companyId,
          {bool employee = false, bool force = false}) =>
      cache.read(notificationsPath(companyId, employee: employee), () async {
        notificationRequests++;
        return {
          'notifications': notices,
          if (unreadNoticeCount != null) 'unread': unreadNoticeCount,
        };
      }, force: force);

  @override
  Future<Map<String, dynamic>> notificationRead(String companyId, String id,
      {bool employee = false, bool read = true}) async {
    notices = [
      for (final notice in notices)
        if (id == 'all' || id == notice['id'])
          {...notice, 'readAt': read ? 1 : null}
        else
          notice,
    ];
    unreadNoticeCount = notices.where((n) => n['readAt'] == null).length;
    return {'updated': true};
  }

  @override
  bool get taskRealtimeConnected => connected;
  @override
  Stream<TaskRealtimeUpdate> get taskUpdates => updates.stream;

  @override
  Future<Map<String, dynamic>> taskAssignees(String companyId,
          {bool employee = false, String search = '', int offset = 0}) async =>
      {'employees': [], 'nextOffset': null};

  @override
  Future<Map<String, dynamic>> tasks(String companyId,
      {bool employee = false,
      bool force = false,
      Map<String, String> filters = const {}}) {
    final path =
        '${tasksPath(companyId, employee: employee)}?${Uri(queryParameters: filters).query}';
    return cache.read(path, () async {
      requests++;
      await taskResponseGate;
      taskQueries.add(Map.of(filters));
      final matching = (taskRecords ??
              [
                {
                  'recordId': 'task',
                  'title': title,
                  'status': 'TODO',
                  'priority': 'MEDIUM',
                  'dueDate': '2026-11-06',
                  'createdAt': 1,
                  'recordVersion': 1,
                }
              ])
          .where((row) =>
              filters['status'] == null || row['status'] == filters['status'])
          .toList();
      final offset = int.tryParse(filters['offset'] ?? '') ?? 0;
      final limit = int.tryParse(filters['limit'] ?? '') ?? 40;
      return {
        'records': matching.skip(offset).take(limit).toList(),
        'summary': <String, dynamic>{},
        'dateCounts': <String, dynamic>{},
        'total': matching.length,
        'nextOffset': offset + limit < matching.length ? offset + limit : null,
      };
    }, force: force);
  }
}

void main() {
  testWidgets('payroll alerts use the total badge and stay in the inbox on tap',
      (tester) async {
    final api = _TaskApi()
      ..unreadNoticeCount = 45
      ..notices = [
        {
          'id': 'n' * 43,
          'taskId': null,
          'type': 'payroll-paid',
          'title': 'Salary payment recorded',
          'body': 'Your salary payment was recorded.',
          'createdAt': 1764000000000,
          'readAt': null,
        }
      ];
    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      appBar: AppBar(actions: [
        NotificationCenter(
          api: api,
          companyId: 'c' * 43,
          employee: true,
          onTask: opened.add,
        )
      ]),
    )));
    await tester.pumpAndSettle();
    expect(find.text('45'), findsOneWidget);
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary payment recorded'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.text('Salary payment recorded'), findsOneWidget);
    expect(find.byTooltip('Mark unread'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await api.updates.close();
    api.cache.dispose();
  });

  testWidgets('older pending tasks appear before loading more completed tasks',
      (tester) async {
    Map<String, dynamic> task(int number, String status) => {
          'recordId': 'task-$number',
          'title': 'Task $number',
          'status': status,
          'priority': 'MEDIUM',
          'dueDate': '2026-11-06',
          'createdAt': number,
          'recordVersion': 1,
        };
    final api = _TaskApi()
      ..taskRecords = [
        for (var number = 90; number > 1; number--) task(number, 'COMPLETED'),
        task(1, 'TODO'),
      ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: TaskWorkspace(api: api, companyId: 'c' * 43),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Task 1'), findsOneWidget);
    expect(api.taskQueries.map((query) => query['status']), taskStatuses);
    expect(api.taskQueries.every((query) => query['limit'] == '10'), isTrue);

    final loadMore = find.text('Load more (11 of 90)');
    await tester.scrollUntilVisible(loadMore, 400,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(loadMore);
    await tester.pumpAndSettle();
    expect(api.taskQueries.where((query) => query.containsKey('offset')), [
      containsPair('status', 'COMPLETED'),
    ]);
    expect(api.taskQueries.last['offset'], '10');
    await tester.pumpWidget(const SizedBox());
    await api.updates.close();
    api.cache.dispose();
  });

  testWidgets('initial task load shows status and a failed load can be retried',
      (tester) async {
    final api = _TaskApi();
    final response = Completer<void>();
    api.taskResponseGate = response.future;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: TaskWorkspace(api: api, companyId: 'c' * 43),
    )));
    expect(find.text('Loading tasks…'), findsOneWidget);
    await tester.pump();
    expect(find.text('Loading tasks…'), findsOneWidget);
    expect(find.text('No tasks'), findsNothing);

    response.completeError(StateError('Task request failed'));
    await tester.pumpAndSettle();
    expect(find.text('Loading tasks…'), findsNothing);
    expect(find.text('No tasks'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    api.taskResponseGate = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Initial task'), findsOneWidget);
    expect(find.text('Loading tasks…'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await api.updates.close();
    api.cache.dispose();
  });

  testWidgets('live notifications avoid polling and refresh from invalidation',
      (tester) async {
    final api = _TaskApi();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      appBar: AppBar(actions: [
        NotificationCenter(
          api: api,
          companyId: 'c' * 43,
          employee: false,
          onTask: (_) {},
        )
      ]),
    )));
    await tester.pumpAndSettle();
    expect(api.notificationRequests, 1);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(api.notificationRequests, 1);
    api.cache.invalidate((path) => path.endsWith('/notifications'));
    await tester.pumpAndSettle();
    expect(api.notificationRequests, 2);
    api.connected = false;
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(api.notificationRequests, 3);
    await tester.pumpWidget(const SizedBox());
    await api.updates.close();
    api.cache.dispose();
  });

  testWidgets('dashboard realtime refreshes reuse fresh task pages',
      (tester) async {
    final api = _TaskApi();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: SingleChildScrollView(
          child: DashboardTasks(
        api: api,
        companyId: 'c' * 43,
        employee: false,
        onTask: (_) {},
      )),
    )));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(api.requests, 4);
    api.cache.invalidate((path) => path.contains('/tasks'));
    api.updates.add(TaskRealtimeUpdate(
        companyId: 'c' * 43, connected: true, refresh: true));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(api.requests, 8);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(api.requests, 8);
    await tester.pumpWidget(const SizedBox());
    await api.updates.close();
    api.cache.dispose();
  });

  testWidgets('task cache updates render without a second forced request',
      (tester) async {
    final api = _TaskApi();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: TaskWorkspace(api: api, companyId: 'c' * 43),
    )));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(api.requests, 4);
    expect(find.text('Initial task'), findsOneWidget);

    api.title = 'Updated task';
    api.cache.invalidate((path) => path.contains('/tasks'));
    api.updates.add(TaskRealtimeUpdate(
        companyId: 'c' * 43, connected: true, refresh: true));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(api.requests, 8);
    expect(find.text('Updated task'), findsOneWidget);

    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(api.requests, 8, reason: 'A healthy live connection must not poll.');
    await tester.pumpWidget(const SizedBox());
    await api.updates.close();
    api.cache.dispose();
  });

  testWidgets('disconnected tasks poll once a minute and stop when inactive',
      (tester) async {
    final api = _TaskApi()..connected = false;
    Widget page(bool active) => MaterialApp(
            home: Scaffold(
          body: TaskWorkspace(api: api, companyId: 'c' * 43, active: active),
        ));
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(api.requests, 4);
    await tester.pump(const Duration(seconds: 59));
    await tester.pumpAndSettle();
    expect(api.requests, 8);
    await tester.pumpWidget(page(false));
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(api.requests, 8);
    await tester.pumpWidget(const SizedBox());
    await api.updates.close();
    api.cache.dispose();
  });
}
