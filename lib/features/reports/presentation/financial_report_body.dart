import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/report_format.dart';
import 'report_trends.dart';
import 'report_grid.dart';

const ledgerColumnLabels = {
  'date': 'Date',
  'number': 'Journal / voucher',
  'description': 'Description',
  'sourceType': 'Source / type',
  'debit': 'Debit',
  'credit': 'Credit',
  'balance': 'Running balance',
};

class FinancialReportBody extends StatefulWidget {
  const FinancialReportBody({
    super.key,
    required this.data,
    required this.kind,
    required this.rows,
    required this.dense,
    this.parentheses = false,
    this.fullTrial = false,
    this.format = const ReportFormat(),
    this.transactionSearch = '',
    this.sourceFilter = '',
    this.ledgerColumns = const {
      'date',
      'number',
      'description',
      'sourceType',
      'debit',
      'credit',
      'balance',
    },
    this.onDrillDown,
    this.onJournal,
    this.onTransactionSearch,
    this.onSourceFilter,
    this.onColumnsChanged,
  });
  final Map<String, dynamic> data;
  final String kind, transactionSearch, sourceFilter;
  final List<Map<String, dynamic>> rows;
  final bool dense, parentheses, fullTrial;
  final ReportFormat format;
  final Set<String> ledgerColumns;
  final void Function(Map<String, dynamic>)? onDrillDown, onJournal;
  final ValueChanged<String>? onTransactionSearch, onSourceFilter;
  final ValueChanged<Set<String>>? onColumnsChanged;
  @override
  State<FinancialReportBody> createState() => _FinancialReportBodyState();
}

