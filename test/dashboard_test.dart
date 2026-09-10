import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/billing/data/local_repository.dart';
import 'package:tpc_invoice/features/billing/presentation/billing_cubit.dart';
import 'package:tpc_invoice/features/billing/presentation/dashboard_view.dart';
import 'package:tpc_invoice/features/office/data/local_office_repository.dart';
import 'package:tpc_invoice/features/office/presentation/office_cubit.dart';

void main() {
  testWidgets('DashboardView renders 6 KPI cards, dual bar chart, P&L, transactions and cash flow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final billingCubit = BillingCubit(LocalRepository());
    final officeCubit = OfficeCubit(LocalOfficeRepository());

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: billingCubit),
          BlocProvider.value(value: officeCubit),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DashboardView(
              onNewInvoice: () {},
              onNavigate: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Welcome Header
    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.text("Here's what's happening with your business today."), findsOneWidget);

    // Verify 6 KPI Cards
    expect(find.text('Total Income'), findsWidgets);
    expect(find.text('Total Expenses'), findsWidgets);
    expect(find.text('Net Profit'), findsWidgets);
    expect(find.text('Cash / Bank Balance'), findsOneWidget);
    expect(find.text('Receivables'), findsOneWidget);
    expect(find.text('Payables'), findsOneWidget);

    // Verify Monthly Income vs Expense Card
    expect(find.text('Monthly Income vs Expense'), findsOneWidget);
    expect(find.text('Income'), findsWidgets);
    expect(find.text('Expenses'), findsWidgets);
    expect(find.text('Jan'), findsOneWidget);
    expect(find.text('Dec'), findsOneWidget);

    // Verify Profit & Loss Summary Card
    expect(find.text('Profit & Loss Summary'), findsOneWidget);
    expect(find.text('View Report'), findsOneWidget);
    expect(find.text('Profit Margin'), findsOneWidget);

    // Verify Recent Transactions Card
    expect(find.text('Recent Transactions'), findsOneWidget);
    expect(find.text('View All'), findsOneWidget);
    expect(find.text('Consulting Services'), findsOneWidget);

    // Verify Cash Flow Summary Card
    expect(find.text('Cash Flow Summary'), findsOneWidget);
    expect(find.text('Opening Balance'), findsOneWidget);
    expect(find.text('Closing Balance'), findsOneWidget);
    expect(find.textContaining('Your cash balance has increased'), findsOneWidget);
  });
}
