import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/saas/cash_reversal_editor.dart';

void main() {
  testWidgets(
    'reversal requires a real date and reason and returns no financial values',
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
                    builder: (_) => const CashReversalEditor(),
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
      await tester.tap(find.text('Reverse entry'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid date.'), findsOneWidget);
      expect(find.text('Enter a reason.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '2026-02-30');
      await tester.tap(find.text('Reverse entry'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid date.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '2026-10-01');
      await tester.enterText(
        find.byType(TextFormField).last,
        ' Duplicate entry ',
      );
      await tester.tap(find.text('Reverse entry'));
      await tester.pumpAndSettle();
      expect(result, {'date': '2026-10-01', 'description': 'Duplicate entry'});
    },
  );
}
