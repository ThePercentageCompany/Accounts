import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/tasks/presentation/task_workspace.dart';

const widths = [
  320.0,
  360.0,
  375.0,
  390.0,
  412.0,
  430.0,
  768.0,
  820.0,
  1024.0,
  1280.0,
  1440.0,
  1920.0
];
Map<String, dynamic> task() => {
      'recordId': 't' * 43,
      'employeeId': 'e' * 43,
      'title':
          'Prepare a very long October accounting report for all departments and projects',
      'assigneeName': 'Ahmed with a very long employee name',
      'description': 'Description ' * 60,
      'project': 'Accounting project ' * 8,
      'tags': 'monthly,accounting,review',
      'status': 'IN_PROGRESS',
      'priority': 'HIGH',
      'dueDate': taskDate(taskToday()),
      'startDate': taskDate(taskToday()),
      'endTime': '16:00',
      'recordVersion': 1,
      'reminder': 'NONE'
    };
SaasApi api() => SaasApi(
    origin: 'https://api.test',
    client: MockClient((request) async {
      final row = task();
      final data = request.url.path.endsWith('/assignees')
          ? {
              'employees': [
                {'recordId': 'e' * 43, 'fullName': row['assigneeName']}
              ]
            }
          : request.url.path.endsWith('/${'t' * 43}')
              ? {
                  'task': row,
                  'comments': [
                    {
                      'body': 'Comment ' * 100,
                      'createdAt': 1800000000000,
                      'createdBy': 'e' * 43
                    }
                  ],
                  'activity': [
                    {'summary': 'Task created', 'createdAt': 1800000000000}
                  ]
                }
              : {
                  'records': [row],
                  'total': 1,
                  'nextOffset': null,
                  'summary': {
                    'todo': 0,
                    'inProgress': 1,
                    'today': 1,
                    'overdue': 0
                  }
                };
      return http.Response(jsonEncode(data), 200,
          headers: {'content-type': 'application/json'});
    }));
