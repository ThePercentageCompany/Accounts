import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/workspace/presentation/workspace_help.dart';

void main() {
  testWidgets('animated flow switches repeatedly and topic filters work',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WorkspaceHelp()));
    for (final step in ['2. Invoice', '4. Reports', '1. Customer']) {
      final target = find.text(step);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    }
    final topic = find.widgetWithText(ChoiceChip, 'Accounting basics');
    await tester.ensureVisible(topic);
    await tester.tap(topic);
    await tester.pumpAndSettle();
    expect(find.text('What is the ledger?'), findsOneWidget);
    expect(find.text('Is an invoice the same as a receipt?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search finds accounting explanation and empty state',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WorkspaceHelp()));
    final search = find.byType(TextField);
    await tester.ensureVisible(search);
    await tester.enterText(search, 'What is the ledger?');
    await tester.pumpAndSettle();
    final answer = find.descendant(
        of: find.byType(ExpansionTile),
        matching: find.text('What is the ledger?'));
    await tester.ensureVisible(answer);
    await tester.tap(answer);
    await tester.pumpAndSettle();
    expect(find.textContaining('groups posted journal lines'), findsOneWidget);
    await tester.ensureVisible(search);
    await tester.enterText(search, 'no-such-topic');
    await tester.pumpAndSettle();
    expect(find.textContaining('No matching answers.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flow and FAQs fit narrow and desktop layouts at large text',
      (tester) async {
    for (final width in [320.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(
            size: Size(width, 900),
            textScaler: const TextScaler.linear(3),
            disableAnimations: true),
        child: WorkspaceHelp(key: ValueKey(width)),
      )));
      await tester.pumpAndSettle();
      final receipt = find.text('3. Receipt');
      await tester.ensureVisible(receipt);
      await tester.tap(receipt);
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Record the customer’s payment'), findsOneWidget);
      final faq = find.text('What is a balance sheet?');
      await tester.ensureVisible(faq);
      await tester.tap(faq);
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Assets = Liabilities + Equity'), findsOneWidget);
      await tester.tap(faq);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
