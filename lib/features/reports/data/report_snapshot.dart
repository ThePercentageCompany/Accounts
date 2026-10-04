import 'dart:convert';
import 'report_format.dart';

class ReportTable {
  const ReportTable(this.title, this.headers, this.rows, this.numericColumns);
  final String title;
  final List<String> headers;
  final List<List<Object?>> rows;
  final Set<int> numericColumns;
}

/// All exporters consume the same frozen visible rows and applied settings.
class ReportSnapshot {
  ReportSnapshot(this.title, Map<String, dynamic> report)
    : data = Map<String, dynamic>.from(jsonDecode(jsonEncode(report)) as Map);
  final String title;
  final Map<String, dynamic> data;
  ReportFormat get format => ReportFormat(
    locale: data['metadata']?['numberLocale'] ?? 'en_AE',
    datePattern: data['metadata']?['dateFormat'] ?? 'yyyy-MM-dd',
    parentheses: data['parentheses'] == true,
  );
  List<List<Object?>> get context => [
    ['Company', data['metadata']?['companyName'] ?? 'Workspace'],
    ['Currency', data['metadata']?['currency'] ?? 'Workspace currency'],
    ['Basis', data['metadata']?['accountingBasis'] ?? 'Posted journals'],
    ['From', data['from'] ?? 'Inception', 'As of', data['asOf']],
    if (data['comparison'] != null)
      [
        'Comparison from',
        data['comparison']['from'] ?? 'Inception',
        'As of',
        data['comparison']['asOf'],
      ],
    ['Generated', data['metadata']?['generatedAt'] ?? 'Unavailable'],
    [
      'Account search',
      data['accountSearch'] ?? '',
      'Hide zero',
      data['hideZeroBalances'] ?? false,
    ],
    [
      'Transaction search',
      data['transactionSearch'] ?? '',
      'Source filter',
      data['sourceFilter'] ?? 'All',
    ],
    [
      'Totals scope',
      data['totalsScope'] ?? 'All accounts in selected reporting period',
    ],
  ];
  List<ReportTable> get tables {
    final accounts = (data['accounts'] as List? ?? []).cast<Map>();
    final kind = data['kind'];
    final ledger =
        kind == 'general-ledger' ||
        (accounts.isNotEmpty && accounts.first.containsKey('entries'));
    final statement =
        ['balance-sheet', 'profit-and-loss'].contains(kind) ||
        (accounts.isNotEmpty && accounts.first.containsKey('amount'));
    final full = data['fullTrial'] == true;
    final compare = data['comparison'] != null;
    final tables = <ReportTable>[];
    final totals = <List<Object?>>[];
    for (final e in data.entries) {
      if (reportMinor(e.value) != null && e.value is String) {
        totals.add([e.key, e.value]);
      }
    }
    if (totals.isNotEmpty) {
      tables.add(
        ReportTable(
          'Report totals (all accounts)',
          ['Metric', 'Amount'],
          totals,
          {1},
        ),
      );
    }
    if (ledger) {
      for (final a in accounts) {
        final columns = List<String>.from(
          data['ledgerColumns'] ??
              [
                'date',
                'number',
                'description',
                'sourceType',
                'debit',
                'credit',
                'balance',
              ],
        );
        const labels = {
          'date': 'Date',
          'number': 'Journal',
          'description': 'Description',
          'sourceType': 'Source',
          'debit': 'Debit',
          'credit': 'Credit',
          'balance': 'Running balance',
        };
        tables.add(
          ReportTable(
            '${a['accountCode'] ?? a['accountId'] ?? ''} ${a['accountName']}',
            ['Opening', 'Period debit', 'Period credit', 'Closing'],
            [
              [a['opening'], a['debit'], a['credit'], a['closing']],
            ],
            {0, 1, 2, 3},
          ),
        );
        tables.add(
          ReportTable(
            'Account activity',
            columns.map((c) => labels[c] ?? c).toList(),
            [
              for (final e in a['entries'] as List? ?? [])
                [for (final c in columns) e[c]],
            ],
            {
              for (var i = 0; i < columns.length; i++)
                if (['debit', 'credit', 'balance'].contains(columns[i])) i,
            },
          ),
        );
      }
    } else if (accounts.isNotEmpty || kind == 'trial-balance') {
      final keys = statement
          ? ['amount']
          : full
          ? [
              'openingDebit',
              'openingCredit',
              'periodDebit',
              'periodCredit',
              'debit',
              'credit',
            ]
          : ['debit', 'credit'];
      final labels = statement
          ? ['Amount']
          : full
          ? [
              'Opening debit',
              'Opening credit',
              'Period debit',
              'Period credit',
              'Closing debit',
              'Closing credit',
            ]
          : ['Debit', 'Credit'];
      final headers = [
        'Code',
        'Account',
        'Group',
        ...labels,
        if (compare) ...['Comparison', 'Variance', 'Variance %'],
      ];
      tables.add(
        ReportTable(
          'Accounts',
          headers,
          [
            for (final a in accounts)
              [
                a['accountCode'] ?? a['accountId'],
                a['accountName'],
                a['section'] ?? a['accountGroup'],
                for (final k in keys) a[k],
                if (compare) ...[
                  a['comparison']?['previous'],
                  a['comparison']?['amount'],
                  a['comparison']?['percent'] ?? 'Not defined',
                ],
              ],
          ],
          {for (var i = 3; i < headers.length; i++) i},
        ),
      );
    }
    if (data['trends'] is List && (data['trends'] as List).isNotEmpty) {
      tables.add(
        ReportTable(
          'Period breakdown',
          ['From', 'To', 'Income', 'Expenses', 'Net profit'],
          [
            for (final t in data['trends'])
              [
                t['from'],
                t['asOf'],
                t['income'],
                t['expenses'],
                t['netProfit'],
              ],
          ],
          {2, 3, 4},
        ),
      );
    }
    return tables;
  }
}
