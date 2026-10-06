import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/accounting/presentation/cash_entry_editor.dart';

void main() {
  testWidgets('unknown imported payment status requires an explicit choice', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CashEntryEditor(
            expense: true,
            record: {
              'description': 'Imported entry',
              'amount': 20,
              'paymentStatus': 'UNKNOWN',
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a payment status.'), findsOneWidget);
  });
  testWidgets('expense form sends base amount and rate, never client totals', (
    tester,
  ) async {
    Map<String, Object?>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                saved = await showDialog<Map<String, Object?>>(
                  context: context,
                  builder: (_) => const CashEntryEditor(expense: true),
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
    Future<void> fill(String label, String value) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await fill('Description', 'Supplies');
    final category = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Category',
    );
    await tester.ensureVisible(category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Office supplies').last);
    await tester.pumpAndSettle();
    await fill('Amount before tax', '10.001');
    await fill('Tax rate (%)', '5');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(
      find.text('This field is required.'),
      findsOneWidget,
    );
    await fill('Amount before tax', '10.10');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(saved!['amount'], 10.1);
    expect(saved!['category'], 'Office supplies');
    expect(saved!['taxRate'], 5);
    expect(saved!['paymentStatus'], 'UNPAID');
    expect(saved!['paidDate'], '');
    expect(saved!.containsKey('total'), isFalse);
    expect(saved!.containsKey('taxAmount'), isFalse);
  });
}
