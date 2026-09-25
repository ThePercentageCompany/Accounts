import 'package:flutter/material.dart';

class CustomerEditor extends StatefulWidget {
  const CustomerEditor({super.key, this.record});
  final Map<String, dynamic>? record;
  @override
  State<CustomerEditor> createState() => _CustomerEditorState();
}

class _CustomerEditorState extends State<CustomerEditor> {
  final _form = GlobalKey<FormState>();
  static const _fields = {
    'name': 'Customer name',
    'email': 'Email',
    'phone': 'Phone',
    'taxNumber': 'Tax number',
    'address': 'Address',
  };
  late final controllers = {
    for (final key in _fields.keys)
      key: TextEditingController(text: '${widget.record?[key] ?? ''}'),
  };
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.record == null ? 'Add customer' : 'Edit customer'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in _fields.entries)
                TextFormField(
                  controller: controllers[field.key],
                  maxLength: field.key == 'address' ? 1000 : 200,
                  decoration: InputDecoration(labelText: field.value),
                  validator: (v) {
                    if (field.key == 'name' &&
                        (v == null || v.trim().isEmpty)) {
                      return 'Enter a customer name.';
                    }
                    if (field.key == 'email' &&
                        v != null &&
                        v.trim().isNotEmpty &&
                        !RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v.trim())) {
                      return 'Enter a valid email.';
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
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, <String, Object?>{
              for (final field in controllers.entries)
                field.key: field.value.text.trim(),
            });
          }
        },
        child: const Text('Save customer'),
      ),
    ],
  );
}
