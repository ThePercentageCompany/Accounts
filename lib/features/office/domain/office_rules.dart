import '../../billing/domain/totals.dart';
import '../../billing/domain/models.dart';
import 'office_repository.dart';

Map<String, dynamic> calculatePayroll(
  Map<String, dynamic> employee,
  List<Map<String, dynamic>> rows,
  Map<String, dynamic> d,
) {
  final salary = scaled(employee['basic'].toString(), 2) +
      scaled(employee['allowances'].toString(), 2);
  final divisor = int.parse(d['divisor'].toString()),
      days = double.parse(d['baseDays'].toString()),
      scheduled = int.parse(d['scheduledDays'].toString());
  if (divisor < 1 ||
      divisor > 31 ||
      days <= 0 ||
      days > divisor ||
      days * 2 != (days * 2).round() ||
      scheduled < 1 ||
      scheduled > 31) {
    throw StateError('Check divisor, base days and scheduled days.');
  }
  final counted = rows.where((r) => !['off', 'holiday'].contains(r['status'])).length;
  final absent = rows.fold<double>(
      0,
      (n, r) =>
          n +
          (['absent', 'unpaidLeave'].contains(r['status'])
              ? 1.0
              : (r['status'] == 'halfDay' ? 0.5 : 0.0)));
  final base = (salary * days / divisor).round(),
      absence = (salary * absent / divisor).round();
  final overtime = (rows.fold<int>(
              0, (n, r) => n + scaled(r['overtimeHours'].toString(), 2)) *
          scaled(d['overtimeRate'].toString(), 2) /
          100)
      .round();
  final bonus = scaled(d['bonus'].toString(), 2),
      deduction = scaled(d['deductions'].toString(), 2);
  final net = base + overtime + bonus - absence - deduction;
  if (absent > days || net < 0) throw StateError('Deductions exceed salary.');
  return {
    'baseCents': base,
    'absenceCents': absence,
    'overtimeCents': overtime,
    'bonusCents': bonus,
    'deductionCents': deduction,
    'netCents': net,
    'absentDays': absent,
    'markedDays': counted,
    'missingDays': scheduled - counted,
  };
}

/// Computes straight-line monthly and annual depreciation in cents
Map<String, int> calculateDepreciation({
  required int costCents,
  required int residualValueCents,
  required int usefulLifeMonths,
}) {
  if (usefulLifeMonths <= 0) return {'monthlyCents': 0, 'annualCents': 0, 'depreciableCents': 0};
  final depreciable = (costCents - residualValueCents).clamp(0, costCents);
  final monthly = (depreciable / usefulLifeMonths).round();
  final annual = (monthly * 12).clamp(0, depreciable);
  return {
    'depreciableCents': depreciable,
    'monthlyCents': monthly,
    'annualCents': annual,
  };
}

