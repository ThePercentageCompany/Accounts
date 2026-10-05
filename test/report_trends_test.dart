import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/reports/data/report_format.dart';
import 'package:tpc_invoice/features/reports/presentation/report_grid.dart';
import 'package:tpc_invoice/features/reports/presentation/workspace_dashboard.dart';

void main() {
  for (final width in [320.0, 390.0, 1366.0]) {
    for (final largeText in [false, true]) {
      testWidgets('exact trend expansion at $width, large text=$largeText', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: largeText ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(largeText ? 1.5 : 1)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: WorkspaceDashboard(
                  format: ReportFormat(
                    datePattern: largeText ? 'MMMM d, yyyy' : 'yyyy-MM-dd',
                  ),
                  data: {
                    'trends': [
                      for (var i = 0; i < 120; i++)
                        {
                          'from': DateTime(2016, i + 1, 1).toIso8601String(),
                          'asOf': DateTime(2016, i + 2, 0).toIso8601String(),
                          'income': 1000 + i,
                          'expenses': 1000 + i * 2,
                          'netProfit': -i,
                        },
                    ],
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final expand = find.text('View exact trend data');
        await tester.ensureVisible(expand);
        await tester.tap(expand);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Net profit'), findsOneWidget);
        final grid = find.byType(ReportGrid);
        final rows = find.descendant(of: grid, matching: find.byType(ListView));
        await tester.ensureVisible(rows);
        await tester.dragFrom(
          Offset(tester.getCenter(grid).dx, tester.getCenter(rows).dy),
          const Offset(0, -12000),
        );
        await tester.pumpAndSettle();
        expect(find.text('-119.00'), findsOneWidget);
        final horizontal = find.descendant(
          of: grid,
          matching: find.byType(SingleChildScrollView),
        );
        await tester.drag(horizontal, const Offset(-800, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(expand);
        await tester.tap(expand);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(expand);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
