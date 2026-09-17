import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/auth/google_session.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/qr_code.dart';
import 'office_cubit.dart';

/// Owner-only permission editor and private login-code provisioning flow.
class EmployeeAccessDialog extends StatefulWidget {
  const EmployeeAccessDialog({
    super.key,
    required this.employee,
    required this.session,
    required this.cubit,
  });

  final Map<String, dynamic> employee;
  final GoogleSession session;
  final OfficeCubit cubit;

  @override
  State<EmployeeAccessDialog> createState() => _EmployeeAccessDialogState();
}

class _EmployeeAccessDialogState extends State<EmployeeAccessDialog> {
  static const _sections = [
    'Dashboard',
    'Invoices',
    'Quotations',
    'Income & Expenses',
    'Capital & Equity',
    'Fixed Assets',
    'Balance Sheet',
    'Customers',
    'Employees',
    'Payroll',
    'Reports',
    'Settings',
    'Office & Attendance',
  ];
  static const _roles = [
    'Admin',
    'Accountant',
    'Sales',
    'HR & Payroll',
    'Staff',
    'Custom'
  ];
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _employee;
  late final TextEditingController _email;
  late String _role;
  late List<String> _allowed;
  bool _busy = false;
  bool _credentialExists = false;
  String? _inviteLink;
  String? _loginCode;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _employee = Map<String, dynamic>.from(widget.employee);
    final savedRole = _employee['systemRole']?.toString() ?? 'Staff';
    _role = _roles.contains(savedRole) ? savedRole : 'Custom';
    final savedSections = _employee['allowedSections'];
    // Opening a named role must preserve its saved custom permissions.
    _allowed = savedSections is List
        ? savedSections.map((value) => value.toString()).toList()
        : savedSections is String
            ? savedSections
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList()
            : _preset(_role);
    _email = TextEditingController(
      text: _employee['googleEmail']?.toString() ??
          _employee['email']?.toString() ??
          '',
    );
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  List<String> _preset(String role) => switch (role) {
        'Admin' => List<String>.from(_sections),
        'Accountant' => [
            'Dashboard',
            'Invoices',
            'Quotations',
            'Income & Expenses',
            'Capital & Equity',
            'Fixed Assets',
            'Balance Sheet',
            'Customers',
            'Reports'
          ],
        'Sales' => ['Dashboard', 'Invoices', 'Quotations', 'Customers'],
        'HR & Payroll' => [
            'Dashboard',
            'Employees',
            'Payroll',
            'Office & Attendance',
            'Reports'
          ],
        _ => ['Dashboard', 'Office & Attendance'],
      };

  String? get _unavailableReason {
    final session = widget.session;
    if (session.isEmployee) {
      return 'Only the company owner can manage employee login access.';
    }
    final workspace = session.workspace;
    if (!session.authorized ||
        session.isOffline ||
        workspace == null ||
        workspace.spreadsheetId.isEmpty ||
        workspace.driveFolderId.isEmpty ||
        workspace.spreadsheetId == 'local_demo_workspace') {
      return 'Sign in as the company owner and connect online to manage employee login access.';
    }
    if (session.employeeGatewayUrl.isEmpty) {
      return 'Employee login is not configured. Set up the employee gateway before creating QR codes.';
    }
    if ((_employee['id']?.toString() ?? '').trim().isEmpty) {
      return 'Save this employee before creating login access.';
    }
    if (_employee['active'] == false) {
      return 'Activate this employee before creating login access.';
    }
    return null;
  }

  void _changed(VoidCallback change) {
    setState(() {
      change();
      _inviteLink = null;
      _error = null;
      _status = null;
    });
  }