/// Generates balanced Double-Entry Journal for a Capital Transaction
Map<String, dynamic> createCapitalJournal({
  required String transactionId,
  required String shareholderName,
  required String date,
  required String transactionType, // capitalContribution, additionalCapital, capitalWithdrawal
  required String contributionType, // bank, cash, asset
  required int amountCents,
  String? assetName,
  String? accountName,
}) {
  final targetAccount = contributionType.toLowerCase() == 'cash' ? 'Cash in Hand' : (accountName ?? 'Bank Account');
  final isWithdrawal = transactionType == 'capitalWithdrawal';
  
  List<Map<String, dynamic>> lines = [];
  if (!isWithdrawal) {
    if (contributionType.toLowerCase() == 'asset') {
      // Dr Fixed Asset, Cr Shareholder Capital
      lines = [
        {'accountId': 'fixed_asset', 'accountName': assetName ?? 'Fixed Assets', 'accountGroup': 'Asset', 'debitCents': amountCents, 'creditCents': 0},
        {'accountId': 'shareholder_equity', 'accountName': 'Shareholder Capital - $shareholderName', 'accountGroup': 'Equity', 'debitCents': 0, 'creditCents': amountCents},
      ];
    } else {
      // Dr Bank/Cash, Cr Shareholder Capital
      lines = [
        {'accountId': contributionType.toLowerCase() == 'cash' ? 'cash_in_hand' : 'bank_account', 'accountName': targetAccount, 'accountGroup': 'Asset', 'debitCents': amountCents, 'creditCents': 0},
        {'accountId': 'shareholder_equity', 'accountName': 'Shareholder Capital - $shareholderName', 'accountGroup': 'Equity', 'debitCents': 0, 'creditCents': amountCents},
      ];
    }
  } else {
    // Dr Shareholder Capital, Cr Bank/Cash
    lines = [
      {'accountId': 'shareholder_equity', 'accountName': 'Shareholder Capital - $shareholderName', 'accountGroup': 'Equity', 'debitCents': amountCents, 'creditCents': 0},
      {'accountId': contributionType.toLowerCase() == 'cash' ? 'cash_in_hand' : 'bank_account', 'accountName': targetAccount, 'accountGroup': 'Asset', 'debitCents': 0, 'creditCents': amountCents},
    ];
  }

  return {
    'id': 'JRN_${DateTime.now().millisecondsSinceEpoch}',
    'journalNumber': 'JRN-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    'date': date,
    'sourceType': 'capital',
    'sourceId': transactionId,
    'description': isWithdrawal ? 'Capital withdrawal - $shareholderName' : 'Capital contribution ($contributionType) - $shareholderName',
    'lines': lines,
    'totalDebitCents': amountCents,
    'totalCreditCents': amountCents,
    'isBalanced': true,
    'status': 'posted',
  };
}

/// Generates balanced Double-Entry Journal for Shareholder Loans
Map<String, dynamic> createShareholderLoanJournal({
  required String loanId,
  required String shareholderName,
  required String date,
  required String type, // loanReceived, loanRepayment
  required int amountCents,
  required String paymentAccount,
}) {
  final targetAccount = paymentAccount.toLowerCase() == 'cash' ? 'Cash in Hand' : 'Bank Account';
  final isRepayment = type == 'loanRepayment';

  List<Map<String, dynamic>> lines = [];
  if (!isRepayment) {
    // Dr Bank/Cash, Cr Shareholder Loan (Liability)
    lines = [
      {'accountId': paymentAccount.toLowerCase() == 'cash' ? 'cash_in_hand' : 'bank_account', 'accountName': targetAccount, 'accountGroup': 'Asset', 'debitCents': amountCents, 'creditCents': 0},
      {'accountId': 'shareholder_loan', 'accountName': 'Shareholder Loan - $shareholderName', 'accountGroup': 'Liability', 'debitCents': 0, 'creditCents': amountCents},
    ];
  } else {
    // Dr Shareholder Loan, Cr Bank/Cash
    lines = [
      {'accountId': 'shareholder_loan', 'accountName': 'Shareholder Loan - $shareholderName', 'accountGroup': 'Liability', 'debitCents': amountCents, 'creditCents': 0},
      {'accountId': paymentAccount.toLowerCase() == 'cash' ? 'cash_in_hand' : 'bank_account', 'accountName': targetAccount, 'accountGroup': 'Asset', 'debitCents': 0, 'creditCents': amountCents},
    ];
  }

  return {
    'id': 'JRN_${DateTime.now().millisecondsSinceEpoch}',
    'journalNumber': 'JRN-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    'date': date,
    'sourceType': 'shareholder_loan',
    'sourceId': loanId,
    'description': isRepayment ? 'Shareholder loan repayment to $shareholderName' : 'Shareholder loan received from $shareholderName',
    'lines': lines,
    'totalDebitCents': amountCents,
    'totalCreditCents': amountCents,
    'isBalanced': true,
    'status': 'posted',
  };
}

