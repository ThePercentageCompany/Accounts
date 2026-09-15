import '../../billing/domain/models.dart';
import '../../billing/domain/totals.dart';
import 'office_repository.dart';

/// The accounting read model. Every statement consumes only the posted lines
/// returned here; source records are used solely to create a missing, stable
/// migration journal until the record is persisted by its owning repository.
class AccountingEngine {
  const AccountingEngine._();

  static List<Map<String, dynamic>> postedJournals(
      List<Invoice> invoices, OfficeData office) {
    final journals = office.journals
        .where((j) => j['status']?.toString().toLowerCase() == 'posted')
        .map((j) => Map<String, dynamic>.from(j))
        .toList();
    final postedSources =
        journals.map((j) => '${j['sourceType']}:${j['sourceId']}').toSet();

    void add(Map<String, dynamic> journal) {
      final source = '${journal['sourceType']}:${journal['sourceId']}';
      if (postedSources.add(source)) journals.add(journal);
    }

    for (final invoice in invoices.where((i) => i.status == 'issued')) {
      final totals = Totals.of(invoice);
      add(_journal(
          'invoice', invoice.id, invoice.date, 'Invoice ${invoice.number}', [
        _line('accounts_receivable', 'Accounts Receivable', 'Asset',
            debit: totals.total),
        _line('service_consulting_revenue', 'Service & Consulting Revenue',
            'Income',
            credit: totals.subtotal),
        if (totals.tax > 0)
          _line('output_vat_payable', 'Output VAT Payable', 'Liability',
              credit: totals.tax),
      ]));
      for (final payment in invoice.payments) {
        add(_journal('customer_payment', payment.id, payment.date,
            'Customer payment for ${invoice.number}', [
          _line(
              payment.account.toLowerCase() == 'cash'
                  ? 'cash_in_hand'
                  : 'bank_account',
              payment.account.toLowerCase() == 'cash'
                  ? 'Cash in Hand'
                  : 'Bank Account',
              'Asset',
              debit: payment.cents),
          _line('accounts_receivable', 'Accounts Receivable', 'Asset',
              credit: payment.cents),
        ]));
      }
    }

    for (final entry in office.entries.where((e) => e['status'] != 'void')) {
      final amount = (entry['amountCents'] as num?)?.toInt() ?? 0;
      if (amount <= 0) continue;
      final id = entry['id']?.toString() ?? '';
      final date = entry['date']?.toString() ?? '';
      final kind = entry['kind']?.toString() ?? 'expense';
      final account = entry['account']?.toString().toLowerCase() == 'cash'
          ? 'Cash in Hand'
          : 'Bank Account';
      final accountId =
          account == 'Cash in Hand' ? 'cash_in_hand' : 'bank_account';
      if (kind == 'income') {
        add(_journal('finance_income', id, date, 'Other income', [
          _line(accountId, account, 'Asset', debit: amount),
          _line('other_income', 'Other Income', 'Income', credit: amount)
        ]));
      } else if (kind == 'capital') {
        add(_journal('finance_capital', id, date, 'Capital contribution', [
          _line(accountId, account, 'Asset', debit: amount),
          _line('shareholder_capital', 'Shareholder Capital', 'Equity',
              credit: amount)
        ]));
      } else {
        final category = entry['category']?.toString() ?? 'General Operating';
        final isFine = category.toLowerCase().contains('fine') ||
            category.toLowerCase().contains('penalty');
        final expenseName = isFine
            ? 'Fines & Penalties Expense'
            : 'Operating Expenses - $category';
        final expenseId = isFine
            ? 'fines_penalties_expense'
            : 'operating_expense_${category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
        if (entry['status'] == 'unpaid') {
          add(_journal('supplier_bill', id, date, 'Supplier bill', [
            _line(expenseId, expenseName, 'Expense', debit: amount),
            _line('accounts_payable', 'Accounts Payable', 'Liability',
                credit: amount)
          ]));
        } else {
          add(_journal('expense', id, date, 'Expense payment', [
            _line(expenseId, expenseName, 'Expense', debit: amount),
            _line(accountId, account, 'Asset', credit: amount)
          ]));
        }
      }
    }

    for (final payroll in office.payroll
        .where((p) => p['status'] == 'approved' || p['status'] == 'paid')) {
      final amount = (payroll['netCents'] as num?)?.toInt() ?? 0;
      if (amount <= 0) continue;
      final isPaid = payroll['status'] == 'paid';
      final account = payroll['account']?.toString().toLowerCase() == 'cash'
          ? 'Cash in Hand'
          : 'Bank Account';
      add(_journal(
          'payroll',
          payroll['id']?.toString() ?? '',
          payroll['paidDate']?.toString().isNotEmpty == true
              ? payroll['paidDate'].toString()
              : '${payroll['month']}-01',
          'Payroll',
          [
            _line(
                'salaries_wages_expense', 'Salaries & Wages Expense', 'Expense',
                debit: amount),
            _line(
                isPaid
                    ? (account == 'Cash in Hand'
                        ? 'cash_in_hand'
                        : 'bank_account')
                    : 'payroll_payable',
                isPaid ? account : 'Payroll Payable',
                isPaid ? 'Asset' : 'Liability',
                credit: amount),
          ]));
    }
    for (final capital
        in office.capitalTransactions.where((r) => r['status'] != 'void')) {
      final amount = (capital['amountCents'] as num?)?.toInt() ?? 0;
      if (amount <= 0) continue;
      final cash =
          capital['contributionType']?.toString().toLowerCase() == 'cash';
      final asset =
          capital['contributionType']?.toString().toLowerCase() == 'asset';
      final withdrawal = capital['transactionType'] == 'capitalWithdrawal';
      final shareholder =
          capital['shareholderName']?.toString() ?? 'Shareholder';
      final debit = asset
          ? _line('fixed_asset',
              capital['assetName']?.toString() ?? 'Fixed Assets', 'Asset',
              debit: amount)
          : _line(cash ? 'cash_in_hand' : 'bank_account',
              cash ? 'Cash in Hand' : 'Bank Account', 'Asset',
              debit: amount);
      final credit = _line('shareholder_capital_$shareholder',
          'Shareholder Capital - $shareholder', 'Equity',
          credit: amount);
      add(_journal(
          'capital',
          capital['id']?.toString() ?? '',
          capital['date']?.toString() ?? '',
          'Capital contribution',
          withdrawal
              ? [
                  _line('shareholder_capital_$shareholder',
                      'Shareholder Capital - $shareholder', 'Equity',
                      debit: amount),
                  _line(cash ? 'cash_in_hand' : 'bank_account',
                      cash ? 'Cash in Hand' : 'Bank Account', 'Asset',
                      credit: amount),
                ]
              : [debit, credit]));
    }
    for (final loan
        in office.shareholderLoans.where((r) => r['status'] != 'void')) {
      final amount = (loan['amountCents'] as num?)?.toInt() ?? 0;
      if (amount <= 0) continue;
      final cash = loan['paymentAccount']?.toString().toLowerCase() == 'cash';
      final repayment = loan['type'] == 'loanRepayment';
      final bank = _line(cash ? 'cash_in_hand' : 'bank_account',
          cash ? 'Cash in Hand' : 'Bank Account', 'Asset',
          debit: repayment ? 0 : amount, credit: repayment ? amount : 0);
      final payable = _line(
          'shareholder_loan_payable', 'Shareholder Loan Payable', 'Liability',
          debit: repayment ? amount : 0, credit: repayment ? 0 : amount);
      add(_journal(
          'shareholder_loan',
          loan['id']?.toString() ?? '',
          loan['date']?.toString() ?? '',
          'Shareholder loan',
          repayment ? [payable, bank] : [bank, payable]));
    }
    for (final asset in office.assets.where((r) => r['status'] != 'void')) {
      final cost = (asset['costCents'] as num?)?.toInt() ?? 0;
      if (cost <= 0) continue;
      final cash = asset['paymentAccount']?.toString().toLowerCase() == 'cash';
      final contributed = asset['acquisitionType'] == 'shareholderContribution';
      final name = asset['name']?.toString() ?? 'Fixed Asset';
      add(_journal(
          'asset_purchase',
          asset['id']?.toString() ?? '',
          asset['purchaseDate']?.toString() ?? '',
          'Asset acquisition - $name', [
        _line('fixed_asset_${asset['category']}',
            '${asset['category'] ?? 'Fixed Assets'} - $name', 'Asset',
            debit: cost),
        contributed
            ? _line('shareholder_capital', 'Shareholder Capital', 'Equity',
                credit: cost)
            : _line(cash ? 'cash_in_hand' : 'bank_account',
                cash ? 'Cash in Hand' : 'Bank Account', 'Asset',
                credit: cost),
      ]));
    }
    return journals;
  }

