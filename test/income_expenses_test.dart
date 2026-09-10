import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tpc_invoice/features/billing/data/local_repository.dart';
import 'package:tpc_invoice/features/billing/presentation/billing_cubit.dart';
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
    expect(find.text('Capital & Equity'), findsOneWidget);

    // Verify Zoho Metric Stat Cards
    expect(find.text('TOTAL INCOME & RECEIPTS'), findsOneWidget);
    expect(find.text('TOTAL EXPENSES & OUTFLOWS'), findsOneWidget);
    expect(find.text('NET CASH MOVEMENT'), findsOneWidget);
    expect(find.text('PENDING BILLS DUE'), findsOneWidget);

    // Verify Tab Badges
    expect(find.textContaining('All Transactions'), findsOneWidget);
    expect(find.textContaining('Income'), findsWidgets);
    expect(find.textContaining('Expenses'), findsWidgets);
    expect(find.textContaining('Capital'), findsWidgets);
  });
}
