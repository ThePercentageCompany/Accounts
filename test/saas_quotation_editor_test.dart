import 'support/form_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/saas/quotation_editor.dart';

void main() {
  testWidgets(
    'quotation draft validates customer and dates without derived fields',
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
                  builder: (_) => QuotationEditor(
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
      final fields = find.byType(TextFormField);
      await fillFormField(tester, fields.at(0), '2026-09-28');
      await fillFormField(tester, fields.at(1), '2026-09-01');
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(
        find.text('Valid until cannot precede issue date.'),
        findsOneWidget,
      );
      await fillFormField(tester, fields.at(1), '2026-10-28');
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(result?['customerId'], 'c' * 43);
      expect(result?['currency'], 'AED');
      expect(result?.containsKey('total'), isFalse);
      expect(result?.containsKey('status'), isFalse);
    },
  );
}
