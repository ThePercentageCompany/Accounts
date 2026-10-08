import 'dart:async';
import 'dart:convert';
import 'package:tpc_invoice/core/offline/offline_store.dart';
import 'package:tpc_invoice/core/widgets/workspace_sync_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/workspace/presentation/shared_workspace.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';

class _WorkspaceOfflineStore implements OfflineStore {
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

void main() {
  testWidgets(
      'app bar tracks unsynced changes and force sync acknowledges them',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var submissions = 0;
    var exited = false;
    final syncGate = Completer<void>();
    final api = SaasApi(
      origin: 'https://api.test',
      offlineStore: _WorkspaceOfflineStore(),
      offlineAutomatic: false,
      client: MockClient((request) async {
        if (request.url.path == '/v1/me') {
          return http.Response('{"owner":{"ownerId":"owner"}}', 200);
        }
        if (request.url.path.endsWith('/sync')) {
          submissions++;
          final op = jsonDecode(request.body)['operations'][0];
          await syncGate.future;
          return http.Response(
              jsonEncode({
                'results': [
                  {
                    'operationId': op['operationId'],
                    'status': 'APPLIED',
                    'recordId': 'r' * 43,
                    'version': 1,
                  }
                ]
              }),
              200);
        }
        return http.Response(
            '{"records":[],"accounts":[],"journalCount":0}', 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(
        home: SharedWorkspace(
      api: api,
      companyId: 'c' * 43,
      ownerId: 'owner',
      preferences: prefs,
      title: 'Company',
      onBack: () => exited = true,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Synced'), findsNothing);
    expect(find.byTooltip(RegExp(r'^Synced\n')), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).bottom, isNull);
    await api.outbox('owner', 'c' * 43).enqueue(
        'Customers', 'create', {'name': 'Local customer'},
        expectedVersion: 0);
    await tester.pumpAndSettle();
    expect(find.text('1 unsynced'), findsNothing);
    expect(find.byTooltip(RegExp(r'^1 unsynced\n')), findsOneWidget);
    await tester.longPress(find.byKey(const Key('workspace-sync')));
    await tester.pump();
    expect(
        find.textContaining(
            'Changes saved on this device await server confirmation.'),
        findsOneWidget);
    Tooltip.dismissAllToolTips();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('workspace-sync')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
        tester
            .widget<WorkspaceSyncIcon>(find.byType(WorkspaceSyncIcon))
            .syncing,
        isTrue);
    expect(find.byTooltip(RegExp(r'^Syncing · 1 unsynced\n')), findsOneWidget);
    syncGate.complete();
    await tester.pumpAndSettle();
    expect(submissions, 1);
    expect(find.byTooltip(RegExp(r'^Synced\n')), findsOneWidget);
    expect(
        tester
            .widget<WorkspaceSyncIcon>(find.byType(WorkspaceSyncIcon))
            .syncing,
        isFalse);
    await tester.tap(find.byTooltip('Quit workspace'));
    expect(exited, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets('mobile selectors open reports and accounting subsections',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final paths = <String>[];
    final api = SaasApi(
      origin: 'https://api.test',
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
            '{"records":[],"accounts":[],"journalCount":0}', 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: SharedWorkspace(
        api: api,
        companyId: 'c' * 43,
        title: 'Mobile workspace',
        onBack: () {},
        employee: const {
          'allowedSections': ['Reports', 'Capital & Equity'],
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General ledger').last);
    await tester.pumpAndSettle();
    expect(paths.last, '/v1/employee/reports/general-ledger');
    await tester.tap(find.byTooltip('All workspace sections'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capital & Equity').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Capital accounts'));
    await tester.tap(find.text('Capital accounts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shareholder loans').last);
    await tester.pumpAndSettle();
    expect(paths.last, endsWith('/ShareholderLoans'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets(
      'mobile admin menu exposes every section including Tasks and Calendar',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((_) async => http.Response(
            '{"records":[],"employees":[],"accounts":[],"journalCount":0}',
            200)));
    await tester.pumpWidget(MaterialApp(
        home: SharedWorkspace(
      api: api,
      companyId: 'c' * 43,
      ownerId: 'owner',
      preferences: prefs,
      title: 'Admin workspace',
      onBack: () {},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('All workspace sections'));
    await tester.pumpAndSettle();
    for (final section in ['Reports', 'Employees', ...workspaceTables.keys]) {
      final destination = find.descendant(
          of: find.byType(BottomSheet), matching: find.text(section));
      await tester.scrollUntilVisible(destination, 180,
          scrollable: find
              .descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byType(Scrollable))
              .first);
      expect(destination, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    final tasks = find.descendant(
        of: find.byType(BottomSheet), matching: find.text('Tasks'));
    await tester.scrollUntilVisible(tasks, -180,
        scrollable: find
            .descendant(
                of: find.byType(BottomSheet), matching: find.byType(Scrollable))
            .first);
    await tester.tap(tasks);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Tasks'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  for (final width in [390.0, 1366.0]) {
    testWidgets(
      'report sidebar destinations switch authorized routes at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final paths = <String>[];
        final api = SaasApi(
          origin: 'https://api.test',
          client: MockClient((request) async {
            paths.add(request.url.path);
            return http.Response('{"accounts":[],"journalCount":0}', 200);
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: SharedWorkspace(
              api: api,
              companyId: 'c' * 43,
              title: 'Test',
              onBack: () {},
              employee: const {
                'allowedSections': ['Reports'],
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Choose report'), findsNothing);
        if (width < 900) {
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Reports'),
          ));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('General ledger').first);
        await tester.tap(find.text('General ledger').first);
        await tester.pumpAndSettle();
        expect(paths.last, '/v1/employee/reports/general-ledger');
        expect(find.byTooltip('Choose report'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        api.close();
      },
    );
  }
  for (final width in [320.0, 360.0, 390.0, 430.0, 1024.0, 1366.0]) {
    testWidgets('workspace navigation fits $width', (tester) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((_) async => http.Response('{"records":[]}', 200)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SharedWorkspace(
            api: api,
            companyId: 'c' * 43,
            title: 'A long company workspace name',
            onBack: () {},
            employee: const {
              'allowedSections': [
                'Customers',
                'Invoices',
                'Payroll',
                'Settings',
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(NavigationBar),
        width < 900 ? findsOneWidget : findsNothing,
      );
      if (width < 900) {
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('Company profile'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
  testWidgets(
    'owner snapshot appears before response and refresh replaces it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final company = 'c' * 43;
      final store = MemoryCacheStore();
      final response = Completer<http.Response>();
      final api = SaasApi(
        origin: 'https://api.test',
        cacheStore: store,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/Customers')) return response.future;
          return http.Response('{"records":[],"employees":[]}', 200);
        }),
      );
      api.useVerifiedWorkspace(company, ownerId: 'owner');
      await api.cache.read(
        api.recordsPath(company, 'Customers'),
        () async => {
          'records': [
            {'recordId': 'customer', 'name': 'Saved customer'},
          ],
        },
      );
      await tester.pump();
      for (final entry in store.entries.values) {
        entry['syncedAt'] = DateTime.now()
            .subtract(const Duration(minutes: 3))
            .millisecondsSinceEpoch;
      }
      // Simulate a browser restart: keep persistence, discard session memory.
      api.detachWorkspace();
      await tester.pumpWidget(
        MaterialApp(
          home: SharedWorkspace(
            api: api,
            companyId: company,
            title: 'Company',
            onBack: () {},
            ownerId: 'owner',
            preferences: prefs,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customers'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Saved customer'), findsOneWidget);
      response.complete(
        http.Response('{"records":[{"name":"Fresh customer"}]}', 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fresh customer'), findsOneWidget);
      expect(find.text('Saved customer'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
}
