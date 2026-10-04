import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/workspace/presentation/system_settings_panel.dart';

void main() {
  for (final width in [320.0, 1366.0]) {
    testWidgets('settings opens document design editor at $width pixels', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((_) async => http.Response('{"records":[]}', 200)),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SystemSettingsPanel(api: api, companyId: 'workspace'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invoice design'), findsOneWidget);
      expect(find.text('Quotation design'), findsOneWidget);
      await tester.tap(find.text('Invoice design'));
      await tester.pumpAndSettle();
      expect(find.text('Custom HTML design'), findsOneWidget);
      expect(find.text('Save design'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
