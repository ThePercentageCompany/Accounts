import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:flutter/material.dart';

class CompanyProfileEditor extends StatefulWidget {
  const CompanyProfileEditor({super.key, required this.record});
  final Map<String, dynamic> record;
  @override
  State<CompanyProfileEditor> createState() => _CompanyProfileEditorState();
}

class _CompanyProfileEditorState extends State<CompanyProfileEditor> {
  final form = GlobalKey<FormState>();
  static const fields = {
    'name': 'Company name',
    'address': 'Address',
    'email': 'Email',
    'phone': 'Phone',
    'taxNumber': 'Tax number',
    'currency': 'Accounting currency',
    'invoicePrefix': 'Invoice prefix',
    'quotationPrefix': 'Quotation prefix',
    'bankName': 'Bank name',
    'accountHolder': 'Account holder',
    'accountNumber': 'Account number',
    'iban': 'IBAN',
    'swift': 'SWIFT',
  };
  late final controllers = {
    for (final key in fields.keys)
      key: TextEditingController(text: '${widget.record[key] ?? ''}'),
  };
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: const Text('Edit company profile'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              for (final field in fields.entries)
                if (field.key == 'currency')
                  CurrencyFormField(
                    controller: controllers[field.key]!,
                    label: field.value,
                  )
                else
                  TextFormField(
                    controller: controllers[field.key],
                    maxLength: field.key == 'address' ? 1000 : 200,
                    decoration: InputDecoration(labelText: field.value),
                    validator: (value) {
                      final v = value!.trim();
                      if (field.key == 'name' && v.isEmpty) {
                        return 'Enter a company name.';
                      }
                      if (field.key.endsWith('Prefix') &&
                          v.isNotEmpty &&
                          !RegExp(r'^[A-Z0-9-]{1,12}$').hasMatch(v)) {
                        return 'Use 1–12 uppercase letters, digits or hyphens.';
                      }
                      if (field.key == 'email' &&
                          v.isNotEmpty &&
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
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
          if (form.currentState!.validate()) {
            Navigator.pop(context, <String, Object?>{
              for (final entry in controllers.entries)
                entry.key: entry.value.text.trim(),
            });
          }
        },
        child: const Text('Save profile'),
      ),
    ],
  );
}
