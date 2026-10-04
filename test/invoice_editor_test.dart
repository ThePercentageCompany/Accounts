import 'support/form_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/documents/presentation/invoice_editor.dart';

void main() {
  testWidgets(
    'invoice editor requires customer and ordered dates and omits totals',
    (tester) async {
      Map<String, Object?>? result;
      final customers = [
        {'recordId': 'c' * 43, 'name': 'Client'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showDialog<Map<String, Object?>>(
                      context: context,
                      builder: (_) => InvoiceEditor(
                        customers: customers,
                        items: const [
                          {
                            'description': 'Service',
                            'quantity': 1,
                            'unitPrice': 100,
                            'discount': 0,
                            'taxRate': 5,
                          },
                        ],
                      ),
                    ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a customer.'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Client').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).last,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD — US dollar').last);
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await fillFormField(tester, fields.at(0), '2026-09-27');
      await fillFormField(tester, fields.at(1), '2026-09-01');
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(find.text('Due date cannot precede issue date.'), findsOneWidget);
      await fillFormField(tester, fields.at(1), '2026-10-01');
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(result?['customerId'], 'c' * 43);
      expect(result?['currency'], 'USD');
      expect(result?.containsKey('total'), isFalse);
      expect(result?.containsKey('status'), isFalse);
    },
  );
}
