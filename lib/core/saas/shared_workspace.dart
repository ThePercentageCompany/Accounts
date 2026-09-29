import 'package:flutter/material.dart';
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
      if (widget.employee == null) 'Reports',
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
                : selected == 'Reports' && widget.employee == null
                ? TrialBalanceView(
                    key: ValueKey(widget.companyId),
                    api: widget.api,
                    companyId: widget.companyId,
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
      ].contains(table);
  String get _recordLabel => table == 'FinancialPeriods'
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
      : table == 'Expenses'
      ? 'expense'
      : 'income';
  Future<void> _editCustomer([Map<String, dynamic>? record]) async {
    List<Map<String, dynamic>> choices = const [];
    if (table == 'Payroll') {
      final response = await widget.api.employees(widget.companyId);
      choices = (response['employees'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => item['employmentStatus'] == 'ACTIVE')
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
      builder: (_) => table == 'Invoices'
          ? InvoiceEditor(customers: choices, record: record)
          : table == 'InvoiceItems'
          ? InvoiceLineEditor(invoices: choices, record: record)
          : table == 'Receipts'
          ? ReceiptEditor(invoices: choices)
          : table == 'Quotations'
          ? QuotationEditor(customers: choices, record: record)
          : table == 'QuotationItems'
          ? QuotationLineEditor(quotations: choices, record: record)
          : table == 'Payroll'
          ? PayrollEditor(employees: choices, record: record)
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
            if (_editable)
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
          _editable ? 'Company records' : 'Online records · viewing only',
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
                if (_editable && table == 'Payroll' && row['status'] == 'DRAFT')
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
                    const ['Income', 'Expenses'].contains(table) &&
                    row['ledgerStatus'] == 'LINKED' &&
                    row['paymentStatus'] == 'UNPAID')
                  TextButton(
                    onPressed: busy || widget.writes!.pending.isNotEmpty
                        ? null
                        : () => _payCash(row, reverse: true),
                    child: const Text('Reverse entry'),
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
                    (table != 'FinancialPeriods' || row['status'] == 'OPEN') &&
                    (table != 'Invoices' || row['status'] == 'DRAFT') &&
                    (table != 'InvoiceItems' ||
                        row['parentStatus'] == 'DRAFT') &&
                    (table != 'Quotations' || row['status'] == 'DRAFT') &&
                    (table != 'QuotationItems' ||
                        row['parentStatus'] == 'DRAFT') &&
                    (table != 'Payroll' || row['status'] == 'DRAFT') &&
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
    ],
  );
}
