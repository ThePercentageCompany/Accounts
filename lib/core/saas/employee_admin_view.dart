import 'package:flutter/material.dart';
import '../widgets/qr_code.dart';
import 'employee_admin_controller.dart';

class EmployeeAdminView extends StatefulWidget {
  const EmployeeAdminView({super.key, required this.controller});
  final EmployeeAdminController controller;
  @override
  State<EmployeeAdminView> createState() => _EmployeeAdminViewState();
}

class _EmployeeAdminViewState extends State<EmployeeAdminView> {
  @override
  void initState() {
    super.initState();
    widget.controller.refresh();
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
      builder: (context) => AlertDialog(
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
        builder: (context) => AlertDialog(
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
      builder: (context) => AlertDialog(
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
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
          if (c.busy) const LinearProgressIndicator(),
          if (c.error != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(c.error!),
              ),
            ),
          if (c.hasPending) ...[
            const Text(
              'An employee change is pending. Retry the same change before making another edit.',
            ),
            TextButton(
              onPressed: c.busy ? null : c.retry,
              child: const Text('Retry pending change'),
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
          for (final row in c.employees)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['fullName'] as String,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
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
                onChanged: (v) => setState(() => role = v!),
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
                'Assigned sections. Staff access remains limited to their own records where required.',
              ),
              for (final section in employeeSections)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(section),
                  value: sections.contains(section),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      sections.add(section);
                    } else {
                      sections.remove(section);
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
