import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/documents/presentation/document_editor.dart';

void main() {
  for (final quotation in [false, true]) {
    testWidgets(
      '${quotation ? 'quotation' : 'invoice'} keeps form values on denied save and prevents duplicate submission',
      (tester) async {
        var calls = 0;
        final gate = Completer<void>();
        final drafts = <Map<String, Object?>>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => DocumentEditor(
                      quotation: quotation,
                      customers: const [
                        {'recordId': 'customer', 'name': 'Client'},
                      ],
                      record: {
                        'customerId': 'customer',
                        'issueDate': '2026-10-05',
                        'dueDate': '2026-11-05',
                        'validUntil': '2026-11-05',
                        'notes': 'Keep these notes',
                      },
                      items: const [
                        {
                          'description': 'Service',
                          'quantity': 1,
                          'unitPrice': 100,
                          'discount': 0,
                          'taxRate': 5,
                        },
                      ],
                      onSave: (draft) async {
                        calls++;
                        drafts.add(draft);
                        if (calls == 1) {
                          await gate.future;
                          throw const SaasApiException(
                            'WRITE_FORBIDDEN',
                            'Edit permission required.',
                            status: 403,
                          );
                        }
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
        await tester.tap(find.text('Save draft'));
        await tester.pump();
        expect(find.text('Saving…'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Saving…'),
              )
              .onPressed,
          isNull,
        );
        expect(calls, 1);
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text('Edit permission required.'), findsOneWidget);
        expect(find.byType(DocumentEditor), findsOneWidget);
        await tester.tap(find.text('Save draft'));
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(drafts.first, drafts.last);
        expect(drafts.last['notes'], 'Keep these notes');
        expect(find.byType(DocumentEditor), findsNothing);
      },
    );
  }

  testWidgets('changed document asks before discarding', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const DocumentEditor(
                  quotation: false,
                  customers: [
                    {'recordId': 'customer', 'name': 'Client'},
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
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Client').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentEditor), findsOneWidget);
  });
}
