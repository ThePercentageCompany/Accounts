import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/workspace/presentation/shared_workspace.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';

void main() {
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
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customers').last);
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
