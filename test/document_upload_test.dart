import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

void main() {
  const company = 'ccccccccccccccccccccccccccccccccccccccccccc';
  const record = 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr';
  const operation = '550e8400-e29b-41d4-a716-446655440000';

  for (final employee in [false, true]) {
    test('document upload matches API contract (employee: $employee)',
        () async {
      final bytes = Uint8List.fromList(utf8.encode('%PDF-1.7\n'));
      var requests = 0;
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          requests++;
          expect(request.method, 'POST');
          expect(request.url.path,
              '/v1/${employee ? 'employee/' : ''}companies/$company/documents');
          expect(request.headers['Idempotency-Key'], operation);
          // The server rejects unexpected keys, including relatedSection.
          expect(jsonDecode(request.body), {
            'name': 'invoice.pdf',
            'mimeType': 'application/pdf',
            'section': 'Invoices',
            'relatedRecordId': record,
            'data': base64Encode(bytes),
          });
          return http.Response(jsonEncode({'documentId': record}), 201);
        }),
      );
      addTearDown(api.close);

      // An uncertain upload can be retried with the same operation and bytes.
      for (var attempt = 0; attempt < 2; attempt++) {
        final result = await api.upload(company,
            operationId: operation,
            name: 'invoice.pdf',
            mimeType: 'application/pdf',
            relatedSection: 'Invoices',
            relatedRecordId: record,
            bytes: bytes,
            employee: employee);
        expect(result['documentId'], record);
      }
      expect(requests, 2);
    });
  }
}
