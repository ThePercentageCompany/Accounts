import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/accounting/presentation/company_loan_editor.dart';

void main() {
  testWidgets('loan draft requires lender and supports all lender types',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CompanyLoanEditor())));
    expect(find.text('Lender name'), findsOneWidget);
    expect(find.text('Annual interest rate (%)'), findsOneWidget);
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('Enter lender name.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loan repayment rejects excess principal and empty payments',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: CompanyLoanEditor(
      repayment: true,
      record: {
        'lenderName': 'Bank lender',
        'date': '2026-10-01',
        'outstandingBalance': 100,
        'paymentAccount': 'Bank'
      },
    ))));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Principal paid'), '101');
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(find.text('Principal exceeds the outstanding balance.'),
        findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Principal paid'), '0');
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(find.text('Enter principal or interest paid.'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Principal paid'), 'bad');
    await tester.tap(find.text('Record payment'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
