import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/widgets/qr_code.dart';
import 'package:tpc_invoice/features/employees/presentation/cubit/employee_admin_controller.dart';

class EmployeeAdminView extends StatefulWidget {
  const EmployeeAdminView({
    super.key,
    required this.controller,
    this.onDocuments,
    this.active = true,
  });
  final EmployeeAdminController controller;
  final bool active;
  final ValueChanged<Map<String, dynamic>>? onDocuments;
  @override
  State<EmployeeAdminView> createState() => _EmployeeAdminViewState();
}

class _EmployeeAdminViewState extends State<EmployeeAdminView> {
  String _search = '';
  @override
  void initState() {
    super.initState();
    if (widget.active) {
      widget.controller.api.cache.activate(widget.controller.resourcePath);
    }
    widget.controller.refresh(force: false);
  }

  @override
  void didUpdateWidget(covariant EmployeeAdminView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      final c = widget.controller;
      if (widget.active) {
        c.api.cache.activate(c.resourcePath);
        c.refresh(force: false);
      } else {
        c.api.cache.deactivate(c.resourcePath);
      }
    }
  }

  @override
  void dispose() {
    if (widget.active) {
      widget.controller.api.cache.deactivate(widget.controller.resourcePath);
    }
    super.dispose();
  }

  Future<void> _edit([Map<String, dynamic>? employee]) async {
    final c = widget.controller;
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _EmployeeEditor(employee: employee),
    );
    if (values != null) await c.save(employee?['recordId'] as String?, values);
  }

  Future<void> _discardRejected() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AdaptiveFormDialog(
        title: const Text('Discard rejected change?'),
        content: const Text(
          'The server rejected this edit without saving it. Discard it and reload the current employee details before editing again.',
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
    if (yes == true) await widget.controller.discardRejected();
  }

  Future<void> _access(Map<String, dynamic> employee, String action) async {
    final c = widget.controller;
    if (action != 'issue') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AdaptiveFormDialog(
          title: Text(
            action == 'reset'
                ? 'Reset employee access?'
                : 'Revoke employee access?',
          ),
          content: Text(
            'Existing sessions for ${employee['fullName']} will stop working.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    final result = await c.access(employee['recordId'] as String, action);
    if (!mounted || result == null) return;
    if (action == 'revoke') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Employee access revoked.')));
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdaptiveFormDialog(
        title: Text('Access for ${employee['fullName']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: result['qrPayload'] as String, size: 220),
              const SizedBox(height: 12),
              SelectableText(result['inviteLink'] as String),
              const SizedBox(height: 20),
              const Text('Private login code — share separately'),
              SelectableText(
                result['privateCode'] as String,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Copy this code before closing. It cannot be displayed again. Reset access if it is lost.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I saved the code'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<EmployeeAdminController, EmployeeAdminState>(
    bloc: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                'Employees',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              FilledButton.icon(
                onPressed: c.busy || c.hasPending ? null : () => _edit(),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Add employee'),
              ),
              OutlinedButton(
                onPressed: c.busy ? null : c.refresh,
                child: const Text('Refresh'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search employees',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _search = value.toLowerCase()),
            ),
          ),
          SizedBox(
            height: 28,
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  c.busy ||
                      c.api.cache.state(c.resourcePath)?.refreshing == true
                  ? const CupertinoActivityIndicator(radius: 8)
                  : null,
            ),
          ),
          if (c.api.cache.state(c.resourcePath)?.offline == true)
            const Text('Offline - showing saved data.'),
          if (c.api.cache.state(c.resourcePath)?.error != null &&
              c.employees.isNotEmpty)
            const Text('Refresh failed. Showing saved employees.'),
          if (c.error != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(c.error!),
              ),
            ),
          if (c.hasPending) ...[
            Text(
              c.canDiscardRejected
                  ? 'The last save was rejected. Retry the saved edit after the service is fixed, or discard it to correct the details.'
                  : 'The employee save has not been confirmed. Retry to confirm the saved edit and unlock editing.',
            ),
            TextButton(
              onPressed: c.busy ? null : c.retry,
              child: const Text('Retry saved edit'),
            ),
            if (c.canDiscardRejected)
              TextButton(
                onPressed: c.busy ? null : _discardRejected,
                child: const Text('Discard rejected change'),
              ),
          ],
          if (!c.busy && c.employees.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No employees to display. Add your first employee when the company workspace is ready.',
              ),
            ),
          for (final row in c.employees.where(
            (row) => '${row['fullName']} ${row['email']} ${row['role']}'
                .toLowerCase()
                .contains(_search),
          ))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.person_outline,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            row['fullName'] as String,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('${row['role']} · ${row['employmentStatus']}'),
                    Text(row['email'] as String? ?? ''),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final section in row['allowedSections'] as List)
                          Chip(label: Text('$section')),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: c.busy || c.hasPending
                              ? null
                              : () => _edit(row),
                          child: const Text('Edit permissions'),
                        ),
                        for (final action in ['issue', 'reset', 'revoke'])
                          TextButton(
                            onPressed:
                                c.busy ||
                                    c.hasPending ||
                                    (action != 'revoke' &&
                                        row['employmentStatus'] != 'ACTIVE')
                                ? null
                                : () => _access(row, action),
                            child: Text(
                              {
                                'issue': 'Issue QR & code',
                                'reset': 'Reset code',
                                'revoke': 'Revoke access',
                              }[action]!,
                            ),
                          ),
                        if (widget.onDocuments != null)
                          TextButton(
                            onPressed: c.busy || c.hasPending
                                ? null
                                : () => widget.onDocuments!(row),
                            child: const Text('Documents'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _EmployeeEditor extends StatefulWidget {
  const _EmployeeEditor({this.employee});
  final Map<String, dynamic>? employee;
  @override
  State<_EmployeeEditor> createState() => _EmployeeEditorState();
}

class _EmployeeEditorState extends State<_EmployeeEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.employee?['fullName'] as String? ?? '',
  );
  late final email = TextEditingController(
    text: widget.employee?['email'] as String? ?? '',
  );
  late String role = widget.employee?['role'] as String? ?? 'Staff';
  late String status =
      widget.employee?['employmentStatus'] as String? ?? 'ACTIVE';
  late final Set<String> sections = Set<String>.from(
    widget.employee?['allowedSections'] as List? ?? [],
  );
  late final Set<String> writableSections = Set<String>.from(
    widget.employee?['writableSections'] as List? ?? [],
  );
  bool canGrantEdit(String section) =>
      const [
        'Customers',
        'Invoices',
        'Quotations',
        'Income & Expenses',
        'Payroll',
        'Fixed Assets',
        'Capital & Equity',
        'Balance Sheet',
        'Settings',
      ].contains(section) &&
      !(role == 'Staff' &&
          const [
            'Income & Expenses',
            'Payroll',
            'Fixed Assets',
          ].contains(section));
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: Text(widget.employee == null ? 'Add employee' : 'Edit employee'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a name.' : null,
              ),
              TextFormField(
                controller: email,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
                validator: (v) =>
                    v != null &&
                        v.trim().isNotEmpty &&
                        !RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v.trim())
                    ? 'Enter a valid email.'
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final r in ['Staff', 'Manager', 'Accountant'])
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) => setState(() {
                  role = v!;
                  writableSections.removeWhere((s) => !canGrantEdit(s));
                }),
              ),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: 'Employment status',
                ),
                items: [
                  for (final s in ['ACTIVE', 'INACTIVE'])
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => status = v!),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select sections to allow viewing; enable the switch to allow editing. Staff access remains limited to their own records where required.',
              ),
              for (final section in employeeSections)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(section),
                  value: sections.contains(section),
                  subtitle: Text(
                    writableSections.contains(section)
                        ? 'View and edit'
                        : 'View only',
                  ),
                  secondary: canGrantEdit(section) && sections.contains(section)
                      ? Switch(
                          value: writableSections.contains(section),
                          onChanged: (value) => setState(() {
                            if (value) {
                              writableSections.add(section);
                            } else {
                              writableSections.remove(section);
                            }
                          }),
                        )
                      : null,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      sections.add(section);
                    } else {
                      sections.remove(section);
                      writableSections.remove(section);
                    }
                  }),
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
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, <String, Object?>{
              'fullName': name.text.trim(),
              'email': email.text.trim(),
              'role': role,
              'employmentStatus': status,
              'allowedSections': sections.toList(),
              'writableSections': writableSections.toList(),
              'expectedVersion': widget.employee == null
                  ? 0
                  : int.parse('${widget.employee!['recordVersion']}'),
            });
          }
        },
        child: const Text('Save permissions'),
      ),
    ],
  );
}
