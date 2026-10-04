import 'package:flutter/cupertino.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/reports/presentation/workspace_dashboard.dart';
import 'package:tpc_invoice/features/reports/data/report_export.dart';
import 'package:tpc_invoice/core/utils/file_download.dart';

class TrialBalanceView extends StatefulWidget {
  const TrialBalanceView({
    super.key,
    required this.api,
    required this.companyId,
    this.employee = false,
    this.initialDashboard = false,
    this.active = true,
  });
  final SaasApi api;
  final String companyId;
  final bool employee;
  final bool initialDashboard;
  final bool active;
  @override
  State<TrialBalanceView> createState() => _TrialBalanceViewState();
}

class _TrialBalanceViewState extends State<TrialBalanceView> {
  DateTime _date = DateTime.now();
  DateTime _from = DateTime(DateTime.now().year);
  bool _profit = false;
  bool _balance = false;
  String? _extra;
  bool get _period => _profit || _extra != null;
  String get _title => _extra == 'dashboard'
      ? 'Dashboard'
      : _extra == 'general-ledger'
      ? 'General ledger'
      : _balance
      ? 'Balance sheet'
      : _profit
      ? 'Profit and loss'
      : 'Trial balance';
  bool get _statement => _profit || _balance;
  late Future<Map<String, dynamic>> _report;
  Map<String, dynamic>? _displayed;
  String? _watchedPath;
  int _request = 0;
  String get _kind =>
      _extra ??
      (_balance
          ? 'balance-sheet'
          : _profit
          ? 'profit-and-loss'
          : 'trial-balance');
  String get _path {
    final base = widget.employee
        ? '/v1/employee/reports/'
        : '/v1/companies/${widget.companyId}/reports/';
    final period = [
      'dashboard',
      'general-ledger',
      'profit-and-loss',
    ].contains(_kind);
    return '$base$_kind?asOf=$_asOf${period ? '&from=${_from.toIso8601String().substring(0, 10)}' : ''}';
  }

  void _watch() {
    if (_watchedPath != null) widget.api.cache.deactivate(_watchedPath!);
    _watchedPath = widget.active ? _path : null;
    if (_watchedPath != null) widget.api.cache.activate(_watchedPath!);
  }

