import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import '../data/report_format.dart';
import 'dashboard_tasks.dart';
import 'overview_charts.dart';
import 'dashboard_financial_overview.dart';

const employeeOverviewTables = <String, List<String>>{
  'Income & Expenses': ['Income', 'Expenses'],
  'Invoices': ['Invoices', 'Receipts'],
  'Quotations': ['Quotations'],
  'Payroll': ['Payroll'],
  'Customers': ['Customers'],
  'Employees': ['Employees'],
  'Projects': ['Projects'],
  'Fixed Assets': ['Assets'],
  'Cash & Bank': ['MoneyTransfers'],
  'Capital & Equity': [
    'Shareholders',
    'CapitalTransactions',
    'ShareholderLoans'
  ],
  'Balance Sheet': ['FinancialPeriods', 'Journals', 'JournalLines'],
  'Office & Attendance': ['Attendance', 'Overtime'],
};

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard(
      {super.key,
      required this.api,
      required this.companyId,
      required this.employee,
      required this.onTask,
      required this.onSection,
      this.active = true});
  final SaasApi api;
  final String companyId;
  final Map<String, dynamic> employee;
  final ValueChanged<String> onTask;
  final void Function(String, String) onSection;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final allowed = employee['allowedSections'] as List? ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Your workspace overview',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
          'Your enabled sections and the records you have access to. Amounts are grouped by currency and include locally saved changes.'),
      const SizedBox(height: 20),
      if (allowed.contains('Reports')) ...[
        DashboardFinancialOverview(
            api: api,
            companyId: companyId,
            employee: true,
            active: active,
            timeZone: '${employee['timeZone'] ?? 'Asia/Dubai'}',
            onReportSelected: (kind) => onSection('Reports', kind)),
        const SizedBox(height: 20),
      ],
      if (allowed.contains('Tasks')) ...[
        DashboardTasks(
            api: api,
            companyId: companyId,
            employee: true,
            employeeProfile: employee,
            onTask: onTask,
            active: active),
        const SizedBox(height: 16),
      ],
      for (final section in employeeOverviewTables.entries)
        if (allowed.contains(section.key)) ...[
          SectionOverview(
              key: ValueKey((companyId, employee['employeeId'], section.key)),
              api: api,
              companyId: companyId,
              section: section.key,
              tables: section.value,
              active: active,
              onSection: onSection),
          const SizedBox(height: 16),
        ],
      if (!allowed.contains('Tasks') &&
          !allowed.contains('Reports') &&
          !employeeOverviewTables.keys.any(allowed.contains))
        const Card(
            child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                    'Your administrator has not enabled any overview sections yet.'))),
    ]);
  }
}

class SectionOverview extends StatefulWidget {
  const SectionOverview(
      {super.key,
      required this.api,
      required this.companyId,
      required this.section,
      required this.tables,
      required this.active,
      this.employee = true,
      required this.onSection});
  final SaasApi api;
  final String companyId, section;
  final List<String> tables;
  final bool active, employee;
  final void Function(String, String) onSection;
  @override
  State<SectionOverview> createState() => _SectionOverviewState();
}

class _SectionOverviewState extends State<SectionOverview> {
  final _rows = <String, List<Map<String, dynamic>>>{};
  final _errors = <String, String>{};
  bool _busy = false;
  Timer? _timer;
  int _localRevision = 0;
  bool _localDirty = false;
  void _localChanged() {
    if (!mounted || _localRevision == widget.api.cache.localRevision) return;
    _localRevision = widget.api.cache.localRevision;
    _localDirty = true;
    if (!_busy) _load();
  }