  Future<void> _save({bool provision = false, bool reset = false}) async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final unavailable = _unavailableReason;
    if (unavailable != null) {
      setState(() => _error = unavailable);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
      if (provision) _inviteLink = null;
      if (reset) _loginCode = null;
    });
    try {
      final updated = {
        ..._employee,
        'systemRole': _role,
        'allowedSections': List<String>.from(_allowed),
        'googleEmail': _email.text.trim(),
      };
      final saved = await widget.cubit.run('employeeSave', updated);
      if (!saved) {
        throw StateError(
            widget.cubit.state.error ?? 'Employee save is busy. Please retry.');
      }
      _employee = widget.cubit.state.data.employees.firstWhere(
        (record) => record['id'] == updated['id'],
        orElse: () => updated,
      );
      final employeeId = _employee['id'].toString();
      if (provision) {
        // The session syncs the saved permissions before issuing any credential.
        final result = await widget.session
            .provisionEmployeeAccess(employeeId, reset: reset);
        final code = result['loginCode']?.toString();
        if (result['exists'] != true ||
            result['employeeId']?.toString() != employeeId ||
            (reset && (code == null || code.isEmpty))) {
          throw StateError(
              'Employee access could not be confirmed. Please retry.');
        }
        // Keep a newly issued secret in this dialog only, never in the employee record or QR.
        if (code != null && code.isNotEmpty) _loginCode = code;
        _credentialExists = true;
        _inviteLink = widget.session.employeeInviteLink(
          employeeId: employeeId,
          companyName: widget.session.workspace!.companyName,
        );
        _status = _loginCode == null
            ? 'Login access already exists. Use the existing private login code, or reset it below.'
            : 'Permissions saved online. Share this QR and the private login code with this employee.';
      } else {
        await widget.session.syncNow();
        final pending = widget.session.syncManager.pendingQueue.any(
            (operation) =>
                operation.spreadsheetId ==
                    widget.session.workspace?.spreadsheetId &&
                operation.tabName == 'Employees' &&
                operation.recordId == employeeId);
        if (_unavailableReason != null || pending) {
          throw StateError(
              'Permissions were saved locally but could not be confirmed online. Reconnect and save again.');
        }
        _status = 'Permissions saved online.';
      }
    } catch (error) {
      _error = error.toString().replaceFirst(RegExp(r'^Bad state: '), '');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset private login code?'),
        content: const Text(
            'The previous code will stop working and existing employee sessions will be signed out. Share the new code privately with the employee.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reset code')),
        ],
      ),
    );
    if (confirmed == true && mounted) await _save(provision: true, reset: true);
  }

  Future<void> _copy(String value, String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) setState(() => _status = message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not copy to the clipboard. Select and copy the text manually.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.session,
        builder: (context, _) {
          final unavailable = _unavailableReason;
          final enabled = !_busy && unavailable == null;
          return PopScope(
            canPop: !_busy,
            child: AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text(
                  'Access & QR Login • ${_employee['name'] ?? 'Employee'}'),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (unavailable != null) ...[
                          Text(unavailable,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                          const SizedBox(height: 16),
                        ],
                        DropdownButtonFormField<String>(
                          key: ValueKey(_role),
                          initialValue: _role,
                          decoration:
                              const InputDecoration(labelText: 'Employee role'),
                          items: [
                            for (final role in _roles)
                              DropdownMenuItem(value: role, child: Text(role))
                          ],
                          onChanged: enabled
                              ? (role) {
                                  if (role == null) return;
                                  _changed(() {
                                    _role = role;
                                    if (role != 'Custom') {
                                      _allowed = _preset(role);
                                    }
                                  });
                                }
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _email,
                          enabled: enabled,
                          decoration: const InputDecoration(
                              labelText: 'Employee email',
                              helperText:
                                  'Login uses the private code issued below.'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) =>
                              FormValidators.email(value, required: false),
                          onChanged: (_) => _changed(() {}),
                        ),
                        const SizedBox(height: 16),
                        const Text('Assigned sections',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final section in {..._sections, ..._allowed})
                              FilterChip(
                                label: Text(section),
                                selected: _allowed.contains(section),
                                onSelected: enabled
                                    ? (selected) => _changed(() {
                                          _role = 'Custom';
                                          if (selected) {
                                            _allowed.add(section);
                                          } else {
                                            _allowed.remove(section);
                                          }
                                        })
                                    : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                            'Save and create a QR to enable employee login. The employee scans it and enters their private login code. Permissions are verified online.'),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(_error!,
                              key: const Key('employee-access-error'),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ],
                        if (_status != null) ...[
                          const SizedBox(height: 16),
                          Text(_status!,
                              key: const Key('employee-access-status')),
                        ],
                        if (_busy)
                          const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: LinearProgressIndicator()),
                        if (_inviteLink != null && unavailable == null) ...[
                          const SizedBox(height: 20),
                          LayoutBuilder(
                            builder: (context, constraints) => Center(
                              child: QrImageView(
                                data: _inviteLink!,
                                size: constraints.maxWidth.clamp(0, 280).toDouble(),
                                foregroundColor: Colors.black,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: enabled
                                ? () => _copy(
                                    _inviteLink!, 'Employee QR link copied.')
                                : null,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy Employee QR Link'),
                          ),
                          if (_loginCode != null) ...[
                            const SizedBox(height: 16),
                            const Text('Private login code',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            SelectableText(_loginCode!,
                                key: const Key('private-login-code'),
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            const Text(
                                'Copy this code now. It is shown only in this dialog and cannot be retrieved after closing. Share it privately with this employee. The staff number is not a login code.'),
                            TextButton.icon(
                              onPressed: enabled
                                  ? () => _copy(_loginCode!,
                                      'Private login code copied. Share it only with this employee.')
                                  : null,
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy Private Login Code'),
                            ),
                          ],
                        ],
                        if (_credentialExists && unavailable == null)
                          TextButton(
                              onPressed: enabled ? _resetCode : null,
                              child: const Text('Reset Private Login Code')),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Close')),
                OutlinedButton(
                    onPressed: enabled ? () => _save() : null,
                    child: const Text('Save Permissions')),
                FilledButton.icon(
                    onPressed: enabled ? () => _save(provision: true) : null,
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Save & Create QR')),
              ],
            ),
          );
        },
      );
}
