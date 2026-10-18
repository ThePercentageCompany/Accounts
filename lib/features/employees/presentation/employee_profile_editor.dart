import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

class EmployeeProfileEditor extends StatefulWidget {
  const EmployeeProfileEditor(
      {super.key,
      required this.api,
      required this.companyId,
      required this.record});
  final SaasApi api;
  final String companyId;
  final Map<String, dynamic> record;
  @override
  State<EmployeeProfileEditor> createState() => _EmployeeProfileEditorState();
}

class _EmployeeProfileEditorState extends State<EmployeeProfileEditor> {
  final form = GlobalKey<FormState>();
  final operationId = const Uuid().v4();
  late final fields = {
    for (final key in [
      'fullName',
      'email',
      'phone',
      'department',
      'designation'
    ])
      key: TextEditingController(text: '${widget.record[key] ?? ''}')
  };
  bool busy = false, submitted = false;
  String? error;
  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      submitted = true;
      error = null;
    });
    try {
      await widget.api.updateEmployeeProfile(
          widget.companyId,
          widget.record['recordId'],
          {
            for (final field in fields.entries)
              field.key: field.value.text.trim(),
            'expectedVersion': widget.record['recordVersion'],
          },
          operationId);
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = '$failure';
          if (failure is SaasApiException &&
              [400, 403, 409].contains(failure.status)) {
            submitted = false;
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: const Text('Edit employee'),
        content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
                child: Form(
                    key: form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final field in fields.entries)
                        TextFormField(
                            controller: field.value,
                            enabled: !busy && !submitted,
                            maxLength: field.key == 'fullName' ? 160 : 200,
                            decoration: InputDecoration(
                                labelText: const {
                              'fullName': 'Full name',
                              'email': 'Email',
                              'phone': 'Phone',
                              'department': 'Department',
                              'designation': 'Designation'
                            }[field.key]),
                            validator: (value) {
                              if (field.key == 'fullName' &&
                                  (value ?? '').trim().isEmpty) {
                                return 'Enter the employee name.';
                              }
                              if (field.key == 'email' &&
                                  (value ?? '').trim().isNotEmpty &&
                                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(value!.trim())) {
                                return 'Enter a valid email.';
                              }
                              return null;
                            }),
                      if (error != null)
                        Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      if (busy) const LinearProgressIndicator(),
                    ])))),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: busy ? null : save,
              child: Text(submitted ? 'Retry / confirm' : 'Save'))
        ],
      ));
}
