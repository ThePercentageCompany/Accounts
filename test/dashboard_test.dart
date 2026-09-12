import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/billing/data/local_repository.dart';
import 'package:tpc_invoice/features/billing/presentation/billing_cubit.dart';
import 'package:tpc_invoice/features/billing/presentation/dashboard_view.dart';
import 'package:tpc_invoice/features/office/data/local_office_repository.dart';
import 'package:tpc_invoice/features/office/presentation/office_cubit.dart';

void main() {
  testWidgets('DashboardView renders 7 KPI cards, dual bar chart, P&L, transactions and cash flow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
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

    // Verify 7 KPI Cards
    expect(find.text('Total Income'), findsWidgets);
    expect(find.text('Total Expenses'), findsWidgets);
    expect(find.text('Net Profit'), findsWidgets);
    expect(find.text('Capital & Investment'), findsOneWidget);
    expect(find.text('Cash / Bank Balance'), findsOneWidget);
    expect(find.text('Receivables'), findsOneWidget);
    expect(find.text('Payables'), findsOneWidget);

    // Verify Monthly Income vs Expense Card
    expect(find.textContaining('Monthly Income vs Expense'), findsOneWidget);
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

    // Verify Cash Flow Summary Card
    expect(find.text('Cash Flow Summary'), findsOneWidget);
    expect(find.text('Cash Inflows'), findsOneWidget);
    expect(find.text('Cash Outflows'), findsOneWidget);
    expect(find.text('Net Cash Movement'), findsOneWidget);
  });

  testWidgets('DashboardView renders 2-column KPI grid and horizontal scrolling Quick Action pills on mobile', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844); // iPhone 14/15 size
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

    // Verify Quick Actions Pills & Swipe indicator
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Swipe'), findsOneWidget);
    expect(find.text('New Invoice'), findsOneWidget);
    expect(find.text('New Quotation'), findsOneWidget);
    expect(find.text('Add Expense'), findsOneWidget);
    expect(find.text('Capital & Equity'), findsOneWidget);

    // Verify 7 KPI Cards in 2-column grid
    expect(find.text('Total Income'), findsWidgets);
    expect(find.text('Total Expenses'), findsWidgets);
    expect(find.text('Net Profit'), findsWidgets);
    expect(find.text('Capital & Investment'), findsOneWidget);
    expect(find.text('Cash / Bank Balance'), findsOneWidget);
  });
}
