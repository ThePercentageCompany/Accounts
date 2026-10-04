import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/accounting/presentation/financial_period_editor.dart';

void main() {
  testWidgets(
    'period closure requires explicit confirmation and omits server metadata',
    (tester) async {
      Map<String, Object?>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<Map<String, Object?>>(
                    context: context,
                    builder: (_) => const FinancialPeriodEditor(
                      record: {
                        'name': 'September',
                        'startDate': '2026-09-01',
                        'endDate': '2026-09-30',
                        'status': 'OPEN',
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close this period'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save period'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Close financial period?'), findsOneWidget);
      await tester.tap(find.text('Close period'));
      await tester.pumpAndSettle();
      expect(result!['status'], 'CLOSED');
      expect(result!.containsKey('closedBy'), isFalse);
      expect(result!.containsKey('closedAt'), isFalse);
    },
  );
}
