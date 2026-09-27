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
  late Future<Map<String, dynamic>> _report;
  String get _asOf => _date.toIso8601String().substring(0, 10);
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _report = widget.api.trialBalance(widget.companyId, _asOf);
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
          const Text('Trial balance'),
          TextButton(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
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
                    '${data['journalCount']} posted journals through ${data['asOf']}',
                  ),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No posted balances for this date.'),
                    ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Account')),
                        DataColumn(label: Text('Group')),
                        DataColumn(label: Text('Debit'), numeric: true),
                        DataColumn(label: Text('Credit'), numeric: true),
                      ],
                      rows: [
                        for (final row in rows)
                          DataRow(
                            cells: [
                              DataCell(Text('${row['accountName']}')),
                              DataCell(Text('${row['accountGroup']}')),
                              DataCell(Text('${row['debit']}')),
                              DataCell(Text('${row['credit']}')),
                            ],
                          ),
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
