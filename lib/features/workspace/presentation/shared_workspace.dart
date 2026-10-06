import 'package:tpc_invoice/core/widgets/forms/validated_text_field.dart';
import 'package:tpc_invoice/features/tasks/presentation/task_workspace.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'dart:async';
import 'dart:convert';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:tpc_invoice/core/cache/read_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tpc_invoice/core/widgets/appearance_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/features/employees/presentation/cubit/employee_admin_controller.dart';
import 'package:tpc_invoice/features/employees/presentation/employee_admin_view.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/accounting/data/record_write_queue.dart';
import 'package:tpc_invoice/features/customers/presentation/customer_editor.dart';
import 'package:tpc_invoice/features/accounting/presentation/cash_entry_editor.dart';
import 'package:tpc_invoice/features/accounting/presentation/cash_payment_editor.dart';
import 'package:tpc_invoice/features/accounting/presentation/cash_reversal_editor.dart';
import 'package:tpc_invoice/features/accounting/presentation/financial_period_editor.dart';
import 'package:tpc_invoice/features/reports/presentation/trial_balance_view.dart';
import 'package:tpc_invoice/features/reports/presentation/report_configuration_view.dart';
import 'package:tpc_invoice/features/documents/presentation/invoice_editor.dart';
import 'package:tpc_invoice/features/documents/presentation/invoice_return_editor.dart';
import 'package:tpc_invoice/features/accounting/presentation/receipt_editor.dart';
import 'package:tpc_invoice/features/documents/presentation/quotation_editor.dart';
import 'package:tpc_invoice/features/employees/presentation/payroll_editor.dart';
import 'package:tpc_invoice/features/accounting/presentation/asset_editor.dart';
import 'package:tpc_invoice/features/accounting/presentation/capital_editor.dart';
import 'package:tpc_invoice/features/workspace/presentation/company_profile_editor.dart';
import 'package:tpc_invoice/features/documents/data/document_upload_queue.dart';
import 'package:tpc_invoice/features/documents/presentation/record_documents_view.dart';
import 'package:tpc_invoice/features/workspace/presentation/system_settings_panel.dart';
import 'package:tpc_invoice/features/workspace/presentation/workspace_help.dart';

