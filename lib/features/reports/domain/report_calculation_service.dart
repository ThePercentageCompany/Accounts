import '../../billing/domain/models.dart';
import '../../billing/domain/totals.dart';
import '../../office/domain/office_repository.dart';
import 'report_models.dart';

class ReportCalculationService {
  const ReportCalculationService();

  bool _isDateInRange(String? dateStr, DateTime start, DateTime end) {
    if (dateStr == null || dateStr.isEmpty) return true;
    final d = DateTime.tryParse(dateStr);
    if (d == null) return true;
    return (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
        (d.isBefore(end) || d.isAtSameMomentAs(end));
  }

  // -------------------------------------------------------------
  // 1. Profit & Loss (Income Statement)
  // -------------------------------------------------------------
  List<ReportLineItem> generateProfitAndLoss({
    required List<Invoice> invoices,
    required OfficeData office,
    required ReportFilter filter,
  }) {
    final Map<String, int> revenueByService = {};
    int totalRevenueCents = 0;

    for (final inv in invoices) {
      if (inv.status == 'issued' && _isDateInRange(inv.date, filter.startDate, filter.endDate)) {
        final t = Totals.of(inv);
        totalRevenueCents += t.total;
        for (final item in inv.items) {
          final title = item.description.isNotEmpty ? item.description : 'General Services';
          revenueByService[title] = (revenueByService[title] ?? 0) + lineTotal(item);
        }
      }
    }

    final Map<String, int> operatingExpensesByCategory = {};
    int totalExpensesCents = 0;

    for (final e in office.entries) {
      if (e['kind'] == 'expense' && e['status'] == 'paid' && _isDateInRange(e['date']?.toString(), filter.startDate, filter.endDate)) {
        final amt = (e['amountCents'] as num?)?.toInt() ?? 0;
        final cat = e['category']?.toString() ?? 'General Operating';
        operatingExpensesByCategory[cat] = (operatingExpensesByCategory[cat] ?? 0) + amt;
        totalExpensesCents += amt;
      }
    }

    // Payroll expense
    int payrollExpenseCents = 0;
    for (final p in office.payroll) {
      if ((p['status'] == 'approved' || p['status'] == 'paid') && _isDateInRange(p['date']?.toString(), filter.startDate, filter.endDate)) {
        final net = (p['netCents'] as num?)?.toInt() ?? 0;
        payrollExpenseCents += net;
      }
    }
    if (payrollExpenseCents > 0) {
      operatingExpensesByCategory['Salaries & Wages'] = (operatingExpensesByCategory['Salaries & Wages'] ?? 0) + payrollExpenseCents;
      totalExpensesCents += payrollExpenseCents;
    }

    // Depreciation expense
    int depreciationExpenseCents = 0;
    for (final a in office.assets) {
      if (a['status'] != 'disposed' && a['status'] != 'void') {
        final acc = (a['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0;
        depreciationExpenseCents += acc;
      }
    }
    if (depreciationExpenseCents > 0) {
      operatingExpensesByCategory['Depreciation Expense'] = (operatingExpensesByCategory['Depreciation Expense'] ?? 0) + depreciationExpenseCents;
      totalExpensesCents += depreciationExpenseCents;
    }

    final netProfitCents = totalRevenueCents - totalExpensesCents;

    return [
      // Operating Revenue
      const ReportLineItem(label: 'REVENUE & OPERATING INCOME', amount: 0, isHeader: true),
      for (final entry in revenueByService.entries)
        ReportLineItem(label: entry.key, amount: entry.value / 100.0, indentLevel: 1),
      if (revenueByService.isEmpty)
        ReportLineItem(label: 'Operating Sales', amount: totalRevenueCents / 100.0, indentLevel: 1),
      ReportLineItem(label: 'Total Operating Revenue', amount: totalRevenueCents / 100.0, isTotal: true),

      // Operating Expenses
      const ReportLineItem(label: 'OPERATING EXPENSES', amount: 0, isHeader: true),
      for (final entry in operatingExpensesByCategory.entries)
        ReportLineItem(label: entry.key, amount: entry.value / 100.0, indentLevel: 1),
      if (operatingExpensesByCategory.isEmpty)
        const ReportLineItem(label: 'General Operating Costs', amount: 0.0, indentLevel: 1),
      ReportLineItem(label: 'Total Operating Expenses', amount: totalExpensesCents / 100.0, isTotal: true),

      // Net Profit / Loss
      ReportLineItem(
        label: netProfitCents >= 0 ? 'NET OPERATING PROFIT' : 'NET OPERATING LOSS',
        amount: netProfitCents / 100.0,
        isTotal: true,
      ),
    ];
  }

  // -------------------------------------------------------------
  // 2. Receivables Aging Report
  // -------------------------------------------------------------
  List<AgingBucketRow> generateReceivablesAging({
    required List<Invoice> invoices,
    required List<Customer> customers,
    required ReportFilter filter,
  }) {
    final now = DateTime.now();
    final Map<String, List<Invoice>> customerInvoices = {};

    for (final inv in invoices) {
      if (inv.status == 'issued') {
        final bal = Totals.of(inv).balance;
        if (bal > 0) {
          customerInvoices.putIfAbsent(inv.customer.id, () => []).add(inv);
        }
      }
    }

    final List<AgingBucketRow> rows = [];

    for (final c in customers) {
      final invs = customerInvoices[c.id];
      if (invs == null || invs.isEmpty) continue;

      double cur = 0, d1_30 = 0, d31_60 = 0, d61_90 = 0, d90plus = 0, total = 0;

      for (final inv in invs) {
        final due = DateTime.tryParse(inv.dueDate) ?? DateTime.tryParse(inv.date) ?? now;
        final overdueDays = now.difference(due).inDays;
        final bal = Totals.of(inv).balance / 100.0;
        total += bal;

        if (overdueDays <= 0) {
          cur += bal;
        } else if (overdueDays <= 30) {
          d1_30 += bal;
        } else if (overdueDays <= 60) {
          d31_60 += bal;
        } else if (overdueDays <= 90) {
          d61_90 += bal;
        } else {
          d90plus += bal;
        }
      }

      rows.add(AgingBucketRow(
        name: c.name,
        reference: c.id.substring(0, c.id.length.clamp(0, 6)),
        current: cur,
        days1to30: d1_30,
        days31to60: d31_60,
        days61to90: d61_90,
        daysOver90: d90plus,
        total: total,
      ));
    }

    return rows;
  }

  // -------------------------------------------------------------
  // 3. Payables Aging Report
  // -------------------------------------------------------------
  List<AgingBucketRow> generatePayablesAging({
    required OfficeData office,
    required ReportFilter filter,
  }) {
    final now = DateTime.now();
    final Map<String, List<Map<String, dynamic>>> vendorBills = {};

    for (final e in office.entries) {
      if (e['kind'] == 'expense' && e['status'] == 'unpaid') {
        final vendor = e['vendor']?.toString() ?? e['supplier']?.toString() ?? e['category']?.toString() ?? 'Supplier';
        vendorBills.putIfAbsent(vendor, () => []).add(e);
      }
    }

    final List<AgingBucketRow> rows = [];

    for (final entry in vendorBills.entries) {
      double cur = 0, d1_30 = 0, d31_60 = 0, d61_90 = 0, d90plus = 0, total = 0;

      for (final b in entry.value) {
        final dStr = b['dueDate']?.toString() ?? b['date']?.toString();
        final due = (dStr != null ? DateTime.tryParse(dStr) : null) ?? now;
        final overdueDays = now.difference(due).inDays;
        final amt = ((b['amountCents'] as num?)?.toInt() ?? 0) / 100.0;
        total += amt;

        if (overdueDays <= 0) {
          cur += amt;
        } else if (overdueDays <= 30) {
          d1_30 += amt;
        } else if (overdueDays <= 60) {
          d31_60 += amt;
        } else if (overdueDays <= 90) {
          d61_90 += amt;
        } else {
          d90plus += amt;
        }
      }

      rows.add(AgingBucketRow(
        name: entry.key,
        current: cur,
        days1to30: d1_30,
        days31to60: d31_60,
        days61to90: d61_90,
        daysOver90: d90plus,
        total: total,
      ));
    }

    return rows;
  }

  // -------------------------------------------------------------
  // 4. UAE FTA VAT Summary Report
  // -------------------------------------------------------------
  VatSummaryReportData generateVatSummary({
    required List<Invoice> invoices,
    required OfficeData office,
    required ReportFilter filter,
  }) {
    double stdSales = 0, stdSalesVat = 0, zeroSales = 0, exemptSales = 0;
    for (final inv in invoices) {
      if (inv.status == 'issued' && _isDateInRange(inv.date, filter.startDate, filter.endDate)) {
        final t = Totals.of(inv);
        stdSales += t.subtotal / 100.0;
        stdSalesVat += t.tax / 100.0;
      }
    }

    double stdExpenses = 0, recoverableVat = 0;
    for (final e in office.entries) {
      if (e['kind'] == 'expense' && e['status'] == 'paid' && _isDateInRange(e['date']?.toString(), filter.startDate, filter.endDate)) {
        final amt = ((e['amountCents'] as num?)?.toInt() ?? 0) / 100.0;
        final vatRate = (e['vatPercent'] as num?)?.toDouble() ?? 5.0;
        final base = amt / (1 + (vatRate / 100.0));
        final vat = amt - base;
        stdExpenses += base;
        recoverableVat += vat;
      }
    }

    final totalSales = stdSales + zeroSales + exemptSales;
    final totalOutputVat = stdSalesVat;
    final totalInputVat = recoverableVat;
    final netVatPayable = totalOutputVat - totalInputVat;

    return VatSummaryReportData(
      standardRatedSales: stdSales,
      standardRatedSalesVat: stdSalesVat,
      zeroRatedSales: zeroSales,
      exemptSales: exemptSales,
      totalSales: totalSales,
      totalOutputVat: totalOutputVat,
      standardRatedExpenses: stdExpenses,
      recoverableInputVat: recoverableVat,
      totalInputVat: totalInputVat,
      netVatPayable: netVatPayable,
    );
  }

  // -------------------------------------------------------------
  // 5. Cash Flow Statement
  // -------------------------------------------------------------
  List<CashFlowSectionData> generateCashFlowStatement({
    required List<Invoice> invoices,
    required OfficeData office,
    required ReportFilter filter,
  }) {
    // 1. Operating Activities
    final List<ReportLineItem> operatingItems = [];
    double operatingInflow = 0;
    double operatingOutflow = 0;

    for (final inv in invoices) {
      for (final p in inv.payments) {
        if (_isDateInRange(p.date, filter.startDate, filter.endDate)) {
          final amt = p.cents / 100.0;
          operatingInflow += amt;
        }
      }
    }
    operatingItems.add(ReportLineItem(label: 'Customer Invoices Collected', amount: operatingInflow));

    for (final e in office.entries) {
      if (e['kind'] == 'expense' && e['status'] == 'paid' && _isDateInRange(e['date']?.toString(), filter.startDate, filter.endDate)) {
        final amt = ((e['amountCents'] as num?)?.toInt() ?? 0) / 100.0;
        operatingOutflow += amt;
      }
    }
    operatingItems.add(ReportLineItem(label: 'Supplier & Operational Disbursements', amount: -operatingOutflow));

    for (final p in office.payroll) {
      if (p['status'] == 'paid' && _isDateInRange(p['date']?.toString(), filter.startDate, filter.endDate)) {
        final amt = ((p['netCents'] as num?)?.toInt() ?? 0) / 100.0;
        operatingOutflow += amt;
      }
    }

    final netOperating = operatingInflow - operatingOutflow;

    // 2. Investing Activities
    final List<ReportLineItem> investingItems = [];
    double assetPurchases = 0;
    for (final a in office.assets) {
      if (a['acquisitionType'] == 'companyPurchase' && a['status'] != 'void' && _isDateInRange(a['purchaseDate']?.toString(), filter.startDate, filter.endDate)) {
        assetPurchases += ((a['costCents'] as num?)?.toInt() ?? 0) / 100.0;
      }
    }
    investingItems.add(ReportLineItem(label: 'Fixed Asset Capital Acquisitions', amount: -assetPurchases));
    final netInvesting = -assetPurchases;

    // 3. Financing Activities
    final List<ReportLineItem> financingItems = [];
    double capitalInflow = 0;
    double capitalOutflow = 0;

    for (final cap in office.capitalTransactions) {
      if (cap['status'] == 'void') continue;
      if (_isDateInRange(cap['date']?.toString(), filter.startDate, filter.endDate)) {
        final amt = ((cap['amountCents'] as num?)?.toInt() ?? 0) / 100.0;
        final cType = cap['contributionType']?.toString() ?? 'bank';
        final tType = cap['transactionType']?.toString() ?? 'capitalContribution';
        if (cType.toLowerCase() != 'asset') {
          if (tType == 'capitalWithdrawal') {
            capitalOutflow += amt;
          } else {
            capitalInflow += amt;
          }
        }
      }
    }
    financingItems.add(ReportLineItem(label: 'Shareholder Cash Contributions', amount: capitalInflow));
    if (capitalOutflow > 0) {
      financingItems.add(ReportLineItem(label: 'Shareholder Capital Withdrawals', amount: -capitalOutflow));
    }

    for (final loan in office.shareholderLoans) {
      if (loan['status'] == 'void') continue;
      if (_isDateInRange(loan['date']?.toString(), filter.startDate, filter.endDate)) {
        final amt = ((loan['amountCents'] as num?)?.toInt() ?? 0) / 100.0;
        final type = loan['type']?.toString() ?? 'loanReceived';
        if (type == 'loanReceived') {
          capitalInflow += amt;
          financingItems.add(ReportLineItem(label: 'Shareholder Loans Inflow', amount: amt));
        } else {
          capitalOutflow += amt;
          financingItems.add(ReportLineItem(label: 'Shareholder Loan Repayments', amount: -amt));
        }
      }
    }

    final netFinancing = capitalInflow - capitalOutflow;

    return [
      CashFlowSectionData(title: '1. Cash Flow from Operating Activities', items: operatingItems, netCashFlow: netOperating),
      CashFlowSectionData(title: '2. Cash Flow from Investing Activities', items: investingItems, netCashFlow: netInvesting),
      CashFlowSectionData(title: '3. Cash Flow from Financing Activities', items: financingItems, netCashFlow: netFinancing),
    ];
  }

  // -------------------------------------------------------------
  // 6. Sales by Customer Report
  // -------------------------------------------------------------
  List<ReportLineItem> generateSalesByCustomer({
    required List<Invoice> invoices,
    required List<Customer> customers,
    required ReportFilter filter,
  }) {
    final Map<String, int> revenueByCustomer = {};
    final Map<String, int> invoiceCounts = {};
    int grandTotalCents = 0;

    for (final inv in invoices) {
      if (inv.status == 'issued' && _isDateInRange(inv.date, filter.startDate, filter.endDate)) {
        final t = Totals.of(inv);
        revenueByCustomer[inv.customer.id] = (revenueByCustomer[inv.customer.id] ?? 0) + t.total;
        invoiceCounts[inv.customer.id] = (invoiceCounts[inv.customer.id] ?? 0) + 1;
        grandTotalCents += t.total;
      }
    }

    final List<ReportLineItem> items = [];
    for (final c in customers) {
      final revCents = revenueByCustomer[c.id] ?? 0;
      if (revCents > 0 || filter.searchQuery.isEmpty) {
        final count = invoiceCounts[c.id] ?? 0;
        items.add(ReportLineItem(
          label: c.name,
          code: c.id.substring(0, c.id.length.clamp(0, 6)),
          amount: revCents / 100.0,
          secondaryAmount: grandTotalCents > 0 ? (revCents / grandTotalCents) * 100.0 : 0.0,
          metadata: {'invoiceCount': count},
        ));
      }
    }

    items.sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  // -------------------------------------------------------------
  // 7. Statement of Changes in Equity
  // -------------------------------------------------------------
  List<ReportLineItem> generateStatementOfEquity({
    required List<Invoice> invoices,
    required OfficeData office,
    required List<Map<String, dynamic>> companyShareholders,
    required ReportFilter filter,
  }) {
    double openingCapital = 0;
    double cashContributions = 0;
    double assetContributions = 0;
    double capitalWithdrawals = 0;

    for (final cap in office.capitalTransactions) {
      if (cap['status'] == 'void') continue;
      final amt = ((cap['amountCents'] as num?)?.toInt() ?? 0) / 100.0;
      final tType = cap['transactionType']?.toString() ?? 'capitalContribution';
      final cType = cap['contributionType']?.toString() ?? 'bank';

      if (tType == 'capitalWithdrawal') {
        capitalWithdrawals += amt;
      } else if (cType.toLowerCase() == 'asset') {
        assetContributions += amt;
      } else {
        cashContributions += amt;
      }
    }

    for (final a in office.assets) {
      if (a['acquisitionType'] == 'shareholderContribution' && a['status'] != 'void') {
        assetContributions += ((a['costCents'] as num?)?.toInt() ?? 0) / 100.0;
      }
    }

    final closingCapital = openingCapital + cashContributions + assetContributions - capitalWithdrawals;

    // Operating Net Income
    int revCents = 0;
    for (final inv in invoices) {
      if (inv.status == 'issued') revCents += Totals.of(inv).total;
    }
    int expCents = 0;
    for (final e in office.entries) {
      if (e['kind'] == 'expense' && e['status'] == 'paid') expCents += (e['amountCents'] as num?)?.toInt() ?? 0;
    }
    for (final p in office.payroll) {
      if (p['status'] == 'approved' || p['status'] == 'paid') expCents += (p['netCents'] as num?)?.toInt() ?? 0;
    }
    final netProfit = (revCents - expCents) / 100.0;
    final closingEquity = closingCapital + netProfit;

    return [
      const ReportLineItem(label: 'SHAREHOLDER CONTRIBUTED CAPITAL', amount: 0, isHeader: true),
      ReportLineItem(label: 'Opening Shareholder Capital', amount: openingCapital, indentLevel: 1),
      ReportLineItem(label: '+ Cash Capital Contributions', amount: cashContributions, indentLevel: 1),
      ReportLineItem(label: '+ Fixed Asset Capital Contributions', amount: assetContributions, indentLevel: 1),
      if (capitalWithdrawals > 0)
        ReportLineItem(label: '- Capital Withdrawals', amount: -capitalWithdrawals, indentLevel: 1),
      ReportLineItem(label: 'Closing Shareholder Capital', amount: closingCapital, isTotal: true),

      const ReportLineItem(label: 'RETAINED EARNINGS & OPERATING PROFIT', amount: 0, isHeader: true),
      const ReportLineItem(label: 'Opening Retained Earnings', amount: 0.0, indentLevel: 1),
      ReportLineItem(label: '+ Current Period Net Operating Income', amount: netProfit, indentLevel: 1),
      ReportLineItem(label: 'Closing Retained Earnings', amount: netProfit, isTotal: true),

      ReportLineItem(label: 'TOTAL CLOSING SHAREHOLDER EQUITY', amount: closingEquity, isTotal: true),
    ];
  }

  // -------------------------------------------------------------
  // 8. General Ledger Transaction Log
  // -------------------------------------------------------------
  List<Map<String, dynamic>> generateGeneralLedger({
    required List<Invoice> invoices,
    required OfficeData office,
    required List<Map<String, dynamic>> companyShareholders,
    required ReportFilter filter,
  }) {
    final List<Map<String, dynamic>> entries = [];
    int runningBalanceCents = 0;

    void addEntry(String date, String accountName, String description, int debit, int credit) {
      if (!_isDateInRange(date, filter.startDate, filter.endDate)) return;
      runningBalanceCents += (debit - credit);
      entries.add({
        'date': date,
        'accountName': accountName,
        'description': description,
        'debitCents': debit,
        'creditCents': credit,
        'balanceCents': runningBalanceCents,
      });
    }

    // 1. Invoices & Payments
    for (final inv in invoices) {
      if (inv.status == 'issued') {
        final t = Totals.of(inv);
        addEntry(inv.date, 'Accounts Receivable', 'Invoice ${inv.number} - ${inv.customer.name}', t.total, 0);
        addEntry(inv.date, 'Service Revenue', 'Invoice ${inv.number} - Services', 0, t.subtotal);
        if (t.tax > 0) {
          addEntry(inv.date, 'VAT Output Liability', 'Invoice ${inv.number} - VAT 5%', 0, t.tax);
        }

        for (final p in inv.payments) {
          final acc = p.account.toLowerCase() == 'cash' ? 'Cash in Hand' : 'Bank Account';
          addEntry(p.date, acc, 'Payment for Invoice ${inv.number}', p.cents, 0);
          addEntry(p.date, 'Accounts Receivable', 'Payment Received - ${inv.customer.name}', 0, p.cents);
        }
      }
    }

    // 2. Office Entries (Expenses / Bills / Other Income)
    for (final e in office.entries) {
      final date = e['date']?.toString() ?? '';
      final amount = (e['amountCents'] as num?)?.toInt() ?? 0;
      final category = e['category']?.toString() ?? 'General';
      final acc = (e['account']?.toString() ?? 'Bank').toLowerCase() == 'cash' ? 'Cash in Hand' : 'Bank Account';

      if (e['status'] == 'unpaid') {
        addEntry(date, 'Operating Expenses - $category', 'Supplier Bill - ${e['supplier'] ?? 'Expense'}', amount, 0);
        addEntry(date, 'Accounts Payable', 'Bill Accrual - ${e['supplier'] ?? 'Payable'}', 0, amount);
      } else if (e['status'] == 'paid') {
        if (e['kind'] == 'income') {
          addEntry(date, acc, 'Income Received - $category', amount, 0);
          addEntry(date, 'Other Income', 'Income - ${e['notes'] ?? category}', 0, amount);
        } else {
          addEntry(date, 'Operating Expenses - $category', 'Expense Payment - ${e['notes'] ?? category}', amount, 0);
          addEntry(date, acc, 'Payment Disbursed', 0, amount);
        }
      }
    }

    // 3. Payroll
    for (final p in office.payroll) {
      final date = p['date']?.toString() ?? '';
      final net = (p['netCents'] as num?)?.toInt() ?? 0;
      final acc = (p['account']?.toString() ?? 'Bank').toLowerCase() == 'cash' ? 'Cash in Hand' : 'Bank Account';
      if (p['status'] == 'paid') {
        addEntry(date, 'Salaries & Wages Expense', 'Payroll Disbursement', net, 0);
        addEntry(date, acc, 'Payroll Net Transfer', 0, net);
      } else if (p['status'] == 'approved') {
        addEntry(date, 'Salaries & Wages Expense', 'Payroll Accrual', net, 0);
        addEntry(date, 'Payroll Due Payable', 'Payroll Liability', 0, net);
      }
    }

    // 4. Capital Contributions & Withdrawals
    for (final cap in office.capitalTransactions) {
      if (cap['status'] == 'void') continue;
      final date = cap['date']?.toString() ?? '';
      final amt = (cap['amountCents'] as num?)?.toInt() ?? 0;
      final tType = cap['transactionType']?.toString() ?? 'capitalContribution';
      final cType = cap['contributionType']?.toString() ?? 'bank';
      final assetAcc = cType.toLowerCase() == 'asset' ? 'Fixed Assets' : (cType.toLowerCase() == 'cash' ? 'Cash in Hand' : 'Bank Account');

      if (tType == 'capitalWithdrawal') {
        addEntry(date, 'Shareholder Capital', 'Capital Withdrawal', amt, 0);
        addEntry(date, assetAcc, 'Capital Withdrawal Payout', 0, amt);
      } else {
        addEntry(date, assetAcc, 'Shareholder Capital Injection', amt, 0);
        addEntry(date, 'Shareholder Capital', 'Contributed Equity', 0, amt);
      }
    }

    // 5. Shareholder Loans
    for (final loan in office.shareholderLoans) {
      if (loan['status'] == 'void') continue;
      final date = loan['date']?.toString() ?? '';
      final amt = (loan['amountCents'] as num?)?.toInt() ?? 0;
      final type = loan['type']?.toString() ?? 'loanReceived';
      if (type == 'loanReceived') {
        addEntry(date, 'Bank Account', 'Shareholder Loan Received', amt, 0);
        addEntry(date, 'Shareholder Loans Payable', 'Loan Liability', 0, amt);
      } else {
        addEntry(date, 'Shareholder Loans Payable', 'Shareholder Loan Repayment', amt, 0);
        addEntry(date, 'Bank Account', 'Loan Repayment Disbursement', 0, amt);
      }
    }

    // Sort by date ascending
    entries.sort((a, b) => (a['date']?.toString() ?? '').compareTo(b['date']?.toString() ?? ''));
    return entries;
  }
}
