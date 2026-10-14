import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/workspace/presentation/business_group_view.dart';

void main() {
  for (final width in [320.0, 768.0, 1440.0]) {
    testWidgets(
        'group overview preserves separate country currencies at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = SaasApi(
          origin: 'https://api.test',
          client: MockClient((request) async => http.Response(
              jsonEncode({
                'groups': [
                  {'id': 'g' * 43, 'name': 'TPC Group'}
                ],
                'entities': [
                  {
                    'companyId': 'a' * 43,
                    'name': 'Dubai business',
                    'groupId': 'g' * 43,
                    'countryCode': 'AE',
                    'currency': 'AED',
                    'timeZone': 'Asia/Dubai',
                    'taxRegistration': '',
                    'metrics': {
                      'employees': 2,
                      'openTasks': 3,
                      'invoices': 1,
                      'outstandingByCurrency': {'AED': 100}
                    }
                  },
                  {
                    'companyId': 'b' * 43,
                    'name': 'India business',
                    'groupId': 'g' * 43,
                    'countryCode': 'IN',
                    'currency': 'INR',
                    'timeZone': 'Asia/Kolkata',
                    'taxRegistration': '',
                    'metrics': {
                      'employees': 4,
                      'openTasks': 1,
                      'invoices': 1,
                      'outstandingByCurrency': {'INR': 200}
                    }
                  },
                ]
              }),
              200)));
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
              body: BusinessGroupView(api: api, onOpen: (_) async {}))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('AED 100.00'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('AED 100.00'), findsOneWidget);
      expect(find.text('INR 200.00'), findsOneWidget);
      expect(find.text('300.00'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    });
  }
}
