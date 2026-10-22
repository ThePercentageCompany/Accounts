import 'offline_store.dart';
import 'offline_outbox.dart';
import 'fixed_decimal.dart';

BigInt _minor(Object? value) => decimalUnits(value);

String _money(BigInt value) =>
    '${value.isNegative ? '-' : ''}${value.abs() ~/ BigInt.from(100)}.${(value.abs() % BigInt.from(100)).toString().padLeft(2, '0')}';

/// A separate view over confirmed reports. Never persists estimates as ledger rows.
Map<String, dynamic> projectFinancialReport(
  OfflineOutbox box,
  Map<String, dynamic> snapshot,
  String kind,
  List<Map<String, dynamic>> Function(String table) records,
) {
  final report = copyJson(snapshot);
  final lines = <Map<String, dynamic>>[];
  final unresolved = <String>[];
  final projected = <String>{};
  Map<String, dynamic> source(Map op) =>
      records('${op['table']}')
          .where((row) => row['recordId'] == (op['recordId'] ?? op['localId']))
          .firstOrNull ??
      {};
  const accounts = <String, (String, String)>{
    'cash_in_hand': ('Cash in Hand', 'Asset'),
    'bank_account': ('Bank Account', 'Asset'),
    'cash': ('Cash', 'Asset'),
    'bank': ('Bank', 'Asset'),
    'accounts_receivable': ('Accounts Receivable', 'Asset'),
    'accounts_payable': ('Accounts Payable', 'Liability'),
    'other_income': ('Other Income', 'Income'),
    'operating_expense': ('Operating Expense', 'Expense'),
    'output_vat_payable': ('Output VAT Payable', 'Liability'),
    'input_vat': ('Input VAT', 'Asset'),
    'service_consulting_revenue': ('Service & Consulting Revenue', 'Income'),
    'fixed_assets': ('Fixed Assets', 'Asset'),
    'shareholder_equity': ('Shareholder Equity', 'Equity'),
    'shareholder_loan': ('Shareholder Loan', 'Liability'),
    'salary_expense': ('Salary Expense', 'Expense'),
    'salary_payable': ('Salary Payable', 'Liability'),
    'payroll_deductions_payable': ('Payroll Deductions Payable', 'Liability'),
    'depreciation_expense': ('Depreciation Expense', 'Expense'),
    'accumulated_depreciation': ('Accumulated Depreciation', 'Asset'),
    'loss_on_asset_disposal': ('Loss on Asset Disposal', 'Expense'),
    'gain_on_asset_disposal': ('Gain on Asset Disposal', 'Income'),
  };
  String cash(Object? value, {bool legacy = false}) =>
      '${value ?? ''}'.toLowerCase() == 'cash'
      ? (legacy ? 'cash_in_hand' : 'cash')
      : (legacy ? 'bank_account' : 'bank');
  for (final op in box.pending) {
    if (op['state'] == 'failed') continue;
    final table = '${op['table']}', action = '${op['action']}';
    final journalPosting =
        table == 'Journals' &&
        action == 'update' &&
        (op['values'] as Map?)?['status'] == 'POSTED';
    if ([
          'create',
          'update',
          'delete',
          'send',
          'convert',
          'upload',
          'transferMatch',
        ].contains(action) &&
        !journalPosting) {
      continue;
    }
    if (op['submitted'] == true) {
      // A response can be lost after the server commits. A refreshed statement
      // may already include this command, and section snapshots cannot prove
      // whether it does. Retain the command and pending indicator without
      // adding its estimate twice to an authoritative balance.
      unresolved.add('${op['operationId']}');
      continue;
    }
    final row = source(op);
    final values = Map<String, dynamic>.from(op['values'] as Map? ?? {});
    final next = {...row, ...values};
    final start = lines.length;
    var journalNumber = 0;
    final rate = row['exchangeRate'] ?? 1;
    BigInt amount(Object? value) => convertMinor(value, rate);

    void line(String date, String id, BigInt net) {
      final account = accounts[id];
      if (account == null || net == BigInt.zero || date.isEmpty) return;
      lines.add({
        'date': date,
        'accountId': id,
        'accountName': account.$1,
        'accountGroup': account.$2,
        'net': net,
        'operationId': op['operationId'],
        'journalId': 'local_${op['operationId']}_$journalNumber',
        'sourceType': table,
        'sourceId': op['recordId'] ?? op['localId'],
        'description': next['description'] ?? 'Pending $table $action',
      });
    }

    void pair(String date, String debit, String credit, BigInt value) {
      journalNumber++;
      line(date, debit, value);
      line(date, credit, -value);
    }

    try {
      if (row.isNotEmpty && journalPosting) {
        final journalLines = records(
          'JournalLines',
        ).where((line) => line['journalId'] == row['recordId']).toList();
        if (journalLines.length >= 2) {
          for (final entry in journalLines) {
            lines.add({
              ...entry,
              'date': next['date'],
              'net': _minor(entry['debit']) - _minor(entry['credit']),
              'operationId': op['operationId'],
              'journalId': 'local_${op['operationId']}',
              'sourceType': next['sourceType'] ?? 'Manual',
              'sourceId': next['sourceId'] ?? row['recordId'],
              'description': next['description'] ?? 'Pending journal',
            });
          }
        }
      } else if (row.isNotEmpty &&
          ['Income', 'Expenses'].contains(table) &&
          action == 'post') {
        final income = table == 'Income', date = '${row['date'] ?? ''}';
        final control = income ? 'accounts_receivable' : 'accounts_payable';
        final total = amount(row['total']), tax = amount(row['taxAmount']);
        line(date, control, income ? total : -total);
        line(
          date,
          income ? 'other_income' : 'operating_expense',
          income ? -(total - tax) : total - tax,
        );
        line(
          date,
          income ? 'output_vat_payable' : 'input_vat',
          income ? -tax : tax,
        );
        if (row['paymentStatus'] == 'PAID') {
          pair(
            '${row['paidDate'] ?? ''}',
            income ? cash(row['account'], legacy: true) : control,
            income ? control : cash(row['account'], legacy: true),
            total,
          );
        }
      } else if (row.isNotEmpty &&
          ['Income', 'Expenses'].contains(table) &&
          action == 'pay' &&
          (next['paymentExchangeRate'] ?? row['exchangeRate'] ?? 1) ==
              (row['exchangeRate'] ?? 1)) {
        final income = table == 'Income';
        pair(
          '${next['paidDate'] ?? ''}',
          income ? cash(next['account'], legacy: true) : 'accounts_payable',
          income ? 'accounts_receivable' : cash(next['account'], legacy: true),
          amount(row['total']),
        );
      } else if (row.isNotEmpty && table == 'Invoices' && action == 'issue') {
        final date = '${row['issueDate'] ?? ''}',
            total = amount(row['total']),
            tax = amount(row['taxAmount']);
        line(date, 'accounts_receivable', total);
        line(date, 'service_consulting_revenue', -(total - tax));
        line(date, 'output_vat_payable', -tax);
      } else if (row.isNotEmpty &&
          table == 'MoneyTransfers' &&
          action == 'transferPost') {
        pair(
          '${row['date'] ?? ''}',
          cash(row['toAccount'], legacy: true),
          cash(row['fromAccount'], legacy: true),
          _minor(row['amount']),
        );
      } else if (row.isNotEmpty &&
          table == 'Assets' &&
          action == 'capitalize') {
        pair(
          '${row['purchaseDate'] ?? ''}',
          'fixed_assets',
          cash(row['paymentAccount']),
          _minor(row['cost']),
        );
      } else if (row.isNotEmpty &&
          table == 'CapitalTransactions' &&
          action == 'capitalPost') {
        pair(
          '${row['date'] ?? ''}',
          cash(row['destinationAccount']),
          'shareholder_equity',
          _minor(row['amount']),
        );
      } else if (row.isNotEmpty &&
          table == 'ShareholderLoans' &&
          action == 'loanPost') {
        pair(
          '${row['date'] ?? ''}',
          cash(row['paymentAccount']),
          'shareholder_loan',
          _minor(row['principal']),
        );
      } else if (row.isNotEmpty &&
          table == 'Assets' &&
          action == 'depreciate' &&
          row['usefulLife'] is num &&
          (row['usefulLife'] as num) > 0) {
        final cost = _minor(row['cost']),
            residual = _minor(row['residualValue']),
            accumulated = _minor(row['accumulatedDepreciation']);
        final life = BigInt.from(row['usefulLife'] as num);
        final monthly = (cost - residual + life ~/ BigInt.two) ~/ life;
        final remaining = cost - residual - accumulated;
        if (remaining > BigInt.zero) {
          pair(
            '${next['lastDepreciationDate'] ?? ''}',
            'depreciation_expense',
            'accumulated_depreciation',
            monthly < remaining ? monthly : remaining,
          );
        }
      } else if (row.isNotEmpty &&
          table == 'Assets' &&
          action == 'assetDispose') {
        final date = '${next['disposalDate'] ?? ''}',
            cost = _minor(row['cost']),
            accumulated = _minor(row['accumulatedDepreciation']),
            proceeds = _minor(next['disposalProceeds']);
        final gain = proceeds - (cost - accumulated);
        line(date, cash(next['disposalAccount']), proceeds);
        line(date, 'accumulated_depreciation', accumulated);
        line(date, 'fixed_assets', -cost);
        line(
          date,
          gain.isNegative ? 'loss_on_asset_disposal' : 'gain_on_asset_disposal',
          -gain,
        );
      } else if (row.isNotEmpty &&
          table == 'ShareholderLoans' &&
          action == 'loanRepay') {
        pair(
          '${next['lastRepaymentDate'] ?? ''}',
          'shareholder_loan',
          cash(next['paymentAccount']),
          _minor(row['outstandingBalance']),
        );
      } else if (row.isNotEmpty &&
          table == 'Payroll' &&
          action == 'payrollPay' &&
          (next['paymentExchangeRate'] ?? row['exchangeRate'] ?? 1) ==
              (row['exchangeRate'] ?? 1)) {
        pair(
          '${next['paidDate'] ?? ''}',
          'salary_payable',
          cash(next['paymentAccount']),
          amount(row['netSalary']),
        );
      } else if (row.isNotEmpty &&
          table == 'MoneyTransfers' &&
          action == 'transferReverse') {
        pair(
          '${next['reversalDate'] ?? ''}',
          cash(row['fromAccount'], legacy: true),
          cash(row['toAccount'], legacy: true),
          _minor(row['amount']),
        );
      } else if (table == 'Receipts' &&
          action == 'receive' &&
          (next['exchangeRate'] ?? 1) == 1 &&
          (next['paymentExchangeRate'] ?? 1) == 1 &&
          records('Invoices').any(
            (invoice) =>
                invoice['recordId'] == next['invoiceId'] &&
                (invoice['exchangeRate'] ?? 1) == 1,
          )) {
        pair(
          '${next['paymentDate'] ?? ''}',
          cash(next['paymentAccount']),
          'accounts_receivable',
          _minor(next['amount']),
        );
      } else if (row.isNotEmpty && table == 'Payroll' && action == 'approve') {
        final month = DateTime.tryParse('${row['month']}-01');
        if (month != null) {
          final date = DateTime(
            month.year,
            month.month + 1,
            0,
          ).toIso8601String().substring(0, 10);
          line(date, 'salary_expense', amount(row['grossSalary']));
          line(date, 'salary_payable', -amount(row['netSalary']));
          line(date, 'payroll_deductions_payable', -amount(row['deductions']));
        }
      } else if (row.isNotEmpty &&
          [
            'reverse',
            'invoiceVoid',
            'payrollReverse',
            'receiptReverse',
          ].contains(action)) {
        final types = action == 'invoiceVoid'
            ? ['Invoice']
            : action == 'receiptReverse'
            ? ['Receipt']
            : action == 'payrollReverse'
            ? ['Payroll', if (row['status'] == 'PAID') 'PayrollPayment']
            : [table, if (row['paymentStatus'] == 'PAID') '${table}Payment'];
        final originals = records('Journals')
            .where(
              (journal) =>
                  journal['sourceId'] == row['recordId'] &&
                  types.contains(journal['sourceType']) &&
                  journal['status'] == 'POSTED',
            )
            .toList();
        final date =
            '${next[action == 'invoiceVoid'
                    ? 'voidDate'
                    : action == 'reverse'
                    ? 'date'
                    : 'reversalDate'] ?? ''}';
        if (originals.length == types.length &&
            types.every(
              (type) =>
                  originals
                      .where((journal) => journal['sourceType'] == type)
                      .length ==
                  1,
            )) {
          for (final original in originals) {
            final originalLines = records('JournalLines')
                .where((line) => line['journalId'] == original['recordId'])
                .toList();
            if (originalLines.length < 2) {
              lines.removeRange(start, lines.length);
              break;
            }
            for (final originalLine in originalLines) {
              lines.add({
                ...originalLine,
                'date': date,
                'net':
                    _minor(originalLine['credit']) -
                    _minor(originalLine['debit']),
                'operationId': op['operationId'],
                'sourceType': table,
                'journalId':
                    'local_${op['operationId']}_${original['recordId']}',
                'sourceId': row['recordId'],
                'description': 'Pending reversal',
              });
            }
          }
        }
      }
    } on FormatException {
      // An invalid local draft/rate remains in the outbox for correction. Never
      // guess its financial effect or prevent confirmed reports from opening.
      lines.removeRange(start, lines.length);
      unresolved.add('${op['operationId']}');
      continue;
    }
    if (lines.length == start ||
        lines
                .skip(start)
                .fold(
                  BigInt.zero,
                  (sum, line) => sum + (line['net'] as BigInt),
                ) !=
            BigInt.zero) {
      lines.removeRange(start, lines.length);
      unresolved.add('${op['operationId']}');
    } else {
      projected.add('${op['operationId']}');
    }
  }
  if (projected.isEmpty && unresolved.isEmpty) return report;
  _apply(report, kind, lines);
  final comparison = report['comparison'];
  if (comparison is Map) {
    final previous = <String, dynamic>{
      'from': comparison['from'],
      'asOf': comparison['asOf'],
      'accounts': comparison['accounts'] ?? [],
      for (final entry in (comparison['totals'] as Map? ?? {}).entries)
        '${entry.key}': entry.value['previous'],
    };
    _apply(previous, kind, lines);
    comparison['accounts'] = previous['accounts'];
    Map<String, dynamic> variance(Object? current, Object? old) {
      final delta = _minor(current) - _minor(old), base = _minor(old).abs();
      final percent = base == BigInt.zero
          ? (delta == BigInt.zero ? '0.00' : null)
          : _money(
              (delta.abs() * BigInt.from(10000) + base ~/ BigInt.two) ~/
                  base *
                  (delta.isNegative ? -BigInt.one : BigInt.one),
            );
      return {'previous': old, 'amount': _money(delta), 'percent': percent};
    }

    for (final key in (comparison['totals'] as Map? ?? {}).keys.toList()) {
      if (report[key] != null && previous[key] != null) {
        comparison['totals'][key] = variance(report[key], previous[key]);
      }
    }
    for (final account in report['accounts'] as List? ?? []) {
      final old = (previous['accounts'] as List)
          .where((row) => row['accountId'] == account['accountId'])
          .firstOrNull;
      Object? value(Map row) =>
          row['amount'] ??
          row['closing'] ??
          _money(_minor(row['debit']) - _minor(row['credit']));
      account['comparison'] = variance(
        value(account as Map),
        old == null ? '0.00' : value(old as Map),
      );
    }
  }
  report['provisional'] = true;
  report['projectedOperations'] = projected.length;
  report['pendingOperations'] = projected.length + unresolved.length;
  report['pendingCalculation'] = unresolved.length;
  report['metadata'] = {
    ...Map<String, dynamic>.from(report['metadata'] as Map? ?? {}),
    'accountingBasis': 'Provisional · includes local changes pending sync',
  };
  return report;
}

