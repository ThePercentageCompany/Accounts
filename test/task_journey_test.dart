import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/workspace/presentation/shared_workspace.dart';
import 'package:tpc_invoice/features/tasks/presentation/task_workspace.dart';

void main() {
  for (final size in [
    const Size(320, 800),
    const Size(1440, 1000),
    const Size(820, 390)
  ]) {
    testWidgets(
        'manager creates, comments, completes and calendars a task at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final rows = <Map<String, dynamic>>[],
          comments = <Map<String, dynamic>>[],
          paths = <String>[];
      var syncCount = 0;
      final api = SaasApi(
          origin: 'https://api.test',
          client: MockClient((request) async {
            final path = request.url.path;
            paths.add(path);
            Map<String, dynamic> data;
            if (path.endsWith('/assignees')) {
              data = {
                'employees': [
                  {
                    'recordId': 'e' * 43,
                    'fullName': 'Ahmed',
                    'department': 'Accounts'
                  },
                  {
                    'recordId': 's' * 43,
                    'fullName': 'Sarah',
                    'department': 'Sales'
                  }
                ],
                'nextOffset': null
              };
            } else if (path.endsWith('/sync')) {
              syncCount++;
              final body = jsonDecode(request.body) as Map;
              final operations = body['operations'] as List;
              final results = <Map<String, dynamic>>[];
              for (final operation in operations.cast<Map>()) {
                final values = Map<String, dynamic>.from(
                    operation['values'] as Map? ?? {});
                if (operation['table'] == 'Tasks') {
                  if (operation['action'] == 'create') {
                    rows.add({
                      ...values,
                      'assigneeName': 'Ahmed',
                      'recordId': 't' * 43,
                      'recordVersion': 1
                    });
                  } else if (operation['action'] == 'delete') {
                    rows.clear();
                  } else {
                    rows.single.addAll(values);
                    rows.single['assigneeName'] =
                        rows.single['employeeId'] == 's' * 43
                            ? 'Sarah'
                            : 'Ahmed';
                    rows.single['recordVersion'] =
                        (rows.single['recordVersion'] as int) + 1;
                  }
                } else {
                  comments.add({
                    ...values,
                    'createdAt': 1800000000000,
                    'createdBy': 'e' * 43,
                    'authorName': 'Ahmed'
                  });
                }
                results.add({
                  'operationId': operation['operationId'],
                  'status': 'APPLIED',
                  'recordId': 't' * 43,
                  'version': rows.isEmpty ? 1 : rows.single['recordVersion']
                });
              }
              data = {'results': results};
            } else if (path.endsWith('/${'t' * 43}')) {
              data = {
                'task': rows.single,
                'comments': comments,
                'activity': []
              };
            } else if (path.endsWith('/tasks')) {
              data = {
                'records': rows,
                'total': rows.length,
                'nextOffset': null,
                'dateCounts': {if (rows.isNotEmpty) rows.single['dueDate']: 1},
                'summary': {}
              };
            } else if (path == '/v1/employee/me') {
              data = {
                'employee': {
                  'employeeId': 'e' * 43,
                  'companyId': 'c' * 43,
                  'role': 'Manager',
                  'allowedSections': ['Tasks'],
                  'writableSections': ['Tasks']
                }
              };
            } else {
              data = {};
            }
            return http.Response(jsonEncode(data), 200,
                headers: {'content-type': 'application/json'});
          }));
      await tester.pumpWidget(MaterialApp(
          home: SharedWorkspace(
              api: api,
              companyId: 'c' * 43,
              title: 'Test workspace',
              onBack: () {},
              preferences: preferences,
              employee: {
            'employeeId': 'e' * 43,
            'companyId': 'c' * 43,
            'role': 'Manager',
            'allowedSections': ['Tasks'],
            'writableSections': ['Tasks']
          })));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final create = find.byTooltip('Create task').evaluate().isNotEmpty
          ? find.byTooltip('Create task')
          : find.text('New Task');
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      await tester.enterText(
          find
              .descendant(
                  of: find.byType(TaskEditor),
                  matching: find.byType(TextFormField))
              .first,
          'Prepare invoice');
      await tester.scrollUntilVisible(find.text('Select employee'), 120,
          scrollable: find
              .descendant(
                  of: find.byType(TaskEditor),
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select employee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ahmed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create Task'));
      await tester.pumpAndSettle();
      expect(rows.single['employeeId'], 'e' * 43);
      expect(syncCount, 1);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Prepare invoice'), 120,
          scrollable: find
              .descendant(
                  of: find.byType(TaskWorkspace).first,
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      for (var attempt = 0;
          attempt < 10 &&
              find.text('Prepare invoice').hitTestable().evaluate().isEmpty;
          attempt++) {
        await tester.drag(
            find.byType(TaskWorkspace).first, const Offset(0, -100));
        await tester.pumpAndSettle();
      }
      expect(find.text('Prepare invoice').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Prepare invoice'));
      await tester.pumpAndSettle();
      final comment = find.widgetWithText(TextField, 'Add a comment');
      await tester.ensureVisible(comment);
      await tester.pumpAndSettle();
      await tester.enterText(comment, 'Ready for review');
      await tester.ensureVisible(find.text('Post comment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post comment'));
      await tester.pumpAndSettle();
      expect(comments.single['body'], 'Ready for review');
      expect(syncCount, 2);
      final status =
          find.widgetWithText(DropdownButtonFormField<String>, 'Status').last;
      await tester.ensureVisible(status);
      await tester.pumpAndSettle();
      await tester.tap(status);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completed').last);
      await tester.pumpAndSettle();
      expect(rows.single['status'], 'COMPLETED');
      expect(syncCount, 3);
      await tester.tap(find.byTooltip('Edit / reassign'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find
              .descendant(
                  of: find.byType(TaskEditor),
                  matching: find.byType(TextFormField))
              .first,
          'Prepare revised invoice');
      final assignee = find.descendant(
          of: find.byType(TaskEditor),
          matching: find.byType(TaskAssigneeField));
      await tester.scrollUntilVisible(assignee, 120,
          scrollable: find
              .descendant(
                  of: find.byType(TaskEditor),
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await tester.tap(assignee);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sarah'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save Task'));
      await tester.pumpAndSettle();
      expect(rows.single['employeeId'], 's' * 43);
      expect(rows.single['title'], 'Prepare revised invoice');
      expect(syncCount, 4);
      await tester.tap(find.byTooltip('Close task'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Calendar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Prepare revised invoice'), 120,
          scrollable: find
              .descendant(
                  of: find.byType(TaskWorkspace).last,
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      expect(find.text('Prepare revised invoice'), findsWidgets);
      expect(find.text('Today'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(paths.any((p) => p.contains('/logout')), isFalse);
      expect(
          preferences.getKeys().any(
              (k) => k.startsWith('saas_records_') && !k.endsWith('-rejected')),
          isFalse);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
}
