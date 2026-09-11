import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tpc_invoice/features/billing/data/local_repository.dart';
import 'package:tpc_invoice/features/billing/domain/models.dart';
import 'package:tpc_invoice/features/billing/presentation/billing_cubit.dart';
import 'package:tpc_invoice/features/billing/presentation/editors.dart';
import 'package:tpc_invoice/features/office/data/local_office_repository.dart';
import 'package:tpc_invoice/features/office/data/pdf_office_documents.dart';
import 'package:tpc_invoice/features/office/domain/office_documents.dart';
import 'package:tpc_invoice/features/office/presentation/office_cubit.dart';
import 'package:tpc_invoice/features/office/presentation/office_screen.dart';

void main() {
  testWidgets('Income & Expenses unified section renders Zoho metrics, filters, and action buttons', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final billingCubit = BillingCubit(LocalRepository());
    final officeCubit = OfficeCubit(LocalOfficeRepository());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OfficeDocuments>(create: (_) => PdfOfficeDocuments()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: billingCubit),
            BlocProvider.value(value: officeCubit),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OfficeScreen(initialPage: 3),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Action Buttons
    expect(find.text('Add Income'), findsWidgets);
    expect(find.text('Add Expense'), findsWidgets);

    // Verify Zoho Metric Stat Cards
    expect(find.text('TOTAL INCOME & RECEIPTS'), findsOneWidget);
    expect(find.text('TOTAL EXPENSES & OUTFLOWS'), findsOneWidget);
    expect(find.text('NET CASH MOVEMENT'), findsOneWidget);
    expect(find.text('PENDING BILLS DUE'), findsOneWidget);

    // Verify Tab Badges
    expect(find.textContaining('All Transactions'), findsOneWidget);
    expect(find.textContaining('Income'), findsWidgets);
    expect(find.textContaining('Expenses'), findsWidgets);
  });

  testWidgets('Company Settings includes Shareholders & Capital Equity management', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final billingCubit = BillingCubit(LocalRepository());
    final officeCubit = OfficeCubit(LocalOfficeRepository());

    const sampleCompany = Company(
      name: 'The Percentage FZ LLC',
      shareholders: [
        {
          'id': 'sh_1',
          'name': 'Ahmed Al Mansoori',
          'role': 'Managing Partner',
          'sharesPercent': '60.0',
          'investedAmount': '300000.00',
          'date': '2024-01-01',
          'email': 'ahmed@tpc.com',
          'phone': '+971501234567',
        },
        {
          'id': 'sh_2',
          'name': 'John Partner',
          'role': 'Executive Director',
          'sharesPercent': '40.0',
          'investedAmount': '200000.00',
          'date': '2024-01-01',
          'email': 'john@tpc.com',
          'phone': '+971509876543',
        },
      ],
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: billingCubit),
          BlocProvider.value(value: officeCubit),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CompanyEditor(company: sampleCompany),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Shareholders & Capital Equity card
    expect(find.text('Shareholders & Capital Equity'), findsOneWidget);
    expect(find.text('TOTAL INVESTED CAPITAL'), findsOneWidget);
    expect(find.text('AED 500000.00'), findsOneWidget);
    expect(find.text('ACTIVE PARTNERS'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('EQUITY ALLOCATED'), findsOneWidget);
    expect(find.text('100.0%'), findsOneWidget);

    // Verify Shareholders in the list
    expect(find.text('Ahmed Al Mansoori'), findsOneWidget);
    expect(find.text('John Partner'), findsOneWidget);
    expect(find.text('60.0% Equity'), findsOneWidget);
    expect(find.text('40.0% Equity'), findsOneWidget);
    expect(find.text('AED 300000.00'), findsOneWidget);
    expect(find.text('AED 200000.00'), findsOneWidget);
  });

  testWidgets('Income & Expenses screen renders cleanly on compact mobile viewport (375x812) with zero overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final billingCubit = BillingCubit(LocalRepository());
    final officeCubit = OfficeCubit(LocalOfficeRepository());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OfficeDocuments>(create: (_) => PdfOfficeDocuments()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: billingCubit),
            BlocProvider.value(value: officeCubit),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OfficeScreen(initialPage: 3),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Mobile 2x2 Bento Stat Cards
    expect(find.text('TOTAL INCOME & RECEIPTS'), findsOneWidget);
    expect(find.text('TOTAL EXPENSES & OUTFLOWS'), findsOneWidget);
    expect(find.text('NET CASH MOVEMENT'), findsOneWidget);
    expect(find.text('PENDING BILLS DUE'), findsOneWidget);

    // Verify Mobile Action Buttons
    expect(find.text('Add Income'), findsWidgets);
    expect(find.text('Add Expense'), findsWidgets);

    // Verify Mobile Capsule Filter Badges
    expect(find.textContaining('All Transactions'), findsOneWidget);
    expect(find.textContaining('Income'), findsWidgets);
    expect(find.textContaining('Expenses'), findsWidgets);
    expect(find.textContaining('Unpaid Bills'), findsOneWidget);

    // Verify Bank & Cash Movement bar
    expect(find.textContaining('Bank:'), findsOneWidget);
    expect(find.textContaining('Cash:'), findsOneWidget);

    // Tap Add Income to open TransactionDialog on mobile
    await tester.tap(find.text('Add Income').first);
    await tester.pumpAndSettle();

    // Verify TransactionDialog elements render without overflow
    expect(find.text('Record Transaction'), findsOneWidget);
    expect(find.text('Amount (AED) *'), findsOneWidget);
    expect(find.text('Date *'), findsOneWidget);
    expect(find.text('Category *'), findsOneWidget);
    expect(find.text('Payment Status'), findsNothing); // for income, payment status is not shown
    expect(find.text('Account / Method'), findsOneWidget);

    // Close Dialog via top header close icon
    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await tester.pumpAndSettle();
  });
}

