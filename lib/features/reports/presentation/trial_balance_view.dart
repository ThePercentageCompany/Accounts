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
    this.reportKind,
  });
  final SaasApi api;
  final String companyId;
  final bool employee;
  final bool initialDashboard;
  final bool active;
  final String? reportKind;
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
    if (oldWidget.reportKind != widget.reportKind) {
      _selectKind(widget.reportKind ?? 'dashboard');
      _load();
      return;
    }
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
    if (widget.reportKind != null) _selectKind(widget.reportKind!);
    _load();
  }

  void _selectKind(String kind) {
    _extra = ['dashboard', 'general-ledger'].contains(kind) ? kind : null;
    _profit = kind == 'profit-and-loss';
    _balance = kind == 'balance-sheet';
    if (_from.isAfter(_date)) _from = DateTime(_date.year);
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

  Future<void> _filterDates(String preset) async {
    if (preset == 'Custom') {
      if (_period) {
        final range = await showDateRangePicker(
          context: context,
          initialEntryMode: DatePickerEntryMode.calendarOnly,
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
          initialDateRange: DateTimeRange(start: _from, end: _date),
        );
        if (range == null || !mounted) return;
        setState(() {
          _from = range.start;
          _date = range.end;
          _load();
        });
      } else {
        final date = await showDatePicker(
          context: context,
          initialEntryMode: DatePickerEntryMode.calendarOnly,
          initialDate: _date,
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
        );
        if (date == null || !mounted) return;
        setState(() {
          _date = date;
          _load();
        });
      }
      return;
    }
    setState(() {
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day);
      _from = switch (preset) {
        'This Year' => DateTime(now.year),
        'This Month' => DateTime(now.year, now.month),
        'This Week' => _date.subtract(Duration(days: now.weekday - 1)),
        _ => _date,
      };
      _load();
    });
  }

  Future<void> _exportCsv() async {
    final data = _displayed;
    if (data == null) return;
    try {
      await downloadFile(
        reportCsv(_title, data),
        filename:
            '${_title.toLowerCase().replaceAll(' ', '-')}-${data['asOf']}.csv',
        mimeType: 'text/csv;charset=utf-8',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Export unavailable. Downloads are supported in the web app.',
            ),
          ),
        );
      }
    }
  }

  void _reportInfo() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('About this report'),
      content: const Text(
        'Includes posted journals only; drafts are excluded. Amounts use the workspace accounting currency. Income and expenses cover the selected period; other dashboard balances are cumulative through the end date. Graphs compare current totals, not historical trends. General ledger balances are debit-positive.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.reportKind == null)
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
                        const SizedBox(width: 6),
                        const Icon(Icons.expand_more, size: 18),
                      ],
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'Filter dates',
                icon: const Icon(Icons.calendar_month_outlined),
                onSelected: _filterDates,
                itemBuilder: (_) => [
                  for (final preset in [
                    'Today',
                    'This Week',
                    'This Month',
                    'This Year',
                    'Custom',
                  ])
                    PopupMenuItem(value: preset, child: Text(preset)),
                ],
              ),
              IconButton(
                tooltip: 'Refresh report',
                onPressed: () => setState(() => _load(force: true)),
                icon: const Icon(Icons.refresh),
              ),
              PopupMenuButton<String>(
                tooltip: 'Report options',
                onSelected: (value) {
                  if (value == 'csv') {
                    _exportCsv();
                  } else {
                    _reportInfo();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'csv',
                    enabled: _displayed != null,
                    child: const Text('Export CSV'),
                  ),
                  const PopupMenuItem(
                    value: 'info',
                    child: Text('About this report'),
                  ),
                ],
              ),
            ],
          ),
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
                  if (widget.api.cache.state(_path)?.refreshing == true)
                    SizedBox(
                      height: 18,
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
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.sizeOf(context).width < 600
                          ? 12
                          : 24,
                      vertical: 4,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_period ? "${_from.toIso8601String().substring(0, 10)} to " : "As of "}$_asOf · ${data['journalCount'] ?? 0} posted journals',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
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
