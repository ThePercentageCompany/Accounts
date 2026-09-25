import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/saas/saas_api.dart';
import 'package:tpc_invoice/core/saas/employee_admin_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
