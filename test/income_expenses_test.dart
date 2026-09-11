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

  testWidgets('Company Settings renders company profile and bank details cleanly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final billingCubit = BillingCubit(LocalRepository());
    final officeCubit = OfficeCubit(LocalOfficeRepository());

    const sampleCompany = Company(
      name: 'The Percentage FZ LLC',
      email: 'info@thepercentage.ae',
      phone: '+971 4 123 4567',
      address: 'Business Bay, Dubai, UAE',
      trn: '100200300400003',
      bank: 'Emirates NBD',
      accountHolder: 'The Percentage FZ LLC',
      accountNumber: '1234567890',
      iban: 'AE123456789012345678901',
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

    // Verify Company Settings headers & cards
    expect(find.text('Company Settings'), findsOneWidget);
    expect(find.text('Business Profile'), findsOneWidget);
    expect(find.text('The Percentage FZ LLC'), findsWidgets);
    expect(find.text('info@thepercentage.ae'), findsOneWidget);

    // Verify Bank & Payment Information card & fields
    expect(find.text('Bank & Payment Information'), findsOneWidget);
    expect(find.text('Emirates NBD'), findsOneWidget);
    expect(find.text('Save Company Settings'), findsOneWidget);
    expect(find.text('Current Session'), findsOneWidget);
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

