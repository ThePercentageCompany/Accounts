import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/main.dart';
import 'package:tpc_invoice/features/auth/presentation/saas_app.dart';

void main() {
  testWidgets(
      'a cold task URL resolves to the sign-in app with its destination',
      (tester) async {
    final company = 'c' * 43;
    final task = 't' * 43;
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/tasks/$company/$task';
    addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(const TpcApp());
    await tester.pump();
    final app = tester.widget<SaasApp>(find.byType(SaasApp));
    expect(app.initialTask!.companyId, company);
    expect(app.initialTask!.taskId, task);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
