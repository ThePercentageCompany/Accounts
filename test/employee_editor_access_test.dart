import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/workspace/presentation/shared_workspace.dart';
import 'package:tpc_invoice/features/documents/presentation/invoice_editor.dart';
import 'package:tpc_invoice/features/documents/presentation/quotation_editor.dart';

void main() {
  for (final section in ['Invoices', 'Quotations']) {
    testWidgets('employee $section editor opens without Customers or Settings grants', (tester) async {
      SharedPreferences.setMockInitialValues({}); final prefs = await SharedPreferences.getInstance();
      final paths = <String>[];
      final api = SaasApi(origin: 'https://api.test', client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/v1/employee/records/Customers') return http.Response(jsonEncode({'error': {'code':'SECTION_FORBIDDEN','message':'Customers not assigned'}}),403);
        if (request.url.path == '/v1/employee/references/Customers') {
          expect(request.url.queryParameters['section'], section);
          expect(request.headers['X-TPC-Company'], 'c' * 43);
          return http.Response(jsonEncode({'records':[{'recordId':'x' * 43,'name':'Client'}]}),200);
        }
        if (request.url.path == '/v1/employee/references/CompanyProfile') return http.Response(jsonEncode({'records':[{'recordId':'company','name':'Company','currency':'USD'}]}),200);
        return http.Response('{"records":[]}',200);
      }));
      await tester.pumpWidget(MaterialApp(home: SharedWorkspace(api:api, companyId:'c' * 43,title:'Employee',onBack:(){},preferences:prefs,employee:{'employeeId':'e' * 43,'role':'Manager','allowedSections':[section],'writableSections':[section]})));
      await tester.pumpAndSettle();
      await tester.tap(find.text(section == 'Invoices' ? 'Add draft invoice' : 'Add draft quotation'));
      await tester.pumpAndSettle();
      expect(section == 'Invoices' ? find.byType(InvoiceEditor) : find.byType(QuotationEditor), findsOneWidget);
      expect(paths.contains('/v1/employee/records/Customers'),isFalse);
      expect(paths.any((p)=>p.startsWith('/v1/companies/')),isFalse);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox()); api.close();
    });
  }
}
