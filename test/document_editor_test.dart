import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_kit/invoice_kit.dart' as kit;
import 'package:tpc_invoice/core/saas/document_editor.dart';
import 'package:tpc_invoice/core/saas/invoice_document.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';

const items = [
  {
    'description': 'Consulting',
    'quantity': 3,
    'unitPrice': 0.1,
    'discount': 0.05,
    'taxRate': 5,
  },
  {
    'description': 'Design',
    'quantity': 2,
    'unitPrice': 50,
    'discount': 5,
    'taxRate': 5,
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'preview estimates round each line in minor units and tolerate incomplete input',
    () {
      expect(estimateDocument(items), {
        'subtotal': 100.3,
        'discount': 5.05,
        'taxAmount': 4.76,
        'total': 100.01,
      });
      expect(
        estimateDocument([
          {'quantity': double.nan, 'unitPrice': double.infinity},
        ])['total'],
        0,
      );
      expect(
        estimateDocument([
          {'quantity': 1e100, 'unitPrice': 1},
        ])['total'],
        0,
      );
    },
  );
  for (final quotation in [false, true]) {
    test(
      'invoice_kit exports ${quotation ? 'quotation' : 'invoice'} with saved authoritative totals',
      () async {
        final record = {
          'issueDate': '2026-10-04',
          'currency': 'AED',
          'status': 'DRAFT',
          'total': 999.99,
          'subtotal': 1000,
          'discount': 0.01,
          'taxAmount': 0,
          'recordVersion': 7,
        };
        final data = documentData(
          quotation: quotation,
          record: record,
          company: {'name': 'TPC'},
          customer: {'name': 'Client'},
          items: items,
        );
        expect(data.get('totals.total'), 999.99);
        expect(data.get('title'), quotation ? 'QUOTATION' : 'INVOICE');
        for (final style in DocumentStyle.values) {
          final bytes = await kit.InvoiceGenerator.generate(
            data: data,
            template: BusinessDocumentTemplate(style: style),
            config: const kit.TemplateConfig(extras: {'compress': false}),
          );
          expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
          expect(latin1.decode(bytes), contains('999.99'));
        }
      },
    );

    testWidgets(
      'complete ${quotation ? 'quotation' : 'invoice'} duplicates, reorders and saves base line inputs',
      (tester) async {
        tester.view.physicalSize = const Size(1366, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, Object?>? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async =>
                      result = await showDialog<Map<String, Object?>>(
                        context: context,
                        builder: (_) => DocumentEditor(
                          quotation: quotation,
                          customers: const [
                            {'recordId': 'customer', 'name': 'Client'},
                          ],
                          items: items,
                          record: {
                            'customerId': 'customer',
                            'issueDate': '2026-10-04',
                            'validUntil': '2026-11-04',
                            'dueDate': '2026-11-04',
                          },
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
        final duplicate = find.byTooltip('Duplicate item').first;
        await tester.ensureVisible(duplicate);
        await tester.tap(duplicate);
        await tester.pumpAndSettle();
        expect(find.text('Item 3'), findsOneWidget);
        final move = find.byTooltip('Move item up').last;
        await tester.ensureVisible(move);
        await tester.tap(move);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save draft'));
        await tester.pumpAndSettle();
        expect(result?['items'], [items[0], items[1], items[0]]);
        expect(result?.containsKey('total'), isFalse);
        expect(
          (result!['items'] as List).every(
            (line) => !(line as Map).containsKey('lineTotal'),
          ),
          isTrue,
        );
      },
    );
  }
  for (final size in [
    const Size(320, 740),
    const Size(390, 740),
    const Size(740, 360),
    const Size(1366, 900),
  ]) {
    testWidgets('advanced document editor fits $size at large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const Scaffold(
            body: DocumentEditor(
              quotation: false,
              customers: [
                {'recordId': 'c', 'name': 'Client'},
              ],
              items: items,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Estimated total'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Save draft'), findsOneWidget);
    });
  }
}
