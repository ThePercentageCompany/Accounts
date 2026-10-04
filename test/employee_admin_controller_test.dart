import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/employees/presentation/cubit/employee_admin_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'employee Cubit publishes refresh state without mutating old snapshots',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient(
          (_) async => http.Response(
            '{"employees":[{"employeeId":"employee","fullName":"Alex"}]}',
            200,
          ),
        ),
      );
      final controller = EmployeeAdminController(
        api,
        await SharedPreferences.getInstance(),
        'owner',
        'c' * 43,
      );
      final states = <EmployeeAdminState>[];
      final subscription = controller.stream.listen(states.add);
      await controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(states.first.busy, isTrue);
      expect(states.last.busy, isFalse);
      expect(states.last.employees.single['fullName'], 'Alex');
      controller.employees.single['fullName'] = 'Updated';
      expect(states.last.employees.single['fullName'], 'Alex');
      expect(() => states.last.employees.clear(), throwsUnsupportedError);
      await controller.close();
      await subscription.cancel();
      api.close();
    },
  );
  final company = 'c' * 43;
  final employee = 'e' * 43;
  final values = <String, Object?>{
    'fullName': 'Alex',
    'role': 'Staff',
    'employmentStatus': 'ACTIVE',
    'allowedSections': ['Payroll'],
    'expectedVersion': 0,
  };

  test(
    'permission edit rejected by old API recovers without changing its key',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final writes = <http.Request>[];
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response('{"employees":[]}', 200);
          }
          writes.add(r);
          if (writes.length == 1) {
            return http.Response(
              '{"error":{"code":"INVALID_EMPLOYEE","message":"Unsupported employee fields."}}',
              400,
            );
          }
          if (writes.length == 2) {
            throw http.ClientException('Lost retry response');
          }
          return http.Response('{"version":2}', 200);
        }),
      );
      final c = EmployeeAdminController(api, prefs, 'owner', company);
      await c.save(employee, {
        ...values,
        'allowedSections': ['Customers'],
        'writableSections': ['Customers'],
        'expectedVersion': 1,
      });
      expect(c.canDiscardRejected, isTrue);
      await c.retry();
      expect(c.hasPending, isTrue);
      expect(c.canDiscardRejected, isFalse);
      await c.discardRejected();
      expect(c.hasPending, isTrue);
      await c.retry();
      expect(c.hasPending, isFalse);
      expect(c.error, isNull);
      for (final write in writes.skip(1)) {
        expect(write.body, writes.first.body);
        expect(
          write.headers['Idempotency-Key'],
          writes.first.headers['Idempotency-Key'],
        );
      }
      c.dispose();
      api.close();
    },
  );

  test('refresh confirms a persisted write before loading employees', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final requests = <http.Request>[];
    var fail = true;
    final api = SaasApi(
      origin: 'https://api.test',
      client: MockClient((r) async {
        requests.add(r);
        if (r.method == 'GET') {
          return http.Response('{"employees":[]}', 200);
        }
        if (fail) throw http.ClientException('Lost response');
        return http.Response('{"version":1}', 200);
      }),
    );
    final first = EmployeeAdminController(api, prefs, 'owner', company);
    await first.save(null, values);
    first.dispose();
    fail = false;
    final resumed = EmployeeAdminController(api, prefs, 'owner', company);
    await resumed.refresh(force: false);
    expect(requests.map((r) => r.method), ['POST', 'POST', 'GET']);
    expect(requests[0].body, requests[1].body);
    expect(
      requests[0].headers['Idempotency-Key'],
      requests[1].headers['Idempotency-Key'],
    );
    expect(resumed.hasPending, isFalse);
    expect(resumed.error, isNull);
    resumed.dispose();
    api.close();
  });

  test(
    'uncertain employee save survives restart and uses identical payload/key',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final requests = <http.Request>[];
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          if (r.method == 'GET') return http.Response('{"employees":[]}', 200);
          requests.add(r);
          if (requests.length == 1) throw http.ClientException('Lost response');
          return http.Response(
            jsonEncode({'employeeId': employee, 'version': 1}),
            200,
          );
        }),
      );
      final first = EmployeeAdminController(api, prefs, 'owner', company);
      expect(await first.save(null, values), isFalse);
      expect(first.hasPending, isTrue);
      expect(first.canDiscardRejected, isFalse);
      await first.discardRejected();
      expect(first.hasPending, isTrue);
      first.dispose();
      final otherCompany = EmployeeAdminController(
        api,
        prefs,
        'owner',
        'b' * 43,
      );
      expect(otherCompany.hasPending, isFalse);
      final resumed = EmployeeAdminController(api, prefs, 'owner', company);
      await resumed.retry();
      expect(resumed.hasPending, isFalse);
      expect(requests.length, 2);
      expect(requests[0].body, requests[1].body);
      expect(
        requests[0].headers['Idempotency-Key'],
        requests[1].headers['Idempotency-Key'],
      );
      resumed.dispose();
      otherCompany.dispose();
      api.close();
    },
  );

  test(
    'confirmed version rejection permits explicit discard but never auto-discards',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient(
          (r) async => r.method == 'GET'
              ? http.Response('{"employees":[]}', 200)
              : http.Response(
                  '{"error":{"code":"VERSION_CONFLICT","message":"Refresh before editing."}}',
                  409,
                ),
        ),
      );
      final c = EmployeeAdminController(api, prefs, 'owner', company);
      await c.save(employee, {...values, 'expectedVersion': 1});
      expect(c.hasPending, isTrue);
      expect(c.canDiscardRejected, isTrue);
      await c.refresh();
      expect(c.hasPending, isTrue);
      expect(c.canDiscardRejected, isTrue);
      await c.discardRejected();
      expect(c.hasPending, isFalse);
      c.dispose();
      api.close();
    },
  );

  test(
    'private codes remain ephemeral and each explicit reset has a fresh key',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final keys = <String?>[];
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          expect(
            r.url.path,
            '/v1/companies/$company/employees/$employee/access/reset',
          );
          keys.add(r.headers['Idempotency-Key']);
          return http.Response(
            '{"privateCode":"test-secret","inviteLink":"https://app.test"}',
            200,
          );
        }),
      );
      final c = EmployeeAdminController(api, prefs, 'owner', company);
      expect(
        (await c.access(employee, 'reset'))!['privateCode'],
        'test-secret',
      );
      await c.access(employee, 'reset');
      expect(keys[0], isNot(keys[1]));
      expect(prefs.getKeys(), isEmpty);
      c.dispose();
      api.close();
    },
  );
}
