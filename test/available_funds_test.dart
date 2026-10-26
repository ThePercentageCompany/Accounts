import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/reports/presentation/overview_charts.dart';

void main() {
  testWidgets('available funds keep overdrafts and signed net totals visible',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OverviewDonut(
      data: [
        OverviewDatum('Cash', -120, display: '-120.00'),
        OverviewDatum('Bank', 50, display: '50.00'),
      ],
      centerLabel: 'Cash & bank',
      totalLabel: '-70.00',
    ))));
    await tester.pumpAndSettle();
    expect(find.text('-70.00'), findsOneWidget);
    expect(find.text('-120.00'), findsOneWidget);
    expect(find.text('50.00'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
