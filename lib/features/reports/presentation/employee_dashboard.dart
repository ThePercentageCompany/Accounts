import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import '../data/report_format.dart';
import 'dashboard_tasks.dart';
import 'overview_charts.dart';
import 'dashboard_financial_overview.dart';
import 'workspace_quick_look_card.dart';
import 'package:intl/intl.dart';
import 'package:tpc_invoice/core/utils/business_time.dart';
import '../data/payroll_period.dart';

const employeeOverviewTables = <String, List<String>>{
  'Income & Expenses': ['Income', 'Expenses'],
  'Invoices': ['Invoices', 'Receipts'],
  'Quotations': ['Quotations'],
  'Payroll': ['Payroll'],
  'Customers': ['Customers'],
  'Employees': ['Employees'],
  'Projects': ['Projects'],
  'Fixed Assets': ['Assets'],
  'Cash & Bank': ['MoneyTransfers', 'CompanyLoans'],
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
              timeZone: '${employee['timeZone'] ?? 'Asia/Dubai'}',
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
      this.compact = false,
      this.timeZone = 'Asia/Dubai',
      required this.onSection});
  final SaasApi api;
  final String companyId, section;
  final List<String> tables;
  final bool active, employee, compact;
  final String timeZone;
  final void Function(String, String) onSection;
  @override
  State<SectionOverview> createState() => _SectionOverviewState();
}

class _SectionOverviewState extends State<SectionOverview> {
  String _payrollScope = 'all';
  late int _payrollYear = businessNow(widget.timeZone).year;
  late int _payrollMonth = businessNow(widget.timeZone).month;

  Map<String, List<Map<String, dynamic>>> get _displayRows => {
        for (final entry in _rows.entries)
          entry.key: entry.key == 'Payroll'
              ? entry.value
                  .where((row) => payrollMatchesPeriod(row,
                      scope: _payrollScope,
                      year: _payrollYear,
                      month: _payrollMonth))
                  .toList()
              : entry.value,
      };

  Widget _payrollFilters() {
    final years = <int>{_payrollYear, businessNow(widget.timeZone).year};
    for (final row in _rows['Payroll'] ?? <Map<String, dynamic>>[]) {
      final value = '${row['month'] ?? ''}';
      if (RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) {
        years.add(int.parse(value.substring(0, 4)));
      }
    }
    final orderedYears = years.toList()..sort((a, b) => b.compareTo(a));
    Widget dropdown<T>(String label, T value, List<DropdownMenuItem<T>> items,
            ValueChanged<T> changed) =>
        SizedBox(
            width: 130,
            child: DropdownButtonFormField<T>(
                key: ValueKey('payroll-filter-$label'),
                initialValue: value,
                isExpanded: true,
                decoration: InputDecoration(labelText: label, isDense: true),
                items: items,
                onChanged: (next) {
                  if (next != null) setState(() => changed(next));
                }));
    return Wrap(spacing: 8, runSpacing: 8, children: [
      dropdown<String>(
          'Payroll period',
          _payrollScope,
          const [
            DropdownMenuItem(value: 'all', child: Text('All')),
            DropdownMenuItem(value: 'year', child: Text('Year')),
            DropdownMenuItem(value: 'month', child: Text('Month')),
          ],
          (value) => _payrollScope = value),
      if (_payrollScope != 'all')
        dropdown<int>(
            'Year',
            _payrollYear,
            [
              for (final year in orderedYears)
                DropdownMenuItem(value: year, child: Text('$year')),
            ],
            (value) => _payrollYear = value),
      if (_payrollScope == 'month')
        dropdown<int>(
            'Month',
            _payrollMonth,
            [
              for (var month = 1; month <= 12; month++)
                DropdownMenuItem(
                    value: month,
                    child:
                        Text(DateFormat.MMMM().format(DateTime(2000, month)))),
            ],
            (value) => _payrollMonth = value),
    ]);
  }

