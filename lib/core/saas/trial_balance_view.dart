import 'package:flutter/material.dart';
import 'saas_api.dart';
import 'workspace_dashboard.dart';
import 'report_export.dart';
import '../utils/file_download.dart';

class TrialBalanceView extends StatefulWidget {
  const TrialBalanceView({
    super.key,
    required this.api,
    required this.companyId,
    this.employee = false,
    this.initialDashboard = false,
  });
  final SaasApi api;
  final String companyId;
  final bool employee;
  final bool initialDashboard;
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
  String get _asOf => _date.toIso8601String().substring(0, 10);
  @override
  void initState() {
    super.initState();
    if (widget.initialDashboard) _extra = 'dashboard';
    _load();
  }

  void _load() {
    _report = widget.employee
        ? widget.api.employeeReport(
            _extra ??
                (_balance
                    ? 'balance-sheet'
                    : _profit
                        ? 'profit-and-loss'
                        : 'trial-balance'),
            _from.toIso8601String().substring(0, 10),
            _asOf)
        : _extra != null
            ? widget.api.report(widget.companyId, _extra!,
                _from.toIso8601String().substring(0, 10), _asOf)
            : _balance
                ? widget.api.balanceSheet(widget.companyId, _asOf)
                : _profit
                    ? widget.api.profitAndLoss(
                        widget.companyId,
                        _from.toIso8601String().substring(0, 10),
                        _asOf,
                      )
                    : widget.api.trialBalance(widget.companyId, _asOf);
    // Observe immediate failures before the next frame attaches FutureBuilder.
    // FutureBuilder still receives the original future and displays its error.
    _report.ignore();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final entry in {
                'dashboard': 'Dashboard',
                'general-ledger': 'General ledger'
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
                        })),
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
              if (_period)
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
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
                  child:
                      Text('From ${_from.toIso8601String().substring(0, 10)}'),
                ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
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
                onPressed: () => setState(_load),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
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
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      snapshot.error is SaasApiException
                          ? (snapshot.error as SaasApiException).message
                          : 'Report unavailable. Retry.',
                    ),
                  );
                }
                final data = snapshot.data!,
                    rows = data['accounts'] as List? ?? [];
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      TextButton.icon(
                          icon: const Icon(Icons.download),
                          label: const Text('Export CSV'),
                          onPressed: () async {
                            try {
                              await downloadFile(reportCsv(_title, data),
                                  filename:
                                      '${_title.toLowerCase().replaceAll(' ', '-')}-${data['asOf']}.csv',
                                  mimeType: 'text/csv;charset=utf-8');
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Export unavailable. Downloads are supported in the web app.')));
                              }
                            }
                          }),
                      Text(
                        '${data['journalCount']} posted journals ${_period && _extra != 'dashboard' ? "from ${data['from']} " : ""}through ${data['asOf']}',
                      ),
                      if (_extra == 'dashboard')
                        Text(
                            'Income and expenses: ${data['from']} through ${data['asOf']}. Other balances are cumulative.'),
                      if (_extra == 'dashboard') WorkspaceDashboard(data: data),
                      if (_extra == 'general-ledger')
                        for (final account in rows)
                          ExpansionTile(
                              title: Text(
                                  '${account['accountName']} (${account['accountGroup']})'),
                              subtitle: Text(
                                  'Opening: ${account['opening']}   Closing: ${account['closing']}'),
                              children: [
                                Text(
                                    'Period debit: ${account['debit']}   Period credit: ${account['credit']}'),
                                for (final entry in account['entries'])
                                  ListTile(
                                      title: Text(
                                          '${entry['date']} · ${entry['number']} · ${entry['description']}'),
                                      subtitle: Text(
                                          'Debit: ${entry['debit']}   Credit: ${entry['credit']}   Balance: ${entry['balance']}')),
                              ]),
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
                      if (_extra == null)
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
                                          '${row[_statement ? 'amount' : 'debit']}'),
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
