import 'package:tpc_invoice/core/widgets/forms/validated_text_field.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:flutter/material.dart';

class ProjectEditor extends StatefulWidget {
  const ProjectEditor({super.key, this.record});
  final Map<String, dynamic>? record;
  @override
  State<ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends State<ProjectEditor> {
  final _form = GlobalKey<FormState>();
  static const _fields = {'name': 'Project name', 'description': 'Description'};
  late final controllers = {
    for (final key in _fields.keys)
      key: TextEditingController(text: '${widget.record?[key] ?? ''}'),
  };
  late String _status = widget.record?['status']?.toString() ?? 'ACTIVE';
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title: Text(widget.record == null ? 'Add project' : 'Edit project'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: PopupFormFields(
                children: [
                  DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                            value: 'ACTIVE', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'ARCHIVED', child: Text('Archived'))
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _status = value);
                      }),
                  for (final field in _fields.entries)
                    ValidatedTextField(
                      controller: controllers[field.key],
                      kind: AppValidators.kindForKey(field.key),
                      required: field.key == 'name',
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      maxLength: field.key == 'description' ? 1000 : 200,
                      maxLines: field.key == 'description' ? 3 : 1,
                      decoration: InputDecoration(labelText: field.value),
                      validator: (v) {
                        if (field.key == 'name' &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Enter a project name.';
                        }
                        return null;
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          LoadingButton.text(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          LoadingButton(
            onPressed: () {
              if (AppFormValidation.validate(_form.currentState!)) {
                Navigator.pop(context, <String, Object?>{
                  'status': _status,
                  for (final field in controllers.entries)
                    field.key: field.value.text.trim(),
                });
              }
            },
            child: const Text('Save project'),
          ),
        ],
      );
}
