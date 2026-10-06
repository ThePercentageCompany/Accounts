import 'support/form_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/accounting/presentation/cash_payment_editor.dart';

void main() {
  testWidgets('payment requires a real date and account and sends no amount', (
    tester,
  ) async {
    Map<String, Object?>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<Map<String, Object?>>(
                  context: context,
                  builder: (_) => const CashPaymentEditor(total: 10.61),
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
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid date.'), findsOneWidget);
    expect(find.text('Select a payment method.'), findsOneWidget);
    await fillFormField(tester, find.byType(TextFormField).first, '2026-02-30');
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid date.'), findsOneWidget);
    await fillFormField(tester, find.byType(TextFormField).first, '2026-10-01');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(result, {
      'paidDate': '2026-10-01',
      'account': 'Bank',
      'reference': '',
    });
  });
}