const workspaceTables = <String, List<String>>{
  'Tasks': <String>[],
  'Calendar': <String>[],
  'Invoices': ['Invoices', 'CreditNotes', 'Receipts', 'ReceiptAllocations'],
  'Quotations': ['Quotations'],
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
  'CreditNotes': 'Credit notes / returns',
  'ReceiptAllocations': 'Payment allocations',
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
  final Map<String, String> _subsections = {};
  Map<String, String> _children(String section) => section == 'Reports'
      ? const {
          'dashboard': 'Dashboard',
          'chart-of-accounts': 'Chart of Accounts',
          'journal-entries': 'Journal Entries',
          'general-ledger': 'General ledger',
          'trial-balance': 'Trial balance',
          'profit-and-loss': 'Profit and loss',
          'balance-sheet': 'Balance sheet',
          'report-settings': 'Report Settings',
        }
      : {
          for (final table in workspaceTables[section] ?? <String>[])
            table: tableTitles[table] ?? table,
        };
  String _subsection(String section) =>
      _subsections[section] ?? _children(section).keys.first;
  void _navigate(String section, String child) => setState(() {
        _selected = section;
        _subsections[section] = child;
      });
  String _destinationTitle(String section) => _children(section).isEmpty
      ? section
      : _children(section)[_subsection(section)]!;
  final Set<String> _visited = {};
  @override
  void initState() {
    super.initState();
    widget.api.useVerifiedWorkspace(
      widget.companyId,
      ownerId: widget.ownerId,
      employee: widget.employee,
    );
    _writes?.initialize().catchError((Object error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              'Device storage is unavailable. Changes have not been saved: $error',
            ),
          ),
        );
      }
    });
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
        if (allowed == null ||
            (section == 'Calendar'
                ? allowed.contains('Tasks')
                : allowed.contains(section)))
          section,
    ];
    final selected =
        sections.contains(_selected) ? _selected : sections.firstOrNull;
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
        title: wide
            ? SizedBox(
                width: 420,
                child: Autocomplete<String>(
                  optionsBuilder: (value) => value.text.trim().isEmpty
                      ? const Iterable<String>.empty()
                      : sections.where(
                          (s) => s.toLowerCase().contains(
                                value.text.toLowerCase(),
                              ),
                        ),
                  onSelected: (value) => setState(() => _selected = value),
                  fieldViewBuilder: (context, controller, focus, submit) =>
                      TextField(
                    inputFormatters: [
                      AppInputFormatters.text,
                      AppInputFormatters.search
                    ],
                    controller: controller,
                    focusNode: focus,
                    decoration: const InputDecoration(
                      hintText: 'Search workspace sections...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
              )
            : Text(
                wide
                    ? widget.title
                    : selected == 'Reports'
                        ? 'Home'
                        : selected ?? 'Workspace',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          IconButton(
            tooltip: 'How to use / FAQ',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const WorkspaceHelp()),
            ),
          ),
          const AppearanceSelector(),
          if (wide) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              child: Icon(
                widget.employee == null
                    ? Icons.person_outline
                    : Icons.badge_outlined,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.employee == null ? 'Admin' : 'Employee'),
          ],
          const SizedBox(width: 20),
        ],
        leading: IconButton(
          onPressed: widget.onBack,
          tooltip: 'Back to account',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      bottomNavigationBar: wide ||
              (sections.length < 2 &&
                  !sections.any((section) => _children(section).length > 1))
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
                          trailing: LoadingButton.text(
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
                        selected == 'Reports' ? 8 : (wide ? 20 : 12),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected == 'Reports'
                                  ? (_subsection('Reports') == 'dashboard'
                                      ? 'Business overview'
                                      : _destinationTitle('Reports'))
                                  : selected ?? 'Workspace',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (wide) const SizedBox(height: 6),
                            if (wide)
                              Text(
                                '${widget.title}  /  ${selected == null ? 'Workspace' : _destinationTitle(selected)}',
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
      : ['Tasks', 'Calendar'].contains(selected)
          ? TaskWorkspace(
              api: widget.api,
              companyId: widget.companyId,
              employee: widget.employee,
              calendar: selected == 'Calendar',
              active: active,
              uploads: _uploads,
              writes: _writes,
            )
          : selected == 'Reports'
              ? [
                  'chart-of-accounts',
                  'report-settings',
                ].contains(_subsection('Reports'))
                  ? ReportConfigurationView(
                      key: ValueKey((widget.companyId, _subsection('Reports'))),
                      api: widget.api,
                      companyId: widget.companyId,
                      employee: widget.employee != null,
                      chart: _subsection('Reports') == 'chart-of-accounts',
                    )
                  : _subsection('Reports') == 'journal-entries'
                      ? _RecordsPanel(
                          key: ValueKey((widget.companyId, 'report-journals')),
                          api: widget.api,
                          companyId: widget.companyId,
                          employee: widget.employee != null,
                          active: active,
                          tables: const ['Journals', 'JournalLines'],
                          selectedTable: 'Journals',
                          writes: widget.employee == null ||
                                  (widget.employee!['writableSections']
                                              as List? ??
                                          [])
                                      .contains('Balance Sheet')
                              ? _writes
                              : null,
                          uploads: _uploads,
                        )
                      : TrialBalanceView(
                          key: ValueKey(widget.companyId),
                          api: widget.api,
                          companyId: widget.companyId,
                          employee: widget.employee != null,
                          initialDashboard: true,
                          reportKind: _subsection('Reports'),
                          active: active,
                          companyName: widget.title,
                          onReportSelected: (kind) =>
                              _navigate('Reports', kind),
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
                      writes: widget.employee == null ||
                              (widget.employee!['writableSections'] as List? ??
                                      [])
                                  .contains(selected)
                          ? _writes
                          : null,
                      uploads: _uploads,
                      selectedTable: _children(selected).isEmpty
                          ? 'Employees'
                          : _subsection(selected),
                      tables: selected == 'Employees'
                          ? ['Employees']
                          : workspaceTables[selected]!,
                    );

  IconData _sectionIcon(String section) => switch (section) {
        'Tasks' => Icons.task_alt,
        'Calendar' => Icons.calendar_month_outlined,
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
                for (final section in group.value.where(sections.contains)) ...[
                  if (_children(section).length > 1)
                    ExpansionTile(
                      key: PageStorageKey(('workspace-section', section)),
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                      leading: Icon(_sectionIcon(section)),
                      title: Text(section),
                      initiallyExpanded: false,
                      children: [
                        for (final child in _children(section).entries)
                          ListTile(
                            contentPadding: const EdgeInsets.only(
                              left: 48,
                              right: 16,
                            ),
                            title: Text(child.value),
                            selected: section == selected &&
                                _subsection(section) == child.key,
                            onTap: () => Navigator.pop(
                              context,
                              '$section::${child.key}',
                            ),
                          ),
                      ],
                    )
                  else
                    ListTile(
                      leading: Icon(_sectionIcon(section)),
                      title: Text(section),
                      selected: section == selected,
                      trailing:
                          section == selected ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(context, section),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
    if (mounted && choice != null) {
      final parts = choice.split('::');
      if (parts.length == 2) {
        _navigate(parts[0], parts[1]);
      } else {
        setState(() => _selected = choice);
      }
    }
  }

  Widget _navigation(List<String> sections, String? selected) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    const icons = <String, IconData>{
      'Tasks': Icons.task_alt,
      'Calendar': Icons.calendar_month_outlined,
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
    return Material(
      color: colors.surface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            child: Row(
              children: [
                Icon(Icons.auto_graph, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'TPC Accounts',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          for (final group in const <String, List<String>>{
            'Overview': ['Reports'],
            'DAILY OPERATIONS': [
              'Tasks',
              'Calendar',
              'Invoices',
              'Quotations',
              'Customers',
              'Employees',
              'Payroll',
              'Office & Attendance',
            ],
            'ACCOUNTING': [
              'Income & Expenses',
              'Fixed Assets',
              'Capital & Equity',
              'Balance Sheet',
            ],
            'SYSTEM': ['Settings'],
          }.entries) ...[
            if (group.key != 'Overview' && group.value.any(sections.contains))
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                child: Text(
                  group.key,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            for (final section in group.value.where(sections.contains)) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  selected: selected == section,
                  selectedTileColor:
                      dark ? const Color(0xFF333333) : colors.primaryContainer,
                  selectedColor: dark ? colors.onSurface : colors.primary,
                  textColor: colors.onSurfaceVariant,
                  iconColor: colors.onSurfaceVariant,
                  leading: Icon(icons[section], size: 21),
                  title: Text(
                    section == 'Reports' ? 'Overview' : section,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => setState(() => _selected = section),
                ),
              ),
              if (selected == section && _children(section).length > 1)
                for (final child in _children(section).entries)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 4),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      title: Text(
                        child.value,
                        style: const TextStyle(fontSize: 13),
                      ),
                      selected: _subsection(section) == child.key,
                      selectedTileColor: colors.surfaceContainerHighest,
                      leading: Icon(Icons.subdirectory_arrow_right, size: 16),
                      onTap: () => _navigate(section, child.key),
                    ),
                  ),
            ],
          ],
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
    this.selectedTable,
  });
  final bool active;
  final String? selectedTable;
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
  late String table = widget.selectedTable ?? widget.tables.first;
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
  ButtonStyle get _destructiveActionStyle => ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.error,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: Theme.of(context).colorScheme.error.withValues(alpha: .5),
          ),
        ),
      );
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
          LoadingButton.text(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep edit'),
          ),
          LoadingButton(
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

  Future<void> _exportPending() async {
    final text =
        const JsonEncoder.withIndent('  ').convert(widget.writes!.pending);
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Pending changes on this device'),
              content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(child: SelectableText(text))),
              actions: [
                TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Copy JSON')),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
  }

  Future<void> _reviewRejected() async {
    final box = widget.writes?.outbox;
    final op = box?.pending
        .where((op) => op['state'] == 'failed' && op['local'] == true)
        .firstOrNull;
    if (box == null || op == null) return;
    final entity = op['table'] as String;
    try {
      final user = jsonDecode(box.scope)[2] as String;
      await widget.api.verifySyncIdentity(
        user,
        widget.companyId,
        employee: widget.employee,
      );
      await widget.api.records(
        widget.companyId,
        entity,
        employee: widget.employee,
        force: true,
      );
      final path = widget.api.recordsPath(
        widget.companyId,
        entity,
        employee: widget.employee,
      );
      final state = widget.api.cache.state(path);
      if (state?.error != null) throw state!.error!;
      final server = (state?.data?['records'] as List? ?? [])
          .where((r) => r['recordId'] == op['recordId'])
          .firstOrNull;
      if (server == null && op['action'] != 'create') {
        throw const SaasApiException(
          'VERSION_CONFLICT',
          'The server record was deleted. Export or discard this rejected edit.',
        );
      }
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Review rejected change'),
          content: SingleChildScrollView(
            child: Text(
              '${op['error']}\n\nYour saved values:\n${const JsonEncoder.withIndent('  ').convert(op['values'])}\n\nLatest server values:\n${const JsonEncoder.withIndent('  ').convert(server)}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep saved change'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Edit and resubmit'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      final saved = Map<String, dynamic>.from(
        box.data['records']['$entity:${op['localId']}'] as Map,
      );
      final version = server?['recordVersion'] as int? ?? 0;
      Future<void> correct(Map<String, Object?> values) => box.correctRejected(
            op['operationId'] as String,
            values,
            expectedVersion: version,
          );
      if (op['action'] == 'delete') {
        await correct({});
      } else if (entity == 'Customers') {
        final values = await showDialog<Map<String, Object?>>(
          context: context,
          builder: (_) => CustomerEditor(record: saved),
        );
        if (values != null) await correct(values);
      } else if (const ['Invoices', 'Quotations'].contains(entity)) {
        final references = await Future.wait([
          widget.api.editorReferences(
            widget.companyId,
            'Customers',
            entity,
            employee: widget.employee,
          ),
          widget.api.editorReferences(
            widget.companyId,
            'CompanyProfile',
            entity,
            employee: widget.employee,
          ),
        ]);
        final customers = (references[0]['records'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        final company = (references[1]['records'] as List).firstOrNull as Map?;
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => entity == 'Invoices'
              ? InvoiceEditor(
                  customers: customers,
                  company: Map<String, dynamic>.from(company ?? {}),
                  record: saved,
                  items: (saved['items'] as List? ?? [])
                      .map((r) => Map<String, dynamic>.from(r as Map))
                      .toList(),
                  onSave: correct,
                )
              : QuotationEditor(
                  customers: customers,
                  company: Map<String, dynamic>.from(company ?? {}),
                  record: saved,
                  items: (saved['items'] as List? ?? [])
                      .map((r) => Map<String, dynamic>.from(r as Map))
                      .toList(),
                  onSave: correct,
                ),
        );
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => error =
              failure is SaasApiException ? failure.message : '$failure',
        );
      }
    }
  }

  Future<void> _deleteLocalRecord(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $_recordLabel?'),
        content: const Text(
          'The deletion is saved on this device and remains pending until the server confirms it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.writes!.enqueue(
        table,
        'delete',
        {},
        recordId: record['recordId'] as String,
        expectedVersion: record['recordVersion'] as int? ?? 0,
      );
      if (mounted) await _load();
    } catch (failure) {
      if (mounted) {
        setState(
          () => error =
              failure is SaasApiException ? failure.message : '$failure',
        );
      }
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
        'Receipts',
        'Quotations',
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
                  : table == 'Receipts'
                      ? 'receipt'
                      : table == 'Quotations'
                          ? 'draft quotation'
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
      if (mounted) {
        setState(() => error = e.message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        const message = 'Could not open the editor. Please retry.';
        setState(() => error = message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openRecordEditor(Map<String, dynamic>? record) async {
    Map<String, Object?>? submittedDraft;
    Future<void> saveDocument(Map<String, Object?> draft) async {
      if (widget.writes!.supportsLocal(
        table,
        record == null ? 'create' : 'update',
        record,
      )) {
        await widget.writes!.enqueue(
          table,
          record == null ? 'create' : 'update',
          draft,
          recordId: record?['recordId'] as String?,
          expectedVersion:
              record == null ? 0 : int.parse('${record['recordVersion']}'),
        );
        return;
      }
      if (widget.writes!.canDiscardRejected) {
        await widget.writes!.discardRejected();
      }
      if (submittedDraft != null &&
          widget.writes!.pending.isNotEmpty &&
          dataFingerprint(Map<String, dynamic>.from(submittedDraft!)) !=
              dataFingerprint(Map<String, dynamic>.from(draft))) {
        throw const SaasApiException(
          'PENDING',
          'The previous save is still pending. Restore those values and retry before changing this draft.',
        );
      }
      if (widget.writes!.pending.isEmpty) {
        submittedDraft = draft;
        await widget.writes!.enqueue(
          table,
          record == null ? 'create' : 'update',
          draft,
          recordId: record?['recordId'] as String?,
          expectedVersion:
              record == null ? 0 : int.parse('${record['recordVersion']}'),
        );
      }
      await widget.writes!.flush();
    }

    List<Map<String, dynamic>> choices = const [];
    List<Map<String, dynamic>> documentItems = const [];
    Map<String, dynamic> documentCompany = const {};
    if (const ['Invoices', 'Quotations'].contains(table)) {
      final itemTable = table == 'Invoices' ? 'InvoiceItems' : 'QuotationItems';
      final parentKey = table == 'Invoices' ? 'invoiceId' : 'quotationId';
      final references = await Future.wait([
        widget.api.editorReferences(
          widget.companyId,
          'Customers',
          table,
          employee: widget.employee,
        ),
        widget.api.editorReferences(
          widget.companyId,
          'CompanyProfile',
          table,
          employee: widget.employee,
        ),
        if (record != null && record['items'] is! List)
          widget.api.records(
            widget.companyId,
            itemTable,
            employee: widget.employee,
            force: !widget.writes!.supportsLocal(table, 'update', record),
          ),
      ]);
      if (!mounted) return;
      choices = (references.first['records'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      if (record != null) {
        if (record['items'] is List) {
          documentItems = (record['items'] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
        } else {
          final response = references.last;
          documentItems = (response['records'] as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .where((row) => row[parentKey] == record['recordId'])
              .toList()
            ..sort(
              (a, b) => (num.tryParse('${a['lineNumber']}') ?? 0).compareTo(
                num.tryParse('${b['lineNumber']}') ?? 0,
              ),
            );
        }
      }
      {
        // Only public company fields are exposed to authorized employee editors.
        final response = references[1];
        documentCompany = (response['records'] as List).isEmpty
            ? {}
            : Map<String, dynamic>.from(
                (response['records'] as List).first as Map,
              );
      }
      if (!mounted) return;
    }
    if (table == 'Payroll') {
      final response = widget.employee
          ? await widget.api.editorReferences(
              widget.companyId,
              'Employees',
              'Payroll',
              employee: true,
            )
          : await widget.api.employees(widget.companyId);
      choices = (response[widget.employee ? 'records' : 'employees'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => item['employmentStatus'] == 'ACTIVE')
          .toList();
      if (!mounted) return;
    }
    if (const ['CapitalTransactions', 'ShareholderLoans'].contains(table)) {
      final response = await widget.api.editorReferences(
        widget.companyId,
        'Shareholders',
        'Capital & Equity',
        employee: widget.employee,
      );
      choices = (response['records'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => item['status'] == 'ACTIVE')
          .toList();
      if (!mounted) return;
    }
    if (table == 'Receipts') {
      final response = await widget.api.records(
        widget.companyId,
        'Invoices',
        employee: widget.employee,
      );
      choices = (response['records'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where(
            (item) =>
                const ['Invoices', 'Quotations'].contains(table) ||
                (table == 'Receipts' &&
                    const [
                      'ISSUED',
                      'PARTIALLY_PAID',
                      'PARTIALLY_RETURNED',
                    ].contains(item['status']) &&
                    (num.tryParse('${item['balance']}') ?? 0) > 0),
          )
          .toList();
      if (!mounted) return;
    }
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      barrierDismissible: !const ['Invoices', 'Quotations'].contains(table),
      builder: (_) => table == 'CompanyProfile'
          ? CompanyProfileEditor(record: record!)
          : table == 'Invoices'
              ? InvoiceEditor(
                  onSave: saveDocument,
                  customers: choices,
                  record: record,
                  items: documentItems,
                  company: documentCompany,
                )
              : table == 'Receipts'
                  ? ReceiptEditor(invoices: choices)
                  : table == 'Quotations'
                      ? QuotationEditor(
                          onSave: saveDocument,
                          customers: choices,
                          record: record,
                          items: documentItems,
                          company: documentCompany,
                        )
                      : table == 'Payroll'
                          ? PayrollEditor(
                              employees: choices,
                              record: record,
                              preview: (values) => widget.api.payrollPreview(
                                widget.companyId,
                                values,
                                employee: widget.employee,
                              ),
                            )
                          : table == 'Assets'
                              ? AssetEditor(record: record)
                              : table == 'Shareholders'
                                  ? ShareholderEditor(record: record)
                                  : table == 'CapitalTransactions'
                                      ? CapitalContributionEditor(
                                          shareholders: choices, record: record)
                                      : table == 'ShareholderLoans'
                                          ? ShareholderLoanEditor(
                                              shareholders: choices,
                                              record: record)
                                          : table == 'Customers'
                                              ? CustomerEditor(record: record)
                                              : table == 'FinancialPeriods'
                                                  ? FinancialPeriodEditor(
                                                      record: record)
                                                  : CashEntryEditor(
                                                      expense:
                                                          table == 'Expenses',
                                                      record: record),
    );
    if (values == null || !mounted) return;
    if (const ['Invoices', 'Quotations'].contains(table)) {
      await _load(force: widget.writes!.outbox == null);
      return;
    }
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
        expectedVersion:
            record == null ? 0 : int.parse('${record['recordVersion']}'),
      );
      if (!widget.writes!.supportsLocal(
        table,
        record == null ? 'create' : 'update',
        record,
      )) {
        await widget.writes!.flush();
      }
      if (mounted) await _load(force: widget.writes!.outbox == null);
    } on SaasApiException catch (e) {
      if (mounted) {
        final rejectedDraft = record == null &&
            const ['Invoices', 'Quotations'].contains(table) &&
            widget.writes!.pending.isEmpty;
        setState(
          () => error = rejectedDraft
              ? '${e.message} The draft was not saved. You can create a new one.'
              : e.message,
        );
      }
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
          LoadingButton.text(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          LoadingButton(
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
          LoadingButton.text(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          LoadingButton(
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

  Future<void> _returnInvoice(Map<String, dynamic> record) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final responses = await Future.wait([
        widget.api.records(
          widget.companyId,
          'InvoiceItems',
          employee: widget.employee,
          force: true,
        ),
        widget.api.records(
          widget.companyId,
          'CreditNoteItems',
          employee: widget.employee,
          force: true,
        ),
      ]);
      List<Map<String, dynamic>> related(Map<String, dynamic> response) =>
          (response['records'] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .where((r) => r['invoiceId'] == record['recordId'])
              .toList();
      if (!mounted) return;
      final input = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => InvoiceReturnEditor(
          invoice: record,
          items: related(responses[0]),
          returns: related(responses[1]),
        ),
      );
      if (input == null || !mounted) return;
      await widget.writes!.enqueue(
        'Invoices',
        'invoiceReturn',
        input,
        recordId: record['recordId'] as String,
        expectedVersion: int.parse('${record['recordVersion']}'),
      );
      await widget.writes!.flush();
      if (mounted) await _load(force: true);
    } on SaasApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not confirm the return. Retry any pending request.',
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
          LoadingButton.text(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          LoadingButton(
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
            LoadingButton.text(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            LoadingButton(
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
            LoadingButton.text(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            LoadingButton(
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
          LoadingButton.text(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          LoadingButton(
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
            LoadingButton.text(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            LoadingButton(
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
    widget.writes?.outbox?.addListener(_cacheChanged);
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
    if (oldWidget.selectedTable != widget.selectedTable &&
        widget.selectedTable != null) {
      _tableSearch[table] = _search;
      table = widget.selectedTable!;
      rows = [];
      _hasData = false;
      _search = _tableSearch[table] ?? '';
      _searchController.text = _search;
      _watch();
      _load();
      return;
    }
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
        final serverRows = (data['records'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        final fresh =
            widget.writes?.visibleRows(table, serverRows) ?? serverRows;
        final changed = dataFingerprint({'records': fresh}) !=
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
      } else if ((widget.api.cache.scope == null ||
              (state?.error is SaasApiException &&
                  (state!.error as SaasApiException).status == 403)) &&
          _hasData) {
        setState(() {
          rows = [];
          _hasData = false;
          if (state?.error is SaasApiException) {
            error = (state!.error as SaasApiException).message;
          }
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
    widget.writes?.outbox?.removeListener(_cacheChanged);
    if (_watchedPath != null) widget.api.cache.deactivate(_watchedPath!);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final requestedTable = table, request = ++_request;
    final cached = widget.api.cache.state(_path)?.data;
    setState(() {
      _loading = true;
      if (cached != null) {
        rows = widget.writes?.visibleRows(
              table,
              (cached['records'] as List)
                  .map((r) => Map<String, dynamic>.from(r as Map))
                  .toList(),
            ) ??
            (cached['records'] as List)
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

  String _title(Map<String, dynamic> row) => const ['Invoices', 'Quotations']
              .contains(table) &&
          '${row['number'] ?? ''}'.trim().isEmpty
      ? 'Draft ${table == 'Invoices' ? 'invoice' : 'quotation'} · ${row['issueDate'] ?? ''}'
      : '${row['name'] ?? row['fullName'] ?? row['number'] ?? row['description'] ?? row['date'] ?? row['month'] ?? 'Record'}';
  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (table == 'CompanyProfile' && !widget.employee)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .4,
              ),
              child: SingleChildScrollView(
                child: SystemSettingsPanel(
                  api: widget.api,
                  companyId: widget.companyId,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.selectedTable != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        tableTitles[table] ?? table,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (widget.selectedTable == null)
                    PopupMenuButton<String>(
                      tooltip: 'Choose record type',
                      enabled: !busy,
                      initialValue: table,
                      onSelected: (value) {
                        _tableSearch[table] = _search;
                        rows = [];
                        _hasData = false;
                        table = value;
                        _search = _tableSearch[table] ?? '';
                        _searchController.text = _search;
                        _watch();
                        _load();
                      },
                      itemBuilder: (_) => [
                        for (final t in widget.tables)
                          PopupMenuItem(
                              value: t, child: Text(tableTitles[t] ?? t)),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tableTitles[table] ?? table,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.expand_more, size: 18),
                          ],
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Filter statuses',
                    icon: Icon(
                      (_statusFilters[table]?.isNotEmpty ?? false)
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined,
                    ),
                    onSelected: (status) => setState(() {
                      if (status == '__all') {
                        _statusFilters[table] = {};
                      } else {
                        final values =
                            _statusFilters.putIfAbsent(table, () => {});
                        values.contains(status)
                            ? values.remove(status)
                            : values.add(status);
                      }
                    }),
                    itemBuilder: (_) => [
                      CheckedPopupMenuItem(
                        value: '__all',
                        checked: _statusFilters[table]?.isEmpty ?? true,
                        child: const Text('All statuses'),
                      ),
                      for (final status in rows
                          .map(
                            (row) =>
                                '${row['status'] ?? row['paymentStatus'] ?? ''}',
                          )
                          .where((value) => value.isNotEmpty)
                          .toSet())
                        CheckedPopupMenuItem(
                          value: status,
                          checked:
                              _statusFilters[table]?.contains(status) ?? false,
                          child:
                              Text(status.toLowerCase().replaceAll('_', ' ')),
                        ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Refresh records',
                    onPressed:
                        busy || _loading ? null : () => _load(force: true),
                    icon: const Icon(Icons.refresh),
                  ),
                  if (_editable && table != 'CompanyProfile')
                    LoadingButton.icon(
                      onPressed: busy || widget.writes!.hasBlockingPending
                          ? null
                          : () => _editCustomer(),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Add $_recordLabel'),
                    ),
                  if (widget.writes?.pending.isNotEmpty == true)
                    PopupMenuButton<String>(
                      tooltip: 'Pending change options',
                      enabled: !busy,
                      onSelected: (value) {
                        if (value == 'retry') {
                          _retryWrite();
                        } else if (value == 'export') {
                          _exportPending();
                        } else if (value == 'review') {
                          _reviewRejected();
                        } else {
                          _discardRejected();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'retry',
                          child: Text('Retry pending change'),
                        ),
                        const PopupMenuItem(
                            value: 'export',
                            child: Text('Export pending changes')),
                        if (widget.writes?.canDiscardRejected == true)
                          const PopupMenuItem(
                            value: 'review',
                            child: Text('Review rejected change'),
                          ),
                        if (widget.writes?.canDiscardRejected == true)
                          const PopupMenuItem(
                            value: 'discard',
                            child: Text('Discard rejected edit'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: TextField(
              inputFormatters: [
                AppInputFormatters.text,
                AppInputFormatters.search
              ],
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search records',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear record search',
                        onPressed: () => setState(() {
                          _search = '';
                          _searchController.clear();
                        }),
                        icon: const Icon(Icons.close, size: 18),
                      ),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          if (_statusFilters[table]?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Status: ${_statusFilters[table]!.map((value) => value.toLowerCase().replaceAll('_', ' ')).join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          if (!busy && error == null && rows.isNotEmpty && _visibleRows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No records match your search.'),
            ),
          SizedBox(
            height: 28,
            child: Align(
              alignment: Alignment.centerRight,
              child: busy ||
                      (_loading && _hasData) ||
                      widget.api.cache.state(_path)?.refreshing == true
                  ? const AppActivityIndicator(radius: 8)
                  : null,
            ),
          ),
          if (_savedData) const Text('Offline - showing saved data.'),
          if (widget.writes?.outbox != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(widget.api.cache.storageError != null
                    ? 'Read cache unavailable on this device'
                    : widget.writes!.outbox!.status),
              ),
            ),
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
            child: _loading && !_hasData
                ? const RecordSkeleton()
                : RefreshIndicator.noSpinner(
                    onRefresh: () => _load(force: true),
                    child: ListView.builder(
                      key: PageStorageKey((widget.companyId, table)),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      itemCount: _visibleRows.length,
                      itemBuilder: (context, index) {
                        final row = _visibleRows[index];
                        return RecordCard(
                          key:
                              PageStorageKey((table, row['recordId'] ?? index)),
                          title: Text(
                            _title(row),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          collapsedBackgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          subtitle: RecordSummary(record: row),
                          children: [
                            if (row['_localOnly'] == true)
                              RecordNotice(
                                title: row['syncStatus'] == 'SYNCED'
                                    ? 'Synced'
                                    : 'Saved on this device',
                                message: row['_syncError'] as String? ??
                                    'Changes pending. Financial totals and final numbering are confirmed by the server.',
                              ),
                            if (table == 'Invoices' && row['status'] != 'DRAFT')
                              const RecordNotice(
                                title: 'Invoice history is protected',
                                icon: Icons.lock_outline,
                                message:
                                    'Issued invoices are locked. Use Return items / credit note to correct returned goods or services. Credit notes preserve the original invoice and payment history.',
                              ),
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
                              LoadingButton.outlinedIcon(
                                icon: const Icon(Icons.attach_file),
                                label: Text(
                                  table == 'CompanyProfile'
                                      ? 'Manage logo'
                                      : 'Documents',
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
                              LoadingButton(
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
                                        ? null
                                        : () => _issueInvoice(row),
                                child: const Text('Issue invoice'),
                              ),
                            if (_editable &&
                                table == 'Invoices' &&
                                row['status'] == 'ISSUED' &&
                                num.tryParse('${row['paidAmount']}') == 0)
                              LoadingButton.outlined(
                                style: _destructiveActionStyle,
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
                                        ? null
                                        : () => _voidInvoice(row),
                                child: const Text('Void invoice'),
                              ),
                            if (_editable &&
                                table == 'Invoices' &&
                                const [
                                  'ISSUED',
                                  'PARTIALLY_PAID',
                                  'PAID',
                                  'PARTIALLY_RETURNED',
                                ].contains(row['status']))
                              LoadingButton.icon(
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
                                        ? null
                                        : () => _returnInvoice(row),
                                icon: const Icon(
                                    Icons.assignment_return_outlined),
                                label: const Text('Return items / credit note'),
                              ),
                            if (_editable &&
                                table == 'Quotations' &&
                                row['status'] == 'DRAFT')
                              LoadingButton(
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
                                        ? null
                                        : () => _quotationAction(row, 'send'),
                                child: const Text('Finalize quotation'),
                              ),
                            if (_editable &&
                                table == 'Quotations' &&
                                row['status'] == 'SENT')
                              LoadingButton(
                                onPressed: busy ||
                                        widget.writes!.pending.isNotEmpty
                                    ? null
                                    : () => _quotationAction(row, 'convert'),
                                child: const Text('Create draft invoice'),
                              ),
                            if (_editable &&
                                table == 'Payroll' &&
                                row['status'] == 'DRAFT')
                              LoadingButton(
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
                                        ? null
                                        : () => _payrollAction(row, 'approve'),
                                child: const Text('Approve payroll'),
                              ),
                            if (_editable &&
                                table == 'Payroll' &&
                                row['status'] == 'APPROVED')
                              LoadingButton(
                                onPressed: busy ||
                                        widget.writes!.pending.isNotEmpty
                                    ? null
                                    : () => _payrollAction(row, 'payrollPay'),
                                child: const Text('Pay payroll'),
                              ),
                            if (_editable &&
                                table == 'Payroll' &&
                                const ['APPROVED', 'PAID']
                                    .contains(row['status']))
                              LoadingButton.outlined(
                                style: _destructiveActionStyle,
                                onPressed: busy ||
                                        widget.writes!.pending.isNotEmpty
                                    ? null
                                    : () =>
                                        _payrollAction(row, 'payrollReverse'),
                                child: Text(
                                  row['status'] == 'PAID'
                                      ? 'Refund and reverse payroll'
                                      : 'Reverse payroll',
                                ),
                              ),
                            if (_editable &&
                                table == 'Assets' &&
                                row['status'] == 'DRAFT')
                              LoadingButton(
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
                                        ? null
                                        : () => _assetAction(row, 'capitalize'),
                                child: const Text('Capitalize asset'),
                              ),
                            if (_editable &&
                                table == 'Assets' &&
                                row['status'] == 'ACTIVE')
                              LoadingButton.outlined(
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
                                        ? null
                                        : () => _assetAction(row, 'depreciate'),
                                child: const Text('Post monthly depreciation'),
                              ),
                            if (_editable &&
                                table == 'Assets' &&
                                row['status'] == 'ACTIVE')
                              LoadingButton.outlined(
                                style: _destructiveActionStyle,
                                onPressed: busy ||
                                        widget.writes!.pending.isNotEmpty
                                    ? null
                                    : () => _assetAction(row, 'assetDispose'),
                                child: const Text('Dispose asset'),
                              ),
                            if (_editable &&
                                table == 'CapitalTransactions' &&
                                row['status'] == 'DRAFT')
                              LoadingButton(
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
                                        ? null
                                        : () => _postCapital(row),
                                child: const Text('Post contribution'),
                              ),
                            if (_editable &&
                                table == 'ShareholderLoans' &&
                                row['status'] == 'DRAFT')
                              LoadingButton(
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
                                        ? null
                                        : () => _loanAction(row, 'loanPost'),
                                child: const Text('Post loan'),
                              ),
                            if (_editable &&
                                table == 'ShareholderLoans' &&
                                row['status'] == 'ACTIVE')
                              LoadingButton(
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
                                        ? null
                                        : () => _loanAction(row, 'loanRepay'),
                                child: const Text('Repay loan in full'),
                              ),
                            if (_editable &&
                                table == 'Receipts' &&
                                row['status'] == 'POSTED')
                              LoadingButton.outlined(
                                style: _destructiveActionStyle,
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
                                        ? null
                                        : () => _reverseReceipt(row),
                                child: const Text('Reverse receipt'),
                              ),
                            if (_editable &&
                                const ['Income', 'Expenses'].contains(table) &&
                                row['ledgerStatus'] == 'LINKED' &&
                                const [
                                  'UNPAID',
                                  'PAID',
                                ].contains(row['paymentStatus']))
                              LoadingButton.outlined(
                                style: _destructiveActionStyle,
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
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
                              LoadingButton(
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
                                        ? null
                                        : () => _payCash(row),
                                child: const Text('Record payment'),
                              ),
                            if (_editable &&
                                const ['Income', 'Expenses'].contains(table) &&
                                row['ledgerStatus'] == 'UNPOSTED')
                              LoadingButton(
                                onPressed:
                                    busy || widget.writes!.pending.isNotEmpty
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
                                (table != 'Invoices' ||
                                    row['status'] == 'DRAFT') &&
                                (table != 'Quotations' ||
                                    row['status'] == 'DRAFT') &&
                                (table != 'Payroll' ||
                                    row['status'] == 'DRAFT') &&
                                (table != 'Assets' ||
                                    row['status'] == 'DRAFT') &&
                                (table != 'CapitalTransactions' ||
                                    row['status'] == 'DRAFT') &&
                                (table != 'ShareholderLoans' ||
                                    row['status'] == 'DRAFT') &&
                                table != 'Receipts')
                              LoadingButton.outlined(
                                onPressed:
                                    busy || widget.writes!.hasBlockingPending
                                        ? null
                                        : () => _editCustomer(row),
                                child: Text('Edit $_recordLabel'),
                              ),
                            if (_editable &&
                                widget.writes!
                                    .supportsLocal(table, 'delete', row))
                              LoadingButton.outlined(
                                onPressed:
                                    busy || widget.writes!.hasBlockingPending
                                        ? null
                                        : () => _deleteLocalRecord(row),
                                child: Text('Delete $_recordLabel'),
                              ),
                            RecordDetails(record: row),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      );
}