  void _cacheChanged() {
    scheduleMicrotask(() {
      if (!mounted) return;
      final data = widget.api.cache.state(_path)?.data;
      if (widget.api.cache.scope != null || _displayed != null) {
        setState(() {
          _displayed = data;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant TrialBalanceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _watch();
      if (widget.active) _load();
    }
  }

  @override
  void dispose() {
    _request++;
    widget.api.cache.removeListener(_cacheChanged);
    if (_watchedPath != null) widget.api.cache.deactivate(_watchedPath!);
    super.dispose();
  }

  String get _asOf => _date.toIso8601String().substring(0, 10);
  @override
  void initState() {
    super.initState();
    widget.api.cache.addListener(_cacheChanged);
    if (widget.initialDashboard) _extra = 'dashboard';
    _load();
  }

  void _load({bool force = false}) {
    _watch();
    _displayed = widget.api.cache.state(_path)?.data;
    final request = ++_request;
    final future = _fetchReport(force: force);
    _report = future.then((data) {
      if (mounted && request == _request) setState(() => _displayed = data);
      return data;
    });
    _report.ignore();
  }

  Future<Map<String, dynamic>> _fetchReport({bool force = false}) =>
      widget.employee
      ? widget.api.employeeReport(
          _extra ??
              (_balance
                  ? 'balance-sheet'
                  : _profit
                  ? 'profit-and-loss'
                  : 'trial-balance'),
          _from.toIso8601String().substring(0, 10),
          _asOf,
          force: force,
        )
      : _extra != null
      ? widget.api.report(
          widget.companyId,
          _extra!,
          _from.toIso8601String().substring(0, 10),
          _asOf,
          force: force,
        )
      : _balance
      ? widget.api.balanceSheet(widget.companyId, _asOf, force: force)
      : _profit
      ? widget.api.profitAndLoss(
          widget.companyId,
          _from.toIso8601String().substring(0, 10),
          _asOf,
          force: force,
        )
      : widget.api.trialBalance(widget.companyId, _asOf, force: force);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .32,
        ),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (MediaQuery.sizeOf(context).width >= 600)
                for (final preset in ['Today', 'This Week', 'This Month'])
                  ActionChip(
                    label: Text(preset),
                    onPressed: () => setState(() {
                      final now = DateTime.now();
                      _date = DateTime(now.year, now.month, now.day);
                      _from = preset == 'This Month'
                          ? DateTime(now.year, now.month)
                          : preset == 'This Week'
                          ? _date.subtract(Duration(days: now.weekday - 1))
                          : _date;
                      _load();
                    }),
                  ),
              ActionChip(
                label: Text(
                  MediaQuery.sizeOf(context).width < 600
                      ? (_period
                            ? '${_from.toIso8601String().substring(0, 10)} – $_asOf'
                            : 'As of $_asOf')
                      : 'Custom',
                ),
                onPressed: () async {
                  if (!_period) {
                    final date = await showDatePicker(
                      context: context,
                      initialEntryMode: DatePickerEntryMode.calendarOnly,
                      initialDate: _date,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2200),
                    );
                    if (date != null && mounted) {
                      setState(() {
                        _date = date;
                        _load();
                      });
                    }
                  } else {
                    final range = await showDateRangePicker(
                      context: context,
                      initialEntryMode: DatePickerEntryMode.calendarOnly,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2200),
                      initialDateRange: DateTimeRange(start: _from, end: _date),
                    );
                    if (range != null && mounted) {
                      setState(() {
                        _from = range.start;
                        _date = range.end;
                        _load();
                      });
                    }
                  }
                },
              ),
              if (MediaQuery.sizeOf(context).width < 600)
                PopupMenuButton<String>(
                  tooltip: 'Choose report',
                  initialValue: _kind,
                  onSelected: (kind) => setState(() {
                    _extra = ['dashboard', 'general-ledger'].contains(kind)
                        ? kind
                        : null;
                    _profit = kind == 'profit-and-loss';
                    _balance = kind == 'balance-sheet';
                    if (_from.isAfter(_date)) _from = DateTime(_date.year);
                    _load();
                  }),
                  itemBuilder: (_) => [
                    for (final entry in const {
                      'dashboard': 'Dashboard',
                      'general-ledger': 'General ledger',
                      'trial-balance': 'Trial balance',
                      'profit-and-loss': 'Profit and loss',
                      'balance-sheet': 'Balance sheet',
                    }.entries)
                      PopupMenuItem(value: entry.key, child: Text(entry.value)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.expand_more, size: 20),
                      ],
                    ),
                  ),
                ),
              if (MediaQuery.sizeOf(context).width >= 600)
                for (final entry in {
                  'dashboard': 'Dashboard',
                  'general-ledger': 'General ledger',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _extra == entry.key,
                    onSelected: (_) => setState(() {
                      _extra = entry.key;
                      _profit = false;
                      _balance = false;
                      if (_from.isAfter(_date)) {
                        _from = DateTime(_date.year);
                      }
                      _load();
                    }),
                  ),
              if (MediaQuery.sizeOf(context).width >= 600)
                ChoiceChip(
                  label: const Text('Trial balance'),
                  selected: !_statement && _extra == null,
                  onSelected: (_) => setState(() {
                    _profit = false;
                    _balance = false;
                    _extra = null;
                    _load();
                  }),
                ),
              if (MediaQuery.sizeOf(context).width >= 600)
                ChoiceChip(
                  label: const Text('Profit and loss'),
                  selected: _profit,
                  onSelected: (_) => setState(() {
                    _profit = true;
                    _balance = false;
                    _extra = null;
                    if (_from.isAfter(_date)) _from = DateTime(_date.year);
                    _load();
                  }),
                ),
              if (MediaQuery.sizeOf(context).width >= 600)
                ChoiceChip(
                  label: const Text('Balance sheet'),
                  selected: _balance,
                  onSelected: (_) => setState(() {
                    _balance = true;
                    _profit = false;
                    _extra = null;
                    _load();
                  }),
                ),
              if (_period && MediaQuery.sizeOf(context).width >= 600)
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialEntryMode: DatePickerEntryMode.calendarOnly,
                      initialDate: _from,
                      firstDate: DateTime(1900),
                      lastDate: _date,
                    );
                    if (date != null && mounted) {
                      setState(() {
                        _from = date;
                        _load();
                      });
                    }
                  },
                  child: Text(
                    'From ${_from.toIso8601String().substring(0, 10)}',
                  ),
                ),
              if (MediaQuery.sizeOf(context).width >= 600)
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialEntryMode: DatePickerEntryMode.calendarOnly,
                      initialDate: _date,
                      firstDate: _period ? _from : DateTime(1900),
                      lastDate: DateTime(2200),
                    );
                    if (date != null && mounted) {
                      setState(() {
                        _date = date;
                        _load();
                      });
                    }
                  },
                  child: Text('As of $_asOf'),
                ),
              IconButton(
                tooltip: 'Refresh report',
                onPressed: () => setState(() => _load(force: true)),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      ),
      if (MediaQuery.sizeOf(context).width >= 600)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Includes posted journals only; drafts are excluded. Amounts use the workspace accounting currency. General ledger balances are debit-positive.',
          ),
        ),
      Expanded(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _report,
          builder: (context, snapshot) {
            if (_displayed == null &&
                snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (_displayed == null && snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error is SaasApiException
                      ? (snapshot.error as SaasApiException).message
                      : 'Report unavailable. Retry.',
                ),
              );
            }
            if (_displayed == null) {
              return const Center(
                child: Text("Sign in again to load this report."),
              );
            }
            final data = _displayed!, rows = data['accounts'] as List? ?? [];
            return SingleChildScrollView(
              key: PageStorageKey(_path),
              child: Column(
                children: [
                  SizedBox(
                    height: 28,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: widget.api.cache.state(_path)?.refreshing == true
                          ? const Padding(
                              padding: EdgeInsets.only(right: 24),
                              child: CupertinoActivityIndicator(radius: 8),
                            )
                          : null,
                    ),
                  ),
                  if (widget.api.cache.state(_path)?.offline == true)
                    const Text('Offline - showing saved data.'),
                  if (widget.api.cache.state(_path)?.error != null &&
                      _displayed != null)
                    const Text(
                      'Refresh failed. Showing saved report; use Refresh to retry.',
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Export CSV'),
                    onPressed: () async {
                      try {
                        await downloadFile(
                          reportCsv(_title, data),
                          filename:
                              '${_title.toLowerCase().replaceAll(' ', '-')}-${data['asOf']}.csv',
                          mimeType: 'text/csv;charset=utf-8',
                        );
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Export unavailable. Downloads are supported in the web app.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  Text(
                    '${data['journalCount']} posted journals ${_period && _extra != 'dashboard' ? "from ${data['from']} " : ""}through ${data['asOf']}',
                  ),
                  if (_extra == 'dashboard')
                    Text(
                      'Income and expenses: ${data['from']} through ${data['asOf']}. Other balances are cumulative.',
                    ),
                  if (_extra == 'dashboard') WorkspaceDashboard(data: data),
                  if (_extra == 'general-ledger')
                    for (final account in rows)
                      ExpansionTile(
                        title: Text(
                          '${account['accountName']} (${account['accountGroup']})',
                        ),
                        subtitle: Text(
                          'Opening: ${account['opening']}   Closing: ${account['closing']}',
                        ),
                        children: [
                          Text(
                            'Period debit: ${account['debit']}   Period credit: ${account['credit']}',
                          ),
                          for (final entry in account['entries'])
                            ListTile(
                              title: Text(
                                '${entry['date']} · ${entry['number']} · ${entry['description']}',
                              ),
                              subtitle: Text(
                                'Debit: ${entry['debit']}   Credit: ${entry['credit']}   Balance: ${entry['balance']}',
                              ),
                            ),
                        ],
                      ),
                  if (_profit)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Income: ${data['totalIncome']}   Expenses: ${data['totalExpenses']}   Net profit / loss: ${data['netProfit']}',
                      ),
                    ),
                  if (_balance)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text('Assets: ${data['totalAssets']}'),
                          Text('Liabilities: ${data['totalLiabilities']}'),
                          Text('Posted equity: ${data['postedEquity']}'),
                          Text(
                            'Accumulated earnings: ${data['accumulatedEarnings']}',
                          ),
                          Text('Total equity: ${data['totalEquity']}'),
                          Text(
                            'Liabilities + equity: ${data['totalLiabilitiesAndEquity']}',
                          ),
                          const Text(
                            'Accumulated earnings include income and expenses not transferred into posted equity.',
                          ),
                        ],
                      ),
                    ),
                  if (rows.isEmpty && _extra != 'dashboard')
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No posted balances for this date.'),
                    ),
                  if (_extra == null && MediaQuery.sizeOf(context).width < 600)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          for (final row in rows)
                            Card(
                              child: ListTile(
                                title: Text('${row['accountName']}'),
                                subtitle: Text(
                                  '${row['accountGroup']}\n${_statement ? 'Amount: ${row['amount']}' : 'Debit: ${row['debit']}   Credit: ${row['credit']}'}',
                                ),
                              ),
                            ),
                          if (!_statement)
                            ListTile(
                              title: const Text('Total'),
                              subtitle: Text(
                                'Debit: ${data['totalDebit']}   Credit: ${data['totalCredit']}',
                              ),
                            ),
                          const Text(
                            'Posted journals only. Drafts excluded. Amounts use workspace accounting currency.',
                          ),
                        ],
                      ),
                    ),
                  if (_extra == null && MediaQuery.sizeOf(context).width >= 600)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          const DataColumn(label: Text('Account')),
                          const DataColumn(label: Text('Group')),
                          DataColumn(
                            label: Text(_statement ? 'Amount' : 'Debit'),
                            numeric: true,
                          ),
                          if (!_statement)
                            const DataColumn(
                              label: Text('Credit'),
                              numeric: true,
                            ),
                        ],
                        rows: [
                          for (final row in rows)
                            DataRow(
                              cells: [
                                DataCell(Text('${row['accountName']}')),
                                DataCell(Text('${row['accountGroup']}')),
                                DataCell(
                                  Text(
                                    '${row[_statement ? 'amount' : 'debit']}',
                                  ),
                                ),
                                if (!_statement)
                                  DataCell(Text('${row['credit']}')),
                              ],
                            ),
                          if (!_statement)
                            DataRow(
                              cells: [
                                const DataCell(Text('Total')),
                                const DataCell(Text('')),
                                DataCell(Text('${data['totalDebit']}')),
                                DataCell(Text('${data['totalCredit']}')),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}
