import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/saas/invoice_return_editor.dart';

void main() {
  for (final width in [320.0, 1000.0]) {
    testWidgets(
        'partial return validates remaining quantity and submits original line ID at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, Object?>? result;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                      body: TextButton(
                    onPressed: () async =>
                        result = await showDialog<Map<String, Object?>>(
                            context: context,
                            builder: (_) => InvoiceReturnEditor(
                                  invoice: const {
                                    'number': 'INV-2026-000001',
                                    'issueDate': '2026-10-01',
                                    'currency': 'AED',
                                    'balance': 0
                                  },
                                  items: [
                                    {
                                      'recordId': 'i' * 43,
                                      'description': 'Consulting',
                                      'quantity': 3,
                                      'unitPrice': 10,
                                      'discount': 1,
                                      'taxAmount': 1.45
                                    }
                                  ],
                                  returns: [
                                    {'invoiceItemId': 'i' * 43, 'quantity': 1}
                                  ],
                                )),
                    child: const Text('Open'),
                  )))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).at(1), 'Returned service');
      await tester.enterText(find.byType(TextFormField).at(2), '3');
      await tester.tap(find.text('Post credit note'));
      await tester.pumpAndSettle();
      expect(find.text('Enter 0 to 2.0 (up to 2 decimals).'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(2), '1');
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Estimated credit: AED 10.15'), findsOneWidget);
      await tester.tap(find.text('Post credit note'));
      await tester.pumpAndSettle();
      expect(result?['returnItems'], [
        {'invoiceItemId': 'i' * 43, 'quantity': 1}
      ]);
      expect(result?['refundAccount'], 'Bank');
      expect(tester.takeException(), isNull);
    });
  }
}
