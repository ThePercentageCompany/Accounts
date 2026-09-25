import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/main.dart';
import 'package:tpc_invoice/core/saas/saas_app.dart';

void main() {
  testWidgets('missing shared API fails closed without legacy login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TpcApp());
    await tester.pumpAndSettle();
    expect(find.byType(TpcApp), findsOneWidget);
    expect(find.byType(SaasApp), findsOneWidget);
    expect(find.byKey(const Key('shared-service-unavailable')), findsOneWidget);
  });
}