/// Generates balanced Double-Entry Journal for Fixed Asset Purchase
Map<String, dynamic> createAssetPurchaseJournal({
  required String assetId,
  required String assetName,
  required String category,
  required String date,
  required String acquisitionType, // companyPurchase, shareholderContribution, openingBalance
  required int costCents,
  String? paymentAccount,
  String? shareholderName,
}) {
  List<Map<String, dynamic>> lines = [];
  if (acquisitionType == 'shareholderContribution') {
    // Dr Fixed Asset, Cr Shareholder Capital
    lines = [
      {'accountId': 'fixed_asset_$category', 'accountName': '$category - $assetName', 'accountGroup': 'Asset', 'debitCents': costCents, 'creditCents': 0},
      {'accountId': 'shareholder_equity', 'accountName': 'Shareholder Capital - ${shareholderName ?? 'Partner'}', 'accountGroup': 'Equity', 'debitCents': 0, 'creditCents': costCents},
    ];
  } else if (acquisitionType == 'openingBalance') {
    // Dr Fixed Asset, Cr Opening Balance Equity
    lines = [
      {'accountId': 'fixed_asset_$category', 'accountName': '$category - $assetName', 'accountGroup': 'Asset', 'debitCents': costCents, 'creditCents': 0},
      {'accountId': 'opening_balance_equity', 'accountName': 'Opening Balance Equity', 'accountGroup': 'Equity', 'debitCents': 0, 'creditCents': costCents},
    ];
  } else {
    // Company Purchase: Dr Fixed Asset, Cr Bank/Cash or Accounts Payable
    final payAcc = paymentAccount?.toLowerCase() == 'cash'
        ? 'Cash in Hand'
        : (paymentAccount?.toLowerCase() == 'credit' ? 'Accounts Payable' : 'Bank Account');
    final payGroup = paymentAccount?.toLowerCase() == 'credit' ? 'Liability' : 'Asset';
    final payId = paymentAccount?.toLowerCase() == 'cash'
        ? 'cash_in_hand'
        : (paymentAccount?.toLowerCase() == 'credit' ? 'accounts_payable' : 'bank_account');

    lines = [
      {'accountId': 'fixed_asset_$category', 'accountName': '$category - $assetName', 'accountGroup': 'Asset', 'debitCents': costCents, 'creditCents': 0},
      {'accountId': payId, 'accountName': payAcc, 'accountGroup': payGroup, 'debitCents': 0, 'creditCents': costCents},
    ];
  }

  return {
    'id': 'JRN_${DateTime.now().millisecondsSinceEpoch}',
    'journalNumber': 'JRN-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    'date': date,
    'sourceType': 'asset_purchase',
    'sourceId': assetId,
    'description': 'Asset acquisition ($acquisitionType): $assetName',
    'lines': lines,
    'totalDebitCents': costCents,
    'totalCreditCents': costCents,
    'isBalanced': true,
    'status': 'posted',
  };
}

/// Generates balanced Double-Entry Journal for Depreciation
Map<String, dynamic> createDepreciationJournal({
  required String assetId,
  required String assetName,
  required String date,
  required int depreciationCents,
}) {
  return {
    'id': 'JRN_${DateTime.now().millisecondsSinceEpoch}',
    'journalNumber': 'JRN-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    'date': date,
    'sourceType': 'depreciation',
    'sourceId': assetId,
    'description': 'Depreciation expense for $assetName',
    'lines': [
      {'accountId': 'depreciation_expense', 'accountName': 'Depreciation Expense', 'accountGroup': 'Expense', 'debitCents': depreciationCents, 'creditCents': 0},
      {'accountId': 'accumulated_depreciation', 'accountName': 'Accumulated Depreciation - $assetName', 'accountGroup': 'Asset', 'debitCents': 0, 'creditCents': depreciationCents},
    ],
    'totalDebitCents': depreciationCents,
    'totalCreditCents': depreciationCents,
    'isBalanced': true,
    'status': 'posted',
  };
}

