import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/auth/presentation/cubit/saas_session.dart';

final employee = <String, dynamic>{
  'employeeId': 'e' * 43,
  'companyId': 'c' * 43,
  'role': 'Accountant',
  'allowedSections': ['Invoices', 'Quotations'],
  'writableSections': ['Invoices', 'Quotations'],
};
http.Response json(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status);
http.Response expired() => json({
  'error': {'code': 'EMPLOYEE_SESSION_EXPIRED', 'message': 'Renew session'},
}, 401);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'late expiry from an older request reuses the completed renewal',
    () async {
      final lateResponse = Completer<void>();
      var renewals = 0, recordReads = 0, renewed = false;
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/refresh')) {
            renewals++;
            renewed = true;
            return json({'employee': employee});
          }
          if (request.url.path.contains('/records/')) {
            recordReads++;
            if (recordReads == 1) {
              await lateResponse.future;
              return expired();
            }
            return json({'records': []});
          }
          return renewed ? json({'employee': employee}) : expired();
        }),
      );
      addTearDown(api.close);
      final pending = api.records('c' * 43, 'Invoices', employee: true);
      await api.employeeMe();
      lateResponse.complete();
      await pending;
      expect(renewals, 1);
      expect(recordReads, 2);
    },
  );

  test('parallel expired reads share renewal and retry once', () async {
    var renewals = 0, renewed = false;
    final gate = Completer<void>();
    final api = SaasApi(
      origin: 'https://api.test',
      cacheStore: MemoryCacheStore(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/refresh')) {
          renewals++;
          await gate.future;
          renewed = true;
          return json({
            'employee': employee,
            'expiresAt': DateTime.now()
                .add(const Duration(hours: 8))
                .millisecondsSinceEpoch,
          });
        }
        return renewed ? json({'records': []}) : expired();
      }),
    );
    addTearDown(api.close);
    api.useVerifiedWorkspace('c' * 43, employee: employee);
    final reads = Future.wait([
      api.records('c' * 43, 'Invoices', employee: true),
      api.records('c' * 43, 'Quotations', employee: true),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete();
    await reads;
    expect(renewals, 1);
    expect(api.cache.scope, isNotNull);
  });

  test(
    'employee restoration honors last login mode even when owner cookie is also valid',
    () async {
      SharedPreferences.setMockInitialValues({
        'tpc_saas_session_mode': 'employee',
      });
      final paths = <String>[];
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          paths.add(request.url.path);
          return json({'employee': employee});
        }),
      );
      addTearDown(api.close);
      final session = SaasSession(api, await SharedPreferences.getInstance());
      addTearDown(session.close);
      await session.restore();
      expect(paths, ['/v1/employee/me']);
      expect(session.owner, isNull);
      expect(session.employee?['employeeId'], employee['employeeId']);
    },
  );

  test(
    'proxy authentication-looking failures and network saves never trigger logout or replay',
    () async {
      var calls = 0, signouts = 0;
      final api = SaasApi(
        origin: 'https://api.test',
        cacheStore: MemoryCacheStore(),
        client: MockClient((request) async {
          calls++;
          if (request.method == 'POST') {
            throw http.ClientException('Connection lost');
          }
          return http.Response('<html>Proxy failure</html>', 401);
        }),
      );
      addTearDown(api.close);
      api.onAccessRevoked = () => signouts++;
      api.useVerifiedWorkspace('c' * 43, employee: employee);
      await expectLater(
        api.records('c' * 43, 'Invoices', employee: true),
        throwsA(isA<SaasApiException>()),
      );
      expect(signouts, 0);
      expect(api.cache.scope, isNotNull);
      await expectLater(
        api.sync('c' * 43, [], employee: true),
        throwsA(isA<SaasApiException>()),
      );
      expect(calls, 2);
    },
  );

  test(
    'permission changes after renewal update scope without logging out',
    () async {
      final updated = {...employee, 'writableSections': <String>[]};
      var changed = 0;
      final api = SaasApi(
        origin: 'https://api.test',
        cacheStore: MemoryCacheStore(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/refresh')) {
            return json({'employee': updated});
          }
          return expired();
        }),
      );
      addTearDown(api.close);
      api.useVerifiedWorkspace('c' * 43, employee: employee);
      final scope = api.cache.scope;
      api.onEmployeeChanged = (value) {
        changed++;
        expect(value['writableSections'], isEmpty);
      };
      await expectLater(
        api.records('c' * 43, 'Invoices', employee: true),
        throwsA(
          isA<SaasApiException>().having(
            (e) => e.code,
            'code',
            'CONTEXT_CHANGED',
          ),
        ),
      );
      expect(changed, 1);
      expect(api.cache.scope, isNot(scope));
      expect(api.cache.scope, isNotNull);
    },
  );

  test(
    'sync retries the identical operation only after explicit renewable expiry',
    () async {
      final bodies = <String>[];
      var renewals = 0;
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/refresh')) {
            renewals++;
            return json({'employee': employee});
          }
          bodies.add(request.body);
          return bodies.length == 1 ? expired() : json({'results': []});
        }),
      );
      addTearDown(api.close);
      final operation = {
        'operationId': 'stable_operation_123',
        'table': 'Invoices',
        'action': 'create',
        'expectedVersion': 0,
        'values': <String, Object?>{},
      };
      await api.sync('c' * 43, [operation], employee: true);
      expect(bodies.length, 2);
      expect(bodies.first, bodies.last);
      expect(renewals, 1);
    },
  );

  test(
    'repeated expiry stops after one renewal and invalid sessions never renew',
    () async {
      for (final code in [
        'EMPLOYEE_SESSION_EXPIRED',
        'EMPLOYEE_SESSION_INVALID',
      ]) {
        var renewals = 0, reads = 0;
        final api = SaasApi(
          origin: 'https://api.test',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/refresh')) {
              renewals++;
              return json({'employee': employee});
            }
            reads++;
            return json({
              'error': {'code': code, 'message': 'Session ended'},
            }, 401);
          }),
        );
        await expectLater(api.employeeMe(), throwsA(isA<SaasApiException>()));
        expect(renewals, code == 'EMPLOYEE_SESSION_EXPIRED' ? 1 : 0);
        expect(reads, code == 'EMPLOYEE_SESSION_EXPIRED' ? 2 : 1);
        api.close();
      }
    },
  );

  test(
    'resource denial purges that resource while preserving session and other cached records',
    () async {
      var denied = false, signouts = 0;
      final store = MemoryCacheStore();
      final api = SaasApi(
        origin: 'https://api.test',
        cacheStore: store,
        client: MockClient((request) async {
          if (denied && request.url.path.endsWith('/Invoices')) {
            return json({
              'error': {
                'code': 'SECTION_FORBIDDEN',
                'message': 'Section not assigned',
              },
            }, 403);
          }
          return json({
            'records': [
              {'recordId': 'record'},
            ],
          });
        }),
      );
      addTearDown(api.close);
      api.onAccessRevoked = () => signouts++;
      api.useVerifiedWorkspace('c' * 43, employee: employee);
      await api.records('c' * 43, 'Invoices', employee: true);
      await api.records('c' * 43, 'Quotations', employee: true);
      denied = true;
      await expectLater(
        api.records('c' * 43, 'Invoices', employee: true, force: true),
        throwsA(isA<SaasApiException>()),
      );
      expect(signouts, 0);
      expect(api.cache.scope, isNotNull);
      expect(api.cache.state('/v1/employee/records/Invoices')?.data, isNull);
      expect(
        api.cache.state('/v1/employee/records/Quotations')?.data,
        isNotNull,
      );
    },
  );

  test('renewal failure clears cached identity in a controlled way', () async {
    var signouts = 0;
    final api = SaasApi(
      origin: 'https://api.test',
      cacheStore: MemoryCacheStore(),
      client: MockClient(
        (request) async => request.url.path.endsWith('/refresh')
            ? json({
                'error': {
                  'code': 'EMPLOYEE_SESSION_INVALID',
                  'message': 'Sign in again',
                },
              }, 401)
            : expired(),
      ),
    );
    addTearDown(api.close);
    api.onAccessRevoked = () => signouts++;
    api.useVerifiedWorkspace('c' * 43, employee: employee);
    await expectLater(
      api.records('c' * 43, 'Invoices', employee: true),
      throwsA(isA<SaasApiException>()),
    );
    expect(signouts, 1);
    expect(api.cache.scope, isNull);
  });

  test(
    'refresh restores the selected authorized workspace and logout removes its selection',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final companies = [
        for (final id in ['a', 'b'])
          {'companyId': id * 43, 'name': id, 'stage': 'READY'},
      ];
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          if (request.url.path == '/v1/me') {
            return json({
              'owner': {'ownerId': 'owner'},
            });
          }
          if (request.url.path.endsWith('/setup')) {
            return json({'company': companies.last});
          }
          if (request.url.path.endsWith('/logout')) {
            return http.Response('', 204);
          }
          return json({'companies': companies});
        }),
      );
      addTearDown(api.close);
      final first = SaasSession(api, prefs);
      await first.restore();
      await first.selectCompany('b' * 43);
      await first.rememberWorkspace(true);
      await first.close();
      final restored = SaasSession(api, prefs);
      addTearDown(restored.close);
      await restored.restore();
      expect(restored.company?['companyId'], 'b' * 43);
      expect(restored.restoreWorkspace, isTrue);
      await restored.signOut();
      expect(restored.owner, isNull);
      expect(api.cache.scope, isNull);
      expect(prefs.getString('tpc_saas_selected_company_owner'), isNull);
    },
  );
}
