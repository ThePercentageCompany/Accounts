import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/accounting/presentation/receipt_editor.dart';

void main() {
  testWidgets(
    'receipt editor derives invoice authority and prevents overpayment',
    (tester) async {
      Map<String, Object?>? result;
      final invoices = [
        {
          'recordId': 'i' * 43,
          'customerId': 'c' * 43,
          'number': 'INV-2026-000001',
          'currency': 'AED',
          'balance': 75.25,
          'status': 'ISSUED',
        },
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showDialog<Map<String, Object?>>(
                      context: context,
                      builder: (_) => ReceiptEditor(invoices: invoices),
                    ),
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
      expect(find.text('Choose an open invoice.'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('INV-2026-000001 · AED 75.25').last);
      await tester.pumpAndSettle();
      final amount = find.byType(TextFormField).at(1);
      await tester.enterText(amount, '75.26');
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      expect(
        find.text('Amount cannot exceed the outstanding balance.'),
        findsOneWidget,
      );
      await tester.enterText(amount, '75.25');
      await tester.tap(find.text('Record payment'));
      await tester.pumpAndSettle();
      expect(result?['invoiceId'], 'i' * 43);
      expect(result?['customerId'], 'c' * 43);
      expect(result?['currency'], 'AED');
      expect(result?['amount'], 75.25);
      expect(result?.containsKey('status'), isFalse);
    },
  );
}
