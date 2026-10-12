import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/documents/data/html_document_design.dart';
import 'package:tpc_invoice/features/documents/data/shared_record_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const company = 'ccccccccccccccccccccccccccccccccccccccccccc';
  const record = 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';
  const origin = 'https://api.test';

  test(
      'local design migrates online once and later sessions use the online source',
      () async {
    final local = '$defaultHtmlDocumentDesign<p>Existing design</p>';
    final scope = '$origin|$company|Invoices';
    // Uri.toString includes no trailing slash for this origin.
    SharedPreferences.setMockInitialValues({
      'html-document-design-v1:${Uri.encodeComponent(scope)}': local,
    });
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
    expect(
        await HtmlDocumentDesignStore(api, company, 'Invoices').load(), local);
    expect(writes, 1);
    SharedPreferences.setMockInitialValues({});
    expect(
        await HtmlDocumentDesignStore(api, company, 'Invoices').load(), local);
    expect(writes, 1);
  });

  test(
      'employees load the company source and PDF bytes from employee endpoints',
      () async {
    SharedPreferences.setMockInitialValues({});
    final calls = <String>[];
    final api = SaasApi(
        origin: origin,
        client: MockClient((request) async {
          calls.add(request.url.path);
          expect(request.method, 'GET');
          if (request.url.path.contains('/record-pdf/')) {
            return http.Response('%PDF-company-html', 200);
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
    final bytes = await sharedRecordPdf(api, company, 'Quotations', record,
        employee: true);
    expect(utf8.decode(bytes), '%PDF-company-html');
    expect(calls, [
      '/v1/employee/companies/$company/document-designs/Quotations',
      '/v1/employee/companies/$company/record-pdf/Quotations/$record',
    ]);
  });
}
