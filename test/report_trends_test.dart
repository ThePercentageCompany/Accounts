import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/reports/data/report_format.dart';
import 'package:tpc_invoice/features/reports/presentation/workspace_dashboard.dart';
import 'package:tpc_invoice/features/reports/presentation/report_trends.dart';

void main() {
  for (final count in [0, 1, 120]) {
    testWidgets('trend lifecycle with $count rows, resizing and large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              key: const PageStorageKey('report-page'),
              child: ReportTrends(
                format: const ReportFormat(datePattern: 'yyyy-MM-dd EEEEEE'),
                trends: [
                  for (var i = 0; i < count; i++)
                    {
                      'from': '2026-01-01',
                      'asOf': null,
                      'income': i == 0 ? 'NaN' : '1234.56',
                      'expenses': null,
                      'netProfit': '-12.34',
                    },
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (count == 0) {
        expect(find.text('No trend data for this period.'), findsOneWidget);
      } else {
        expect(find.text('Graph unavailable for this report.'), findsOneWidget);
        final tile = find.text('View exact trend data');
        final page = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        for (var i = 0; i < 3; i++) {
          await tester.ensureVisible(tile);
          // Ensure the report page has saved a numeric offset before the tile
          // writes its expansion flag into the same PageStorage bucket.
          page.position.jumpTo(page.position.pixels + 1);
          await tester.pumpAndSettle();
          await tester.tap(tile);
          for (var frame = 0; frame < 16; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.takeException(), isNull);
          }
          expect(
            PageStorage.of(page.context).readState(page.context),
            isA<double>(),
          );
          tester.view.physicalSize = i.isEven
              ? const Size(1366, 600)
              : const Size(600, 1366);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('-12.34'), findsNWidgets(count));
          await tester.ensureVisible(tile);
          await tester.tap(tile);
          await tester.pumpAndSettle();
        }
        await tester.tap(tile);
        await tester.pumpAndSettle();
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Other page')),
          ),
        );
        await tester.pumpAndSettle();
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('Net profit'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0, 1366.0]) {
    for (final largeText in [false, true]) {
      testWidgets('exact trend expansion at $width, large text=$largeText', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final outer = ScrollController();
        addTearDown(outer.dispose);
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
                key: const PageStorageKey('report-page'),
                controller: outer,
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
        expect(
          find.byKey(const Key('exact-trend-vertical-scroll')),
          findsNothing,
        );
        for (final key in ['exact-trend-horizontal-scroll']) {
          final position = tester
              .widget<SingleChildScrollView>(find.byKey(PageStorageKey(key)))
              .controller!
              .position;
          expect(position.viewportDimension.isFinite, isTrue);
          expect(position.maxScrollExtent.isFinite, isTrue);
        }
        await tester.ensureVisible(find.text('From'));
        await tester.dragFrom(const Offset(100, 500), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(find.text('-119.00'), findsOneWidget);
        expect(outer.offset, greaterThan(0));
        await tester.ensureVisible(find.text('From'));
        await tester.dragFrom(
          tester.getTopLeft(grid) + const Offset(40, 20),
          const Offset(-800, 0),
        );
        await tester.pumpAndSettle();
        if (width < 800) {
          expect(
            tester
                .widget<SingleChildScrollView>(
                  find.byKey(
                    const PageStorageKey('exact-trend-horizontal-scroll'),
                  ),
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
