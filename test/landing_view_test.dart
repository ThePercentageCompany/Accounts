import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/auth/presentation/saas_app.dart';
import 'package:tpc_invoice/features/auth/presentation/landing_view.dart';
import 'package:tpc_invoice/features/workspace/presentation/workspace_help.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('landing and public FAQ fit $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final api = SaasApi(
          origin: 'https://api.test',
          client: MockClient((_) async => http.Response(
              '{"error":{"code":"UNAUTHORIZED","message":"Sign in"}}', 401)));
      await tester.pumpWidget(MaterialApp(home: SaasApp(api: api)));
      await tester.pumpAndSettle();
      expect(find.byType(LandingView), findsOneWidget);
      expect(find.text('Get started with Google'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('FAQ & getting started'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkspaceHelp), findsOneWidget);
      await tester.ensureVisible(find.text('What is TPC Accounts?'));
      await tester.tap(find.text('What is TPC Accounts?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('TPC Accounts is a company workspace'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(LandingView), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
}
