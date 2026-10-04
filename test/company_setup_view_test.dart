import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/auth/presentation/cubit/saas_session.dart';
import 'package:tpc_invoice/features/workspace/presentation/company_setup_view.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [320.0, 1200.0]) {
      testWidgets(
        'workspace management fits $width dark=$dark and selects safely',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final a = 'a' * 43, b = 'b' * 43;
          final companies = [
            {'companyId': a, 'name': 'Alpha Company', 'stage': 'READY'},
            {
              'companyId': b,
              'name': 'Beta Company',
              'stage': 'RECOVERABLE_FAILURE',
            },
          ];
          var deletes = 0;
          final api = SaasApi(
            origin: 'https://api.test',
            client: MockClient((r) async {
              if (r.method == 'DELETE') {
                deletes++;
                return http.Response('{"deleted":true}', 200);
              }
              if (r.url.path.endsWith('/me')) {
                return http.Response('{"owner":{"ownerId":"owner"}}', 200);
              }
              if (r.url.path.endsWith('/companies')) {
                return http.Response(jsonEncode({'companies': companies}), 200);
              }
              return http.Response(
                jsonEncode({'company': companies.last}),
                200,
              );
            }),
          );
          final session = SaasSession(
            api,
            await SharedPreferences.getInstance(),
          );
          await session.restore();
          var opened = false;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: Scaffold(
                body: CompanySetupView(
                  session: session,
                  navigate: (_) async {},
                  onOpen: () => opened = true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final search = find.widgetWithText(TextField, 'Search workspaces');
          await tester.enterText(search, 'no matching company');
          await tester.pumpAndSettle();
          expect(find.text('No workspaces match your search.'), findsOneWidget);
          await tester.enterText(search, '');
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byTooltip('Expand company form'));
          await tester.tap(find.byTooltip('Expand company form'));
          await tester.pumpAndSettle();
          expect(
            find.widgetWithText(TextField, 'New company name'),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Open company workspace'));
          await tester.tap(find.text('Open company workspace'));
          expect(opened, isTrue);
          await tester.ensureVisible(find.text('Delete workspace'));
          await tester.tap(find.text('Delete workspace'));
          await tester.pumpAndSettle();
          expect(find.text('This cannot be undone.'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(deletes, 0);
          await tester.ensureVisible(find.text('Beta Company').first);
          await tester.tap(find.text('Beta Company').first);
          await tester.pumpAndSettle();
          expect(session.company?['companyId'], b);
          expect(find.text('Retry setup'), findsOneWidget);
          await tester.ensureVisible(find.text('Delete workspace'));
          await tester.tap(find.text('Delete workspace'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete all workspace data'));
          await tester.pumpAndSettle();
          expect(deletes, 1);
          expect(session.companies.length, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await session.close();
          api.close();
        },
      );
    }
  }
}
