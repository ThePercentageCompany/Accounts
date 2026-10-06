import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

void main() {
  for (final employee in [false, true]) {
    test(
      'payroll preview sends adjustments to ${employee ? 'employee' : 'owner'} endpoint',
      () async {
        final company = 'c' * 43;
        final values = <String, Object?>{
          'employeeId': 'e' * 43,
          'month': '2026-09',
          'bonus': 100,
          'deductions': 50,
        };
        final api = SaasApi(
          origin: 'https://api.test',
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(
              request.url.path,
              employee
                  ? '/v1/employee/payroll/preview'
                  : '/v1/companies/$company/payroll/preview',
            );
            expect(jsonDecode(request.body), values);
            return http.Response('{"totals":{"netSalary":5550}}', 200);
          }),
        );
        addTearDown(api.close);
        final result = await api.payrollPreview(
          company,
          values,
          employee: employee,
        );
        expect(result['totals']['netSalary'], 5550);
      },
    );
  }
}
