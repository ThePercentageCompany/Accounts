import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/features/documents/data/html_document_design.dart';
import 'package:tpc_invoice/features/documents/presentation/html_document_design_editor.dart';

void main() {
  testWidgets('HTML editor fits narrow mobile screens', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HtmlDocumentDesignEditor(
            store: HtmlDocumentDesignStore('mobile-test'),
            preview: (source) async => source,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Save design'));
    await tester.tap(find.text('Save design'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('editor updates a saved design', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = HtmlDocumentDesignStore('editor-test');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HtmlDocumentDesignEditor(
            store: store,
            preview: (source) async => source,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '$defaultHtmlDocumentDesign<p>Updated brand</p>',
    );
    await tester.ensureVisible(find.text('Save design'));
    await tester.tap(find.text('Save design'));
    await tester.pumpAndSettle();
    expect(await store.load(), contains('Updated brand'));
    expect(find.text('Design saved on this device.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'saved totals and text are inserted without interpreting customer HTML',
    () {
      final html = renderHtmlDocument(
        source: defaultHtmlDocumentDesign,
        section: 'Invoices',
        record: {'total': 105.25, 'dueDate': '2026-10-30'},
        company: {},
        customer: {'name': '<script>alert(1)</script>'},
        items: [
          {'description': '<b>Service</b>', 'lineTotal': 105.25},
        ],
      );
      expect(html, contains('105.25'));
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('&lt;b&gt;Service&lt;&#47;b&gt;'));
      expect(html, contains('2026-10-30'));
      expect(html, contains('Content-Security-Policy'));
      expect(html, isNot(contains('{{items}}')));
    },
  );
  test('quotation uses validity and unsupported designs fail visibly', () {
    final html = renderHtmlDocument(
      source: defaultHtmlDocumentDesign,
      section: 'Quotations',
      record: {'total': 5, 'validUntil': '2026-11-01'},
      company: {},
      customer: {},
      items: [],
    );
    expect(html, contains('QUOTATION'));
    expect(html, contains('2026-11-01'));
    expect(
      () => validateHtmlDocumentDesign('<p>Missing totals</p>'),
      throwsFormatException,
    );
    expect(
      () => validateHtmlDocumentDesign('{{items}}{{record.total}}{{unknown}}'),
      throwsFormatException,
    );
  });
  test(
    'templates persist independently by workspace and document type',
    () async {
      SharedPreferences.setMockInitialValues({});
      final invoice = HtmlDocumentDesignStore('workspace-a|Invoices');
      final quotation = HtmlDocumentDesignStore('workspace-a|Quotations');
      final other = HtmlDocumentDesignStore('workspace-b|Invoices');
      await invoice.save('$defaultHtmlDocumentDesign<p>Custom</p>');
      expect(await invoice.load(), contains('Custom'));
      expect(await quotation.load(), defaultHtmlDocumentDesign);
      expect(await other.load(), defaultHtmlDocumentDesign);
    },
  );
}
