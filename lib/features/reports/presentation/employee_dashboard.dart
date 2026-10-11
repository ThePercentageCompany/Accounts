import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import '../data/report_format.dart';
import 'dashboard_tasks.dart';

const employeeOverviewTables = <String, List<String>>{
  'Income & Expenses': ['Income', 'Expenses'],
  'Invoices': ['Invoices', 'Receipts'],
  'Quotations': ['Quotations'],
  'Payroll': ['Payroll'],
  'Customers': ['Customers'],
  'Employees': ['Employees'],
  'Projects': ['Projects'],
  'Fixed Assets': ['Assets'],
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
          _SectionOverview(
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
          !employeeOverviewTables.keys.any(allowed.contains))
        const Card(
            child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                    'Your administrator has not enabled any overview sections yet.'))),
    ]);
  }
}

class _SectionOverview extends StatefulWidget {
  const _SectionOverview(
      {super.key,
      required this.api,
      required this.companyId,
      required this.section,
      required this.tables,
      required this.active,
      required this.onSection});
  final SaasApi api;
  final String companyId, section;
  final List<String> tables;
  final bool active;
  final void Function(String, String) onSection;
  @override
  State<_SectionOverview> createState() => _SectionOverviewState();
}

class _SectionOverviewState extends State<_SectionOverview> {
  final _rows = <String, List<Map<String, dynamic>>>{};
  final _errors = <String, String>{};
  bool _busy = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.active &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
        _load();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _SectionOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (_busy || !widget.active) return;
    setState(() => _busy = true);
    await Future.wait(widget.tables.map((table) async {
      try {
        final response = await widget.api
            .records(widget.companyId, table, employee: true, force: force);
        if (!mounted) return;
        _rows[table] = (response['records'] as List? ?? [])
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
    if (mounted) setState(() => _busy = false);
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
