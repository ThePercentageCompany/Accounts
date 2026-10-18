import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/documents/data/html_document_design.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const company = 'ccccccccccccccccccccccccccccccccccccccccccc';
  const record = 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';
  const origin = 'https://api.test';

  for (final pair in [
    ('Credit note', 'CreditNotes'),
    ('Payslip', 'Payroll'),
    ('Receipt', 'Receipts')
  ]) {
    test('${pair.$1} load, save and preview use the same connected endpoint',
        () async {
      final paths = <String>[];
      final api = SaasApi(
          origin: 'https://project.supabase.co',
          client: MockClient((request) async {
            paths.add('${request.method} ${request.url.path}');
            if (request.url.path.contains('/record-html/')) {
              return http.Response('<html>Preview</html>', 200);
            }
            return http.Response(
                jsonEncode({'source': defaultHtmlDocumentDesign, 'version': 1}),
                200);
          }));
      addTearDown(api.close);
      await api.documentDesign(company, pair.$1);
      await api.saveDocumentDesign(
          company, pair.$1, defaultHtmlDocumentDesign, 0);
      await api.recordHtml(company, pair.$1, record,
          source: defaultHtmlDocumentDesign);
      await api.documentDesign(company, pair.$1, employee: true);
      await api.recordHtml(company, pair.$1, record, employee: true);
      expect(paths, [
        'GET /functions/v1/api/v1/companies/$company/document-designs/${pair.$2}',
        'PUT /functions/v1/api/v1/companies/$company/document-designs/${pair.$2}',
        'POST /functions/v1/api/v1/companies/$company/record-html/${pair.$2}/$record',
        'GET /functions/v1/api/v1/employee/companies/$company/document-designs/${pair.$2}',
        'GET /functions/v1/api/v1/employee/companies/$company/record-html/${pair.$2}/$record',
      ]);
    });
  }

  for (final section in ['Receipts', 'CreditNotes', 'Payroll']) {
    test('$section template saves separately and prints the saved design',
        () async {
      var version = 0;
      var source = defaultHtmlDocumentDesign;
      final api = SaasApi(
          origin: origin,
          client: MockClient((request) async {
            if (request.url.path.contains('/record-html/')) {
              expect(request.url.path,
                  '/v1/companies/$company/record-html/$section/$record');
              return http.Response('<html>$section saved design</html>', 200);
            }
            expect(request.url.path,
                '/v1/companies/$company/document-designs/$section');
            if (request.method == 'PUT') {
              final input = jsonDecode(request.body) as Map;
              expect(input['expectedVersion'], version);
              source = input['source'];
              version++;
            }
            return http.Response(
                jsonEncode({'source': source, 'version': version}), 200);
          }));
      addTearDown(api.close);
      final store = HtmlDocumentDesignStore(api, company, section);
      await store.load();
      await store.save('$defaultHtmlDocumentDesign<p>$section</p>');
      expect(await store.load(), contains('<p>$section</p>'));
      expect(await savedRecordHtml(api, company, section, record),
          '<html>$section saved design</html>');
      expect(version, 1);
    });
  }

  for (final employee in [false, true]) {
    test(
        'final HTML uses the online company design for ${employee ? 'employee' : 'admin'}',
        () async {
      final api = SaasApi(
          origin: origin,
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.body, isEmpty);
            expect(request.url.path,
                '/v1/${employee ? 'employee/' : ''}companies/$company/record-html/Invoices/$record');
            return http.Response(
                '<html>Latest saved company design</html>', 200);
          }));
      addTearDown(api.close);
      expect(
          await savedRecordHtml(api, company, 'Invoices', record,
              employee: employee),
          '<html>Latest saved company design</html>');
    });
  }

  test('saved online design is available to later sessions', () async {
    final local = '$defaultHtmlDocumentDesign<p>Existing design</p>';
    SharedPreferences.setMockInitialValues({});
    var version = 0, writes = 0;
    var source = defaultHtmlDocumentDesign;
    final api = SaasApi(
        origin: origin,
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            final input = jsonDecode(request.body) as Map;
            expect(input['expectedVersion'], version);
            source = input['source'] as String;
            version++;
            writes++;
          }
          return http.Response(
              jsonEncode({'source': source, 'version': version}), 200);
        }));
    addTearDown(api.close);
    final firstSession = HtmlDocumentDesignStore(api, company, 'Invoices');
    expect(await firstSession.load(), defaultHtmlDocumentDesign);
    await firstSession.save(local);
    expect(writes, 1);
    SharedPreferences.setMockInitialValues({});
    expect(
        await HtmlDocumentDesignStore(api, company, 'Invoices').load(), local);
    expect(writes, 1);
  });

  test('employees load the company source and HTML from employee endpoints',
      () async {
    SharedPreferences.setMockInitialValues({});
    final calls = <String>[];
    final api = SaasApi(
        origin: origin,
        client: MockClient((request) async {
          calls.add(request.url.path);
          expect(request.method, 'GET');
          if (request.url.path.contains('/record-html/')) {
            return http.Response('<html>Company design</html>', 200);
          }
          return http.Response(
              jsonEncode({'source': defaultHtmlDocumentDesign, 'version': 2}),
              200);
        }));
    addTearDown(api.close);
    final store =
        HtmlDocumentDesignStore(api, company, 'Quotations', employee: true);
    expect(await store.load(), defaultHtmlDocumentDesign);
    await expectLater(store.save(defaultHtmlDocumentDesign), throwsStateError);
    final html =
        await api.recordHtml(company, 'Quotations', record, employee: true);
    expect(html, '<html>Company design</html>');
    expect(calls, [
      '/v1/employee/companies/$company/document-designs/Quotations',
      '/v1/employee/companies/$company/record-html/Quotations/$record',
    ]);
  });
}