  static List<Map<String, dynamic>> postedLines(
      List<Invoice> invoices, OfficeData office) {
    final lines = <Map<String, dynamic>>[];
    for (final journal in postedJournals(invoices, office)) {
      for (final raw in (journal['lines'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final line = Map<String, dynamic>.from(raw);
        final debit = (line['debitCents'] as num?)?.toInt() ?? 0;
        final credit = (line['creditCents'] as num?)?.toInt() ?? 0;
        if (debit < 0 ||
            credit < 0 ||
            (debit > 0 && credit > 0) ||
            (debit == 0 && credit == 0)) continue;
        lines.add({
          ...line,
          'journalId': journal['id'],
          'journalNumber': journal['journalNumber'],
          'date': journal['date'],
          'description': journal['description'],
          'sourceType': journal['sourceType'],
          'sourceId': journal['sourceId']
        });
      }
    }
    return lines;
  }

  static Map<String, dynamic> _journal(String type, String id, String date,
          String description, List<Map<String, dynamic>> lines) =>
      {
        'id': 'migration_$type\_$id',
        'journalNumber': 'MIG-$type-$id',
        'date': date,
        'description': description,
        'sourceType': type,
        'sourceId': id,
        'status': 'posted',
        'lines': lines,
      };

  static Map<String, dynamic> _line(String id, String name, String group,
          {int debit = 0, int credit = 0}) =>
      {
        'accountId': id,
        'accountName': name,
        'accountGroup': group,
        'debitCents': debit,
        'creditCents': credit
      };
}
