import 'package:tpc_invoice/core/widgets/forms/validated_text_field.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/widgets/forms/currency_selector.dart';

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
    'preferredCurrency': 'Preferred currency (AED, INR, GBP; optional)',
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
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title: Text(widget.record == null ? 'Add customer' : 'Edit customer'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: PopupFormFields(
                children: [
                  for (final field in _fields.entries)
                    if (field.key == 'preferredCurrency')
                      CurrencySelector(
                          controller: controllers[field.key]!,
                          label: 'Preferred currency',
                          optional: true)
                    else
                      ValidatedTextField(
                        controller: controllers[field.key],
                        kind: AppValidators.kindForKey(field.key),
                        required: field.key == 'name',
                        keyboardType: field.key == 'email'
                            ? TextInputType.emailAddress
                            : field.key == 'phone'
                                ? TextInputType.phone
                                : TextInputType.text,
                        textInputAction: TextInputAction.next,
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
                              !AppValidators.emailPattern.hasMatch(v.trim())) {
                            return 'Enter a valid email.';
                          }
                          if (field.key == 'preferredCurrency' &&
                              (v?.trim().isNotEmpty ?? false) &&
                              !RegExp(r'^[A-Z]{3}$')
                                  .hasMatch(v!.trim().toUpperCase())) {
                            return 'Enter a three-letter currency code.';
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
                  for (final field in controllers.entries)
                    field.key: field.key == 'preferredCurrency'
                        ? field.value.text.trim().toUpperCase()
                        : field.value.text.trim(),
                });
              }
            },
            child: const Text('Save customer'),
          ),
        ],
      );
}
