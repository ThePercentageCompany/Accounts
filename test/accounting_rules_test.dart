import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/billing/domain/models.dart';
import 'package:tpc_invoice/features/office/domain/office_repository.dart';
import 'package:tpc_invoice/features/office/domain/office_rules.dart';

void main() {
  group('Double-Entry Accounting & Depreciation Rules Tests', () {
    test('calculateDepreciation accurately calculates monthly and annual straight-line depreciation', () {
      // Cost: AED 5,000 (500,000 cents), Residual: AED 500 (50,000 cents), Useful Life: 36 months (3 years)
      final dep = calculateDepreciation(
        costCents: 500000,
        residualValueCents: 50000,
        usefulLifeMonths: 36,
      );

      // Depreciable = 450,000 cents (AED 4,500)
      expect(dep['depreciableCents'], 450000);
      // Monthly = 450,000 / 36 = 12,500 cents (AED 125.00)
      expect(dep['monthlyCents'], 12500);
      // Annual = 12,500 * 12 = 150,000 cents (AED 1,500.00)
      expect(dep['annualCents'], 150000);
    });

    test('createCapitalJournal generates balanced debit and credit entries', () {
      // Partner A contributes AED 10,000 to Bank
      final journal = createCapitalJournal(
        transactionId: 'CAP-001',
        shareholderName: 'Partner A',
        date: '2026-09-11',
        transactionType: 'capitalContribution',
        contributionType: 'bank',
        amountCents: 1000000,
      );

      expect(journal['isBalanced'], isTrue);
      expect(journal['totalDebitCents'], 1000000);
      expect(journal['totalCreditCents'], 1000000);

      final lines = (journal['lines'] as List).cast<Map<String, dynamic>>();
      expect(lines.length, 2);

      // Dr Bank Account AED 10,000
      expect(lines[0]['accountId'], 'bank_account');
      expect(lines[0]['debitCents'], 1000000);
      expect(lines[0]['creditCents'], 0);

      // Cr Shareholder Capital AED 10,000
      expect(lines[1]['accountId'], 'shareholder_equity');
      expect(lines[1]['debitCents'], 0);
      expect(lines[1]['creditCents'], 1000000);
    });

    test('createCapitalJournal for Asset Contribution debits Fixed Assets and credits Capital', () {
      final journal = createCapitalJournal(
        transactionId: 'CAP-002',
        shareholderName: 'Partner A',
        date: '2026-09-11',
        transactionType: 'capitalContribution',
        contributionType: 'asset',
        amountCents: 600000,
        assetName: 'MacBook Pro',
      );

      expect(journal['isBalanced'], isTrue);
      final lines = (journal['lines'] as List).cast<Map<String, dynamic>>();

      // Dr Fixed Asset
      expect(lines[0]['accountId'], 'fixed_asset');
      expect(lines[0]['debitCents'], 600000);

      // Cr Shareholder Capital
      expect(lines[1]['accountId'], 'shareholder_equity');
      expect(lines[1]['creditCents'], 600000);
    });

    test('createShareholderLoanJournal generates balanced liability entries', () {
      // Partner A gives company AED 20,000 loan
      final loanJournal = createShareholderLoanJournal(
        loanId: 'LOAN-001',
        shareholderName: 'Partner A',
        date: '2026-09-11',
        type: 'loanReceived',
        amountCents: 2000000,
        paymentAccount: 'Bank',
      );

      expect(loanJournal['isBalanced'], isTrue);
      final lines = (loanJournal['lines'] as List).cast<Map<String, dynamic>>();

      // Dr Bank, Cr Shareholder Loan (Liability)
      expect(lines[0]['accountGroup'], 'Asset');
      expect(lines[0]['debitCents'], 2000000);
      expect(lines[1]['accountGroup'], 'Liability');
      expect(lines[1]['creditCents'], 2000000);
    });

    test('calculateBalanceSheet verifies Assets = Liabilities + Equity with strict P&L isolation', () {
      // Scenario from Section 48 of the specification:
      // Partner A invests Cash: AED 50,000 (5,000,000 cents)
      // Partner A contributes Laptop: AED 6,000 (600,000 cents)
      // Company earns service income: AED 10,000 (1,000,000 cents) via Issued Invoice
      // Company pays operating expenses: AED 3,000 (300,000 cents)

      const customer = Customer(id: 'CUST-1', name: 'Acme Corp');
      const company = Company(name: 'TPC FZ LLC', shareholders: [
        {'id': 'SHR-1', 'name': 'Partner A', 'ownershipPercentage': 100.0, 'agreedCapital': 100000.0}
      ]);

      final invoice = Invoice(
        id: 'INV-1',
        number: 'TPC-2026-0001',
        date: '2026-09-11',
        customer: customer,
        company: company,
        items: const [LineItem(description: 'Website Development', quantity: '1', rate: '10000.00')],
        payments: const [
          Payment(id: 'PAY-1', cents: 1000000, date: '2026-09-11', account: 'Bank')
        ],
        status: 'issued',
      );

      final office = OfficeData(
        shareholders: const [
          {'id': 'SHR-1', 'name': 'Partner A', 'ownershipPercentage': 100.0, 'agreedCapital': 100000.0}
        ],
        capitalTransactions: const [
          {
            'id': 'CAP-1',
            'shareholderId': 'SHR-1',
            'shareholderName': 'Partner A',
            'transactionType': 'capitalContribution',
            'contributionType': 'cash',
            'amountCents': 5000000,
            'bankAccountId': 'Cash',
            'status': 'posted',
          }
        ],
        assets: const [
          {
            'id': 'AST-1',
            'name': 'MacBook Pro',
            'category': 'Computers & IT Equipment',
            'acquisitionType': 'shareholderContribution',
            'shareholderId': 'SHR-1',
            'costCents': 600000,
            'accumulatedDepreciationCents': 0,
            'status': 'active',
          }
        ],
        entries: const [
          {
            'id': 'EXP-1',
            'kind': 'expense',
            'category': 'Rent',
            'amountCents': 300000,
            'account': 'Bank',
            'status': 'paid',
            'paidDate': '2026-09-11',
          }
        ],
      );

      final bs = calculateBalanceSheet([invoice], office, company.shareholders);

      // 1. Operating Profit & Loss verification
      expect(bs['operatingIncomeCents'], 1000000); // AED 10,000
      expect(bs['operatingExpensesCents'], 300000); // AED 3,000
      expect(bs['currentYearNetProfitCents'], 700000); // Net Profit AED 7,000

      // 2. Shareholder Capital verification
      // Total Invested = Cash (AED 50,000) + Laptop (AED 6,000) = AED 56,000
      expect(bs['totalShareholderEquityCents'], 5600000);

      // 3. Equity = Capital (56,000) + Net Profit (7,000) = AED 63,000
      expect(bs['totalEquityCents'], 6300000);

      // 4. Assets = Cash (50,000) + Bank (10,000 - 3,000 = 7,000) + Laptop (6,000) = AED 63,000
      expect(bs['totalAssetsCents'], 6300000);

      // 5. Balance Sheet Equality verification
      expect(bs['isBalanced'], isTrue);
      expect(bs['totalAssetsCents'], bs['totalLiabilitiesAndEquityCents']);
    });

    test('calculateTrialBalance verifies total debits match total credits', () {
      const customer = Customer(id: 'CUST-1', name: 'Acme Corp');
      const company = Company(name: 'TPC FZ LLC');

      final invoice = Invoice(
        id: 'INV-1',
        date: '2026-09-11',
        customer: customer,
        company: company,
        items: const [LineItem(description: 'Digital Marketing', quantity: '1', rate: '5000.00')],
        payments: const [Payment(id: 'PAY-1', cents: 500000, date: '2026-09-11', account: 'Bank')],
        status: 'issued',
      );

      final office = OfficeData(
        capitalTransactions: const [
          {
            'id': 'CAP-1',
            'shareholderName': 'Partner A',
            'transactionType': 'capitalContribution',
            'contributionType': 'bank',
            'amountCents': 2000000,
            'status': 'posted',
          }
        ],
        entries: const [
          {
            'id': 'EXP-1',
            'kind': 'expense',
            'category': 'Software',
            'amountCents': 100000,
            'account': 'Bank',
            'status': 'paid',
            'paidDate': '2026-09-11',
          }
        ],
      );

      final tb = calculateTrialBalance([invoice], office);
      expect(tb['isBalanced'], isTrue);
      expect(tb['totalDebitCents'], tb['totalCreditCents']);
    });
  });
}
