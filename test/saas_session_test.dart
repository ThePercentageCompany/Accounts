import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/auth/presentation/cubit/saas_session.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:tpc_invoice/core/offline/offline_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('revoked employee session clears the restored offline identity',
      () async {
    SharedPreferences.setMockInitialValues({});
    final api = SaasApi(
      origin: 'https://api.test',
      offlineStore: IndexedOfflineStore(newIdbFactoryMemory()),
      offlineAutomatic: false,
      client: MockClient((_) async => http.Response(
          jsonEncode({
            'error': {'code': 'UNAUTHORIZED', 'message': 'Sign in.'}
          }),
          401)),
    );
    await api.saveSessionProfile({
      'expiresAt': DateTime.now().millisecondsSinceEpoch + 60000,
      'employee': {'employeeId': 'e' * 43, 'companyId': 'c' * 43},
      'companies': <Object>[],
    });
    final session = SaasSession(api, await SharedPreferences.getInstance());
    expect(await session.restoreCachedSession(), isTrue);
    await session.restore(employeeOnly: true);
    expect(session.employee, isNull);
    expect(await api.offlineSessionProfile(), isNull);
    await session.close();
    api.close();
  });
  test(
      'offline profile restores without secrets, expires and is removed at logout',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var offline = false;
    final api = SaasApi(
        origin: 'https://api.test',
        offlineStore: IndexedOfflineStore(newIdbFactoryMemory()),
        offlineAutomatic: false,
        client: MockClient((r) async {
          if (offline) throw http.ClientException('offline');
          if (r.url.path == '/v1/me') {
            return http.Response(
                jsonEncode({
                  'owner': {
                    'ownerId': 'o' * 43,
                    'name': 'Owner',
                    'accessToken': 'must-not-be-stored',
                  }
                }),
                200);
          }
          if (r.url.path == '/v1/companies') {
            return http.Response(
                jsonEncode({
                  'companies': [
                    {
                      'companyId': 'c' * 43,
                      'name': 'Company',
                      'stage': 'READY',
                    }
                  ]
                }),
                200);
          }
          return http.Response('{}', 200);
        }));
    final first = SaasSession(api, prefs);
    await first.restore();
    final profile = await api.offlineSessionProfile();
    expect(jsonEncode(profile), isNot(contains('must-not-be-stored')));
    final expiry = profile!['expiresAt'];
    await first.close();
    offline = true;
    final restored = SaasSession(api, prefs);
    expect(await restored.restoreCachedSession(), isTrue);
    await restored.restore();
    expect(restored.owner?['ownerId'], 'o' * 43);
    expect(restored.ready, isTrue);
    expect((await api.offlineSessionProfile())!['expiresAt'], expiry);
    offline = false;
    await restored.signOut();
    expect(await api.offlineSessionProfile(), isNull);
    await api.saveSessionProfile({...profile, 'expiresAt': 0});
    expect(await api.offlineSessionProfile(), isNull);
    await restored.close();
    api.close();
  });
  test(
    'session emits immutable busy and signed-in snapshots and closes safely',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'employee': {
                'employeeId': 'e' * 43,
                'companyId': 'c' * 43,
                'fullName': 'Alex',
                'allowedSections': ['Invoices'],
              },
            }),
            200,
          ),
        ),
      );
      final session = SaasSession(api, await SharedPreferences.getInstance());
      final states = <SessionState>[];
      final subscription = session.stream.listen(states.add);
      await session.employeeLogin('i' * 43, '123456');
      await Future<void>.delayed(Duration.zero);
      expect(states.first.busy, isTrue);
      expect(states.last.busy, isFalse);
      expect(states.last.employee?['fullName'], 'Alex');
      expect(
        () => states.last.employee!['fullName'] = 'Changed',
        throwsUnsupportedError,
      );
      session.employee!['fullName'] = 'Mutable working value';
      expect(states.last.employee?['fullName'], 'Alex');
      await session.close();
      expect(session.isClosed, isTrue);
      expect(api.onAccessRevoked, isNull);
      await subscription.cancel();
      api.close();
    },
  );
  test(
    'workspace deletion clears tenant queues and preserves other workspaces',
    () async {
      final id = 'c' * 43;
      SharedPreferences.setMockInitialValues({
        'saas_records_owner_${id}_op': '{}',
        'saas_document_owner_$id': '{}',
        'saas_employee_write_owner_$id': '{}',
        'saas_records_owner_other_op': '{}',
      });
      final prefs = await SharedPreferences.getInstance();
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/v1/companies/$id');
          return http.Response('{"deleted":true}', 200);
        }),
      );
      final session = SaasSession(api, prefs);
      session.owner = {'ownerId': 'owner'};
      session.company = {'companyId': id, 'name': 'Company', 'stage': 'READY'};
      session.companies = [session.company!];
      await session.deleteCompany();
      expect(session.company, isNull);
      expect(session.companies, isEmpty);
      expect(prefs.getKeys(), {'saas_records_owner_other_op'});
      session.dispose();
      api.close();
    },
  );
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