void _apply(
  Map<String, dynamic> report,
  String kind,
  List<Map<String, dynamic>> lines,
) {
  final asOf = '${report['asOf'] ?? '9999-12-31'}',
      from = '${report['from'] ?? ''}';
  final accounts = [
    for (final row in report['accounts'] as List? ?? [])
      Map<String, dynamic>.from(row as Map),
  ];
  void add(Map target, String key, BigInt value) =>
      target[key] = _money(_minor(target[key]) + value);
  final changes = <String, BigInt>{};
  final journals = <String>{};
  final yearMonth =
      (report['metadata']?['financialYearMonth'] as num?)?.toInt() ?? 1;
  final yearDay =
      (report['metadata']?['financialYearDay'] as num?)?.toInt() ?? 1;
  final cutoff = DateTime.tryParse(asOf) ?? DateTime.now();
  var yearStart = DateTime(cutoff.year, yearMonth, yearDay);
  if (yearStart.isAfter(cutoff)) {
    yearStart = DateTime(cutoff.year - 1, yearMonth, yearDay);
  }
  final fiscalStart = yearStart.toIso8601String().substring(0, 10);
  void change(String key, BigInt amount) =>
      changes[key] = (changes[key] ?? BigInt.zero) + amount;
  for (final line in lines) {
    final date = '${line['date']}';
    if (date.compareTo(asOf) > 0) continue;
    final group = '${line['accountGroup']}',
        id = '${line['accountId']}',
        net = line['net'] as BigInt;
    final inPeriod = from.isEmpty || date.compareTo(from) >= 0;
    if (inPeriod || kind == 'balance-sheet' || kind == 'dashboard') {
      journals.add('${line['journalId']}');
    }
    final income = group == 'Income', expense = group == 'Expense';
    final earning = income || expense;
    if (earning) {
      change('accumulatedEarnings', -net);
      change(
        date.compareTo(fiscalStart) >= 0
            ? 'currentYearEarnings'
            : 'priorYearUnclosedEarnings',
        -net,
      );
    }
    if (group == 'Equity') change('postedEquity', -net);
    final cashKey = const {
      'cash': 'cash',
      'cash_in_hand': 'cash',
      'bank': 'bank',
      'bank_account': 'bank',
      'accounts_receivable': 'receivables',
      'accounts_payable': 'payables',
    }[id];
    if (cashKey != null) change(cashKey, group == 'Liability' ? -net : net);
    if (inPeriod && income) {
      changes['totalIncome'] = (changes['totalIncome'] ?? BigInt.zero) - net;
    }
    if (inPeriod && expense) {
      changes['totalExpenses'] =
          (changes['totalExpenses'] ?? BigInt.zero) + net;
    }
    if (group == 'Asset') {
      changes['totalAssets'] = (changes['totalAssets'] ?? BigInt.zero) + net;
    }
    if (group == 'Liability') {
      changes['totalLiabilities'] =
          (changes['totalLiabilities'] ?? BigInt.zero) - net;
    }
    if (group == 'Equity' || income || expense) {
      changes['totalEquity'] = (changes['totalEquity'] ?? BigInt.zero) - net;
    }
    if ((kind == 'profit-and-loss' && (!inPeriod || !(income || expense))) ||
        (kind == 'balance-sheet' && (income || expense)) ||
        kind == 'dashboard') {
      continue;
    }
    var account = accounts.where((row) => row['accountId'] == id).firstOrNull;
    if (account == null) {
      account = {
        'accountId': id,
        'accountName': line['accountName'],
        'accountGroup': group,
        'accountCode': id,
        'section': '$group · Unclassified',
        'reportingRole': '',
        'normalSide': group == 'Asset' || expense ? 'Debit' : 'Credit',
        if (['balance-sheet', 'profit-and-loss'].contains(kind))
          'amount': '0.00',
        if (kind == 'general-ledger') 'entries': <dynamic>[],
      };
      accounts.add(account);
    }
    if (account.containsKey('amount')) {
      add(account, 'amount', group == 'Asset' || expense ? net : -net);
    } else if (kind == 'general-ledger') {
      add(
        account,
        inPeriod ? (net.isNegative ? 'credit' : 'debit') : 'opening',
        inPeriod ? net.abs() : net,
      );
      add(account, 'closing', net);
      if (inPeriod) {
        (account['entries'] as List).add({
          ...line,
          'net': null,
          'debit': _money(net.isNegative ? BigInt.zero : net),
          'credit': _money(net.isNegative ? -net : BigInt.zero),
          'journalId': line['journalId'],
          'number': 'Pending sync',
          'balance': account['closing'],
        });
      }
    } else {
      final closing =
          _minor(account['debit']) - _minor(account['credit']) + net;
      account['debit'] = _money(closing.isNegative ? BigInt.zero : closing);
      account['credit'] = _money(closing.isNegative ? -closing : BigInt.zero);
      if (from.isNotEmpty) {
        if (inPeriod) {
          add(
            account,
            net.isNegative ? 'periodCredit' : 'periodDebit',
            net.abs(),
          );
        } else {
          final opening =
              _minor(account['openingDebit']) -
              _minor(account['openingCredit']) +
              net;
          account['openingDebit'] = _money(
            opening.isNegative ? BigInt.zero : opening,
          );
          account['openingCredit'] = _money(
            opening.isNegative ? -opening : BigInt.zero,
          );
        }
      }
    }
  }
  if (kind == 'balance-sheet') {
    for (final entry in {
      '__current_earnings': 'currentYearEarnings',
      '__prior_earnings': 'priorYearUnclosedEarnings',
    }.entries) {
      final row = accounts
          .where((row) => row['accountId'] == entry.key)
          .firstOrNull;
      if (row != null) add(row, 'amount', changes[entry.value] ?? BigInt.zero);
    }
  }
  if (kind != 'dashboard') report['accounts'] = accounts;
  if (report['journalCount'] is num) {
    report['journalCount'] =
        (report['journalCount'] as num).toInt() + journals.length;
  }
  for (final entry in changes.entries) {
    if (report.containsKey(entry.key)) add(report, entry.key, entry.value);
  }
  final profit =
      (changes['totalIncome'] ?? BigInt.zero) -
      (changes['totalExpenses'] ?? BigInt.zero);
  if (report.containsKey('netProfit')) add(report, 'netProfit', profit);
  if (report.containsKey('totalLiabilitiesAndEquity')) {
    add(
      report,
      'totalLiabilitiesAndEquity',
      (changes['totalLiabilities'] ?? BigInt.zero) +
          (changes['totalEquity'] ?? BigInt.zero),
    );
  }
  if (kind == 'general-ledger') {
    for (final account in accounts) {
      final entries = (account['entries'] as List? ?? []);
      entries.sort(
        (a, b) => '${a['date']}${a['journalId']}${a['lineNumber'] ?? 0}'
            .compareTo('${b['date']}${b['journalId']}${b['lineNumber'] ?? 0}'),
      );
      var running = _minor(account['opening']);
      for (final entry in entries) {
        running += _minor(entry['debit']) - _minor(entry['credit']);
        entry['balance'] = _money(running);
      }
    }
  }
  if (kind == 'profit-and-loss') {
    final classified = accounts.every(
      (row) => '${row['reportingRole'] ?? ''}'.isNotEmpty,
    );
    report['classificationComplete'] = classified;
    if (classified) {
      BigInt role(String role) => accounts
          .where((row) => row['reportingRole'] == role)
          .fold(
            BigInt.zero,
            (sum, row) =>
                sum +
                _minor(row['amount']) *
                    (row['accountGroup'] == 'Income' &&
                            ['sales-returns', 'discounts'].contains(role)
                        ? -BigInt.one
                        : BigInt.one),
          );
      final revenue =
          role('revenue') - role('sales-returns') - role('discounts');
      final gross = revenue - role('cogs'),
          operating = gross - role('operating-expenses');
      report.addAll({
        'netRevenue': _money(revenue),
        'grossProfit': _money(gross),
        'operatingProfit': _money(operating),
      });
      for (final entry in {
        'grossMargin': gross,
        'operatingMargin': operating,
        'netMargin': _minor(report['netProfit']),
      }.entries) {
        final numerator = entry.value * BigInt.from(10000);
        report[entry.key] = revenue == BigInt.zero
            ? null
            : _money(
                ((numerator.abs() + revenue.abs() ~/ BigInt.two) ~/
                        revenue.abs()) *
                    (numerator.isNegative != revenue.isNegative
                        ? -BigInt.one
                        : BigInt.one),
              );
      }
    } else {
      for (final key in [
        'netRevenue',
        'grossProfit',
        'operatingProfit',
        'grossMargin',
        'operatingMargin',
        'netMargin',
      ]) {
        report[key] = null;
      }
    }
  }
  if (kind == 'dashboard' && lines.isNotEmpty) {
    report['grossProfit'] = null;
    report['netRevenue'] = null;
  }
  if (report['sections'] is List) {
    report['sections'] = [
      for (final section in accounts.map((row) => '${row['section']}').toSet())
        {
          'name': section,
          'amount': _money(
            accounts
                .where((row) => '${row['section']}' == section)
                .fold(
                  BigInt.zero,
                  (sum, row) =>
                      sum +
                      (row.containsKey('amount')
                          ? _minor(row['amount'])
                          : _minor(row['debit']) - _minor(row['credit'])),
                ),
          ),
        },
    ];
  }
  if (kind == 'trial-balance') {
    for (final field in [
      'debit',
      'credit',
      'openingDebit',
      'openingCredit',
      'periodDebit',
      'periodCredit',
    ]) {
      final key = 'total${field[0].toUpperCase()}${field.substring(1)}';
      if (report.containsKey(key)) {
        report[key] = _money(
          accounts.fold(BigInt.zero, (sum, row) => sum + _minor(row[field])),
        );
      }
    }
  }
  if (report['trends'] is List) {
    for (final raw in report['trends'] as List) {
      final trend = raw as Map<String, dynamic>;
      final delta = <String, dynamic>{
        'from': trend['from'],
        'asOf': trend['asOf'],
        'totalIncome': '0.00',
        'totalExpenses': '0.00',
        'netProfit': '0.00',
      };
      _apply(delta, 'dashboard', lines);
      add(trend, 'income', _minor(delta['totalIncome']));
      add(trend, 'expenses', _minor(delta['totalExpenses']));
      add(trend, 'netProfit', _minor(delta['netProfit']));
    }
  }
}
