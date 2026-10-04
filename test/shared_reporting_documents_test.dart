import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/features/workspace/presentation/company_profile_editor.dart';
import 'package:tpc_invoice/features/documents/data/document_upload_queue.dart';
import 'package:tpc_invoice/features/documents/presentation/record_documents_view.dart';
import 'package:tpc_invoice/features/reports/data/report_export.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/documents/data/shared_record_pdf.dart';
import 'package:tpc_invoice/features/reports/presentation/trial_balance_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('employee reports use employee session routes', (tester) async {
    final paths = <String>[];
    final api = SaasApi(
      origin: 'https://api.test',
      client: MockClient((r) async {
        paths.add(r.url.path);
        return http.Response('{"accounts":[],"journalCount":0}', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrialBalanceView(api: api, companyId: 'c' * 43, employee: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('General ledger'));
    await tester.pumpAndSettle();
    expect(paths, [
      '/v1/employee/reports/trial-balance',
      '/v1/employee/reports/general-ledger',
    ]);
    api.close();
  });
  test(
    'uncertain upload survives restart with identical bytes, target and key',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final requests = <http.Request>[];
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          requests.add(r);
          if (requests.length == 1) throw http.ClientException('lost response');
          return http.Response(jsonEncode({'documentId': 'd' * 43}), 201);
        }),
      );
      final queue = DocumentUploadQueue(api, preferences, 'owner', 'c' * 43);
      await queue.enqueue(
        name: 'test.pdf',
        mimeType: 'application/pdf',
        section: 'Invoices',
        recordId: 'r' * 43,
        bytes: Uint8List.fromList(utf8.encode('%PDF-1.7\n%%EOF')),
      );
      await expectLater(queue.flush(), throwsA(isA<SaasApiException>()));
      expect(
        DocumentUploadQueue(api, preferences, 'other', 'c' * 43).pending,
        isNull,
      );
      final resumed = DocumentUploadQueue(api, preferences, 'owner', 'c' * 43);
      expect(resumed.pending, isNotNull);
      await resumed.flush();
      expect(requests[1].body, requests[0].body);
      expect(
        requests[1].headers['Idempotency-Key'],
        requests[0].headers['Idempotency-Key'],
      );
      expect(resumed.pending, isNull);
      api.close();
    },
  );

  test(
    'format rejection releases local upload while uncertain rejection retains it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var code = 'DOCUMENT_WRITE_PENDING';
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'error': {'code': code, 'message': 'Retry'},
            }),
            409,
          ),
        ),
      );
      final queue = DocumentUploadQueue(api, preferences, 'owner', 'c' * 43);
      await queue.enqueue(
        name: 'test.pdf',
        mimeType: 'application/pdf',
        section: 'Invoices',
        recordId: 'r' * 43,
        bytes: Uint8List(1),
      );
      await expectLater(queue.flush(), throwsA(isA<SaasApiException>()));
      expect(queue.pending, isNotNull);
      code = 'DOCUMENT_TYPE';
      await expectLater(queue.flush(), throwsA(isA<SaasApiException>()));
      expect(queue.pending, isNull);
      api.close();
    },
  );

  test(
    'CSV contains period, signed exact values and neutralized formula names',
    () {
      final csv = utf8.decode(
        reportCsv('General ledger', {
          'from': '2026-09-01',
          'asOf': '2026-09-30',
          'journalCount': 1,
          'accounts': [
            {
              'accountId': 'income',
              'accountName': '=HYPERLINK("evil")',
              'accountGroup': 'Income',
              'opening': '-0.30',
              'debit': '0.00',
              'credit': '0.20',
              'closing': '-0.50',
              'entries': [
                {
                  'date': '2026-09-30',
                  'number': '+cmd',
                  'description': 'a,b\nc',
                  'debit': '0.00',
                  'credit': '0.20',
                  'balance': '-0.50',
                },
              ],
            },
          ],
        }),
      );
      expect(csv, contains('"\'=HYPERLINK(""evil"")"'));
      expect(csv, contains('"-0.50"'));
      expect(csv, contains('"\'+cmd"'));
      expect(csv, contains('"a,b\nc"'));
      expect(csv, contains('2026-09-01'));
    },
  );

  testWidgets(
    'employee documents use authorized employee routes and expose no writes',
    (tester) async {
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          expect(r.url.path, '/v1/employee/companies/${'c' * 43}/documents');
          expect(r.url.queryParameters['recordId'], 'r' * 43);
          return http.Response(
            jsonEncode({
              'documents': [
                {
                  'documentId': 'd' * 43,
                  'name': 'Invoice.pdf',
                  'mimeType': 'application/pdf',
                  'byteLength': 20,
                },
              ],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RecordDocumentsView(
            api: api,
            companyId: 'c' * 43,
            section: 'Invoices',
            record: {'recordId': 'r' * 43},
            employee: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invoice.pdf'), findsOneWidget);
      expect(find.text('Create and attach PDF'), findsNothing);
      expect(find.textContaining('Upload file'), findsNothing);
      api.close();
    },
  );

  testWidgets(
    'profile editor submits business fields without overwriting logo metadata',
    (tester) async {
      Map<String, Object?>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              child: const Text('Edit'),
              onPressed: () async {
                saved = await showDialog<Map<String, Object?>>(
                  context: context,
                  builder: (_) => const CompanyProfileEditor(
                    record: {
                      'name': 'TPC',
                      'currency': 'AED',
                      'recordVersion': 4,
                      'logoDocumentId': 'private',
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(saved?['name'], 'TPC');
      expect(saved?['currency'], 'AED');
      expect(saved?.containsKey('logoDocumentId'), false);
      expect(saved?.containsKey('recordVersion'), false);
    },
  );

  testWidgets(
    'dashboard uses server totals and clears them after failed refresh',
    (tester) async {
      var fail = false;
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          if (fail) {
            return http.Response(
              '{"error":{"code":"LEDGER_INTEGRITY","message":"Repair ledger"}}',
              409,
            );
          }
          if (r.url.path.endsWith('dashboard')) {
            return http.Response(
              jsonEncode({
                'from': '2026-01-01',
                'asOf': '2026-09-30',
                'journalCount': 1,
                'totalIncome': '123.45',
                'totalExpenses': '0.00',
                'netProfit': '123.45',
                'cash': '100.00',
                'bank': '23.45',
                'receivables': '0.00',
                'payables': '0.00',
                'totalAssets': '123.45',
                'totalLiabilities': '0.00',
                'totalEquity': '123.45',
              }),
              200,
            );
          }
          return http.Response('{"accounts":[],"journalCount":0}', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrialBalanceView(api: api, companyId: 'c' * 43),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Period income'), findsOneWidget);
      expect(find.text('123.45'), findsWidgets);
      fail = true;
      await tester.tap(find.byTooltip('Refresh report'));
      await tester.pumpAndSettle();
      expect(find.text('Repair ledger'), findsOneWidget);
      expect(find.text('123.45'), findsNothing);
      expect(find.text('Export CSV'), findsNothing);
      api.close();
    },
  );

  test(
    'shared PDF reads saved records and rejects concurrent version changes',
    () async {
      var invoiceReads = 0, change = false;
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          final table = r.url.path.split('/').last;
          final records = switch (table) {
            'Invoices' => [
              {
                'recordId': 'r' * 43,
                'recordVersion': change && ++invoiceReads > 1 ? 2 : 1,
                'number': 'INV-2026-000001',
                'status': 'ISSUED',
                'currency': 'AED',
                'total': 10.5,
                'taxAmount': 0.5,
              },
            ],
            'CompanyProfile' => [
              {
                'recordId': 'company',
                'recordVersion': 1,
                'name': 'TPC',
                'currency': 'AED',
              },
            ],
            'InvoiceItems' => [
              {
                'invoiceId': 'r' * 43,
                'lineNumber': 1,
                'description': 'Service',
                'quantity': 1,
                'unitPrice': 10,
                'discount': 0,
                'taxAmount': 0.5,
                'lineTotal': 10.5,
              },
            ],
            _ => [],
          };
          return http.Response(jsonEncode({'records': records}), 200);
        }),
      );
      final bytes = await sharedRecordPdf(api, 'c' * 43, 'Invoices', 'r' * 43);
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      change = true;
      await expectLater(
        sharedRecordPdf(api, 'c' * 43, 'Invoices', 'r' * 43),
        throwsA(
          isA<SaasApiException>().having(
            (e) => e.code,
            'code',
            'VERSION_CONFLICT',
          ),
        ),
      );
      api.close();
    },
  );
}
