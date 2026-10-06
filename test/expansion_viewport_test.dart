import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/reports/presentation/report_grid.dart';
import 'package:tpc_invoice/features/reports/presentation/financial_report_body.dart';
import 'package:tpc_invoice/features/reports/data/report_format.dart';

void main() {
  for (final kind in ['profit-and-loss', 'general-ledger']) {
    testWidgets('$kind tiles at mobile width with 300% text', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              key: const PageStorageKey('financial-report-page'),
              child: FinancialReportBody(
                kind: kind,
                dense: false,
                format: const ReportFormat(datePattern: 'yyyy-MM-dd EEEEEE'),
                data: {
                  'trends': [
                    {
                      'from': '2026-01-01',
                      'asOf': null,
                      'income': '1234.56',
                      'expenses': null,
                      'netProfit': '-12.34',
                    },
                  ],
                },
                rows: [
                  {
                    'accountId': 'sales',
                    'accountCode': '4000',
                    'accountName': 'Sales',
                    'accountGroup': 'Income',
                    'amount': '1234.56',
                    'opening': null,
                    'closing': '1234.56',
                    'entries': [
                      for (var i = 0; i < 60; i++)
                        {
                          'date': '2026-01-01',
                          'journalId': '$i',
                          'lineNumber': i,
                          'description': 'Posted activity',
                          'sourceType': 'Invoice',
                          'debit': null,
                          'credit': '1234.56',
                          'balance': '1234.56',
                        },
                    ],
                  },
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final tiles = find.byType(ExpansionTile);
      for (var i = 0; i < tiles.evaluate().length; i++) {
        final tile = tester.widget<ExpansionTile>(tiles.at(i));
        final title = find.descendant(
          of: tiles.at(i),
          matching: find.byWidget(tile.title),
        );
        for (var cycle = 0; cycle < 2; cycle++) {
          await tester.ensureVisible(title);
          await tester.tap(title);
          for (var frame = 0; frame < 16; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.takeException(), isNull);
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

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
              key: const PageStorageKey('grid-report-page'),
              controller: outer,
              child: Column(
                children: [
                  for (var table = 0; table < 2; table++)
                    ExpansionTile(
                      key: PageStorageKey('table-$table'),
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
      // Destroy and recreate both viewports with the same PageStorage bucket.
      // Before the fix, restoreScrollOffset read the tile's bool as double?.
      for (var table = 0; table < 2; table++) {
        final title = find.text('Table $table');
        for (var cycle = 0; cycle < 2; cycle++) {
          await tester.ensureVisible(title);
          await tester.tap(title);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        final vertical = tester.widget<ListView>(
          find.descendant(
            of: find.byType(ReportGrid).at(table),
            matching: find.byType(ListView),
          ),
        );
        expect(
          vertical.controller!.offset,
          vertical.controller!.position.maxScrollExtent,
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
