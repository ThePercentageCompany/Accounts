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
}