class _FinancialReportBodyState extends State<FinancialReportBody> {
  final Map<String, int> _pages = {};
  bool _ascending = true, _newestFirst = false;
  static const _pageSize = 25;
  late final _transactionController = TextEditingController(
    text: widget.transactionSearch,
  );
  @override
  void didUpdateWidget(covariant FinancialReportBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transactionSearch != widget.transactionSearch) {
      _transactionController.text = widget.transactionSearch;
    }
    if (oldWidget.transactionSearch != widget.transactionSearch ||
        oldWidget.sourceFilter != widget.sourceFilter) {
      _pages.clear();
    }
  }

  @override
  void dispose() {
    _transactionController.dispose();
    super.dispose();
  }

  String money(Object? value) => widget.format.money(value);
  Widget amount(Object? value, {VoidCallback? tap}) {
    final text = Text(
      money(value),
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
    );
    return tap == null
        ? text
        : Tooltip(
            message: 'Open posted account activity',
            child: InkWell(
              onTap: tap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: text,
              ),
            ),
          );
  }

  Widget summary(String label, String key) {
    final comparison = widget.data['comparison']?['totals']?[key];
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                money(widget.data[key]),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (comparison != null) ...[
                const SizedBox(height: 8),
                Text('Previous: ${money(comparison['previous'])}'),
                Text(
                  'Change: ${money(comparison['amount'])} (${comparison['percent'] ?? 'Not defined'}${comparison['percent'] == null ? '' : '%'})',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget reconciliation(String label, Object? value) {
    final n = reportMinor(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            n == BigInt.zero ? Icons.check_circle_outline : Icons.info_outline,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              n == null
                  ? '$label: reconciliation unavailable'
                  : '$label: ${n == BigInt.zero ? 'Balanced' : 'Needs review'} | Difference: ${money(value)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statementTable(List<Map<String, dynamic>> accounts) {
    final statement = [
          'balance-sheet',
          'profit-and-loss',
        ].contains(widget.kind),
        compare = widget.data['comparison'] != null;
    final keys = statement
        ? ['amount']
        : widget.fullTrial
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
        : widget.fullTrial
        ? [
            'Opening debit',
            'Opening credit',
            'Period debit',
            'Period credit',
            'Closing debit',
            'Closing credit',
          ]
        : ['Debit', 'Credit'];
    final totals = [
      for (final k in keys)
        reportDecimal(
          accounts.fold<BigInt>(
            BigInt.zero,
            (n, a) => n + (reportMinor(a[k]) ?? BigInt.zero),
          ),
        ),
    ];
    final headers = [
      'Code',
      'Account',
      'Group',
      ...labels,
      if (compare) ...['Comparison', 'Variance', 'Variance % / impact'],
    ];
    final sorted = [...accounts]
      ..sort(
        (a, b) => _ascending
            ? '${a['accountCode'] ?? a['accountId'] ?? ''}'.compareTo(
                '${b['accountCode'] ?? b['accountId'] ?? ''}',
              )
            : '${b['accountCode'] ?? b['accountId'] ?? ''}'.compareTo(
                '${a['accountCode'] ?? a['accountId'] ?? ''}',
              ),
      );
    return ReportGrid(
      headers: headers,
      numeric: {for (var i = 3; i < headers.length; i++) i},
      dense: widget.dense,
      rows: [
        for (final a in sorted)
          [
            Text('${a['accountCode'] ?? a['accountId'] ?? ''}'),
            Row(
              children: [
                Expanded(child: Text('${a['accountName']}')),
                if (a['abnormal'] == true)
                  const Tooltip(
                    message:
                        'Balance is opposite the configured normal side. The account remains in its assigned category.',
                    child: Icon(Icons.warning_amber_outlined, size: 18),
                  ),
              ],
            ),
            Text('${a['accountGroup']}'),
            for (final k in keys)
              amount(
                a[k],
                tap: widget.onDrillDown == null
                    ? null
                    : () => widget.onDrillDown!(a),
              ),
            if (compare) ...[
              amount(a['comparison']?['previous']),
              amount(a['comparison']?['amount']),
              Text(
                '${a['comparison']?['percent'] ?? 'Not defined'}${a['comparison']?['percent'] == null ? '' : '%'}${a['comparison']?['favorable'] == null
                    ? ''
                    : a['comparison']['favorable']
                    ? ' | Favorable'
                    : ' | Unfavorable'}',
              ),
            ],
          ],
      ],
      footer: [
        const Text(''),
        const Text(
          'Visible subtotal',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const Text(''),
        for (final t in totals) amount(t),
        if (compare) ...[const Text(''), const Text(''), const Text('')],
      ],
    );
  }

  Widget _ledger(Map<String, dynamic> account) {
    final entries = (account['entries'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where(
          (e) =>
              '${e['date']} ${e['number']} ${e['description']}'
                  .toLowerCase()
                  .contains(widget.transactionSearch.toLowerCase()) &&
              (widget.sourceFilter.isEmpty ||
                  e['sourceType'] == widget.sourceFilter),
        )
        .toList();
    if (_newestFirst) {
      entries.sort((a, b) {
        final date = '${b['date']}'.compareTo('${a['date']}');
        if (date != 0) return date;
        final journal = '${b['journalId']}'.compareTo('${a['journalId']}');
        return journal != 0
            ? journal
            : (b['lineNumber'] as int? ?? 0).compareTo(
                a['lineNumber'] as int? ?? 0,
              );
      });
    }
    final id = '${account['accountId']}',
        pages = math.max(1, (entries.length / _pageSize).ceil());
    final page = (_pages[id] ?? 0).clamp(0, pages - 1),
        columns = ledgerColumnLabels.keys
            .where(widget.ledgerColumns.contains)
            .toList();
    return Card(
      child: ExpansionTile(
        key: PageStorageKey('ledger-$id'),
        initiallyExpanded: widget.rows.length == 1,
        title: Text(
          '${account['accountCode'] ?? id} | ${account['accountName']}',
        ),
        subtitle: Text(
          '${account['accountGroup']} | Opening: ${money(account['opening'])} | Closing: ${money(account['closing'])}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Period debit: ${money(account['debit'])} | Period credit: ${money(account['credit'])}',
                ),
                if (account['comparison'] != null)
                  Text(
                    'Comparison closing: ${money(account['comparison']['previous'])} | Change: ${money(account['comparison']['amount'])}',
                  ),
                const SizedBox(height: 12),
                if (entries.isEmpty)
                  const Text(
                    'No transactions match the selected period and filters.',
                  ),
                if (entries.isNotEmpty)
                  ReportGrid(
                    headers: columns
                        .map((c) => ledgerColumnLabels[c]!)
                        .toList(),
                    numeric: {
                      for (var i = 0; i < columns.length; i++)
                        if (['debit', 'credit', 'balance'].contains(columns[i]))
                          i,
                    },
                    dense: widget.dense,
                    rows: [
                      for (final e
                          in entries.skip(page * _pageSize).take(_pageSize))
                        [
                          for (final c in columns)
                            if (['debit', 'credit', 'balance'].contains(c))
                              amount(e[c])
                            else if (c == 'date')
                              Text(widget.format.date(e[c]))
                            else if (c == 'number')
                              TextButton(
                                onPressed: widget.onJournal == null
                                    ? null
                                    : () => widget.onJournal!(e),
                                child: Text(
                                  '${e[c] == '' ? e['journalId'] : e[c]}',
                                ),
                              )
                            else if (c == 'sourceType')
                              Text(
                                '${e[c] ?? ''}${RegExp(r'Reversal|Void|Refund').hasMatch('${e[c]}') ? ' | Reversal' : ''}',
                              )
                            else
                              Tooltip(
                                message: '${e[c] ?? ''}',
                                child: Text(
                                  '${e[c] ?? ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                        ],
                    ],
                  ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Previous transactions',
                      onPressed: page == 0
                          ? null
                          : () => setState(() => _pages[id] = page - 1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      'Page ${page + 1} of $pages | ${entries.length} matching transactions',
                    ),
                    IconButton(
                      tooltip: 'Next transactions',
                      onPressed: page + 1 >= pages
                          ? null
                          : () => setState(() => _pages[id] = page + 1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data,
        ledger = widget.kind == 'general-ledger',
        balance = widget.kind == 'balance-sheet',
        profit = widget.kind == 'profit-and-loss';
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final a in widget.rows) {
      groups
          .putIfAbsent('${a['section'] ?? a['accountGroup']}', () => [])
          .add(a);
    }
    final difference = balance
        ? data['difference'] ??
              _difference(
                data['totalAssets'],
                data['totalLiabilitiesAndEquity'],
              )
        : data['closingDifference'] ??
              _difference(data['totalDebit'], data['totalCredit']);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (balance) ...[
                summary('Assets', 'totalAssets'),
                summary('Liabilities', 'totalLiabilities'),
                summary('Total equity', 'totalEquity'),
              ] else if (profit) ...[
                summary('Income', 'totalIncome'),
                summary('Expenses', 'totalExpenses'),
                summary('Net profit / loss', 'netProfit'),
              ] else if (!ledger) ...[
                summary('Closing debit', 'totalDebit'),
                summary('Closing credit', 'totalCredit'),
              ],
            ],
          ),
          if (!ledger && !profit) ...[
            reconciliation(
              balance ? 'Assets = liabilities + equity' : 'Closing',
              difference,
            ),
            if (widget.fullTrial) ...[
              reconciliation('Opening', data['openingDifference']),
              reconciliation('Period movements', data['periodDifference']),
            ],
          ],
          if (widget.kind == 'trial-balance' && widget.fullTrial)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ReportGrid(
                  headers: const [
                    'Opening debit',
                    'Opening credit',
                    'Period debit',
                    'Period credit',
                    'Closing debit',
                    'Closing credit',
                  ],
                  rows: [
                    [
                      for (final k in [
                        'totalOpeningDebit',
                        'totalOpeningCredit',
                        'totalPeriodDebit',
                        'totalPeriodCredit',
                        'totalDebit',
                        'totalCredit',
                      ])
                        amount(data[k]),
                    ],
                  ],
                  numeric: const {0, 1, 2, 3, 4, 5},
                  dense: widget.dense,
                ),
              ),
            ),
          if (balance)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Posted equity: ${money(data['postedEquity'])}'),
                    Text(
                      'Accumulated earnings: ${money(data['accumulatedEarnings'])}',
                    ),
                    Text(
                      'Liabilities + equity: ${money(data['totalLiabilitiesAndEquity'])}',
                    ),
                    if (data['currentYearEarnings'] != null) ...[
                      Text(
                        'Current-year unclosed earnings: ${money(data['currentYearEarnings'])}',
                      ),
                      Text(
                        'Prior-year unclosed earnings: ${money(data['priorYearUnclosedEarnings'])}',
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Accumulated earnings include income and expenses not transferred into posted equity. Current-year earnings follow the financial year and include posted closing transfers; posted equity is counted separately.',
                    ),
                  ],
                ),
              ),
            ),
          if (profit) ...[
            if (data['classificationComplete'] == true)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  summary('Net revenue', 'netRevenue'),
                  summary('Gross profit', 'grossProfit'),
                  summary('Operating profit', 'operatingProfit'),
                ],
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Tooltip(
                message:
                    'Margin = profit / net revenue x 100. Zero revenue has no defined margin.',
                child: Text(
                  data['classificationComplete'] == true
                      ? 'Gross margin: ${data['grossMargin'] ?? 'Not defined'}${data['grossMargin'] == null ? '' : '%'} | Operating margin: ${data['operatingMargin'] ?? 'Not defined'}${data['operatingMargin'] == null ? '' : '%'} | Net margin: ${data['netMargin'] ?? 'Not defined'}${data['netMargin'] == null ? '' : '%'}'
                      : 'Net margin: ${_margin(data['netProfit'], data['totalIncome'])} | Net profit / income x 100',
                ),
              ),
            ),
            if (data['classificationComplete'] == false)
              const Text(
                'Review unclassified accounts in Chart of Accounts to enable gross and operating profit.',
              ),
          ],
          if (widget.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No accounts match this view. Adjust search or zero-balance filters.',
              ),
            ),
          if (ledger) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Debit-positive balances; negatives indicate credit. Running balances include all preceding postings and remain in original posting order when filtered or sorted.',
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _transactionController,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'Search transactions',
                    ),
                    onChanged: widget.onTransactionSearch,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Transaction type',
                  onSelected: widget.onSourceFilter,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: '',
                      child: Text('All source types'),
                    ),
                    for (final source in {
                      for (final a in widget.rows)
                        for (final e in a['entries'] as List? ?? [])
                          '${e['sourceType'] ?? ''}',
                    }.where((s) => s.isNotEmpty))
                      PopupMenuItem(value: source, child: Text(source)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.sourceFilter.isEmpty
                          ? 'All source types'
                          : widget.sourceFilter,
                    ),
                  ),
                ),
                FilterChip(
                  label: const Text('Newest first'),
                  selected: _newestFirst,
                  onSelected: (v) => setState(() => _newestFirst = v),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Ledger columns',
                  onSelected: (column) {
                    final selected = {...widget.ledgerColumns};
                    if (selected.contains(column)) {
                      selected.remove(column);
                    } else {
                      selected.add(column);
                    }
                    widget.onColumnsChanged?.call(selected);
                  },
                  itemBuilder: (_) => [
                    for (final c in ledgerColumnLabels.entries)
                      CheckedPopupMenuItem(
                        value: c.key,
                        checked: widget.ledgerColumns.contains(c.key),
                        enabled: !['date', 'debit', 'credit'].contains(c.key),
                        child: Text(c.value),
                      ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Columns'),
                  ),
                ),
              ],
            ),
            for (final a in widget.rows) _ledger(a),
          ] else if (widget.rows.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _ascending = !_ascending),
                icon: Icon(
                  _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                ),
                label: const Text('Sort by account code'),
              ),
            ),
            for (final group in groups.entries)
              Card(
                child: ExpansionTile(
                  key: PageStorageKey('${widget.kind}-${group.key}'),
                  initiallyExpanded: true,
                  title: Text(
                    group.key,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: [_statementTable(group.value)],
                ),
              ),
            if (!profit && !balance)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Total (all accounts) | Debit: ${money(data['totalDebit'])} | Credit: ${money(data['totalCredit'])}',
                ),
              ),
          ],
          if (profit &&
              data['trends'] is List &&
              (data['trends'] as List).isNotEmpty)
            ReportTrends(
              trends: List<Map<String, dynamic>>.from(
                (data['trends'] as List).map(
                  (t) => Map<String, dynamic>.from(t),
                ),
              ),
              format: widget.format,
            ),
          if (profit &&
              data['trends'] is List &&
              (data['trends'] as List).isNotEmpty)
            Card(
              child: ExpansionTile(
                title: const Text('Monthly period breakdown'),
                children: [
                  ReportGrid(
                    headers: const [
                      'From',
                      'To',
                      'Income',
                      'Expenses',
                      'Net profit',
                    ],
                    numeric: const {2, 3, 4},
                    dense: widget.dense,
                    rows: [
                      for (final t in data['trends'])
                        [
                          Text(widget.format.date(t['from'])),
                          Text(widget.format.date(t['asOf'])),
                          amount(t['income']),
                          amount(t['expenses']),
                          amount(t['netProfit']),
                        ],
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            balance
                ? 'Account classifications are preserved, including abnormal balances. Assets = liabilities + equity.'
                : ledger
                ? 'Opening balances include posted entries before the selected start date. Drafts are excluded.'
                : profit
                ? 'Variance uses the absolute comparison value as denominator. A nonzero amount compared with zero has an undefined percentage.'
                : 'Equal debit and credit totals confirm arithmetic balance; they do not prove that every accounting entry is correct.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String? _difference(Object? a, Object? b) {
    final left = reportMinor(a), right = reportMinor(b);
    return left == null || right == null ? null : reportDecimal(left - right);
  }

  String _margin(Object? n, Object? d) {
    final net = reportMinor(n), denominator = reportMinor(d);
    return net == null || denominator == null || denominator == BigInt.zero
        ? 'Not defined (income unavailable or zero)'
        : '${reportDecimal(net * BigInt.from(10000) ~/ denominator)}%';
  }
}
