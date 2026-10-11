import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/accounting/presentation/transfer_editor.dart';

void main() {
  for (final source in ['cash', 'bank']) {
    testWidgets(
        '$source transfer saves opposite destination without income fields',
        (tester) async {
      Map<String, Object?>? saved;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                        onPressed: () async {
                          saved = await showDialog<Map<String, Object?>>(
                              context: context,
                              builder: (_) => TransferEditor(record: {
                                    'date': '2026-10-10',
                                    'fromAccount': source,
                                    'amount': 1000.25,
                                    'description': 'Business transfer',
                                    'reference': 'TR-1',
                                  }));
                        },
                        child: const Text('Open'),
                      )))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(saved, {
        'date': '2026-10-10',
        'fromAccount': source,
        'toAccount': source == 'cash' ? 'bank' : 'cash',
        'amount': 1000.25,
        'description': 'Business transfer',
        'reference': 'TR-1',
      });
    });
  }
  testWidgets('empty transfer cannot be saved', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: TransferEditor())));
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a positive amount with up to two decimals.'),
        findsOneWidget);
    expect(find.text('Enter a valid date.'), findsOneWidget);
    expect(find.text('Required.'), findsOneWidget);
  });
}
