import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/saas/customer_editor.dart';
import 'package:tpc_invoice/core/saas/mobile_components.dart';
import 'package:tpc_invoice/core/saas/workspace_dashboard.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';

void main() {
  for (final size in [
    const Size(320, 740),
    const Size(360, 740),
    const Size(390, 740),
    const Size(430, 740),
    const Size(740, 360),
    const Size(768, 1024),
    const Size(1366, 768)
  ]) {
    testWidgets('dashboard and keyboard form fit $size at large text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget app(Widget home, {double keyboard = 0}) => MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.5),
                  viewInsets: EdgeInsets.only(bottom: keyboard)),
              child: child!),
          home: home);
      await tester.pumpWidget(app(const Scaffold(
          body: SingleChildScrollView(
              child:
                  WorkspaceDashboard(data: {'totalIncome': 123456789.99})))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
          app(const Scaffold(body: CustomerEditor()), keyboard: 180));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Save customer'), findsOneWidget);
      await tester.enterText(
          find.byType(TextFormField).first, 'Unsaved customer');
      await tester.pump();
      expect(find.text('Unsaved customer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'searchable selection filters supplied data and retains selection',
      (tester) async {
    tester.view.physicalSize = const Size(390, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SearchableRecordField(
                decoration: const InputDecoration(labelText: 'Customer'),
                items: [
                  for (final name in ['Alice', 'Bob', 'Chris'])
                    DropdownMenuItem(value: name, child: Text(name))
                ],
                onChanged: (value) => selected = value))));
    await tester.tap(find.text('Choose an option'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bob');
    await tester.pump();
    expect(find.text('Alice'), findsNothing);
    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();
    expect(selected, 'Bob');
    expect(find.text('Bob'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
