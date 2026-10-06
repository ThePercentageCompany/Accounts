import 'package:tpc_invoice/core/widgets/forms/validated_text_field.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../data/report_settings.dart';
import '../data/report_format.dart';
import '../data/report_snapshot.dart';
import '../data/report_exports.dart';
import 'package:tpc_invoice/core/utils/report_print.dart';
import 'package:flutter/material.dart';
import 'financial_report_body.dart';
import 'report_grid.dart';
import 'package:tpc_invoice/features/documents/presentation/record_documents_view.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/reports/presentation/workspace_dashboard.dart';

import 'package:tpc_invoice/core/utils/file_download.dart';

class TrialBalanceView extends StatefulWidget {
  const TrialBalanceView({
    super.key,
    required this.api,
    required this.companyId,
    this.employee = false,
    this.initialDashboard = false,
    this.active = true,
    this.reportKind,
    this.companyName,
    this.initialAccountId,
    this.initialFrom,
    this.initialAsOf,
    this.onReportSelected,
  });
  final SaasApi api;
  final String companyId;
  final bool employee;
  final bool initialDashboard;
  final bool active;
  final String? reportKind, companyName, initialAccountId;
  final DateTime? initialFrom, initialAsOf;
  final ValueChanged<String>? onReportSelected;
  @override
  State<TrialBalanceView> createState() => _TrialBalanceViewState();
}

class _TrialBalanceViewState extends State<TrialBalanceView> {
  DateTime _date = DateTime.now();
  DateTime _from = DateTime(DateTime.now().year);
  bool _profit = false;
  bool _balance = false;
  String? _extra;
  bool _fullTrial = false;
  String _comparison = 'none';
  DateTime? _customCompareFrom, _customCompareAsOf;
  Map<String, dynamic> _settings = defaultReportSettings();
  bool _preferencesApplied = false;
  bool _exporting = false;
  bool _savingView = false;
  String _preset = 'This Year';
  String? _selectedAccountId;
  String _transactionSearch = '', _sourceFilter = '';
  final Set<String> _ledgerColumns = {
    'date',
    'number',
    'description',
    'sourceType',
    'debit',
    'credit',
    'balance',
  };
  bool get _period => !_balance && (_profit || _extra != null || _fullTrial);
  ReportFormat get _format => ReportFormat(
        locale: _settings['numberLocale'],
        datePattern: _settings['dateFormat'],
        parentheses: _parentheses,
      );
  (String?, String?) get _comparisonDates {
    if (_comparison == 'none') return (null, null);
    DateTime start, end;
    if (_comparison == 'custom') {
      start = _customCompareFrom ?? _from;
      end = _customCompareAsOf ?? _date;
    } else if (_comparison == 'previous-year') {
      start = previousYearDate(_from);
      end = previousYearDate(_date);
    } else {
      final length = DateTime.utc(_date.year, _date.month, _date.day)
              .difference(DateTime.utc(_from.year, _from.month, _from.day))
              .inDays +
          1;
      end = _period
          ? DateTime(_from.year, _from.month, _from.day - 1)
          : DateTime(_date.year, _date.month, 0);
      start = end.subtract(Duration(days: length - 1));
    }
    return (
      _period ? start.toIso8601String().substring(0, 10) : null,
      end.toIso8601String().substring(0, 10),
    );
  }

