import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/reports/data/report_format.dart';
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
            theme: (largeText ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
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
        for (var frame = 0; frame < 12; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Net profit'), findsOneWidget);
        final grid = find.byKey(const Key('exact-trend-table'));
        final rows = find.byKey(const Key('exact-trend-vertical-scroll'));
        await tester.ensureVisible(rows);
        for (final key in [
          'exact-trend-vertical-scroll',
          'exact-trend-horizontal-scroll'
        ]) {
          final position = tester
              .widget<SingleChildScrollView>(find.byKey(Key(key)))
              .controller!
              .position;
          expect(position.viewportDimension.isFinite, isTrue);
          expect(position.maxScrollExtent.isFinite, isTrue);
        }
        await tester.dragFrom(
          Offset(tester.getCenter(grid).dx, tester.getCenter(rows).dy),
          const Offset(0, -12000),
        );
        await tester.pumpAndSettle();
        expect(find.text('-119.00'), findsOneWidget);
        expect(
          tester.widget<SingleChildScrollView>(rows).controller!.offset,
          greaterThan(0),
        );
        await tester.dragFrom(tester.getCenter(grid), const Offset(-800, 0));
        await tester.pumpAndSettle();
        if (width < 800) {
          expect(
            tester
                .widget<SingleChildScrollView>(
                  find.byKey(const Key('exact-trend-horizontal-scroll')),
                )
                .controller!
                .offset,
            greaterThan(0),
          );
        }
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
