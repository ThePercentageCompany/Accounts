import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';

void main() {
  for (final width in [320.0, 390.0, 1366.0]) {
    testWidgets('grouped expanded records fit $width with large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final row = <String, dynamic>{
        'number': 'INV-001',
        'status': 'ISSUED',
        'issueDate': '2026-10-05',
        'total': 125.5,
        'paidAmount': 0,
        'email': 'accounts@example.com',
        'notes': 'A long note ' * 15,
        'recordId': 'private-id',
        'recordVersion': 3,
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: RecordCard(
                  title: const Text('INV-001'),
                  subtitle: RecordSummary(record: row),
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text('Documents'),
                    ),
                    RecordDetails(record: row),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('INV-001').first);
      await tester.pumpAndSettle();
      expect(find.text('Amounts & quantities'), findsOneWidget);
      expect(find.text('125.50'), findsOneWidget);
      expect(find.text('private-id'), findsNothing);
      expect(find.text('Record version'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('INV-001').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('INV-001').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [320.0, 740.0, 1366.0]) {
    testWidgets('loading record actions align inside the card at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1000),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: RecordCard(
                  title: const Text('Issued invoice'),
                  subtitle: const Text('INV-001'),
                  children: [
                    const RecordNotice(
                      title: 'Invoice history is protected',
                      message:
                          'Issued invoices are locked. Credit notes preserve the original invoice and payment history.',
                    ),
                    LoadingButton.outlinedIcon(
                      key: const Key('documents'),
                      onPressed: () {},
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Documents'),
                    ),
                    LoadingButton.outlined(
                      key: const Key('void'),
                      onPressed: () {},
                      child: const Text('Void invoice'),
                    ),
                    LoadingButton.icon(
                      key: const Key('return'),
                      onPressed: () {},
                      icon: const Icon(Icons.assignment_return_outlined),
                      label: const Text('Return items / credit note'),
                    ),
                    const RecordDetails(
                      record: {
                        'number': 'INV-001',
                        'status': 'ISSUED',
                        'total': 125.5,
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Documents'), findsNothing);
      await tester.tap(find.text('Issued invoice'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final docs = tester.getRect(find.byKey(const Key('documents')));
      final voidAction = tester.getRect(find.byKey(const Key('void')));
      final returnAction = tester.getRect(find.byKey(const Key('return')));
      expect(
        tester.getRect(find.byType(RecordNotice)).bottom,
        lessThan(docs.top),
      );
      expect(
        tester.getRect(find.byType(RecordDetails)).top,
        greaterThan(returnAction.bottom),
      );
      if (width < 600) {
        expect(voidAction.left, docs.left);
        expect(returnAction.left, docs.left);
        expect(voidAction.width, docs.width);
        expect(returnAction.width, docs.width);
        expect(returnAction.top, greaterThan(voidAction.bottom));
      } else if (width >= 1000) {
        expect(voidAction.top, docs.top);
        expect(returnAction.top, docs.top);
      }
      await tester.ensureVisible(find.byKey(const Key('return')));
      await tester.tap(find.byKey(const Key('return')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
