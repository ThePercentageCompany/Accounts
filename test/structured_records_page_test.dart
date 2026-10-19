import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

void main() {
  const company = 'ccccccccccccccccccccccccccccccccccccccccccc';
  test('typed record requests send a bounded cursor and preserve page metadata',
      () async {
    final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path,
              '/v1/companies/$company/structured-records/Invoices');
          expect(
              request.url.queryParameters, {'after': '10000', 'limit': '100'});
          return http.Response(
              jsonEncode({
                'records': [
                  {'record_id': 'invoice', 'ordinal': 10001, 'total': 123.45}
                ],
                'nextCursor': 10001
              }),
              200);
        }));
    addTearDown(api.close);
    final page =
        await api.structuredRecordsPage(company, 'Invoices', after: 10000);
    expect(page['nextCursor'], 10001);
    expect((page['records'] as List).single['record_id'], 'invoice');
  });
  test('invalid cursors and unbounded page sizes never reach the server', () {
    final api = SaasApi(
        origin: 'https://api.test',
        client:
            MockClient((_) async => throw StateError('No request expected')));
    addTearDown(api.close);
    for (final limit in [0, 501]) {
      expect(() => api.structuredRecordsPage(company, 'Invoices', limit: limit),
          throwsA(isA<SaasApiException>()));
    }
    expect(() => api.structuredRecordsPage(company, 'Invoices', after: -1),
        throwsA(isA<SaasApiException>()));
  });
}
