import 'package:flutter/material.dart';
import 'saas_api.dart';

class TrialBalanceView extends StatefulWidget {
  const TrialBalanceView({
    super.key,
    required this.api,
    required this.companyId,
  });
  final SaasApi api;
  final String companyId;
  @override
  State<TrialBalanceView> createState() => _TrialBalanceViewState();
}

class _TrialBalanceViewState extends State<TrialBalanceView> {
  DateTime _date = DateTime.now();
  DateTime _from = DateTime(DateTime.now().year);
  bool _profit = false;
  bool _balance = false;
  bool get _statement => _profit || _balance;
  late Future<Map<String, dynamic>> _report;
  String get _asOf => _date.toIso8601String().substring(0, 10);
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _report = _balance
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
          ChoiceChip(
            label: const Text('Trial balance'),
            selected: !_statement,
            onSelected: (_) => setState(() {
              _profit = false;
              _balance = false;
              _load();
            }),
          ),
          ChoiceChip(
            label: const Text('Profit and loss'),
            selected: _profit,
            onSelected: (_) => setState(() {
              _profit = true;
              _balance = false;
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
              _load();
            }),
          ),
          if (_profit)
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
              child: Text('From ${_from.toIso8601String().substring(0, 10)}'),
            ),
          TextButton(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: _profit ? _from : DateTime(1900),
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
          'Includes posted journals only. Unposted entries and transactions not yet connected to the ledger are excluded. Amounts use the workspace accounting currency.',
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
            final data = snapshot.data!, rows = data['accounts'] as List;
            return SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    '${data['journalCount']} posted journals ${_profit ? "from ${data['from']} " : ""}through ${data['asOf']}',
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
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No posted balances for this date.'),
                    ),
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
                                Text('${row[_statement ? 'amount' : 'debit']}'),
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
