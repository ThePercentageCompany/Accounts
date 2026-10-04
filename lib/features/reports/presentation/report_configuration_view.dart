import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import '../data/report_settings.dart';

class ReportConfigurationView extends StatefulWidget {
  const ReportConfigurationView({
    super.key,
    required this.api,
    required this.companyId,
    this.employee = false,
    this.chart = false,
  });
  final SaasApi api;
  final String companyId;
  final bool employee, chart;
  @override
  State<ReportConfigurationView> createState() =>
      _ReportConfigurationViewState();
}

class _ReportConfigurationViewState extends State<ReportConfigurationView> {
  Map<String, dynamic>? _settings;
  List<Map<String, dynamic>> _unregistered = [];
  String? _error;
  bool _busy = false, _dirty = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final settings = await widget.api.reportSettings(
        widget.companyId,
        employee: widget.employee,
        force: true,
      );
      if (settings['version'] is! int || settings['accounts'] is! List) {
        throw const FormatException(
          'Report settings unavailable. Update the company service.',
        );
      }
      List<Map<String, dynamic>> unregistered = [];
      if (widget.chart) {
        final report = await widget.api.financialReport(
          widget.companyId,
          'trial-balance',
          asOf: DateTime.now().toIso8601String().substring(0, 10),
          employee: widget.employee,
        );
        final ids = (settings['accounts'] as List)
            .map((a) => a['accountId'])
            .toSet();
        unregistered = (report['accounts'] as List? ?? [])
            .map((a) => Map<String, dynamic>.from(a as Map))
            .where((a) => !ids.contains(a['accountId']))
            .toList();
      }
      if (mounted) {
        setState(() {
          _settings = settings;
          _unregistered = unregistered;
          _dirty = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _change(String key, Object value) => setState(() {
    _settings![key] = value;
    _dirty = true;
  });
  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.saveReportSettings(
        widget.companyId,
        _settings!,
      );
      if (mounted) {
        setState(() {
          _settings = result;
          _dirty = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Report settings saved.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editAccount([
    Map<String, dynamic>? old,
    Map<String, dynamic>? ledger,
  ]) async {
    final source = old ?? ledger;
    final id = TextEditingController(text: source?['accountId'] ?? '');
    final code = TextEditingController(
      text: old?['code'] ?? source?['accountId'] ?? '',
    );
    final name = TextEditingController(
      text: old?['name'] ?? ledger?['accountName'] ?? '',
    );
    var group = '${old?['group'] ?? ledger?['accountGroup'] ?? 'Asset'}';
    var role = '${old?['role'] ?? ''}';
    var normal =
        '${old?['normalSide'] ?? (['Asset', 'Expense'].contains(group) ? 'Debit' : 'Credit')}';
    var active = old?['active'] != false;
    final form = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            old == null ? 'Register account' : 'Edit reporting classification',
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: id,
                      readOnly: source != null,
                      decoration: const InputDecoration(
                        labelText: 'Account ID',
                      ),
                      validator: (v) {
                        if (!RegExp(
                          r'^[A-Za-z0-9_-]{1,100}$',
                        ).hasMatch(v ?? '')) {
                          return 'Use letters, numbers, underscores or hyphens.';
                        }
                        if (old == null &&
                            (_settings!['accounts'] as List).any(
                              (a) => a['accountId'] == v,
                            )) {
                          return 'This account is already registered.';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: code,
                      decoration: const InputDecoration(
                        labelText: 'Account code',
                      ),
                      validator: (v) {
                        if (!RegExp(
                          r'^[A-Za-z0-9.-]{1,24}$',
                        ).hasMatch(v ?? '')) {
                          return 'Enter a code up to 24 characters.';
                        }
                        if ((_settings!['accounts'] as List).any(
                          (a) =>
                              a['code'] == v &&
                              a['accountId'] != old?['accountId'],
                        )) {
                          return 'This code is already in use.';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Account name',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty || v.length > 200
                          ? 'Enter a name up to 200 characters.'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: group,
                      decoration: const InputDecoration(
                        labelText: 'Ledger group',
                      ),
                      items: [
                        for (final g in reportRoles.keys)
                          DropdownMenuItem(value: g, child: Text(g)),
                      ],
                      onChanged: ledger != null
                          ? null
                          : (v) => update(() {
                              group = v!;
                              role = '';
                            }),
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey(group),
                      initialValue: role,
                      decoration: const InputDecoration(
                        labelText: 'Statement classification',
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Unclassified (review required)'),
                        ),
                        for (final r in reportRoles[group]!)
                          DropdownMenuItem(
                            value: r,
                            child: Text(r.replaceAll('-', ' ')),
                          ),
                      ],
                      onChanged: (v) => update(() => role = v!),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: normal,
                      decoration: const InputDecoration(
                        labelText: 'Normal balance',
                      ),
                      items: [
                        for (final n in ['Debit', 'Credit'])
                          DropdownMenuItem(value: n, child: Text(n)),
                      ],
                      onChanged: (v) => update(() => normal = v!),
                    ),
                    SwitchListTile(
                      title: const Text('Active'),
                      value: active,
                      onChanged: (v) => update(() => active = v),
                    ),
                    const Text(
                      'Reporting mappings preserve posted balances. An inactive account remains visible when it has posted activity.',
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => form.currentState!.validate()
                  ? Navigator.pop(context, {
                      'accountId': id.text.trim(),
                      'code': code.text.trim(),
                      'name': name.text.trim(),
                      'group': group,
                      'role': role,
                      'normalSide': normal,
                      'active': active,
                    })
                  : null,
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    id.dispose();
    code.dispose();
    name.dispose();
    if (result != null && mounted) {
      setState(() {
        final accounts = List<dynamic>.from(_settings!['accounts']);
        accounts.removeWhere((a) => a['accountId'] == result['accountId']);
        accounts.add(result);
        _settings!['accounts'] = accounts;
        _unregistered.removeWhere((a) => a['accountId'] == result['accountId']);
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.chart ? 'Chart of Accounts' : 'Report Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            widget.employee
                ? 'Company reporting configuration · read only'
                : 'Company reporting configuration · changes require Save',
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!),
            ),
          if (settings == null && !_busy)
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          if (settings != null) ...[
            if (widget.chart) ...[
              if (!widget.employee)
                FilledButton.icon(
                  onPressed: _busy ? null : () => _editAccount(),
                  icon: const Icon(Icons.add),
                  label: const Text('Register account'),
                ),
              const SizedBox(height: 16),
              for (final account in settings['accounts'] as List)
                Card(
                  child: ListTile(
                    title: Text('${account['code']} · ${account['name']}'),
                    subtitle: Text(
                      '${account['group']} · ${account['role'] == '' ? 'Unclassified' : account['role']} · Normal ${account['normalSide']} · ${account['active'] ? 'Active' : 'Inactive'}',
                    ),
                    trailing: widget.employee
                        ? null
                        : IconButton(
                            tooltip: 'Edit classification',
                            onPressed: _busy
                                ? null
                                : () => _editAccount(
                                    Map<String, dynamic>.from(account),
                                  ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                  ),
                ),
              if (_unregistered.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Unregistered ledger accounts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'These identities come from posted journals. Register and review their classification before using detailed statements.',
                ),
                for (final account in _unregistered)
                  ListTile(
                    title: Text('${account['accountName']}'),
                    subtitle: Text(
                      '${account['accountId']} · ${account['accountGroup']}',
                    ),
                    trailing: widget.employee
                        ? null
                        : OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _editAccount(null, account),
                            child: const Text('Register'),
                          ),
                  ),
              ],
              if ((settings['accounts'] as List).isEmpty &&
                  _unregistered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No accounts registered. Register accounts without creating sample balances.',
                  ),
                ),
            ] else ...[
              SizedBox(
                width: 440,
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: settings['financialYearMonth'],
                      decoration: const InputDecoration(
                        labelText: 'Financial year starts in month',
                      ),
                      items: [
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem(value: m, child: Text('$m')),
                      ],
                      onChanged: widget.employee || _busy
                          ? null
                          : (v) => _change('financialYearMonth', v!),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: settings['financialYearDay'],
                      decoration: const InputDecoration(
                        labelText: 'Financial year start day (1–28)',
                      ),
                      items: [
                        for (var d = 1; d <= 28; d++)
                          DropdownMenuItem(value: d, child: Text('$d')),
                      ],
                      onChanged: widget.employee || _busy
                          ? null
                          : (v) => _change('financialYearDay', v!),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: settings['dateFormat'],
                      decoration: const InputDecoration(
                        labelText: 'Date format',
                      ),
                      items: [
                        for (final p in [
                          'yyyy-MM-dd',
                          'dd/MM/yyyy',
                          'MM/dd/yyyy',
                        ])
                          DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: widget.employee || _busy
                          ? null
                          : (v) => _change('dateFormat', v!),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: settings['numberLocale'],
                      decoration: const InputDecoration(
                        labelText: 'Number formatting',
                      ),
                      items: [
                        for (final p in ['en_AE', 'en_US', 'en_IN', 'de_DE'])
                          DropdownMenuItem(value: p, child: Text(p)),
                      ],
                      onChanged: widget.employee || _busy
                          ? null
                          : (v) => _change('numberLocale', v!),
                    ),
                    SwitchListTile(
                      title: const Text('Negative amounts in parentheses'),
                      value: settings['parentheses'],
                      onChanged: widget.employee || _busy
                          ? null
                          : (v) => _change('parentheses', v),
                    ),
                    SwitchListTile(
                      title: const Text('Default to dense tables'),
                      value: settings['dense'],
                      onChanged: widget.employee || _busy
                          ? null
                          : (v) => _change('dense', v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Accounting currency comes from Company Profile. Posted journals use two decimal places. Currency changes follow the existing posting restrictions.',
              ),
            ],
            const SizedBox(height: 24),
            if (!widget.employee)
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    onPressed: _busy || !_dirty ? null : _save,
                    child: const Text('Save configuration'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (_dirty) {
                              final discard = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Discard unsaved changes?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Keep editing'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Discard'),
                                    ),
                                  ],
                                ),
                              );
                              if (discard != true) return;
                            }
                            _load();
                          },
                    child: const Text('Reload'),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