void main() {
  for (final mobile in [false, true]) {
    for (final rejected in [false, true]) {
      testWidgets(
          'board drag ${mobile ? 'mobile' : 'desktop'} '
          '${rejected ? 'restores rejected status' : 'saves status'}',
          (tester) async {
        tester.view.physicalSize = Size(mobile ? 390 : 1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final row = task()..['title'] = 'Drag this task';
        Map? operation;
        final service = SaasApi(
          origin: 'https://api.test',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/sync')) {
              operation = (jsonDecode(request.body)['operations'] as List)
                  .single as Map;
              if (!rejected) {
                row['status'] = operation!['values']['status'];
                row['recordVersion'] = 2;
              }
              return http.Response(
                  jsonEncode({
                    'results': [
                      {
                        'status': rejected ? 'REJECTED' : 'APPLIED',
                        if (rejected)
                          'error': {'code': 'CONFLICT', 'message': 'Try again'}
                      }
                    ]
                  }),
                  200);
            }
            return http.Response(
                jsonEncode(request.url.path.endsWith('/assignees')
                    ? {'employees': []}
                    : {
                        'records': [row],
                        'total': 1,
                        'summary': {}
                      }),
                200);
          }),
        );
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
          body: TaskWorkspace(api: service, companyId: 'c' * 43),
        )));
        await tester.pumpAndSettle();
        if (mobile) {
          await tester.tap(find.text('Board'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ChoiceChip, 'In Progress'));
          await tester.pumpAndSettle();
        }
        final source = tester.getCenter(find.text('Drag this task'));
        final target = tester.getCenter(find.byKey(ValueKey(
          mobile ? 'task-status-COMPLETED' : 'task-column-COMPLETED',
        )));
        final gesture = await tester.startGesture(source);
        if (mobile) await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveTo(target);
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(operation?['values'], {'status': 'COMPLETED'});
        expect(operation?['expectedVersion'], 1);
        if (mobile && rejected) {
          await tester.tap(find.widgetWithText(ChoiceChip, 'In Progress'));
          await tester.pumpAndSettle();
        }
        final column = find.byKey(ValueKey(
          'task-column-${rejected ? 'IN_PROGRESS' : 'COMPLETED'}',
        ));
        expect(
            find.descendant(of: column, matching: find.text('Drag this task')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        service.close();
      });
    }
  }
  for (final width in widths) {
    for (final calendar in [false, true]) {
      testWidgets(
          'tasks ${calendar ? 'calendar' : 'board/list'} adapts at $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = api();
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: TaskWorkspace(
                    api: service, companyId: 'c' * 43, calendar: calendar))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (width < 768 && !calendar) {
          expect(find.byType(TaskCard), findsOneWidget);
          expect(find.byType(DragTarget<Map<String, dynamic>>), findsNothing);
        }
        if (calendar) {
          await tester.ensureVisible(find.text('Month').last);
          await tester.tap(find.text('Month').last);
          await tester.pumpAndSettle();
          expect(find.byType(GridView), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Week').last);
          await tester.tap(find.text('Week').last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        service.close();
      });
    }
    testWidgets('create form and details handle long content at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = api();
      await tester.pumpWidget(MaterialApp(
          home: TaskEditor(
              api: service,
              companyId: 'c' * 43,
              employee: false,
              task: task(),
              assignees: [
                {'recordId': 'e' * 43, 'fullName': 'Long employee name ' * 8}
              ],
              onSave: (_, _) async {})));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpWidget(MaterialApp(
          home: TaskDetails(
              api: service,
              companyId: 'c' * 43,
              employee: false,
              employeeId: '',
              manage: true,
              task: task(),
              onWrite: (_, _, _, {operationId}) async {},
              onEdit: (_) async {})));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.close();
    });
  }
  testWidgets(
      'mobile filters remain usable with keyboard and apply without navigation',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = api();
    await tester.pumpWidget(MaterialApp(
        home:
            Scaffold(body: TaskWorkspace(api: service, companyId: 'c' * 43))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Apply filters'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.ensureVisible(find.text('Apply filters'));
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.close();
  });
  testWidgets(
      'employee cannot create tasks and receives assignments through refresh',
      (tester) async {
    final service = api();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TaskWorkspace(api: service, companyId: 'c' * 43, employee: {
      'employeeId': 'e' * 43,
      'writableSections': <String>[]
    }))));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Create task'), findsNothing);
    expect(find.text('New Task'), findsNothing);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.close();
  });
  testWidgets(
      'calendar agenda fetches selected-day tasks missing from a partial month page',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = taskDate(taskToday()), ranges = <Map<String, String>>[];
    final service = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/assignees')) {
            return http.Response('{"employees":[]}', 200);
          }
          final query = request.url.queryParameters;
          ranges.add(query);
          final day = query['from'] == today && query['to'] == today;
          final rows = day
              ? [
                  {...task(), 'title': 'Selected-day task'},
                  {
                    ...task(),
                    'recordId': 'z' * 43,
                    'title': 'Selected-day other'
                  }
                ]
              : [
                  for (var i = 0; i < 40; i++)
                    {
                      ...task(),
                      'recordId': '$i'.padLeft(43, 'x'),
                      'title': 'Other task $i',
                      'dueDate': taskDate(DateTime(taskToday().year,
                          taskToday().month, taskToday().day == 1 ? 2 : 1))
                    }
                ];
          return http.Response(
              jsonEncode({
                'records': rows,
                'total': day ? 2 : 42,
                'nextOffset': day ? null : 40,
                'dateCounts': {today: 2},
                'summary': {}
              }),
              200);
        }));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TaskWorkspace(
                api: service, companyId: 'c' * 43, calendar: true))));
    await tester.pumpAndSettle();
    expect(ranges.any((q) => q['from'] == today && q['to'] == today), isTrue);
    expect(find.text('Selected-day task'), findsOneWidget);
    expect(find.text('Selected-day other'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.close();
  });
  testWidgets(
      'assigned work appears through polling without logout or page navigation',
      (tester) async {
    var assigned = false, calls = 0;
    final paths = <String>[];
    final service = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          paths.add(request.url.path);
          calls++;
          return http.Response(
              jsonEncode({
                'records': assigned ? [task()] : [],
                'total': assigned ? 1 : 0,
                'nextOffset': null,
                'summary': {}
              }),
              200);
        }));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TaskWorkspace(api: service, companyId: 'c' * 43, employee: {
      'employeeId': 'e' * 43,
      'writableSections': <String>[]
    }))));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsNothing);
    assigned = true;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    expect(calls, 3);
    expect(paths.where((p) => p.contains('/tasks')).length, 2);
    expect(paths.where((p) => p.contains('/references/Projects')).length, 1);
    expect(paths.any((p) => p.contains('/logout')), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.close();
  });
}