  String get _title => _extra == 'dashboard'
      ? 'Dashboard'
      : _extra == 'general-ledger'
          ? 'General ledger'
          : _balance
              ? 'Balance sheet'
              : _profit
                  ? 'Profit and loss'
                  : 'Trial balance';
  String _search = '';
  bool _hideZero = false;
  bool _dense = false;
  bool _parentheses = false;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _visibleRows(
    Map<String, dynamic> data,
  ) =>
      (data['accounts'] as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .where((row) {
        final matches =
            '${row['accountName']} ${row['accountId']} ${row['accountCode']} ${row['accountGroup']}'
                .toLowerCase()
                .contains(_search.toLowerCase());
        final keys = _kind == 'trial-balance' && _fullTrial
            ? [
                'openingDebit',
                'openingCredit',
                'periodDebit',
                'periodCredit',
                'debit',
                'credit',
              ]
            : _kind == 'general-ledger'
                ? ['opening', 'debit', 'credit', 'closing']
                : (_profit || _balance)
                    ? ['amount']
                    : ['debit', 'credit'];
        return matches &&
            (_selectedAccountId == null ||
                row['accountId'] == _selectedAccountId) &&
            (!_hideZero ||
                !keys.every((key) => reportMinor(row[key]) == BigInt.zero) ||
                row['comparison']?['previous'] != null &&
                    reportMinor(row['comparison']['previous']) != BigInt.zero);
      }).toList();
  late Future<Map<String, dynamic>> _report;
  Map<String, dynamic>? _displayed;
  String? _watchedPath;
  int _request = 0;
  String get _kind =>
      _extra ??
      (_balance
          ? 'balance-sheet'
          : _profit
              ? 'profit-and-loss'
              : 'trial-balance');
  String get _path => widget.api.financialReportPath(
        widget.companyId,
        _kind,
        asOf: _asOf,
        from: _period ? _from.toIso8601String().substring(0, 10) : null,
        compareFrom: _comparisonDates.$1,
        compareAsOf: _comparisonDates.$2,
        employee: widget.employee,
      );

  void _watch() {
    if (_watchedPath != null) widget.api.cache.deactivate(_watchedPath!);
    _watchedPath = widget.active ? _path : null;
    if (_watchedPath != null) widget.api.cache.activate(_watchedPath!);
  }

  void _cacheChanged() {
    scheduleMicrotask(() {
      if (!mounted) return;
      final data = widget.api.cache.state(_path)?.data;
      if (widget.api.cache.scope != null || _displayed != null) {
        setState(() {
          _displayed = data;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant TrialBalanceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reportKind != widget.reportKind) {
      _selectKind(widget.reportKind ?? 'dashboard');
      _load();
      return;
    }
    if (oldWidget.active != widget.active) {
      _watch();
      if (widget.active) _load();
    }
  }

  @override
  void dispose() {
    _request++;
    _searchController.dispose();
    widget.api.cache.removeListener(_cacheChanged);
    if (_watchedPath != null) widget.api.cache.deactivate(_watchedPath!);
    super.dispose();
  }

  String get _asOf => _date.toIso8601String().substring(0, 10);
  @override
  void initState() {
    super.initState();
    widget.api.cache.addListener(_cacheChanged);
    _selectedAccountId = widget.initialAccountId;
    if (widget.initialFrom != null) _from = widget.initialFrom!;
    if (widget.initialAsOf != null) _date = widget.initialAsOf!;
    if (widget.initialDashboard) _extra = 'dashboard';
    if (widget.reportKind != null) _selectKind(widget.reportKind!);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openSharedView();
    });
  }

  void _selectKind(String kind) {
    _extra = ['dashboard', 'general-ledger'].contains(kind) ? kind : null;
    _profit = kind == 'profit-and-loss';
    _balance = kind == 'balance-sheet';
    if (_from.isAfter(_date)) _from = DateTime(_date.year);
  }

  void _load({bool force = false}) {
    _watch();
    _displayed = widget.api.cache.state(_path)?.data;
    final request = ++_request;
    final future = _fetchReport(force: force);
    _report = future.then((data) {
      var fiscalReload = false;
      if (mounted && request == _request) {
        setState(() {
          _displayed = data;
          final metadata = data['metadata'];
          if (metadata is Map) {
            for (final k in [
              'financialYearMonth',
              'financialYearDay',
              'dateFormat',
              'numberLocale',
            ]) {
              if (metadata[k] != null) _settings[k] = metadata[k];
            }
            if (!_preferencesApplied) {
              _dense = metadata['dense'] == true;
              _parentheses = metadata['parentheses'] == true;
              _preferencesApplied = true;
            }
            if (_preset == 'This Year' &&
                widget.initialFrom == null &&
                _period) {
              final start = financialYearStart(
                _date,
                _settings['financialYearMonth'],
                _settings['financialYearDay'],
              );
              if (start != _from) {
                _from = start;
                fiscalReload = true;
              }
            }
          }
        });
        if (fiscalReload) {
          scheduleMicrotask(() {
            if (mounted && request == _request) setState(() => _load());
          });
        }
      }
      return data;
    });
    _report.ignore();
  }

  Future<Map<String, dynamic>> _fetchReport({bool force = false}) =>
      widget.api.financialReport(
        widget.companyId,
        _kind,
        asOf: _asOf,
        from: _period ? _from.toIso8601String().substring(0, 10) : null,
        compareFrom: _comparisonDates.$1,
        compareAsOf: _comparisonDates.$2,
        employee: widget.employee,
        force: force,
      );

  Future<void> _filterDates(String preset) async {
    if (preset == 'Custom') {
      if (_period) {
        final range = await showDateRangePicker(
          context: context,
          initialEntryMode: DatePickerEntryMode.calendarOnly,
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
          initialDateRange: DateTimeRange(start: _from, end: _date),
        );
        if (range == null || !mounted) return;
        setState(() {
          _preset = 'Custom';
          _from = range.start;
          _date = range.end;
          _load();
        });
      } else {
        final date = await showDatePicker(
          context: context,
          initialEntryMode: DatePickerEntryMode.calendarOnly,
          initialDate: _date,
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
        );
        if (date == null || !mounted) return;
        setState(() {
          _preset = 'Custom';
          _date = date;
          _load();
        });
      }
      return;
    }
    setState(() {
      _preset = preset;
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day);
      _from = switch (preset) {
        'This Year' => financialYearStart(
            _date,
            _settings['financialYearMonth'],
            _settings['financialYearDay'],
          ),
        'This Month' => DateTime(now.year, now.month),
        'Last Month' => DateTime(now.year, now.month - 1),
        'This Quarter' => DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1),
        'This Week' => _date.subtract(Duration(days: now.weekday - 1)),
        _ => _date,
      };
      if (preset == 'Last Month') _date = DateTime(now.year, now.month, 0);
      _load();
    });
  }

  ReportSnapshot _snapshot() => ReportSnapshot(_title, {
        ..._displayed!,
        'kind': _kind,
        'accounts': _exportRows(),
        'accountSearch': _search,
        'hideZeroBalances': _hideZero,
        'fullTrial': _fullTrial,
        'parentheses': _parentheses,
        'accountId': _selectedAccountId,
        'transactionSearch': _transactionSearch,
        'sourceFilter': _sourceFilter,
        'ledgerColumns': _ledgerColumns.toList(),
        'totalsScope':
            'All accounts in selected reporting period; account activity follows visible filters',
      });
  List<Map<String, dynamic>> _exportRows() => _visibleRows(_displayed!)
      .map(
        (a) => {
          ...a,
          if (_kind == 'general-ledger')
            'entries': (a['entries'] as List? ?? [])
                .where(
                  (e) =>
                      '${e['date']} ${e['number']} ${e['description']}'
                          .toLowerCase()
                          .contains(_transactionSearch.toLowerCase()) &&
                      (_sourceFilter.isEmpty ||
                          e['sourceType'] == _sourceFilter),
                )
                .toList(),
        },
      )
      .toList();
  Future<void> _export(String type) async {
    if (_displayed == null || _exporting) return;
    final snapshot = _snapshot();
    setState(() => _exporting = true);
    try {
      if (type == 'print') {
        await printReport(snapshotHtml(snapshot));
      } else {
        final bytes = type == 'pdf'
            ? await snapshotPdf(snapshot)
            : type == 'xlsx'
                ? snapshotXlsx(snapshot)
                : snapshotCsv(snapshot);
        await downloadFile(
          bytes,
          filename:
              '${_title.toLowerCase().replaceAll(' ', '-')}-${snapshot.data['asOf']}.$type',
          mimeType: type == 'pdf'
              ? 'application/pdf'
              : type == 'xlsx'
                  ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                  : 'text/csv;charset=utf-8',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export unavailable: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _chooseComparison(String mode) async {
    if (mode == 'custom') {
      if (_period) {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
          initialDateRange: DateTimeRange(
            start: _customCompareFrom ?? _from,
            end: _customCompareAsOf ?? _date,
          ),
        );
        if (range == null || !mounted) return;
        _customCompareFrom = range.start;
        _customCompareAsOf = range.end;
      } else {
        final date = await showDatePicker(
          context: context,
          firstDate: DateTime(1900),
          lastDate: DateTime(2200),
          initialDate: _customCompareAsOf ?? _date,
        );
        if (date == null || !mounted) return;
        _customCompareAsOf = date;
      }
    }
    if (mounted) {
      setState(() {
        _comparison = mode;
        _load();
      });
    }
  }

  Map<String, dynamic> _viewSettings(String name, String id) => {
        'id': id,
        'name': name,
        'kind': _kind,
        'from': _from.toIso8601String().substring(0, 10),
        'asOf': _asOf,
        'comparison': _comparison,
        'compareFrom':
            (_customCompareFrom ?? _from).toIso8601String().substring(
                  0,
                  10,
                ),
        'compareAsOf':
            (_customCompareAsOf ?? _date).toIso8601String().substring(
                  0,
                  10,
                ),
        'search': _search,
        'hideZero': _hideZero,
        'fullTrial': _fullTrial,
        'dense': _dense,
        'parentheses': _parentheses,
        'accountId': _selectedAccountId,
        'transactionSearch': _transactionSearch,
        'sourceFilter': _sourceFilter,
        'ledgerColumns': _ledgerColumns.toList(),
      };
  void _restoreView(Map view) {
    setState(() {
      _preset = 'Custom';
      _selectKind(view['kind']);
      _from = DateTime.parse(view['from']);
      _date = DateTime.parse(view['asOf']);
      _comparison = view['comparison'];
      _customCompareFrom = DateTime.parse(view['compareFrom']);
      _customCompareAsOf = DateTime.parse(view['compareAsOf']);
      _search = view['search'];
      _searchController.text = _search;
      _hideZero = view['hideZero'];
      _fullTrial = view['fullTrial'];
      _dense = view['dense'];
      _parentheses = view['parentheses'];
      _selectedAccountId = view['accountId'];
      _transactionSearch = view['transactionSearch'] ?? '';
      _sourceFilter = view['sourceFilter'] ?? '';
      _ledgerColumns
        ..clear()
        ..addAll(
          List<String>.from(view['ledgerColumns'] ?? ledgerColumnLabels.keys),
        );
      _load();
    });
    widget.onReportSelected?.call(view['kind']);
  }

  Future<void> _savedViews() async {
    try {
      final settings = await widget.api.reportSettings(
        widget.companyId,
        employee: widget.employee,
        force: true,
      );
      if (settings['views'] is! List) {
        throw const FormatException(
          'Saved views unavailable. Update the company service.',
        );
      }
      if (!mounted) return;
      final views = List<Map<String, dynamic>>.from(
        (settings['views'] as List).map((v) => Map<String, dynamic>.from(v)),
      );
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Saved report views'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (views.isEmpty)
                    const Text(
                      'No saved views. Views contain report settings only.',
                    ),
                  for (final v in views)
                    ListTile(
                      title: Text(v['name']),
                      subtitle: Text(
                        '${v['kind']} · ${v['from']} to ${v['asOf']}',
                      ),
                      onTap: () => Navigator.pop(context, 'open:${v['id']}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (a) =>
                            Navigator.pop(context, '$a:${v['id']}'),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'share',
                            child: Text('Copy permission-checked link'),
                          ),
                          if (!widget.employee)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete saved view'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            LoadingButton.text(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (!widget.employee)
              LoadingButton(
                onPressed: () => Navigator.pop(context, 'save'),
                child: const Text('Save current view'),
              ),
          ],
        ),
      );
      if (action == null || !mounted) return;
      if (action == 'save') {
        final controller = TextEditingController();
        final viewForm = GlobalKey<FormState>();
        final name = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Save current view'),
            content: Form(
                key: viewForm,
                child: ValidatedTextField(
                  inputFormatters: [AppInputFormatters.text],
                  controller: controller,
                  required: true,
                  kind: AppInputKind.name,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'View name'),
                )),
            actions: [
              LoadingButton.text(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              LoadingButton(
                onPressed: () {
                  if (AppFormValidation.validate(viewForm.currentState!)) {
                    Navigator.pop(context, controller.text.trim());
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
        controller.dispose();
        if (name == null || !mounted) return;
        views.add(_viewSettings(name, const Uuid().v4()));
      } else {
        final id = action.substring(action.indexOf(':') + 1),
            view = views.firstWhere((v) => v['id'] == id);
        if (action.startsWith('open:')) {
          _restoreView(view);
          return;
        }
        if (action.startsWith('share:')) {
          final link = Uri.base.replace(
            fragment: 'report-view=${widget.companyId}/$id',
          );
          await Clipboard.setData(ClipboardData(text: '$link'));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'View link copied. Recipients need company reporting access.',
                ),
              ),
            );
          }
          return;
        }
        views.removeWhere((v) => v['id'] == id);
      }
      setState(() => _savingView = true);
      final saved = await widget.api.saveReportSettings(widget.companyId, {
        ...settings,
        'views': views,
      });
      if (mounted) {
        _settings = saved;
        setState(() => _savingView = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved report views updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingView = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _openSharedView() async {
    final match = RegExp(
      r'^report-view=([A-Za-z0-9_-]{43})/([A-Za-z0-9_-]{16,64})$',
    ).firstMatch(Uri.base.fragment);
    if (match == null || match[1] != widget.companyId) return;
    try {
      final settings = await widget.api.reportSettings(
        widget.companyId,
        employee: widget.employee,
        force: true,
      );
      final view = (settings['views'] as List).cast<Map>().firstWhere(
            (v) => v['id'] == match[2],
          );
      if (mounted) _restoreView(view);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared view unavailable or access denied.'),
          ),
        );
      }
    }
  }

  void _drillDown(Map<String, dynamic> account) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 1200,
          height: MediaQuery.sizeOf(context).height * .9,
          child: Column(
            children: [
              ListTile(
                title: Text('Account activity · ${account['accountName']}'),
                trailing: IconButton(
                  tooltip: 'Return to report',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: TrialBalanceView(
                  api: widget.api,
                  companyId: widget.companyId,
                  employee: widget.employee,
                  companyName: widget.companyName,
                  reportKind: account['derived'] == true
                      ? 'profit-and-loss'
                      : 'general-ledger',
                  initialAccountId:
                      account['derived'] == true ? null : account['accountId'],
                  initialFrom: account['derived'] == true
                      ? DateTime.parse(account['from'])
                      : _period
                          ? _from
                          : DateTime(1900),
                  initialAsOf: account['derived'] == true
                      ? DateTime.parse(account['asOf'])
                      : _date,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _journal(Map<String, dynamic> entry) {
    final future = widget.api.financialReport(
      widget.companyId,
      'general-ledger',
      from: entry['date'],
      asOf: entry['date'],
      employee: widget.employee,
      force: true,
    );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Journal ${entry['number']}'),
        content: SizedBox(
          width: 900,
          child: FutureBuilder<Map<String, dynamic>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('${snapshot.error}');
              if (!snapshot.hasData) {
                return const SizedBox(height: 80, child: CenteredLoading());
              }
              final lines = <List<Widget>>[];
              for (final a in snapshot.data!['accounts'] as List? ?? []) {
                for (final e in a['entries'] as List? ?? []) {
                  if (e['journalId'] == entry['journalId']) {
                    lines.add([
                      Text('${e['lineNumber'] ?? ''}'),
                      Text('${a['accountName']}'),
                      Text(_format.money(e['debit'])),
                      Text(_format.money(e['credit'])),
                    ]);
                  }
                }
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      'Posted · ${_format.date(entry['date'])}\n${entry['description']}\nSource: ${entry['sourceType']}\nJournal ID: ${entry['journalId']}',
                    ),
                    const SizedBox(height: 16),
                    ReportGrid(
                      headers: const ['Line', 'Account', 'Debit', 'Credit'],
                      rows: lines,
                      numeric: const {2, 3},
                      dense: _dense,
                    ),
                    if ('${entry['sourceId'] ?? ''}'.isNotEmpty)
                      LoadingButton.text(
                        onPressed: () => _source(entry),
                        child: const Text('Open source record'),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          LoadingButton.text(
            onPressed: () => Navigator.pop(context),
            child: const Text('Return to ledger'),
          ),
        ],
      ),
    );
  }

  Future<void> _source(Map<String, dynamic> entry) async {
    final type = '${entry['sourceType']}',
        table = type.startsWith('Invoice')
            ? 'Invoices'
            : type.startsWith('Receipt')
                ? 'Receipts'
                : type.startsWith('Income')
                    ? 'Income'
                    : type.startsWith('Expenses')
                        ? 'Expenses'
                        : type.startsWith('Asset')
                            ? 'Assets'
                            : type.startsWith('Payroll')
                                ? 'Payroll'
                                : type.startsWith('ShareholderLoan')
                                    ? 'ShareholderLoans'
                                    : type == 'CapitalContribution'
                                        ? 'CapitalTransactions'
                                        : null;
    try {
      if (table == null) {
        throw const FormatException(
          'This journal has no supported source-record link.',
        );
      }
      final records = (await widget.api.records(
        widget.companyId,
        table,
        employee: widget.employee,
        force: true,
      ))['records'] as List;
      final record = Map<String, dynamic>.from(
        records.cast<Map>().firstWhere(
              (r) => r['recordId'] == entry['sourceId'],
            ),
      );
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Source · $table'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final field in record.entries.where(
                    (e) =>
                        !const [
                          'recordId',
                          'companyId',
                          'createdBy',
                          'updatedBy',
                          'syncStatus',
                          'recordVersion',
                          'isDeleted',
                          'idempotencyKey',
                        ].contains(e.key) &&
                        '${e.value}'.isNotEmpty,
                  ))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: SelectableText(
                        '${field.key.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}')}: ${field.value}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            if (documentSections.contains(table))
              LoadingButton.text(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => RecordDocumentsView(
                    api: widget.api,
                    companyId: widget.companyId,
                    section: table,
                    record: record,
                    employee: widget.employee,
                  ),
                ),
                child: const Text('Documents'),
              ),
            LoadingButton.text(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Source unavailable: $e')));
      }
    }
  }

  void _reportInfo() => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('About this report'),
          content: const Text(
            'Includes posted journals only; drafts are excluded. Amounts use the workspace accounting currency. Income and expenses cover the selected period; other dashboard balances are cumulative through the end date. Graphs compare current totals, not historical trends. General ledger balances are debit-positive.',
          ),
          actions: [
            LoadingButton.text(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.reportKind == null)
                    PopupMenuButton<String>(
                      tooltip: 'Choose report',
                      initialValue: _kind,
                      onSelected: (kind) => setState(() {
                        _extra = ['dashboard', 'general-ledger'].contains(kind)
                            ? kind
                            : null;
                        _profit = kind == 'profit-and-loss';
                        _balance = kind == 'balance-sheet';
                        if (_from.isAfter(_date)) _from = DateTime(_date.year);
                        _load();
                      }),
                      itemBuilder: (_) => [
                        for (final entry in const {
                          'dashboard': 'Dashboard',
                          'general-ledger': 'General ledger',
                          'trial-balance': 'Trial balance',
                          'profit-and-loss': 'Profit and loss',
                          'balance-sheet': 'Balance sheet',
                        }.entries)
                          PopupMenuItem(
                              value: entry.key, child: Text(entry.value)),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _title,
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
                    tooltip: 'Filter dates',
                    icon: const Icon(Icons.calendar_month_outlined),
                    onSelected: _filterDates,
                    itemBuilder: (_) => [
                      for (final preset in [
                        'Today',
                        'This Week',
                        'This Month',
                        'Last Month',
                        'This Quarter',
                        'This Year',
                        'Custom',
                      ])
                        PopupMenuItem(value: preset, child: Text(preset)),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Refresh report',
                    onPressed: () => setState(() => _load(force: true)),
                    icon: const Icon(Icons.refresh),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Compare periods',
                    onSelected: _chooseComparison,
                    icon: const Icon(Icons.compare_arrows),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'none',
                        child: Text('No comparison'),
                      ),
                      PopupMenuItem(
                        value: 'previous-period',
                        child: Text(
                          _period
                              ? 'Previous comparable period'
                              : 'Previous month-end',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'previous-year',
                        child: Text('Previous year'),
                      ),
                      const PopupMenuItem(
                        value: 'custom',
                        child: Text('Custom comparison'),
                      ),
                    ],
                  ),
                  LoadingButton.iconOnly(
                    tooltip: 'Saved report views',
                    onPressed: _savingView ? null : _savedViews,
                    icon: const Icon(Icons.bookmarks_outlined),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Report options',
                    onSelected: (value) {
                      if (['csv', 'pdf', 'xlsx', 'print'].contains(value)) {
                        _export(value);
                      } else {
                        _reportInfo();
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'csv',
                        enabled: _displayed != null && !_exporting,
                        child: const Text('Export CSV'),
                      ),
                      for (final entry in const {
                        'pdf': 'Export PDF',
                        'xlsx': 'Export Excel',
                        'print': 'Print',
                      }.entries)
                        PopupMenuItem(
                          value: entry.key,
                          enabled: _displayed != null && !_exporting,
                          child: Text(entry.value),
                        ),
                      const PopupMenuItem(
                        value: 'info',
                        child: Text('About this report'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workspace / Reports / $_title',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(_title, style: Theme.of(context).textTheme.headlineSmall),
                if (widget.companyName != null ||
                    _displayed?['metadata'] != null)
                  Text(
                    '${_displayed?['metadata']?['companyName'] ?? widget.companyName ?? 'Workspace'} · ${_displayed?['metadata']?['currency'] ?? 'Workspace currency'} · ${_displayed?['metadata']?['accountingBasis'] ?? 'Posted journals'}',
                  ),
                if (_displayed?['metadata']?['generatedAt'] != null)
                  Text(
                    'Generated: ${_displayed!['metadata']['generatedAt']}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                if (_comparison != 'none')
                  Wrap(
                    spacing: 8,
                    children: [
                      InputChip(
                        label: Text(
                          'Comparison: ${_comparisonDates.$1 == null ? 'As of' : '${_format.date(_comparisonDates.$1)} to'} ${_format.date(_comparisonDates.$2)}',
                        ),
                        onDeleted: () => _chooseComparison('none'),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (_extra != 'dashboard')
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 240,
                        child: TextField(
                          inputFormatters: [
                            AppInputFormatters.text,
                            AppInputFormatters.search
                          ],
                          controller: _searchController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search accounts',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) => setState(() => _search = value),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Hide zero balances'),
                        selected: _hideZero,
                        onSelected: (value) =>
                            setState(() => _hideZero = value),
                      ),
                      FilterChip(
                        label: const Text('Dense view'),
                        selected: _dense,
                        onSelected: (value) => setState(() => _dense = value),
                      ),
                      if (_kind == 'trial-balance')
                        FilterChip(
                          label: const Text('Opening & movements'),
                          selected: _fullTrial,
                          onSelected: (v) => setState(() {
                            _fullTrial = v;
                            _load();
                          }),
                        ),
                      if (_kind == 'general-ledger' && _displayed != null)
                        PopupMenuButton<String>(
                          tooltip: 'Select ledger account',
                          onSelected: (id) => setState(
                            () => _selectedAccountId = id.isEmpty ? null : id,
                          ),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: '',
                              child: Text('All accounts'),
                            ),
                            for (final a
                                in _displayed!['accounts'] as List? ?? [])
                              PopupMenuItem(
                                value: '${a['accountId']}',
                                child: Text(
                                  '${a['accountCode'] ?? a['accountId']} · ${a['accountName']}',
                                ),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _selectedAccountId == null
                                  ? 'All accounts'
                                  : 'Account: $_selectedAccountId',
                            ),
                          ),
                        ),
                      if (_search.isNotEmpty ||
                          _hideZero ||
                          _selectedAccountId != null ||
                          _transactionSearch.isNotEmpty ||
                          _sourceFilter.isNotEmpty)
                        LoadingButton.text(
                          onPressed: () => setState(() {
                            _search = '';
                            _hideZero = false;
                            _selectedAccountId = null;
                            _transactionSearch = '';
                            _sourceFilter = '';
                            _searchController.clear();
                          }),
                          child: const Text('Reset filters'),
                        ),
                      FilterChip(
                        label: const Text('Negative (1.00)'),
                        selected: _parentheses,
                        onSelected: (value) =>
                            setState(() => _parentheses = value),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _report,
              builder: (context, snapshot) {
                if (_displayed == null &&
                    snapshot.connectionState != ConnectionState.done) {
                  return const CenteredLoading();
                }
                if (_displayed == null && snapshot.hasError) {
                  return Center(
                    child: Text(
                      snapshot.error is SaasApiException
                          ? (snapshot.error as SaasApiException).message
                          : 'Report unavailable. Retry.',
                    ),
                  );
                }
                if (_displayed == null) {
                  return const Center(
                    child: Text("Sign in again to load this report."),
                  );
                }
                final data = _displayed!;
                return SingleChildScrollView(
                  key: PageStorageKey(_path),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 18,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child:
                              widget.api.cache.state(_path)?.refreshing == true
                                  ? const Padding(
                                      padding: EdgeInsets.only(right: 24),
                                      child: AppActivityIndicator(radius: 8),
                                    )
                                  : null,
                        ),
                      ),
                      if (widget.api.cache.state(_path)?.offline == true)
                        const Text('Offline - showing saved data.'),
                      if (widget.api.cache.state(_path)?.error != null &&
                          _displayed != null)
                        const Text(
                          'Refresh failed. Showing saved report; use Refresh to retry.',
                        ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
                          vertical: 4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_period ? "${_from.toIso8601String().substring(0, 10)} to " : "As of "}$_asOf | ${data['journalCount'] ?? 0} posted journals',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      if (_extra == 'dashboard')
                        WorkspaceDashboard(
                          data: data,
                          format: _format,
                          onReportSelected: (kind) {
                            if (widget.onReportSelected != null) {
                              widget.onReportSelected!(kind);
                            } else {
                              setState(() {
                                _selectKind(kind);
                                _load();
                              });
                            }
                          },
                        ),
                      if (_extra != 'dashboard')
                        FinancialReportBody(
                          data: data,
                          kind: _kind,
                          rows: _visibleRows(data),
                          key: ValueKey(_kind),
                          dense: _dense,
                          parentheses: _parentheses,
                          fullTrial: _kind == 'trial-balance' && _fullTrial,
                          format: _format,
                          transactionSearch: _transactionSearch,
                          sourceFilter: _sourceFilter,
                          ledgerColumns: _ledgerColumns,
                          onDrillDown: _drillDown,
                          onJournal: _journal,
                          onTransactionSearch: (v) =>
                              setState(() => _transactionSearch = v),
                          onSourceFilter: (v) =>
                              setState(() => _sourceFilter = v),
                          onColumnsChanged: (v) => setState(() {
                            _ledgerColumns
                              ..clear()
                              ..addAll(v);
                          }),
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
