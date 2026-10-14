import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/auth/presentation/cubit/saas_session.dart';

void main() {
  for (final employee in [false, true]) {
    test(
        '${employee ? 'employee' : 'owner'} login survives a failed revalidation',
        () async {
      SharedPreferences.setMockInitialValues({
        'tpc_saas_session_mode': employee ? 'employee' : 'owner',
      });
      final preferences = await SharedPreferences.getInstance();
      var offline = false, revoked = false;
      final api = SaasApi(
          origin: 'https://api.test',
          client: MockClient((request) async {
            if (offline) throw http.ClientException('Offline');
            if (revoked) {
              return http.Response(
                  jsonEncode({
                    'error': {
                      'code': 'UNAUTHORIZED',
                      'message': 'Sign in again.'
                    }
                  }),
                  401);
            }
            return http.Response(
                jsonEncode(request.url.path.endsWith('/companies')
                    ? {'companies': []}
                    : employee
                        ? {
                            'employee': {
                              'employeeId': List.filled(43, 'e').join(),
                              'companyId': List.filled(43, 'c').join(),
                              'allowedSections': [],
                              'writableSections': []
                            }
                          }
                        : {
                            'owner': {'ownerId': List.filled(43, 'o').join()}
                          }),
                200);
          }));
      final session = SaasSession(api, preferences);
      await session.restore();
      expect(employee ? session.employee : session.owner, isNotNull);
      offline = true;
      await session.restore();
      expect(employee ? session.employee : session.owner, isNotNull);
      expect(session.error, isNotNull);
      offline = false;
      revoked = true;
      await session.restore();
      expect(session.owner, isNull);
      expect(session.employee, isNull);
      await session.close();
      api.close();
    });
  }
}
