import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/reports/presentation/workspace_quick_look_card.dart';

void main() {
  for (final width in [288.0, 360.0, 600.0]) {
    testWidgets('quick look fits $width and opens the selected table',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      var refreshes = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: WorkspaceQuickLookCard(
            section: 'Invoices',
            tables: const ['Invoices', 'Receipts'],
            rows: const {
              'Invoices': [
                {'status': 'DRAFT'},
                {'status': 'ISSUED', 'syncStatus': 'PENDING'},
                {'status': 'PARTIALLY_PAID'},
                {'status': 'PAID'},
              ],
              'Receipts': [],
            },
            errors: const {},
            busy: false,
            amounts: const {
              'Invoices': ['AED 1,000.00', 'USD 200.00']
            },
            onOpen: (table) => selected = table,
            onRefresh: () => refreshes++),
      ))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('No records yet'), findsOneWidget);
      expect(find.text('AED 1,000.00'), findsOneWidget);
      expect(find.text('USD 200.00'), findsOneWidget);
      await tester.tap(find.text('Receipts'));
      expect(selected, 'Receipts');
      await tester.tap(find.byTooltip('Refresh Invoices'));
      expect(refreshes, 1);
    });
  }

  testWidgets('failed data is unavailable rather than an empty count',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: WorkspaceQuickLookCard(
      section: 'Payroll',
      tables: const ['Payroll'],
      rows: const {},
      errors: const {'Payroll': 'Offline'},
      busy: false,
      amounts: const {},
      onOpen: (_) {},
      onRefresh: () {},
    ))));
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('No records yet'), findsNothing);
  });
}
