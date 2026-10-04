import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/documents/presentation/document_editor.dart';
import 'package:tpc_invoice/features/workspace/presentation/shared_workspace.dart';

void main() {
  test('dark theme uses monochrome surfaces and actions', () {
    final theme = AppTheme.dark();
    for (final color in [
      theme.scaffoldBackgroundColor,
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.surface,
      theme.colorScheme.primaryContainer,
      theme.colorScheme.error,
      theme.colorScheme.errorContainer,
      theme.colorScheme.surfaceContainerLowest,
      theme.colorScheme.surfaceContainerLow,
      theme.colorScheme.surfaceContainer,
      theme.colorScheme.surfaceContainerHigh,
      theme.colorScheme.surfaceContainerHighest,
      theme.colorScheme.inverseSurface,
      theme.colorScheme.inversePrimary,
    ]) {
      expect(color.r, color.g);
      expect(color.g, color.b);
    }
  });

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (Platform.environment['CAPTURE_UI'] != '1') return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.dart_tool/ui-review/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final dark in [false, true]) {
    for (final size in [const Size(390, 844), const Size(1536, 1024)]) {
      testWidgets('document preview adapts to $size dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        if (Platform.environment['CAPTURE_UI'] == '1') {
          await tester.runAsync(() async {
            final font = FontLoader('Inter')
              ..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File('C:/Windows/Fonts/segoeui.ttf').readAsBytes(),
                  ),
                ),
              );
            await font.load();
            final icons = FontLoader('MaterialIcons')
              ..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File(
                      'D:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                    ).readAsBytes(),
                  ),
                ),
              );
            await icons.load();
          });
        }
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: const Scaffold(
                body: DocumentEditor(
                  quotation: false,
                  company: {
                    'name': 'ABC Service LLC',
                    'address': 'Dubai, United Arab Emirates',
                    'currency': 'AED',
                  },
                  customers: [
                    {'recordId': 'customer', 'name': 'Creative Solutions LLC'},
                  ],
                  record: {
                    'customerId': 'customer',
                    'issueDate': '2026-10-04',
                    'dueDate': '2026-11-03',
                    'currency': 'AED',
                    'paymentTerms': 'Payment is due within 30 days.',
                  },
                  items: [
                    {
                      'description': 'Website development',
                      'quantity': 1,
                      'unitPrice': 5000,
                      'discount': 0,
                      'taxRate': 5,
                    },
                    {
                      'description': 'SEO services',
                      'quantity': 1,
                      'unitPrice': 2000,
                      'discount': 0,
                      'taxRate': 5,
                    },
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Invoice preview'),
          size.width >= 1100 ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          key,
          'invoice-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        if (size.width >= 1100) {
          final price = find.widgetWithText(TextFormField, 'Unit price').first;
          await tester.ensureVisible(price);
          await tester.enterText(price, '4000');
          await tester.pump();
          expect(find.text('AED 6300.00'), findsWidgets);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final dark in [false, true]) {
    for (final width in [390.0, 1536.0]) {
      testWidgets('dashboard shell fits $width dark=$dark', (tester) async {
        tester.view.physicalSize = Size(width, 1024);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = SaasApi(
          origin: 'https://api.test',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'totalIncome': 18750,
                'journalCount': 12,
                'from': '2026-01-01',
                'asOf': '2026-10-04',
                'totalExpenses': 4200,
                'netProfit': 14550,
                'cash': 12800,
                'bank': 35200,
                'receivables': 8200,
                'payables': 2300,
                'totalAssets': 56200,
                'totalLiabilities': 2300,
                'totalEquity': 53900,
                'accounts': [],
              }),
              200,
            ),
          ),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: SharedWorkspace(
                api: api,
                companyId: 'c' * 43,
                title: 'ABC Service LLC',
                onBack: () {},
                employee: const {
                  'allowedSections': [
                    'Reports',
                    'Invoices',
                    'Quotations',
                    'Customers',
                    'Employees',
                    'Income & Expenses',
                    'Settings',
                  ],
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Financial quick view'), findsOneWidget);
        expect(
          find.byType(NavigationBar),
          width < 900 ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          key,
          'dashboard-${width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        await tester.pumpWidget(const SizedBox());
        api.close();
      });
    }
  }

  testWidgets('record refresh keeps content visible and in position', (
    tester,
  ) async {
    final refresh = Completer<http.Response>();
    var requests = 0;
    final api = SaasApi(
      origin: 'https://api.test',
      client: MockClient((_) async {
        if (++requests > 1) return refresh.future;
        return http.Response(
          '{"records":[{"recordId":"customer","name":"Existing customer"}]}',
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SharedWorkspace(
          api: api,
          companyId: 'c' * 43,
          title: 'Workspace',
          onBack: () {},
          employee: const {
            'allowedSections': ['Customers'],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('Existing customer'));
    final barriers = find.byType(ModalBarrier).evaluate().length;
    await tester.tap(find.text('Refresh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(tester.getTopLeft(find.text('Existing customer')), before);
    expect(find.byType(ModalBarrier).evaluate().length, barriers);
    refresh.complete(
      http.Response(
        '{"records":[{"recordId":"customer","name":"Existing customer"}]}',
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Existing customer')), before);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });
}
