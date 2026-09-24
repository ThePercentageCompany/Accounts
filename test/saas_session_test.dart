import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/saas/saas_api.dart';
import 'package:tpc_invoice/core/saas/saas_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final companyId = 'c' * 43;
  final company = {'companyId': companyId, 'name': 'Company', 'stage': 'READY'};
  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status);

  test(
    'lost registration response reuses persisted key after restart',
    () async {
      SharedPreferences.setMockInitialValues({
        'tpc_pending_sync_queue': 'keep',
      });
      final preferences = await SharedPreferences.getInstance();
      final keys = <String>[];
      var created = false;
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          if (r.url.path == '/v1/me') {
            return json({
              'owner': {'ownerId': 'owner-a'},
            });
          }
          if (r.method == 'GET') {
            return json({
              'companies': created ? [company] : [],
            });
          }
          keys.add(r.headers['Idempotency-Key']!);
          created = true;
          if (keys.length == 1) throw http.ClientException('Lost response');
          return json({'company': company});
        }),
      );
      final first = SaasSession(api, preferences);
      await first.restore();
      await first.createCompany('Company');
      expect(first.error, isNotNull);
      first.dispose();
      final resumed = SaasSession(api, preferences);
      await resumed.restore();
      expect(resumed.pendingCompanyName, 'Company');
      await resumed.createCompany('Different name');
      expect(keys, hasLength(1));
      await resumed.createCompany('Company');
      expect(keys, hasLength(2));
      expect(keys.first, keys.last);
      expect(resumed.error, isNull);
      expect(resumed.ready, isTrue);
      expect(preferences.containsKey('tpc_saas_registration_owner-a'), isFalse);
      expect(preferences.getString('tpc_pending_sync_queue'), 'keep');
      resumed.dispose();
      api.close();
    },
  );

  test(
    'unknown company is rejected and expired session clears displayed data',
    () async {
      SharedPreferences.setMockInitialValues({});
      var setupRequests = 0;
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          if (r.url.path == '/v1/me') {
            return json({
              'owner': {'ownerId': 'owner-a'},
            });
          }
          if (r.url.path == '/v1/companies') {
            return json({
              'companies': [company],
            });
          }
          setupRequests++;
          return json({
            'error': {'code': 'UNAUTHORIZED', 'message': 'Sign in.'},
          }, 401);
        }),
      );
      final session = SaasSession(api, await SharedPreferences.getInstance());
      await session.restore();
      await session.selectCompany('x' * 43);
      expect(setupRequests, 0);
      await session.refreshSetup();
      expect(setupRequests, 1);
      expect(session.owner, isNull);
      expect(session.company, isNull);
      expect(session.companies, isEmpty);
      session.dispose();
      api.close();
    },
  );

  test(
    'logout failure retains session; successful logout preserves local edits',
    () async {
      SharedPreferences.setMockInitialValues({
        'tpc_pending_sync_queue': 'keep',
      });
      var fail = true;
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          if (r.url.path == '/v1/me') {
            return json({
              'owner': {'ownerId': 'owner-a'},
            });
          }
          if (r.url.path == '/v1/companies') {
            return json({
              'companies': [company],
            });
          }
          if (fail) throw http.ClientException('Offline');
          return http.Response('', 204);
        }),
      );
      final prefs = await SharedPreferences.getInstance();
      final session = SaasSession(api, prefs);
      await session.restore();
      await session.signOut();
      expect(session.owner, isNotNull);
      expect(session.error, isNotNull);
      fail = false;
      await session.signOut();
      expect(session.owner, isNull);
      expect(prefs.getString('tpc_pending_sync_queue'), 'keep');
      session.dispose();
      api.close();
    },
  );
}
