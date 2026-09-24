import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/saas/saas_api.dart';

void main() {
  test(
    'operator origin rejects insecure URLs and embedded credentials or paths',
    () {
      for (final value in [
        '',
        'http://api.test',
        'https://user:pass@api.test',
        'https://api.test/path',
        'https://api.test?x=1',
      ]) {
        expect(
          () => SaasApi(
            origin: value,
            client: MockClient((_) async => http.Response('{}', 200)),
          ),
          throwsA(isA<SaasApiException>()),
        );
      }
    },
  );
  test(
    'mutations use CSRF, stable operation keys and no bearer credentials',
    () async {
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          expect(request.url.toString(), 'https://api.test/v1/companies');
          expect(request.headers['X-TPC-CSRF'], '1');
          expect(request.headers['Idempotency-Key'], 'create_company_12345');
          expect(request.headers.containsKey('Authorization'), false);
          expect(jsonDecode(request.body), {'name': 'Company'});
          return http.Response('{"company":{"companyId":"opaque"}}', 201);
        }),
      );
      expect(
        (await api.createCompany('Company', 'create_company_12345'))['company'],
        {'companyId': 'opaque'},
      );
    },
  );
  test('partial sync failure remains visible despite HTTP success', () async {
    final api = SaasApi(
      origin: 'https://api.test',
      client: MockClient(
        (_) async => http.Response(
          '{"results":[{"operationId":"operation_12345678","status":"FAILED","error":{"code":"VERSION_CONFLICT"}}]}',
          200,
        ),
      ),
    );
    final result = await api.sync('c' * 43, []);
    expect(result['results'][0]['status'], 'FAILED');
  });
  test(
    'expired sessions and non-JSON proxy errors are explicit failures',
    () async {
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient(
          (_) async => http.Response(
            '{"error":{"code":"UNAUTHORIZED","message":"Sign in"}}',
            401,
          ),
        ),
      );
      await expectLater(
        api.me(),
        throwsA(
          isA<SaasApiException>().having(
            (e) => e.requiresSignIn,
            'requires sign in',
            true,
          ),
        ),
      );
      final proxy = SaasApi(
        origin: 'https://api.test',
        client: MockClient((_) async => http.Response('<html>404</html>', 404)),
      );
      await expectLater(
        proxy.me(),
        throwsA(
          isA<SaasApiException>().having(
            (e) => e.code,
            'safe code',
            'SERVICE_UNAVAILABLE',
          ),
        ),
      );
    },
  );
  test('QR links cannot change the trusted app or API origin', () {
    final app = Uri.parse('https://app.test');
    final invite = 'i' * 43;
    expect(
      SaasApi.invitation(
        Uri.parse('https://app.test/#employee-invite=$invite'),
        app,
      ),
      invite,
    );
    expect(
      SaasApi.invitation(
        Uri.parse('https://evil.test/#employee-invite=$invite'),
        app,
      ),
      null,
    );
    expect(
      SaasApi.invitation(
        Uri.parse(
          'https://app.test/?api=https://evil.test#employee-invite=$invite',
        ),
        app,
      ),
      null,
    );
  });
}
