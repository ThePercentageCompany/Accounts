import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_admin_controller.dart';
import 'employee_admin_view.dart';
import 'saas_api.dart';
import 'record_write_queue.dart';
import 'customer_editor.dart';

const workspaceTables = <String, List<String>>{
  'Invoices': ['Invoices', 'InvoiceItems', 'Receipts', 'ReceiptAllocations'],
  'Quotations': ['Quotations', 'QuotationItems'],
  'Customers': ['Customers'],
  'Income & Expenses': ['Income', 'Expenses'],
  'Payroll': ['Payroll', 'PayrollItems', 'Payslips'],
  'Office & Attendance': ['Attendance', 'Overtime'],
  'Fixed Assets': ['Assets'],
  'Capital & Equity': [
    'Shareholders',
    'CapitalAccounts',
    'CapitalTransactions',
    'ShareholderEquity',
    'ShareholderLoans',
  ],
  'Balance Sheet': ['FinancialPeriods', 'Journals', 'JournalLines'],
  'Settings': ['CompanyProfile'],
};

const tableTitles = {
  'InvoiceItems': 'Invoice lines',
  'ReceiptAllocations': 'Payment allocations',
  'QuotationItems': 'Quotation lines',
  'PayrollItems': 'Payroll details',
  'CompanyProfile': 'Company profile',
  'CapitalAccounts': 'Capital accounts',
  'CapitalTransactions': 'Capital transactions',
  'ShareholderEquity': 'Shareholder equity',
  'ShareholderLoans': 'Shareholder loans',
  'FinancialPeriods': 'Financial periods',
  'JournalLines': 'Journal lines',
};

class SharedWorkspace extends StatefulWidget {
  const SharedWorkspace({
    super.key,
    required this.api,
    required this.companyId,
    required this.title,
    required this.onBack,
    this.employee,
    this.ownerId,
    this.preferences,
  });
  final SaasApi api;
  final String companyId;
  final String title;
  final VoidCallback onBack;
  final Map<String, dynamic>? employee;
  final String? ownerId;
  final SharedPreferences? preferences;
  @override
  State<SharedWorkspace> createState() => _SharedWorkspaceState();
}

