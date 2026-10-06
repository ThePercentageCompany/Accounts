import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/reports/presentation/report_grid.dart';

void main() {
  for (final width in [320.0, 1366.0]) {
    testWidgets('multiple expanded desktop grids at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final outer = ScrollController();
      addTearDown(outer.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark().copyWith(platform: TargetPlatform.windows),
          home: Scaffold(
            body: SingleChildScrollView(
              controller: outer,
              child: Column(
                children: [
                  for (var table = 0; table < 2; table++)
                    ExpansionTile(
                      title: Text('Table $table'),
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ReportGrid(
                          headers: const ['Account', 'Debit', 'Credit'],
                          numeric: const {1, 2},
                          dense: false,
                          rows: [
                            for (var row = 0; row < 30; row++)
                              [
                                Text('Account $row'),
                                Text('$row'),
                                Text('$row'),
                              ],
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      for (var table = 0; table < 2; table++) {
        final title = find.text('Table $table');
        await tester.ensureVisible(title);
        await tester.tap(title);
        for (var frame = 0; frame < 15; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpAndSettle();
      final grids = find.byType(ReportGrid);
      final controllers = <ScrollController>{};
      for (var table = 0; table < 2; table++) {
        final horizontal = tester.widget<SingleChildScrollView>(
          find.descendant(
            of: grids.at(table),
            matching: find.byType(SingleChildScrollView),
          ),
        );
        final vertical = tester.widget<ListView>(
          find.descendant(of: grids.at(table), matching: find.byType(ListView)),
        );
        for (final controller in [
          horizontal.controller!,
          vertical.controller!,
        ]) {
          expect(controllers.add(controller), isTrue);
          expect(controller.positions.length, 1);
          expect(controller.position.viewportDimension.isFinite, isTrue);
          expect(controller.position.maxScrollExtent.isFinite, isTrue);
          controller.jumpTo(controller.position.maxScrollExtent);
        }
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