  @override
  void initState() {
    super.initState();
    widget.api.cache.addListener(_localChanged);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.active &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
        _load();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SectionOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      oldWidget.api.cache.removeListener(_localChanged);
      widget.api.cache.addListener(_localChanged);
    }
    if (!oldWidget.active && widget.active) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.api.cache.removeListener(_localChanged);
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (_busy || !widget.active) return;
    _localDirty = false;
    setState(() => _busy = true);
    await Future.wait(widget.tables.map((table) async {
      try {
        final response = !widget.employee && table == 'Employees'
            ? await widget.api.employees(widget.companyId)
            : await widget.api.records(widget.companyId, table,
                employee: widget.employee, force: force);
        if (!mounted) return;
        _rows[table] = ((table == 'Employees' && !widget.employee
                    ? response['employees']
                    : response['records']) as List? ??
                [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _errors.remove(table);
      } catch (_) {
        if (mounted) {
          _errors[table] =
              'Overview unavailable. Open this section to review access or connection details.';
        }
      }
    }));
    if (mounted) {
      setState(() => _busy = false);
      if (_localDirty) _load();
    }
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text(widget.section,
                      style: Theme.of(context).textTheme.titleLarge)),
              if (_busy) const AppActivityIndicator(radius: 8),
              IconButton(
                  tooltip: 'Refresh overview',
                  onPressed: _busy ? null : () => _load(force: true),
                  icon: const Icon(Icons.refresh)),
            ]),
            for (final table in widget.tables) ...[
              const SizedBox(height: 12),
              Text(table, style: Theme.of(context).textTheme.titleMedium),
              if (_rows.containsKey(table)) ...[
                Text('${_rows[table]!.length} records'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final status in _statusCounts(_rows[table]!).entries)
                    Chip(
                        label: Text(
                            '${status.key.replaceAll('_', ' ')}: ${status.value}')),
                  for (final amount in _amounts(_rows[table]!).entries)
                    Chip(
                        label: Text(
                            '${amount.key}: ${const ReportFormat().money(reportDecimal(amount.value))}')),
                ]),
                if (_rows[table]!.any((row) => row['syncStatus'] == 'PENDING'))
                  const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Includes changes saved on this device.')),
                if (_rows[table]!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  OverviewDonut(centerLabel: 'Records', data: [
                    for (final entry in _statusCounts(_rows[table]!).entries)
                      OverviewDatum(entry.key.replaceAll('_', ' '),
                          entry.value.toDouble(),
                          onTap: () => widget.onSection(widget.section, table)),
                    if (_statusCounts(_rows[table]!).isEmpty)
                      OverviewDatum('Records', _rows[table]!.length.toDouble(),
                          onTap: () => widget.onSection(widget.section, table)),
                  ]),
                  const SizedBox(height: 12),
                  ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Activity & recent records'),
                      children: [
                        OverviewBars(
                            data: _activity(_rows[table]!)
                                .entries
                                .map((entry) => OverviewDatum(
                                    entry.key, entry.value.toDouble(),
                                    onTap: () => widget.onSection(
                                        widget.section, table)))
                                .toList()),
                        for (final row in _recent(_rows[table]!))
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(
                                  '${row['title'] ?? row['number'] ?? row['fullName'] ?? row['name'] ?? row['description'] ?? table}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  '${row['status'] ?? row['paymentStatus'] ?? row['employmentStatus'] ?? 'Open record'}'
                                      .replaceAll('_', ' ')),
                              trailing:
                                  const Icon(Icons.arrow_outward, size: 16),
                              onTap: () =>
                                  widget.onSection(widget.section, table)),
                      ]),
                ] else if (!_busy)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No records yet.')),
              ],
              if (_errors[table] != null) Text(_errors[table]!),
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                      onPressed: () => widget.onSection(widget.section, table),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text('Open $table'))),
            ],
          ])));
}

List<Map<String, dynamic>> _recent(List<Map<String, dynamic>> rows) {
  final sorted = [...rows]..sort((a, b) =>
      (num.tryParse('${b['updatedAt']}') ?? 0)
          .compareTo(num.tryParse('${a['updatedAt']}') ?? 0));
  return sorted.take(5).toList();
}

Map<String, int> _activity(List<Map<String, dynamic>> rows) {
  final months = <String, int>{};
  for (final row in rows) {
    final date =
        '${row['issueDate'] ?? row['date'] ?? row['paymentDate'] ?? row['purchaseDate'] ?? row['joinDate'] ?? row['dueDate'] ?? row['month'] ?? ''}';
    if (!RegExp(r'^\d{4}-\d{2}').hasMatch(date)) continue;
    final month = date.substring(0, 7);
    months[month] = (months[month] ?? 0) + 1;
  }
  final keys = months.keys.toList()..sort();
  return {
    for (final key in keys.skip(keys.length > 6 ? keys.length - 6 : 0))
      key: months[key]!
  };
}

Map<String, int> _statusCounts(List<Map<String, dynamic>> rows) {
  final counts = <String, int>{};
  for (final row in rows) {
    final status =
        row['paymentStatus'] ?? row['status'] ?? row['employmentStatus'];
    if (status is String && status.isNotEmpty) {
      counts[status] = (counts[status] ?? 0) + 1;
    }
  }
  return counts;
}

Map<String, BigInt> _amounts(List<Map<String, dynamic>> rows) {
  final totals = <String, BigInt>{};
  for (final row in rows) {
    final amount =
        reportMinor(row['total'] ?? row['netSalary'] ?? row['amount']);
    if (amount == null) continue;
    final currency = '${row['currency'] ?? ''}'.trim();
    final label = currency.isEmpty ? 'Company currency' : currency;
    totals[label] = (totals[label] ?? BigInt.zero) + amount;
  }
  return totals;
}
