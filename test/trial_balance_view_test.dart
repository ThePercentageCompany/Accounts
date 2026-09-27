import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/saas/saas_api.dart';
import 'package:tpc_invoice/core/saas/trial_balance_view.dart';

void main() {
  testWidgets(
    'report refresh clears stale totals when the API rejects ledger data',
    (tester) async {
      var calls = 0;
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          expect(r.url.path, '/v1/companies/${'c' * 43}/reports/trial-balance');
          expect(
            r.url.queryParameters['asOf'],
            matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
          );
          calls++;
          if (calls > 1) {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'LEDGER_INTEGRITY',
                  'message': 'Ledger needs repair.',
                },
              }),
              409,
            );
          }
          return http.Response(
            jsonEncode({
              'asOf': r.url.queryParameters['asOf'],
              'journalCount': 1,
              'accounts': [
                {
                  'accountName': 'Cash',
                  'accountGroup': 'Asset',
                  'debit': '12.34',
                  'credit': '0.00',
                },
              ],
              'totalDebit': '12.34',
              'totalCredit': '12.34',
              'balanced': true,
            }),
            200,
          );
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
      expect(find.text('Cash'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh report'));
      await tester.pumpAndSettle();
      expect(find.text('Ledger needs repair.'), findsOneWidget);
      expect(find.text('Cash'), findsNothing);
      expect(find.text('12.34'), findsNothing);
      api.close();
    },
  );
}