class _SharedWorkspaceState extends State<SharedWorkspace> {
  late final RecordWriteQueue? _writes = widget.employee == null
      ? RecordWriteQueue(
          widget.api,
          widget.preferences!,
          widget.ownerId!,
          widget.companyId,
        )
      : null;
  late final EmployeeAdminController? _employees = widget.employee == null
      ? EmployeeAdminController(
          widget.api,
          widget.preferences!,
          widget.ownerId!,
          widget.companyId,
        )
      : null;
  String? _selected;
  @override
  void dispose() {
    _employees?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = widget.employee?['allowedSections'] as List?;
    final sections = <String>[
      if (_employees != null || allowed!.contains('Employees')) 'Employees',
      for (final section in workspaceTables.keys)
        if (allowed == null || allowed.contains(section)) section,
    ];
    final selected = sections.contains(_selected)
        ? _selected
        : sections.firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          onPressed: widget.onBack,
          tooltip: 'Back to account',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final section in sections)
                  ChoiceChip(
                    label: Text(section),
                    selected: section == selected,
                    onSelected: (_) => setState(() => _selected = section),
                  ),
              ],
            ),
          ),
          Expanded(
            child: selected == null
                ? const Center(
                    child: Text(
                      'No record sections are assigned. Contact your company owner.',
                    ),
                  )
                : selected == 'Employees' && _employees != null
                ? EmployeeAdminView(controller: _employees)
                : _RecordsPanel(
                    key: ValueKey((widget.companyId, selected)),
                    api: widget.api,
                    companyId: widget.companyId,
                    employee: widget.employee != null,
                    writes: _writes,
                    tables: selected == 'Employees'
                        ? ['Employees']
                        : workspaceTables[selected]!,
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecordsPanel extends StatefulWidget {
  const _RecordsPanel({
    super.key,
    required this.api,
    required this.companyId,
    required this.employee,
    required this.tables,
    this.writes,
  });
  final SaasApi api;
  final String companyId;
  final bool employee;
  final List<String> tables;
  final RecordWriteQueue? writes;
  @override
  State<_RecordsPanel> createState() => _RecordsPanelState();
}

class _RecordsPanelState extends State<_RecordsPanel> {
  late String table = widget.tables.first;
  List<Map<String, dynamic>> rows = [];
  bool busy = false;
  String? error;
  int _request = 0;
  Future<void> _editCustomer([Map<String, dynamic>? record]) async {
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => CustomerEditor(record: record),
    );
    if (values == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.enqueue(
        'Customers',
        record == null ? 'create' : 'update',
        values,
        recordId: record?['recordId'] as String?,
        expectedVersion: record == null
            ? 0
            : int.parse('${record['recordVersion']}'),
      );
      await widget.writes!.flush();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to save. Your pending change is retained.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _retryWrite() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.flush();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      busy = true;
      rows = [];
      error = null;
    });
    try {
      final result = await widget.api.records(
        widget.companyId,
        table,
        employee: widget.employee,
      );
      if (!mounted || request != _request) return;
      setState(
        () => rows = (result['records'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList(),
      );
    } on SaasApiException catch (e) {
      if (mounted && request == _request) setState(() => error = e.message);
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => error = 'Unable to load records. Retry when connected.');
      }
    } finally {
      if (mounted && request == _request) setState(() => busy = false);
    }
  }

  String _label(String key) =>
      key.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}');
  String _title(Map<String, dynamic> row) =>
      '${row['name'] ?? row['fullName'] ?? row['number'] ?? row['description'] ?? row['date'] ?? row['month'] ?? 'Record'}';
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Wrap(
          spacing: 12,
          children: [
            DropdownButton<String>(
              value: table,
              items: [
                for (final t in widget.tables)
                  DropdownMenuItem(value: t, child: Text(tableTitles[t] ?? t)),
              ],
              onChanged: busy
                  ? null
                  : (v) {
                      table = v!;
                      _load();
                    },
            ),
            TextButton.icon(
              onPressed: busy ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            if (widget.writes != null && table == 'Customers')
              FilledButton(
                onPressed: busy || widget.writes!.pending.isNotEmpty
                    ? null
                    : () => _editCustomer(),
                child: const Text('Add customer'),
              ),
            if (widget.writes?.pending.isNotEmpty == true)
              OutlinedButton(
                onPressed: busy ? null : _retryWrite,
                child: const Text('Retry pending change'),
              ),
          ],
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text(
          widget.writes != null && table == 'Customers'
              ? 'Company customers'
              : 'Online records · viewing only',
        ),
      ),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Semantics(liveRegion: true, child: Text(error!)),
        ),
      if (!busy && error == null && rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('No records yet.'),
        ),
      Expanded(
        child: ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return ExpansionTile(
              title: Text(_title(row)),
              subtitle: row['status'] == null ? null : Text('${row['status']}'),
              children: [
                if (widget.writes != null && table == 'Customers')
                  TextButton(
                    onPressed: busy || widget.writes!.pending.isNotEmpty
                        ? null
                        : () => _editCustomer(row),
                    child: const Text('Edit customer'),
                  ),
                for (final field in row.entries)
                  if (!field.key.startsWith('_') &&
                      !field.key.endsWith('Id') &&
                      !const [
                        'createdAt',
                        'createdBy',
                        'updatedAt',
                        'updatedBy',
                        'recordVersion',
                        'syncStatus',
                        'isDeleted',
                        'idempotencyKey',
                      ].contains(field.key) &&
                      '${field.value}'.isNotEmpty)
                    ListTile(
                      title: Text(_label(field.key)),
                      subtitle: SelectableText('${field.value}'),
                    ),
              ],
            );
          },
        ),
      ),
    ],
  );
}
