import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/saas/saas_api.dart';
import 'package:tpc_invoice/core/saas/trial_balance_view.dart';

void main() {
  testWidgets('balance sheet displays earnings separately from posted equity', (
    tester,
  ) async {
    final api = SaasApi(
      origin: 'https://api.test',
      client: MockClient((r) async {
        final data = r.url.path.endsWith('/balance-sheet')
            ? {
                'asOf': r.url.queryParameters['asOf'],
                'journalCount': 1,
                'accounts': [],
                'totalAssets': '10.61',
                'totalLiabilities': '0.51',
                'postedEquity': '0.00',
                'accumulatedEarnings': '10.10',
                'totalEquity': '10.10',
                'totalLiabilitiesAndEquity': '10.61',
                'balanced': true,
              }
            : {
                'asOf': r.url.queryParameters['asOf'],
                'journalCount': 0,
                'accounts': [],
                'totalDebit': '0.00',
                'totalCredit': '0.00',
              };
        return http.Response(jsonEncode(data), 200);
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
    await tester.tap(find.text('Balance sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Assets: 10.61'), findsOneWidget);
    expect(find.text('Accumulated earnings: 10.10'), findsOneWidget);
    expect(find.text('Posted equity: 0.00'), findsOneWidget);
    expect(find.text('Liabilities + equity: 10.61'), findsOneWidget);
    api.close();
  });
  testWidgets(
    'profit and loss selection loads its date range and renders signed totals',
    (tester) async {
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          if (r.url.path.endsWith('/profit-and-loss')) {
            expect(r.url.queryParameters['from'], endsWith('-01-01'));
            return http.Response(
              jsonEncode({
                'from': r.url.queryParameters['from'],
                'asOf': r.url.queryParameters['asOf'],
                'journalCount': 1,
                'accounts': [
                  {
                    'accountName': 'Expense',
                    'accountGroup': 'Expense',
                    'amount': '0.30',
                  },
                ],
                'totalIncome': '0.00',
                'totalExpenses': '0.30',
                'netProfit': '-0.30',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'asOf': r.url.queryParameters['asOf'],
              'journalCount': 0,
              'accounts': [],
              'totalDebit': '0.00',
              'totalCredit': '0.00',
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
      await tester.tap(find.text('Profit and loss'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Net profit / loss: -0.30'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Credit'), findsNothing);
      api.close();
    },
  );
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