  final _rows = <String, List<Map<String, dynamic>>>{};
  Map<String, BigInt> _displayAmounts(
      String table, List<Map<String, dynamic>> rows) {
    final totals = _amounts(rows);
    if (table == 'Payroll') {
      for (final currency in _amounts(_rows[table] ?? []).keys) {
        totals.putIfAbsent(currency, () => BigInt.zero);
      }
    }
    return totals;
  }

  final _errors = <String, String>{};
  bool _busy = false;
  int _localRevision = 0;
  bool _localDirty = false;
  bool _cacheScheduled = false;
  final _snapshots = <String, Map<String, dynamic>>{};
  int _generation = 0;
  String _path(String table, {SectionOverview? source}) {
    final view = source ?? widget;
    return !view.employee && table == 'Employees'
        ? '/v1/companies/${view.companyId}/employees'
        : view.api.recordsPath(view.companyId, table, employee: view.employee);
  }

  void _watch(bool active, {SectionOverview? source}) {
    final view = source ?? widget;
    for (final table in view.tables) {
      if (active) {
        view.api.cache.activate(_path(table, source: view));
      } else {
        view.api.cache.deactivate(_path(table, source: view));
      }
    }
  }

  void _localChanged() {
    if (!mounted || !widget.active || _cacheScheduled) return;
    _cacheScheduled = true;
    scheduleMicrotask(() {
      _cacheScheduled = false;
      if (!mounted || !widget.active) return;
      if (_localRevision != widget.api.cache.localRevision) {
        _localRevision = widget.api.cache.localRevision;
        _localDirty = true;
        if (!_busy) _load();
      }
      var changed = false;
      for (final table in widget.tables) {
        final state = widget.api.cache.state(_path(table));
        final data = state?.data;
        if (data == null) {
          if ((widget.api.cache.scope == null ||
                  state?.error is SaasApiException &&
                      (state!.error as SaasApiException).status == 403) &&
              _rows.containsKey(table)) {
            _rows.remove(table);
            _snapshots.remove(table);
            changed = true;
          }
          continue;
        }
        if (identical(data, _snapshots[table])) continue;
        _snapshots[table] = data;
        final key =
            !widget.employee && table == 'Employees' ? 'employees' : 'records';
        final rows = (data[key] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _rows[table] = widget.api
                .workspaceOutbox(widget.companyId, employee: widget.employee)
                ?.overlay(table, rows) ??
            rows;
        _errors.remove(table);
        changed = true;
      }
      if (changed) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    widget.api.cache.addListener(_localChanged);
    if (widget.active) _watch(true);
    _load();
  }

  @override
  void didUpdateWidget(covariant SectionOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final contextChanged = oldWidget.api != widget.api ||
        oldWidget.companyId != widget.companyId ||
        oldWidget.employee != widget.employee ||
        oldWidget.tables.join(',') != widget.tables.join(',');
    if (contextChanged || oldWidget.active != widget.active) {
      if (oldWidget.active) _watch(false, source: oldWidget);
      if (widget.active) _watch(true);
    }
    if (oldWidget.api != widget.api) {
      oldWidget.api.cache.removeListener(_localChanged);
      widget.api.cache.addListener(_localChanged);
    }
    if (contextChanged) {
      _generation++;
      _busy = false;
      _rows.clear();
      _errors.clear();
      _snapshots.clear();
    }
    if (contextChanged || !oldWidget.active && widget.active) _load();
  }

  @override
  void dispose() {
    _generation++;
    if (widget.active) _watch(false);
    widget.api.cache.removeListener(_localChanged);
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (_busy || !widget.active) return;
    final generation = ++_generation;
    _localDirty = false;
    setState(() => _busy = true);
    await Future.wait(widget.tables.map((table) async {
      try {
        final response = !widget.employee && table == 'Employees'
            ? await widget.api.employees(widget.companyId, force: force)
            : await widget.api.records(widget.companyId, table,
                employee: widget.employee, force: force);
        if (!mounted || generation != _generation) return;
        setState(() {
          _rows[table] = ((table == 'Employees' && !widget.employee
                      ? response['employees']
                      : response['records']) as List? ??
                  [])
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          _errors.remove(table);
        });
      } catch (_) {
        if (mounted && generation == _generation) {
          _errors[table] =
              'Overview unavailable. Open this section to review access or connection details.';
        }
      }
    }));
    if (mounted && generation == _generation) {
      setState(() => _busy = false);
      if (_localDirty) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _displayRows;
    return widget.compact
        ? WorkspaceQuickLookCard(
            section: widget.section,
            tables: widget.tables,
            rows: rows,
            errors: _errors,
            busy: _busy,
            filters:
                widget.tables.contains('Payroll') ? _payrollFilters() : null,
            onOpen: (table) => widget.onSection(widget.section, table),
            onRefresh: () => _load(force: true),
            amounts: {
                for (final table in widget.tables)
                  table: [
                    for (final amount
                        in _displayAmounts(table, rows[table] ?? []).entries)
                      '${amount.key} ${const ReportFormat().money(reportDecimal(amount.value))}',
                  ],
              })
        : Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                      if (widget.tables.contains('Payroll')) ...[
                        const SizedBox(height: 12),
                        _payrollFilters(),
                      ],
                      for (final table in widget.tables) ...[
                        const SizedBox(height: 12),
                        Text(table,
                            style: Theme.of(context).textTheme.titleMedium),
                        if (rows.containsKey(table)) ...[
                          Text('${rows[table]!.length} records'),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final status
                                in _statusCounts(rows[table]!).entries)
                              Chip(
                                  label: Text(
                                      '${status.key.replaceAll('_', ' ')}: ${status.value}')),
                            for (final amount
                                in _displayAmounts(table, rows[table]!).entries)
                              Chip(
                                  label: Text(
                                      '${amount.key}: ${const ReportFormat().money(reportDecimal(amount.value))}')),
                          ]),
                          if (rows[table]!
                              .any((row) => row['syncStatus'] == 'PENDING'))
                            const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                    'Includes changes saved on this device.')),
                          if (rows[table]!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            OverviewDonut(centerLabel: 'Records', data: [
                              for (final entry
                                  in _statusCounts(rows[table]!).entries)
                                OverviewDatum(entry.key.replaceAll('_', ' '),
                                    entry.value.toDouble(),
                                    onTap: () => widget.onSection(
                                        widget.section, table)),
                              if (_statusCounts(rows[table]!).isEmpty)
                                OverviewDatum(
                                    'Records', rows[table]!.length.toDouble(),
                                    onTap: () => widget.onSection(
                                        widget.section, table)),
                            ]),
                            const SizedBox(height: 12),
                            ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text('Activity & recent records'),
                                children: [
                                  OverviewBars(
                                      data: _activity(rows[table]!)
                                          .entries
                                          .map((entry) => OverviewDatum(
                                              entry.key, entry.value.toDouble(),
                                              onTap: () => widget.onSection(
                                                  widget.section, table)))
                                          .toList()),
                                  for (final row in _recent(rows[table]!))
                                    ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        title: Text(
                                            table == 'Payroll'
                                                ? '${row['employeeName'] ?? 'Employee'} · ${row['employeeCode'] ?? row['employeeId'] ?? ''} · ${row['month'] ?? ''}'
                                                : '${row['title'] ?? row['number'] ?? row['fullName'] ?? row['name'] ?? row['description'] ?? table}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        subtitle: Text(
                                            '${row['status'] ?? row['paymentStatus'] ?? row['employmentStatus'] ?? 'Open record'}'
                                                .replaceAll('_', ' ')),
                                        trailing: const Icon(
                                            Icons.arrow_outward,
                                            size: 16),
                                        onTap: () => widget.onSection(
                                            widget.section, table)),
                                ]),
                          ] else if (!_busy)
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                    table == 'Payroll' && _payrollScope != 'all'
                                        ? 'No payroll for this period.'
                                        : 'No records yet.')),
                        ],
                        if (_errors[table] != null) Text(_errors[table]!),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                                onPressed: () =>
                                    widget.onSection(widget.section, table),
                                icon: const Icon(Icons.arrow_forward),
                                label: Text('Open $table'))),
                      ],
                    ])));
  }
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
