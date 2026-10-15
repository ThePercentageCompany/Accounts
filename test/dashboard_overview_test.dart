import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/reports/presentation/workspace_dashboard.dart';
import 'package:tpc_invoice/features/reports/presentation/overview_charts.dart';

void main() {
  for (final width in [320.0, 1440.0]) {
    testWidgets('financial overview charts and navigation fit width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: WorkspaceDashboard(data: {
          'from': '2026-01-01',
          'asOf': '2026-10-15',
          'balanced': true,
          'metadata': {'currency': 'AED'},
          'totalIncome': '1000.00',
          'totalExpenses': '400.00',
          'netProfit': '600.00',
          'cash': '100.00',
          'bank': '200.00',
          'receivables': '300.00',
          'payables': '50.00',
          'totalAssets': '600.00',
          'totalLiabilities': '50.00',
          'totalEquity': '550.00',
          'trends': [
            {
              'from': '2026-01-01',
              'asOf': '2026-01-31',
              'income': '1000.00',
              'expenses': '400.00'
            }
          ],
        }, onReportSelected: (kind) => selected = kind),
      ))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(OverviewDonut), findsOneWidget);
      await tester.tap(find.text('Period income'));
      expect(selected, 'profit-and-loss');
    });
  }
  testWidgets('pie chart handles empty and negative balances honestly',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: OverviewDonut(
      data: [OverviewDatum('Cash', 0), OverviewDatum('Bank', 0)],
    ))));
    await tester.pumpAndSettle();
    expect(find.text('No activity'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: OverviewDonut(
      data: [OverviewDatum('Cash', -10), OverviewDatum('Bank', 50)],
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('negative or missing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