/// Generates complete Balance Sheet Report
Map<String, dynamic> calculateBalanceSheet(
  List<Invoice> invoices,
  OfficeData office,
  List<Map<String, dynamic>> companyShareholders,
) {
  var cashInHand = 0, bankAccount = 0, accountsReceivable = 0;
  var accountsPayable = 0, payrollPayable = 0;
  var totalOriginalAssetCost = 0, totalAccumulatedDepreciation = 0;
  var operatingIncome = 0, operatingExpenses = 0, depreciationExpense = 0;
  var totalShareholderEquity = 0;

  void flow(String account, int cents) {
    if (account.toLowerCase() == 'cash') {
      cashInHand += cents;
    } else {
      bankAccount += cents;
    }
  }

  // 1. Invoices & Payments (Operating Income & Accounts Receivable)
  for (final inv in invoices) {
    if (inv.status == 'issued') {
      accountsReceivable += Totals.of(inv).balance;
      for (final p in inv.payments) {
        flow(p.account, p.cents);
      }
      operatingIncome += Totals.of(inv).total;
    }
  }

  // 2. Operational Entries (Bills, Operating Expenses, Other Income, and Finance Capital)
  for (final e in office.entries) {
    final amount = (e['amountCents'] as num?)?.toInt() ?? 0;
    if (e['status'] == 'unpaid') {
      accountsPayable += amount;
    }
    if (e['status'] == 'paid') {
      final account = e['account'] as String? ?? 'Bank';
      if (e['kind'] == 'income') {
        operatingIncome += amount;
        flow(account, amount);
      } else if (e['kind'] == 'capital') {
        totalShareholderEquity += amount;
        flow(account, amount);
      } else if (e['kind'] == 'expense') {
        operatingExpenses += amount;
        flow(account, -amount);
      }
    }
  }

  // 3. Payroll (Salaries Expense & Payable)
  for (final p in office.payroll) {
    final amount = (p['netCents'] as num?)?.toInt() ?? 0;
    if (p['status'] == 'approved') payrollPayable += amount;
    if (p['status'] == 'paid') {
      operatingExpenses += amount;
      flow(p['account'] as String? ?? 'Bank', -amount);
    }
  }

  // 4. Capital Contributions & Withdrawals (Liquidity flow, strictly no effect on Operating P&L)
  for (final cap in office.capitalTransactions) {
    if (cap['status'] == 'void') continue;
    final amount = (cap['amountCents'] as num?)?.toInt() ?? 0;
    final type = cap['transactionType'] as String? ?? 'capitalContribution';
    final contribType = cap['contributionType'] as String? ?? 'bank';
    final account = cap['bankAccountId'] as String? ?? 'Bank';

    if (contribType.toLowerCase() != 'asset') {
      if (type == 'capitalWithdrawal') {
        flow(account, -amount);
      } else {
        flow(account, amount);
      }
    }
  }

  // 5. Shareholder Loans (Liquidity flow & Liabilities)
  var totalShareholderLoans = 0;
  for (final loan in office.shareholderLoans) {
    if (loan['status'] == 'void') continue;
    final amount = (loan['amountCents'] as num?)?.toInt() ?? 0;
    final type = loan['type'] as String? ?? 'loanReceived';
    final account = loan['paymentAccount'] as String? ?? 'Bank';

    if (type == 'loanReceived') {
      totalShareholderLoans += amount;
      flow(account, amount);
    } else if (type == 'loanRepayment') {
      totalShareholderLoans -= amount;
      flow(account, -amount);
    }
  }

  // 6. Fixed Assets (Asset purchases from bank/cash, plus depreciation)
  final Map<String, int> fixedAssetsByCategory = {};
  for (final a in office.assets) {
    if (a['status'] == 'disposed' || a['status'] == 'void') continue;
    final cost = (a['costCents'] as num?)?.toInt() ?? 0;
    final accDep = (a['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0;
    final cat = a['category'] as String? ?? 'Other Fixed Assets';
    final acqType = a['acquisitionType'] as String? ?? 'companyPurchase';
    final payAcc = a['paymentAccount'] as String? ?? 'Bank';

    totalOriginalAssetCost += cost;
    totalAccumulatedDepreciation += accDep;
    depreciationExpense += accDep;
    fixedAssetsByCategory[cat] = (fixedAssetsByCategory[cat] ?? 0) + (cost - accDep);

    // If company bought asset with bank/cash, it reduced liquidity
    if (acqType == 'companyPurchase' && payAcc.toLowerCase() != 'credit') {
      flow(payAcc, -cost);
    }
  }

  // 7. Shareholder Equity per partner
  final List<Map<String, dynamic>> shareholderEquityRows = [];

  // Build map of contributions
  final Map<String, int> partnerCashContributed = {};
  final Map<String, int> partnerAssetContributed = {};

  for (final cap in office.capitalTransactions) {
    if (cap['status'] == 'void') continue;
    final amount = (cap['amountCents'] as num?)?.toInt() ?? 0;
    final sId = cap['shareholderId'] as String? ?? '';
    final type = cap['transactionType'] as String? ?? 'capitalContribution';
    final cType = cap['contributionType'] as String? ?? 'bank';

    if (type == 'capitalWithdrawal') {
      partnerCashContributed[sId] = (partnerCashContributed[sId] ?? 0) - amount;
    } else if (cType.toLowerCase() == 'asset') {
      partnerAssetContributed[sId] = (partnerAssetContributed[sId] ?? 0) + amount;
    } else {
      partnerCashContributed[sId] = (partnerCashContributed[sId] ?? 0) + amount;
    }
  }

  // Also include direct shareholder contributed assets
  for (final a in office.assets) {
    if (a['acquisitionType'] == 'shareholderContribution' && a['status'] != 'void') {
      final sId = a['shareholderId'] as String? ?? '';
      final cost = (a['costCents'] as num?)?.toInt() ?? 0;
      if (sId.isNotEmpty && !(partnerAssetContributed[sId]?.toString().contains(cost.toString()) ?? false)) {
        partnerAssetContributed[sId] = (partnerAssetContributed[sId] ?? 0) + cost;
      }
    }
  }

  // Combine shareholders from company profile or office.shareholders
  final allShareholders = (office.shareholders.isNotEmpty ? office.shareholders : companyShareholders);
  for (final sh in allShareholders) {
    final sId = sh['id'] as String? ?? '';
    final name = sh['name'] as String? ?? 'Shareholder';
    final cash = partnerCashContributed[sId] ?? scaled((sh['cashInvested'] ?? 0).toString(), 2);
    final assets = partnerAssetContributed[sId] ?? scaled((sh['assetContributions'] ?? 0).toString(), 2);
    final total = cash + assets;
    totalShareholderEquity += total;

    shareholderEquityRows.add({
      'shareholderId': sId,
      'name': name,
      'cashInvestedCents': cash,
      'assetContributionCents': assets,
      'totalInvestedCents': total,
      'ownershipPercentage': (sh['ownershipPercentage'] as num?)?.toDouble() ?? 0.0,
    });
  }

  final currentYearNetProfit = operatingIncome - operatingExpenses - depreciationExpense;

  // Assets
  final totalCurrentAssets = cashInHand + bankAccount + accountsReceivable;
  final totalFixedAssets = (totalOriginalAssetCost - totalAccumulatedDepreciation).clamp(0, totalOriginalAssetCost);
  final totalAssets = totalCurrentAssets + totalFixedAssets;

  // Liabilities
  final totalLiabilities = accountsPayable + payrollPayable + totalShareholderLoans;

  // Equity
  final totalEquity = totalShareholderEquity + currentYearNetProfit;

  final totalLiabilitiesAndEquity = totalLiabilities + totalEquity;
  final variance = totalAssets - totalLiabilitiesAndEquity;
  final isBalanced = variance.abs() <= 5; // allow minor cent rounding

  return {
    'currentAssets': [
      {'name': 'Cash in Hand', 'amountCents': cashInHand},
      {'name': 'Bank Accounts', 'amountCents': bankAccount},
      {'name': 'Accounts Receivable (A/R)', 'amountCents': accountsReceivable},
    ],
    'totalCurrentAssetsCents': totalCurrentAssets,
    'fixedAssetsByCategory': fixedAssetsByCategory.entries.map((e) => {'category': e.key, 'amountCents': e.value}).toList(),
    'totalOriginalAssetCostCents': totalOriginalAssetCost,
    'totalAccumulatedDepreciationCents': totalAccumulatedDepreciation,
    'totalFixedAssetsCents': totalFixedAssets,
    'totalAssetsCents': totalAssets,
    
    'liabilities': [
      {'name': 'Accounts Payable (Supplier Bills)', 'amountCents': accountsPayable},
      {'name': 'Payroll Due Payable', 'amountCents': payrollPayable},
      {'name': 'Shareholder Loans Payable', 'amountCents': totalShareholderLoans},
    ],
    'totalLiabilitiesCents': totalLiabilities,

    'shareholderEquityRows': shareholderEquityRows,
    'totalShareholderEquityCents': totalShareholderEquity,
    'currentYearNetProfitCents': currentYearNetProfit,
    'operatingIncomeCents': operatingIncome,
    'operatingExpensesCents': operatingExpenses,
    'depreciationExpenseCents': depreciationExpense,
    'totalEquityCents': totalEquity,

    'totalLiabilitiesAndEquityCents': totalLiabilitiesAndEquity,
    'isBalanced': isBalanced,
    'varianceCents': variance,
  };
}

/// Generates Trial Balance with balanced Debits vs Credits verification
Map<String, dynamic> calculateTrialBalance(List<Invoice> invoices, OfficeData office) {
  final Map<String, Map<String, dynamic>> accounts = {};

  void record(String id, String name, String group, int debit, int credit) {
    if (!accounts.containsKey(id)) {
      accounts[id] = {
        'accountId': id,
        'accountName': name,
        'accountGroup': group,
        'debitCents': 0,
        'creditCents': 0,
      };
    }
    accounts[id]!['debitCents'] = (accounts[id]!['debitCents'] as int) + debit;
    accounts[id]!['creditCents'] = (accounts[id]!['creditCents'] as int) + credit;
  }

  // Invoices & Customer Receipts
  for (final inv in invoices) {
    if (inv.status == 'issued') {
      final total = Totals.of(inv).total;
      record('accounts_receivable', 'Accounts Receivable', 'Asset', total, 0);
      record('service_income', 'Service & Consulting Revenue', 'Income', 0, total);

      for (final p in inv.payments) {
        final accId = p.account.toLowerCase() == 'cash' ? 'cash_in_hand' : 'bank_account';
        final accName = p.account.toLowerCase() == 'cash' ? 'Cash in Hand' : 'Bank Account';
        record(accId, accName, 'Asset', p.cents, 0);
        record('accounts_receivable', 'Accounts Receivable', 'Asset', 0, p.cents);
      }
    }
  }

  // Operating Expenses & Supplier Bills
  for (final e in office.entries) {
    final amount = (e['amountCents'] as num?)?.toInt() ?? 0;
    if (e['status'] == 'unpaid') {
      record('operating_expenses', 'Operating Expenses', 'Expense', amount, 0);
      record('accounts_payable', 'Accounts Payable', 'Liability', 0, amount);
    } else if (e['status'] == 'paid') {
      final accId = (e['account'] as String? ?? 'Bank').toLowerCase() == 'cash' ? 'cash_in_hand' : 'bank_account';
      final accName = (e['account'] as String? ?? 'Bank').toLowerCase() == 'cash' ? 'Cash in Hand' : 'Bank Account';
      if (e['kind'] == 'income') {
        record(accId, accName, 'Asset', amount, 0);
        record('other_income', 'Other Business Income', 'Income', 0, amount);
      } else if (e['kind'] == 'capital') {
        record(accId, accName, 'Asset', amount, 0);
        record('shareholder_capital', 'Shareholder Capital (${e['party']?.toString().isNotEmpty == true ? e['party'] : (e['category'] ?? 'General')})', 'Equity', 0, amount);
      } else {
        record('operating_expenses', 'Operating Expenses - ${(e['category'] ?? 'General')}', 'Expense', amount, 0);
        record(accId, accName, 'Asset', 0, amount);
      }
    }
  }

  // Payroll
  for (final p in office.payroll) {
    final amount = (p['netCents'] as num?)?.toInt() ?? 0;
    if (p['status'] == 'approved') {
      record('salaries_expense', 'Salaries & Wages Expense', 'Expense', amount, 0);
      record('payroll_payable', 'Accrued Payroll Payable', 'Liability', 0, amount);
    } else if (p['status'] == 'paid') {
      final accId = (p['account'] as String? ?? 'Bank').toLowerCase() == 'cash' ? 'cash_in_hand' : 'bank_account';
      final accName = (p['account'] as String? ?? 'Bank').toLowerCase() == 'cash' ? 'Cash in Hand' : 'Bank Account';
      record('salaries_expense', 'Salaries & Wages Expense', 'Expense', amount, 0);
      record(accId, accName, 'Asset', 0, amount);
    }
  }

  // Capital Transactions
  for (final cap in office.capitalTransactions) {
    if (cap['status'] == 'void') continue;
    final amount = (cap['amountCents'] as num?)?.toInt() ?? 0;
    final sName = cap['shareholderName'] as String? ?? 'Shareholder';
    final type = cap['transactionType'] as String? ?? 'capitalContribution';
    final cType = cap['contributionType'] as String? ?? 'bank';
    final accId = cType.toLowerCase() == 'cash' ? 'cash_in_hand' : 'bank_account';
    final accName = cType.toLowerCase() == 'cash' ? 'Cash in Hand' : 'Bank Account';

    if (type == 'capitalWithdrawal') {
      record('shareholder_capital', 'Shareholder Capital ($sName)', 'Equity', amount, 0);
      record(accId, accName, 'Asset', 0, amount);
    } else if (cType.toLowerCase() == 'asset') {
      record('fixed_assets', 'Fixed Assets', 'Asset', amount, 0);
      record('shareholder_capital', 'Shareholder Capital ($sName)', 'Equity', 0, amount);
    } else {
      record(accId, accName, 'Asset', amount, 0);
      record('shareholder_capital', 'Shareholder Capital ($sName)', 'Equity', 0, amount);
    }
  }

  // Shareholder Loans
  for (final loan in office.shareholderLoans) {
    if (loan['status'] == 'void') continue;
    final amount = (loan['amountCents'] as num?)?.toInt() ?? 0;
    final sName = loan['shareholderName'] as String? ?? 'Shareholder';
    final type = loan['type'] as String? ?? 'loanReceived';
    final accId = (loan['paymentAccount'] as String? ?? 'Bank').toLowerCase() == 'cash' ? 'cash_in_hand' : 'bank_account';
    final accName = (loan['paymentAccount'] as String? ?? 'Bank').toLowerCase() == 'cash' ? 'Cash in Hand' : 'Bank Account';

    if (type == 'loanReceived') {
      record(accId, accName, 'Asset', amount, 0);
      record('shareholder_loan', 'Shareholder Loan ($sName)', 'Liability', 0, amount);
    } else {
      record('shareholder_loan', 'Shareholder Loan ($sName)', 'Liability', amount, 0);
      record(accId, accName, 'Asset', 0, amount);
    }
  }

  // Assets & Depreciation
  for (final a in office.assets) {
    if (a['status'] == 'void') continue;
    final cost = (a['costCents'] as num?)?.toInt() ?? 0;
    final accDep = (a['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0;
    final cat = a['category'] as String? ?? 'Fixed Assets';
    final acqType = a['acquisitionType'] as String? ?? 'companyPurchase';

    if (acqType == 'companyPurchase') {
      final payAcc = a['paymentAccount'] as String? ?? 'Bank';
      final accId = payAcc.toLowerCase() == 'cash' ? 'cash_in_hand' : 'bank_account';
      final accName = payAcc.toLowerCase() == 'cash' ? 'Cash in Hand' : 'Bank Account';
      record('fixed_assets_$cat', '$cat - ${(a['name'] ?? '')}', 'Asset', cost, 0);
      record(accId, accName, 'Asset', 0, cost);
    }

    if (accDep > 0) {
      record('depreciation_expense', 'Depreciation Expense', 'Expense', accDep, 0);
      record('accumulated_depreciation', 'Accumulated Depreciation - ${(a['name'] ?? '')}', 'Asset', 0, accDep);
    }
  }

  final rows = accounts.values.map((row) {
    final deb = row['debitCents'] as int;
    final cred = row['creditCents'] as int;
    final net = deb - cred;
    return {
      ...row,
      'netBalanceCents': net,
      'displayDebitCents': net > 0 ? net : 0,
      'displayCreditCents': net < 0 ? -net : 0,
    };
  }).toList();

  var totalDebits = 0, totalCredits = 0;
  for (final r in rows) {
    totalDebits += r['displayDebitCents'] as int;
    totalCredits += r['displayCreditCents'] as int;
  }

  return {
    'rows': rows,
    'totalDebitCents': totalDebits,
    'totalCreditCents': totalCredits,
    'isBalanced': (totalDebits - totalCredits).abs() <= 5,
    'varianceCents': totalDebits - totalCredits,
  };
}

/// Legacy monthly cash flow summary for backward compatibility
Map<String, int> financialSummary(List<Invoice> invoices, OfficeData office, String month) {
  var receipts = 0, otherIncome = 0, capitalInflow = 0, expenses = 0, salaries = 0, receivable = 0, payable = 0, payrollDue = 0, bank = 0, cash = 0;
  void flow(String account, int cents) {
    if (account.toLowerCase() == 'cash') {
      cash += cents;
    } else {
      bank += cents;
    }
  }

  for (final i in invoices.where((i) => i.status == 'issued')) {
    receivable += Totals.of(i).balance;
    for (final p in i.payments.where((p) => p.date.startsWith(month))) {
      receipts += p.cents;
      flow(p.account, p.cents);
    }
  }
  for (final e in office.entries) {
    final amount = (e['amountCents'] as num).toInt();
    if (e['status'] == 'unpaid') payable += amount;
    if (e['status'] != 'paid' || !(e['paidDate'] as String).startsWith(month)) continue;
    if (e['kind'] == 'income' || e['kind'] == 'capital') {
      otherIncome += amount;
      if (e['kind'] == 'capital') capitalInflow += amount;
      flow(e['account'], amount);
    } else {
      expenses += amount;
      flow(e['account'], -amount);
    }
  }
  for (final p in office.payroll) {
    final amount = (p['netCents'] as num).toInt();
    if (p['status'] == 'approved') payrollDue += amount;
    if (p['status'] == 'paid' && (p['paidDate'] as String).startsWith(month)) {
      salaries += amount;
      flow(p['account'], -amount);
    }
  }
  return {
    'Invoice collections': receipts,
    'Other income': otherIncome,
    'Capital / Investment': capitalInflow,
    'Expenses paid': expenses,
    'Payroll paid': salaries,
    'Net cash movement': receipts + otherIncome - expenses - salaries,
    'Bank movement': bank,
    'Cash movement': cash,
    'Customer outstanding (all dates)': receivable,
    'Supplier bills due (all dates)': payable,
    'Approved payroll due (all dates)': payrollDue,
  };
}

