import 'dart:async';
import 'mobile_components.dart';
import 'read_cache.dart';
import 'package:flutter/material.dart';
import '../widgets/appearance_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_admin_controller.dart';
import 'employee_admin_view.dart';
import 'saas_api.dart';
import 'record_write_queue.dart';
import 'customer_editor.dart';
import 'cash_entry_editor.dart';
import 'cash_payment_editor.dart';
import 'cash_reversal_editor.dart';
import 'financial_period_editor.dart';
import 'trial_balance_view.dart';
import 'invoice_editor.dart';
import 'receipt_editor.dart';
import 'quotation_editor.dart';
import 'payroll_editor.dart';
import 'asset_editor.dart';
import 'capital_editor.dart';
import 'company_profile_editor.dart';
import 'document_upload_queue.dart';
import 'record_documents_view.dart';

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
  late final DocumentUploadQueue? _uploads = widget.employee == null
      ? DocumentUploadQueue(
          widget.api,
          widget.preferences!,
          widget.ownerId!,
          widget.companyId,
        )
      : null;
  late final RecordWriteQueue? _writes = widget.preferences != null
      ? RecordWriteQueue(
          widget.api,
          widget.preferences!,
          widget.ownerId ?? 'employee_${widget.employee!['employeeId']}',
          widget.companyId,
          employee: widget.employee != null,
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
  final Set<String> _visited = {};
  @override
  void initState() {
    super.initState();
    widget.api.useVerifiedWorkspace(
      widget.companyId,
      ownerId: widget.ownerId,
      employee: widget.employee,
    );
  }

  @override
  void dispose() {
    _employees?.dispose();
    _uploads?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = widget.employee?['allowedSections'] as List?;
    final sections = <String>[
      if (widget.employee == null || allowed!.contains('Reports')) 'Reports',
      if (_employees != null || allowed!.contains('Employees')) 'Employees',
      for (final section in workspaceTables.keys)
        if (allowed == null || allowed.contains(section)) section,
    ];
    final selected = sections.contains(_selected)
        ? _selected
        : sections.firstOrNull;
    if (selected != null) _visited.add(selected);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final shortcuts = <String>[
      for (final section in ['Reports', 'Invoices', 'Customers'])
        if (sections.contains(section)) section,
      for (final section in sections)
        if (!['Reports', 'Invoices', 'Customers'].contains(section)) section,
    ].take(3).toList();
    final moreSelected = !shortcuts.contains(selected);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: wide ? 64 : 56,
        title: Text(
          wide
              ? widget.title
              : selected == 'Reports'
              ? 'Home'
              : selected ?? 'Workspace',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [AppearanceSelector(), SizedBox(width: 12)],
        leading: IconButton(
          onPressed: widget.onBack,
          tooltip: 'Back to account',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      bottomNavigationBar: wide || sections.length < 2
          ? null
          : NavigationBar(
              selectedIndex: moreSelected
                  ? shortcuts.length
                  : shortcuts.indexOf(selected!),
              onDestinationSelected: (index) {
                if (index < shortcuts.length) {
                  setState(() => _selected = shortcuts[index]);
                } else {
                  _showSections(sections, selected);
                }
              },
              destinations: [
                for (final section in shortcuts)
                  NavigationDestination(
                    icon: Icon(_sectionIcon(section)),
                    label: section == 'Reports' ? 'Home' : section,
                  ),
                NavigationDestination(
                  icon: const Icon(Icons.grid_view_outlined),
                  label: 'More',
                ),
              ],
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              SizedBox(width: 240, child: _navigation(sections, selected)),
            Expanded(
              child: Column(
                children: [
                  if (_uploads != null)
                    ListenableBuilder(
                      listenable: _uploads,
                      builder: (context, _) {
                        final pending = _uploads.pending;
                        if (pending == null) return const SizedBox.shrink();
                        return ListTile(
                          title: Text('Pending upload: ${pending['name']}'),
                          subtitle: Text(
                            '${pending['section']} — retry before other company changes.',
                          ),
                          trailing: TextButton(
                            onPressed: _uploads.busy
                                ? null
                                : () async {
                                    try {
                                      await _uploads.flush();
                                      if (mounted) setState(() {});
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e is SaasApiException
                                                  ? e.message
                                                  : 'Upload not confirmed. Retry.',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: const Text('Retry upload'),
                          ),
                        );
                      },
                    ),
                  if (wide)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 24 : 16,
                        12,
                        24,
                        wide ? 20 : 12,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected == 'Reports'
                                  ? 'Business overview'
                                  : selected ?? 'Workspace',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (wide) const SizedBox(height: 6),
                            if (wide)
                              Text(
                                'Your company, clearly organised.',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: selected == null ? 0 : sections.indexOf(selected),
                      children: sections.isEmpty
                          ? [const Center(child: Text('No sections assigned.'))]
                          : [
                              for (final section in sections)
                                _visited.contains(section)
                                    ? _sectionView(section, section == selected)
                                    : const SizedBox.shrink(),
                            ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionView(String? selected, bool active) => selected == null
      ? const Center(
          child: Text(
            'No record sections are assigned. Contact your company owner.',
          ),
        )
      : selected == 'Reports'
      ? TrialBalanceView(
          key: ValueKey(widget.companyId),
          api: widget.api,
          companyId: widget.companyId,
          employee: widget.employee != null,
          initialDashboard: true,
          active: active,
        )
      : selected == 'Employees' && _employees != null
      ? EmployeeAdminView(
          controller: _employees,
          active: active,
          onDocuments: (row) {
            showDialog<void>(
              context: context,
              builder: (_) => RecordDocumentsView(
                api: widget.api,
                companyId: widget.companyId,
                section: 'Employees',
                record: row,
                uploads: _uploads,
                writes: _writes,
              ),
            );
          },
        )
      : _RecordsPanel(
          key: ValueKey((widget.companyId, selected)),
          api: widget.api,
          companyId: widget.companyId,
          employee: widget.employee != null,
          active: active,
          writes:
              widget.employee == null ||
                  (widget.employee!['writableSections'] as List? ?? [])
                      .contains(selected)
              ? _writes
              : null,
          uploads: _uploads,
          tables: selected == 'Employees'
              ? ['Employees']
              : workspaceTables[selected]!,
        );

  IconData _sectionIcon(String section) => switch (section) {
    'Reports' => Icons.space_dashboard_outlined,
    'Invoices' => Icons.receipt_long_outlined,
    'Customers' => Icons.people_outline,
    'Employees' => Icons.badge_outlined,
    'Settings' => Icons.settings_outlined,
    _ => Icons.folder_outlined,
  };

  Future<void> _showSections(List<String> sections, String? selected) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Workspace',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final group in const <String, List<String>>{
                'Sales & customers': [
                  'Reports',
                  'Invoices',
                  'Quotations',
                  'Customers',
                ],
                'People & office': [
                  'Employees',
                  'Payroll',
                  'Office & Attendance',
                ],
                'Accounting & setup': [
                  'Income & Expenses',
                  'Fixed Assets',
                  'Capital & Equity',
                  'Balance Sheet',
                  'Settings',
                ],
              }.entries) ...[
                if (group.value.any(sections.contains))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      group.key,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                for (final section in group.value.where(sections.contains))
                  ListTile(
                    leading: Icon(_sectionIcon(section)),
                    title: Text(section),
                    selected: section == selected,
                    trailing: section == selected
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(context, section),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
    if (mounted && choice != null) setState(() => _selected = choice);
  }

  Widget _navigation(List<String> sections, String? selected) {
    final colors = Theme.of(context).colorScheme;
    const icons = <String, IconData>{
      'Reports': Icons.space_dashboard_outlined,
      'Employees': Icons.badge_outlined,
      'Invoices': Icons.receipt_long_outlined,
      'Quotations': Icons.request_quote_outlined,
      'Customers': Icons.people_outline,
      'Income & Expenses': Icons.swap_horiz,
      'Payroll': Icons.payments_outlined,
      'Office & Attendance': Icons.event_available_outlined,
      'Fixed Assets': Icons.business_outlined,
      'Capital & Equity': Icons.account_balance_outlined,
      'Balance Sheet': Icons.balance_outlined,
      'Settings': Icons.settings_outlined,
    };
    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            child: Row(
              children: [
                Icon(Icons.auto_graph, color: colors.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'TPC Accounts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          for (final section in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                selected: selected == section,
                selectedTileColor: colors.primaryContainer,
                selectedColor: colors.primary,
                leading: Icon(icons[section], size: 21),
                title: Text(
                  section,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => setState(() => _selected = section),
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
    this.uploads,
    this.active = true,
  });
  final bool active;
  final SaasApi api;
  final String companyId;
  final bool employee;
  final List<String> tables;
  final RecordWriteQueue? writes;
  final DocumentUploadQueue? uploads;
  @override
  State<_RecordsPanel> createState() => _RecordsPanelState();
}

class _RecordsPanelState extends State<_RecordsPanel> {
  late String table = widget.tables.first;
  List<Map<String, dynamic>> rows = [];
  String _search = '';
  final Map<String, Set<String>> _statusFilters = {};
  List<Map<String, dynamic>> get _visibleRows => rows
      .where(
        (row) =>
            (_statusFilters[table]?.isEmpty ?? true) ||
            _statusFilters[table]!.contains(
              '${row['status'] ?? row['paymentStatus'] ?? ''}',
            ),
      )
      .where(
        (row) => [
          _title(row),
          row['status'] ?? '',
          row['paymentStatus'] ?? '',
          row['email'] ?? '',
          row['phone'] ?? '',
        ].join(' ').toLowerCase().contains(_search.toLowerCase()),
      )
      .toList();
  bool busy = false;
  String? error;
  int _request = 0;
  bool _hasData = false;
  bool _loading = false;
  String get _path => widget.api.recordsPath(
    widget.companyId,
    table,
    employee: widget.employee,
  );
  final _searchController = TextEditingController();
  final Map<String, String> _tableSearch = {};
  String? _watchedPath;
  bool _savedData = false;
  Future<void> _discardRejected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard rejected edit?'),
        content: const Text(
          'This edit was rejected without being saved. Discard it and refresh the current record before editing again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep edit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard edit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.discardRejected();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool get _editable =>
      widget.writes != null &&
      const [
        'CompanyProfile',
        'Customers',
        'Income',
        'Expenses',
        'FinancialPeriods',
        'Invoices',
        'InvoiceItems',
        'Receipts',
        'Quotations',
        'QuotationItems',
        'Payroll',
        'Assets',
        'Shareholders',
        'CapitalTransactions',
        'ShareholderLoans',
      ].contains(table);
  String get _recordLabel => table == 'CompanyProfile'
      ? 'company profile'
      : table == 'FinancialPeriods'
      ? 'financial period'
      : table == 'Customers'
      ? 'customer'
      : table == 'Invoices'
      ? 'draft invoice'
      : table == 'InvoiceItems'
      ? 'invoice line'
      : table == 'Receipts'
      ? 'receipt'
      : table == 'Quotations'
      ? 'draft quotation'
      : table == 'QuotationItems'
      ? 'quotation line'
      : table == 'Payroll'
      ? 'payroll draft'
      : table == 'Assets'
      ? 'asset draft'
      : table == 'Shareholders'
      ? 'shareholder'
      : table == 'CapitalTransactions'
      ? 'capital contribution draft'
      : table == 'ShareholderLoans'
      ? 'shareholder loan draft'
      : table == 'Expenses'
      ? 'expense'
      : 'income';
  Future<void> _editCustomer([Map<String, dynamic>? record]) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await _openRecordEditor(record);
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not open the editor. Refresh and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openRecordEditor(Map<String, dynamic>? record) async {
    List<Map<String, dynamic>> choices = const [];
    List<Map<String, dynamic>> documentItems = const [];
    Map<String, dynamic> documentCompany = const {};
    if (const ['Invoices', 'Quotations'].contains(table)) {
      final itemTable = table == 'Invoices' ? 'InvoiceItems' : 'QuotationItems';
      final parentKey = table == 'Invoices' ? 'invoiceId' : 'quotationId';
      if (record != null) {
        final response = await widget.api.records(
          widget.companyId,
          itemTable,
          employee: widget.employee,
          force: true,
        );
        documentItems =
            (response['records'] as List)
                .map((row) => Map<String, dynamic>.from(row as Map))
                .where((row) => row[parentKey] == record['recordId'])
                .toList()
              ..sort(
                (a, b) =>
                    (a['lineNumber'] as num).compareTo(b['lineNumber'] as num),
              );
      }
      // Company settings are owner-only unless separately assigned to employees.
      // Employee editing must not acquire extra permissions just for a preview.
      if (!widget.employee) {
        final response = await widget.api.records(
          widget.companyId,
          'CompanyProfile',
        );
        documentCompany = (response['records'] as List).isEmpty
            ? {}
            : Map<String, dynamic>.from(
                (response['records'] as List).first as Map,
              );
      }
      if (!mounted) return;
    }
    if (table == 'Payroll') {
      final response = await widget.api.employees(widget.companyId);
      choices = (response['employees'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => item['employmentStatus'] == 'ACTIVE')
          .toList();
      if (!mounted) return;
    }
    if (const ['CapitalTransactions', 'ShareholderLoans'].contains(table)) {
      final response = await widget.api.records(
        widget.companyId,
        'Shareholders',
      );
      choices = (response['records'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => item['status'] == 'ACTIVE')
          .toList();
      if (!mounted) return;
    }
    if (const [
      'Invoices',
      'InvoiceItems',
      'Receipts',
      'Quotations',
      'QuotationItems',
    ].contains(table)) {
      final response = await widget.api.records(
        widget.companyId,
        const ['Invoices', 'Quotations'].contains(table)
            ? 'Customers'
            : table == 'QuotationItems'
            ? 'Quotations'
            : 'Invoices',
        employee: widget.employee,
      );
      choices = (response['records'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where(
            (item) =>
                const ['Invoices', 'Quotations'].contains(table) ||
                (table == 'InvoiceItems' && item['status'] == 'DRAFT') ||
                (table == 'Receipts' &&
                    const [
                      'ISSUED',
                      'PARTIALLY_PAID',
                    ].contains(item['status']) &&
                    (item['balance'] as num? ?? 0) > 0) ||
                (table == 'QuotationItems' && item['status'] == 'DRAFT'),
          )
          .toList();
      if (!mounted) return;
    }
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => table == 'CompanyProfile'
          ? CompanyProfileEditor(record: record!)
          : table == 'Invoices'
          ? InvoiceEditor(
              customers: choices,
              record: record,
              items: documentItems,
              company: documentCompany,
            )
          : table == 'InvoiceItems'
          ? InvoiceLineEditor(invoices: choices, record: record)
          : table == 'Receipts'
          ? ReceiptEditor(invoices: choices)
          : table == 'Quotations'
          ? QuotationEditor(
              customers: choices,
              record: record,
              items: documentItems,
              company: documentCompany,
            )
          : table == 'QuotationItems'
          ? QuotationLineEditor(quotations: choices, record: record)
          : table == 'Payroll'
          ? PayrollEditor(employees: choices, record: record)
          : table == 'Assets'
          ? AssetEditor(record: record)
          : table == 'Shareholders'
          ? ShareholderEditor(record: record)
          : table == 'CapitalTransactions'
          ? CapitalContributionEditor(shareholders: choices, record: record)
          : table == 'ShareholderLoans'
          ? ShareholderLoanEditor(shareholders: choices, record: record)
          : table == 'Customers'
          ? CustomerEditor(record: record)
          : table == 'FinancialPeriods'
          ? FinancialPeriodEditor(record: record)
          : CashEntryEditor(expense: table == 'Expenses', record: record),
    );
    if (values == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.enqueue(
        table,
        table == 'Receipts'
            ? 'receive'
            : record == null
            ? 'create'
            : 'update',
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

  Future<void> _postCash(Map<String, dynamic> record) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post to ledger?'),
        content: const Text(
          'This records the entry and any payment in the ledger. The entry will be locked. '
          'Only unpaid entries can be reversed. Paid entries cannot be refunded here yet. '
          'Check the amount, tax, dates and Cash or Bank account before continuing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Post to ledger'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.enqueue(
        table,
        'post',
        {},
        recordId: record['recordId'] as String,
        expectedVersion: int.parse('${record['recordVersion']}'),
      );
      await widget.writes!.flush();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to confirm posting. Retry the pending request.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _issueInvoice(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Issue invoice?'),
        content: const Text(
          'The server will assign the invoice number and post receivable, revenue and VAT. The invoice and its lines cannot be edited afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Issue invoice'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.enqueue(
        'Invoices',
        'issue',
        {},
        recordId: record['recordId'] as String,
        expectedVersion: int.parse('${record['recordVersion']}'),
      );
      await widget.writes!.flush();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to confirm issuing. Retry the pending request.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _voidInvoice(Map<String, dynamic> record) async {
    final input = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const CashReversalEditor(
        title: 'Void invoice',
        explanation:
            'The issued invoice stays in the audit history. An opposite journal will cancel its receivable, revenue and VAT. Reverse every receipt first.',
        actionLabel: 'Void invoice',
      ),
    );
    if (input == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.enqueue(
        'Invoices',
        'invoiceVoid',
        {'voidDate': input['date'], 'voidReason': input['description']},
        recordId: record['recordId'] as String,
        expectedVersion: int.parse('${record['recordVersion']}'),
      );
      await widget.writes!.flush();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Unable to confirm invoice void. Retry the pending request.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _quotationAction(
    Map<String, dynamic> record,
    String action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          action == 'send'
              ? 'Finalize quotation?'
              : 'Convert to draft invoice?',
        ),
        content: Text(
          action == 'send'
              ? 'The server will assign the quotation number and lock its contents.'
              : 'A new draft invoice with the same customer, totals and lines will be created.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              action == 'send' ? 'Finalize quotation' : 'Create draft invoice',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.enqueue(
        'Quotations',
        action,
        {},
        recordId: record['recordId'] as String,
        expectedVersion: int.parse('${record['recordVersion']}'),
      );
      await widget.writes!.flush();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Unable to confirm quotation action. Retry the pending request.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _payrollAction(
    Map<String, dynamic> record,
    String action,
  ) async {
    Map<String, Object?> values = {};
    if (action == 'payrollPay') {
      final result = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => PayrollPaymentEditor(amount: record['netSalary']),
      );
      if (result == null || !mounted) return;
      values = result;
    } else if (action == 'payrollReverse') {
      final result = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => const CashReversalEditor(
          title: 'Reverse payroll',
          explanation:
              'The payroll and its journals stay in the audit history. If it was paid, the server also posts the Cash or Bank refund.',
          actionLabel: 'Reverse payroll',
        ),
      );
      if (result == null || !mounted) return;
      values = {
        'reversalDate': result['date'],
        'reversalReason': result['description'],
      };
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Approve payroll?'),
          content: const Text(
            'The server will verify salary totals and post salary expense and liabilities. The payroll cannot be edited afterward.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve payroll'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.enqueue(
        'Payroll',
        action,
        values,
        recordId: record['recordId'] as String,
        expectedVersion: int.parse('${record['recordVersion']}'),
      );
      await widget.writes!.flush();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Unable to confirm payroll action. Retry the pending request.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _assetAction(Map<String, dynamic> record, String action) async {
    Map<String, Object?> values = {};
    if (action == 'depreciate') {
      final result = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => const AssetDepreciationEditor(),
      );
      if (result == null || !mounted) return;
      values = result;
    } else if (action == 'assetDispose') {
      final result = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => AssetDisposalEditor(bookValue: record['netBookValue']),
      );
      if (result == null || !mounted) return;
      values = result;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Capitalize asset?'),
          content: const Text(
            'The server will post the acquisition to Fixed Assets and the selected Cash or Bank account. The financial details will then be locked.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Capitalize asset'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.enqueue(
        'Assets',
        action,
        values,
        recordId: record['recordId'] as String,
        expectedVersion: int.parse('${record['recordVersion']}'),
      );
      await widget.writes!.flush();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Unable to confirm asset action. Retry the pending request.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _postCapital(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post capital contribution?'),
        content: const Text(
          'The server will debit the selected Cash or Bank account and credit Shareholder Equity. The contribution cannot be edited afterward.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Post contribution'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.enqueue(
        'CapitalTransactions',
        'capitalPost',
        {},
        recordId: record['recordId'] as String,
        expectedVersion: int.parse('${record['recordVersion']}'),
      );
      await widget.writes!.flush();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Unable to confirm capital posting. Retry the pending request.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _loanAction(Map<String, dynamic> record, String action) async {
    Map<String, Object?> values = {};
    if (action == 'loanRepay') {
      final result = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => ShareholderLoanRepaymentEditor(
          amount: record['outstandingBalance'],
        ),
      );
      if (result == null || !mounted) return;
      values = result;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Post shareholder loan?'),
          content: const Text(
            'The server will debit Cash or Bank and credit Shareholder Loan liability. The loan details will then be locked.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Post loan'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.enqueue(
        'ShareholderLoans',
        action,
        values,
        recordId: record['recordId'] as String,
        expectedVersion: int.parse('${record['recordVersion']}'),
      );
      await widget.writes!.flush();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Unable to confirm shareholder loan action. Retry the pending request.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _reverseReceipt(Map<String, dynamic> record) async {
    final input = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => const CashReversalEditor(),
    );
    if (input == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.enqueue(
        'Receipts',
        'receiptReverse',
        {'reversalDate': input['date'], 'reversalReason': input['description']},
        recordId: record['recordId'] as String,
        expectedVersion: int.parse('${record['recordVersion']}'),
      );
      await widget.writes!.flush();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Unable to confirm receipt reversal. Retry the pending request.',
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

  Future<void> _payCash(
    Map<String, dynamic> record, {
    bool reverse = false,
  }) async {
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => reverse
          ? const CashReversalEditor()
          : CashPaymentEditor(total: record['total']),
    );
    if (values == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.writes!.enqueue(
        table,
        reverse ? 'reverse' : 'pay',
        values,
        recordId: record['recordId'] as String,
        expectedVersion: int.parse('${record['recordVersion']}'),
      );
      await widget.writes!.flush();
      if (mounted) await _load();
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Unable to confirm payment. Retry the pending request.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.api.cache.addListener(_cacheChanged);
    _watch();
    _load();
  }

  void _watch() {
    if (_watchedPath != null) widget.api.cache.deactivate(_watchedPath!);
    _watchedPath = widget.active ? _path : null;
    if (_watchedPath != null) widget.api.cache.activate(_watchedPath!);
  }

  @override
  void didUpdateWidget(covariant _RecordsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _watch();
      if (widget.active) _load();
    }
  }

  void _cacheChanged() {
    scheduleMicrotask(() {
      if (!mounted) return;
      final state = widget.api.cache.state(_path);
      final data = state?.data;
      if (data != null) {
        final fresh = (data['records'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        final changed =
            dataFingerprint({'records': fresh}) !=
            dataFingerprint({'records': rows});
        setState(() {
          if (changed) rows = fresh;
          _hasData = true;
          _savedData = state!.offline;
          error = state.error is SaasApiException
              ? (state.error as SaasApiException).message
              : state.error == null
              ? null
              : 'Refresh failed. Showing saved data.';
        });
      } else if (widget.api.cache.scope == null && _hasData) {
        setState(() {
          rows = [];
          _hasData = false;
        });
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _request++;
    widget.api.cache.removeListener(_cacheChanged);
    if (_watchedPath != null) widget.api.cache.deactivate(_watchedPath!);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final requestedTable = table, request = ++_request;
    final cached = widget.api.cache.state(_path)?.data;
    setState(() {
      _loading = cached == null && !_hasData;
      if (cached != null) {
        rows = (cached['records'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _hasData = true;
      }
      error = null;
    });
    try {
      final result = await widget.api.records(
        widget.companyId,
        requestedTable,
        employee: widget.employee,
        force: force,
      );
      if (!mounted || request != _request) return;
      setState(() {
        rows = (result['records'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        _hasData = true;
        _savedData = widget.api.cache.state(_path)?.offline ?? false;
      });
    } on SaasApiException catch (e) {
      if (mounted && request == _request) {
        setState(() {
          if (e.status == 401 || e.status == 403) {
            rows = [];
            _hasData = false;
          }
          error = e.message;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          error = 'Unable to load records. Retry when connected.';
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
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
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButton<String>(
                isExpanded: true,
                value: table,
                items: [
                  for (final t in widget.tables)
                    DropdownMenuItem(
                      value: t,
                      child: Text(tableTitles[t] ?? t),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        _tableSearch[table] = _search;
                        rows = [];
                        _hasData = false;
                        table = v!;
                        _search = _tableSearch[table] ?? '';
                        _searchController.text = _search;
                        _watch();
                        _load();
                      },
              ),
            ),
            TextButton.icon(
              onPressed: busy ? null : () => _load(force: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            if (_editable && table != 'CompanyProfile')
              FilledButton(
                onPressed: busy || widget.writes!.pending.isNotEmpty
                    ? null
                    : () => _editCustomer(),
                child: Text('Add $_recordLabel'),
              ),
            if (widget.writes?.pending.isNotEmpty == true)
              OutlinedButton(
                onPressed: busy ? null : _retryWrite,
                child: const Text('Retry pending change'),
              ),
            if (widget.writes?.canDiscardRejected == true)
              TextButton(
                onPressed: busy ? null : _discardRejected,
                child: const Text('Discard rejected edit'),
              ),
          ],
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text(
          _savedData
              ? 'Saved data - syncing when connected'
              : _editable
              ? 'Company records'
              : widget.employee
              ? 'Online records - read access assigned by admin'
              : 'Company records',
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Search records',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _search = value),
        ),
      ),
      if (rows.any(
        (row) => row['status'] != null || row['paymentStatus'] != null,
      ))
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: const Text('All statuses'),
                    onPressed: () => setState(() => _statusFilters[table] = {}),
                  ),
                ),
                for (final status
                    in rows
                        .map(
                          (row) =>
                              '${row['status'] ?? row['paymentStatus'] ?? ''}',
                        )
                        .where((value) => value.isNotEmpty)
                        .toSet())
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(status.toLowerCase().replaceAll('_', ' ')),
                      selected:
                          _statusFilters[table]?.contains(status) ?? false,
                      onSelected: (selected) => setState(() {
                        final values = _statusFilters.putIfAbsent(
                          table,
                          () => {},
                        );
                        selected ? values.add(status) : values.remove(status);
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
      if (!busy && error == null && rows.isNotEmpty && _visibleRows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('No records match your search.'),
        ),
      if (busy || _loading || widget.api.cache.state(_path)?.refreshing == true)
        const LinearProgressIndicator(),
      if (widget.api.cache.state(_path)?.refreshing == true && _hasData)
        const Text('Updating...'),
      if (_savedData) const Text('Offline - showing saved data.'),
      if (error != null)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Semantics(liveRegion: true, child: Text(error!)),
        ),
      if (!busy && !_loading && error == null && _hasData && rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('No records yet.'),
        ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _load(force: true),
          child: ListView.builder(
            key: PageStorageKey((widget.companyId, table)),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: _visibleRows.length,
            itemBuilder: (context, index) {
              final row = _visibleRows[index];
              return RecordCard(
                key: PageStorageKey((table, row['recordId'] ?? index)),
                title: Text(
                  _title(row),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.surface,
                collapsedBackgroundColor: Theme.of(context).colorScheme.surface,
                subtitle: RecordSummary(record: row),
                children: [
                  if (table == 'CompanyProfile' &&
                      '${row['logoDocumentId'] ?? ''}'.isNotEmpty)
                    PrivateCompanyLogo(
                      key: ValueKey((
                        widget.companyId,
                        row['logoDocumentId'],
                        row['recordVersion'],
                      )),
                      api: widget.api,
                      companyId: widget.companyId,
                      documentId: row['logoDocumentId'],
                      employee: widget.employee,
                    ),
                  if (documentSections.contains(table) &&
                      row['recordId'] != null)
                    TextButton.icon(
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        table == 'CompanyProfile' ? 'Manage logo' : 'Documents',
                      ),
                      onPressed: busy
                          ? null
                          : () async {
                              await showDialog<void>(
                                context: context,
                                builder: (_) => RecordDocumentsView(
                                  api: widget.api,
                                  companyId: widget.companyId,
                                  section: table,
                                  record: row,
                                  employee: widget.employee,
                                  uploads: widget.uploads,
                                  writes: widget.writes,
                                ),
                              );
                              if (mounted) await _load();
                            },
                    ),
                  if (_editable &&
                      table == 'Invoices' &&
                      row['status'] == 'DRAFT')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _issueInvoice(row),
                      child: const Text('Issue invoice'),
                    ),
                  if (_editable &&
                      table == 'Invoices' &&
                      row['status'] == 'ISSUED' &&
                      num.tryParse('${row['paidAmount']}') == 0)
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _voidInvoice(row),
                      child: const Text('Void invoice'),
                    ),
                  if (_editable &&
                      table == 'Quotations' &&
                      row['status'] == 'DRAFT')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _quotationAction(row, 'send'),
                      child: const Text('Finalize quotation'),
                    ),
                  if (_editable &&
                      table == 'Quotations' &&
                      row['status'] == 'SENT')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _quotationAction(row, 'convert'),
                      child: const Text('Create draft invoice'),
                    ),
                  if (_editable &&
                      table == 'Payroll' &&
                      row['status'] == 'DRAFT')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _payrollAction(row, 'approve'),
                      child: const Text('Approve payroll'),
                    ),
                  if (_editable &&
                      table == 'Payroll' &&
                      row['status'] == 'APPROVED')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _payrollAction(row, 'payrollPay'),
                      child: const Text('Pay payroll'),
                    ),
                  if (_editable &&
                      table == 'Payroll' &&
                      const ['APPROVED', 'PAID'].contains(row['status']))
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _payrollAction(row, 'payrollReverse'),
                      child: Text(
                        row['status'] == 'PAID'
                            ? 'Refund and reverse payroll'
                            : 'Reverse payroll',
                      ),
                    ),
                  if (_editable &&
                      table == 'Assets' &&
                      row['status'] == 'DRAFT')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _assetAction(row, 'capitalize'),
                      child: const Text('Capitalize asset'),
                    ),
                  if (_editable &&
                      table == 'Assets' &&
                      row['status'] == 'ACTIVE')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _assetAction(row, 'depreciate'),
                      child: const Text('Post monthly depreciation'),
                    ),
                  if (_editable &&
                      table == 'Assets' &&
                      row['status'] == 'ACTIVE')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _assetAction(row, 'assetDispose'),
                      child: const Text('Dispose asset'),
                    ),
                  if (_editable &&
                      table == 'CapitalTransactions' &&
                      row['status'] == 'DRAFT')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _postCapital(row),
                      child: const Text('Post contribution'),
                    ),
                  if (_editable &&
                      table == 'ShareholderLoans' &&
                      row['status'] == 'DRAFT')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _loanAction(row, 'loanPost'),
                      child: const Text('Post loan'),
                    ),
                  if (_editable &&
                      table == 'ShareholderLoans' &&
                      row['status'] == 'ACTIVE')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _loanAction(row, 'loanRepay'),
                      child: const Text('Repay loan in full'),
                    ),
                  if (_editable &&
                      table == 'Receipts' &&
                      row['status'] == 'POSTED')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _reverseReceipt(row),
                      child: const Text('Reverse receipt'),
                    ),
                  if (_editable &&
                      const ['Income', 'Expenses'].contains(table) &&
                      row['ledgerStatus'] == 'LINKED' &&
                      const ['UNPAID', 'PAID'].contains(row['paymentStatus']))
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _payCash(row, reverse: true),
                      child: Text(
                        row['paymentStatus'] == 'PAID'
                            ? 'Refund and reverse entry'
                            : 'Reverse entry',
                      ),
                    ),
                  if (_editable &&
                      const ['Income', 'Expenses'].contains(table) &&
                      row['ledgerStatus'] == 'LINKED' &&
                      row['paymentStatus'] == 'UNPAID')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _payCash(row),
                      child: const Text('Record payment'),
                    ),
                  if (_editable &&
                      const ['Income', 'Expenses'].contains(table) &&
                      row['ledgerStatus'] == 'UNPOSTED')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _postCash(row),
                      child: const Text('Post to ledger'),
                    ),
                  if (_editable &&
                      !const [
                        'LINKED',
                        'REVERSED',
                      ].contains(row['ledgerStatus']) &&
                      (table != 'FinancialPeriods' ||
                          row['status'] == 'OPEN') &&
                      (table != 'Invoices' || row['status'] == 'DRAFT') &&
                      (table != 'InvoiceItems' ||
                          row['parentStatus'] == 'DRAFT') &&
                      (table != 'Quotations' || row['status'] == 'DRAFT') &&
                      (table != 'QuotationItems' ||
                          row['parentStatus'] == 'DRAFT') &&
                      (table != 'Payroll' || row['status'] == 'DRAFT') &&
                      (table != 'Assets' || row['status'] == 'DRAFT') &&
                      (table != 'CapitalTransactions' ||
                          row['status'] == 'DRAFT') &&
                      (table != 'ShareholderLoans' ||
                          row['status'] == 'DRAFT') &&
                      table != 'Receipts')
                    TextButton(
                      onPressed: busy || widget.writes!.pending.isNotEmpty
                          ? null
                          : () => _editCustomer(row),
                      child: Text('Edit $_recordLabel'),
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
      ),
    ],
  );
}
