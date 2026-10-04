import 'support/form_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/saas/invoice_editor.dart';

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
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Client').last);
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
      expect(result?['currency'], 'AED');
      expect(result?.containsKey('total'), isFalse);
      expect(result?.containsKey('status'), isFalse);
    },
  );

  testWidgets('invoice line sends base inputs without calculated totals', (
    tester,
  ) async {
    Map<String, Object?>? result;
    final invoices = [
      {'recordId': 'i' * 43, 'issueDate': '2026-09-27', 'status': 'DRAFT'},
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await showDialog<Map<String, Object?>>(
                    context: context,
                    builder: (_) => InvoiceLineEditor(invoices: invoices),
                  ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-09-27').last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await fillFormField(tester, fields.at(0), '1');
    await fillFormField(tester, fields.at(1), 'Service');
    await fillFormField(tester, fields.at(2), '3');
    await fillFormField(tester, fields.at(3), '0.10');
    await fillFormField(tester, fields.at(4), '0.05');
    await fillFormField(tester, fields.at(5), '5');
    await tester.tap(find.text('Save line'));
    await tester.pumpAndSettle();
    expect(result?['quantity'], 3.0);
    expect(result?['unitPrice'], 0.1);
    expect(result?.containsKey('lineTotal'), isFalse);
    expect(result?.containsKey('taxAmount'), isFalse);
  });
}
