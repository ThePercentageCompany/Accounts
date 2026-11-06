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

  @override
  bool get workspaceRealtimeConnected => connected;

  @override
  Future<Map<String, dynamic>> notifications(String companyId,
          {bool employee = false, bool force = false}) =>
      cache.read(notificationsPath(companyId, employee: employee), () async {
        notificationRequests++;
        return {'notifications': <Map<String, dynamic>>[]};
      }, force: force);

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
      return {
        'records': [
          {
            'recordId': 'task',
            'title': title,
            'status': 'TODO',
            'priority': 'MEDIUM',
            'dueDate': '2026-11-06',
            'createdAt': 1,
            'recordVersion': 1,
          }
        ],
        'summary': <String, dynamic>{},
        'dateCounts': <String, dynamic>{},
        'total': 1,
        'nextOffset': null,
      };
    }, force: force);
  }
}

void main() {
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
    expect(api.requests, 1);
    expect(find.text('Initial task'), findsOneWidget);

    api.title = 'Updated task';
    api.cache.invalidate((path) => path.contains('/tasks'));
    api.updates.add(TaskRealtimeUpdate(
        companyId: 'c' * 43, connected: true, refresh: true));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(api.requests, 2);
    expect(find.text('Updated task'), findsOneWidget);

    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(api.requests, 2, reason: 'A healthy live connection must not poll.');
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
    expect(api.requests, 1);
    await tester.pump(const Duration(seconds: 59));
    await tester.pumpAndSettle();
    expect(api.requests, 2);
    await tester.pumpWidget(page(false));
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(api.requests, 2);
    await tester.pumpWidget(const SizedBox());
    await api.updates.close();
    api.cache.dispose();
  });
}
