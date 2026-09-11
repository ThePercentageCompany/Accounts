import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/billing/data/local_repository.dart';
import 'package:tpc_invoice/features/billing/domain/models.dart';
import 'package:tpc_invoice/features/billing/presentation/billing_cubit.dart';
import 'package:tpc_invoice/features/office/data/local_office_repository.dart';
import 'package:tpc_invoice/features/office/domain/office_repository.dart';
import 'package:tpc_invoice/features/office/presentation/office_cubit.dart';
import 'package:tpc_invoice/features/reports/domain/report_calculation_service.dart';
import 'package:tpc_invoice/features/reports/domain/report_models.dart';
import 'package:tpc_invoice/features/reports/presentation/reports_hub_screen.dart';

void main() {
  group('Reports Module Calculation Engine Tests', () {
    const calc = ReportCalculationService();
    final filter = ReportFilter(preset: DateRangePreset.allTime);

    final customer = const Customer(id: 'cust_1', name: 'Alpha Corp', email: 'alpha@corp.com', phone: '123');
    final customers = [customer];

    final invoices = [
      Invoice(
        id: 'inv_1',
        number: 'INV-001',
        customer: customer,
        company: const Company(),
        date: '2024-01-15',
        dueDate: '2024-02-15',
        status: 'issued',
        taxRate: '5',
        items: [
          const LineItem(description: 'Website Development', quantity: '1', rate: '10000.00'), // AED 10,000
        ],
        payments: [
          const Payment(id: 'p_1', account: 'Bank', cents: 400000, date: '2024-01-20'), // AED 4,000 paid
        ],
      ),
    ];

    final office = OfficeData(
      entries: [
        {
          'id': 'exp_1',
          'kind': 'expense',
          'category': 'Software & Subscriptions',
          'amountCents': 200000, // AED 2,000
          'status': 'paid',
          'date': '2024-01-18',
          'account': 'Bank',
          'vatPercent': 5.0,
        },
        {
          'id': 'bill_1',
          'kind': 'expense',
          'category': 'Office Supplies',
          'amountCents': 150000, // AED 1,500 unpaid
          'status': 'unpaid',
          'date': '2024-01-10',
          'dueDate': '2024-01-25',
          'supplier': 'Stationery Ltd',
        },
      ],
      payroll: [
        {
          'id': 'pay_1',
          'netCents': 300000, // AED 3,000
          'status': 'paid',
          'date': '2024-01-31',
          'account': 'Bank',
        },
      ],
      capitalTransactions: [
        {
          'id': 'cap_1',
          'transactionType': 'capitalContribution',
          'contributionType': 'bank',
          'amountCents': 5000000, // AED 50,000 capital (MUST NOT BE IN P&L)
          'status': 'approved',
          'date': '2024-01-01',
        },
      ],
      assets: [
        {
          'id': 'asset_1',
          'name': 'MacBook Pro',
          'costCents': 800000,
          'accumulatedDepreciationCents': 80000, // AED 800 depreciation
          'status': 'active',
          'acquisitionType': 'companyPurchase',
        },
      ],
      shareholders: [
        {
          'id': 'sh_1',
          'name': 'Ahmed Al Mansoori',
          'cashInvested': '50000.00',
          'assetContributions': '0.00',
          'ownershipPercentage': 100.0,
        },
      ],
    );

    test('Profit & Loss correctly computes Revenue, Operating Expenses & Net Income with strict Capital Isolation', () {
      final lines = calc.generateProfitAndLoss(invoices: invoices, office: office, filter: filter);

      final revenueItem = lines.firstWhere((l) => l.label == 'Total Operating Revenue');
      expect(revenueItem.amount, 10500.00); // AED 10,000 + 5% VAT = 10,500

      final expenseItem = lines.firstWhere((l) => l.label == 'Total Operating Expenses');
      // AED 2,000 (expense) + AED 3,000 (payroll) + AED 800 (depreciation) = AED 5,800
      expect(expenseItem.amount, 5800.00);

      final netProfitItem = lines.firstWhere((l) => l.label.contains('NET OPERATING PROFIT'));
      expect(netProfitItem.amount, 4700.00); // 10,500 - 5,800 = 4,700
    });

    test('Receivables Aging correctly classifies unpaid balances into aging buckets', () {
      final aging = calc.generateReceivablesAging(invoices: invoices, customers: customers, filter: filter);
      expect(aging.length, 1);
      expect(aging.first.name, 'Alpha Corp');
      expect(aging.first.total, 6500.00); // 10,500 - 4,000 = 6,500
    });

    test('UAE FTA VAT Summary computes 5% output tax and recoverable input tax', () {
      final vat = calc.generateVatSummary(invoices: invoices, office: office, filter: filter);
      expect(vat.standardRatedSales, 10000.00);
      expect(vat.standardRatedSalesVat, 500.00);
      expect(vat.totalOutputVat, 500.00);
      expect(vat.recoverableInputVat, greaterThan(0));
      expect(vat.netVatPayable, lessThanOrEqualTo(500.00));
    });

    test('Cash Flow Statement correctly separates Operating, Investing, and Financing flows', () {
      final sections = calc.generateCashFlowStatement(invoices: invoices, office: office, filter: filter);
      expect(sections.length, 3);

      // Operating Activities (Collected 4,000 - Paid 2,000 - Payroll 3,000 = -1,000)
      expect(sections[0].netCashFlow, -1000.00);

      // Financing Activities (Capital cash contribution = +50,000)
      expect(sections[2].netCashFlow, 50000.00);
    });

    test('Statement of Changes in Equity computes closing shareholder capital and retained earnings', () {
      final equityLines = calc.generateStatementOfEquity(
        invoices: invoices,
        office: office,
        companyShareholders: office.shareholders,
        filter: filter,
      );

      final closingCapital = equityLines.firstWhere((l) => l.label == 'Closing Shareholder Capital');
      expect(closingCapital.amount, 50000.00);

      final totalEquity = equityLines.firstWhere((l) => l.label == 'TOTAL CLOSING SHAREHOLDER EQUITY');
      expect(totalEquity.amount, greaterThan(50000.00));
    });
  });

  group('ReportsHubScreen Widget Tests', () {
    testWidgets('ReportsHubScreen mounts with 8 executive KPI cards and categorized report directory', (WidgetTester tester) async {
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
          child: const MaterialApp(
            home: ReportsHubScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Financial & Business Reports'), findsOneWidget);
      expect(find.text('Report Directory'), findsOneWidget);

      // Verify KPI Cards
      expect(find.text('Total Revenue'), findsOneWidget);
      expect(find.text('Total Expenses'), findsOneWidget);
      expect(find.text('Net Profit'), findsOneWidget);
      expect(find.text('Cash & Bank Balance'), findsOneWidget);
      expect(find.text('A/R Receivables'), findsOneWidget);
      expect(find.text('A/P Payables'), findsOneWidget);
      expect(find.text('Fixed Asset Value'), findsOneWidget);
      expect(find.text('Shareholder Capital'), findsOneWidget);

      // Verify Report Category Titles
      expect(find.text('FINANCIAL STATEMENTS'), findsOneWidget);
      expect(find.text('RECEIVABLES & PAYABLES'), findsOneWidget);
      expect(find.text('SALES & UAE VAT'), findsOneWidget);

      // Tap on Profit & Loss report to open interactive viewer
      await tester.tap(find.text('Profit & Loss (Income Statement)').first);
      await tester.pumpAndSettle();

      // Verify Report Viewer View
      expect(find.text('Profit & Loss Statement'), findsOneWidget);
      expect(find.text('All Reports Hub'), findsOneWidget);
      expect(find.text('Audited Ledger Figures'), findsOneWidget);

      // Tap Back to Hub
      await tester.tap(find.text('All Reports Hub'));
      await tester.pumpAndSettle();

      expect(find.text('Report Directory'), findsOneWidget);
    });
  });
}
