import 'package:tpc_invoice/core/widgets/forms/payment_method_dropdown.dart';
import 'package:tpc_invoice/core/widgets/forms/validated_text_field.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:flutter/material.dart';

class CashPaymentEditor extends StatefulWidget {
  const CashPaymentEditor({super.key, required this.total});
  final Object? total;
  @override
  State<CashPaymentEditor> createState() => _CashPaymentEditorState();
}

class _CashPaymentEditorState extends State<CashPaymentEditor> {
  final _form = GlobalKey<FormState>();
  final _date = TextEditingController();
  final _reference = TextEditingController();
  String? _account;
  @override
  void dispose() {
    _date.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title: const Text('Record full payment'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: PopupFormFields(
                children: [
                  Text(
                    'Pay the full outstanding amount: ${widget.total}. This posts the payment to the ledger. Partial payments and reversals are not available yet.',
                  ),
                  CalendarFormField(
                    controller: _date,
                    decoration: const InputDecoration(
                      labelText: 'Payment date (YYYY-MM-DD)',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      final date = DateTime.tryParse(text);
                      return AppValidators.datePattern.hasMatch(text) &&
                              date != null &&
                              date.toIso8601String().startsWith(text)
                          ? null
                          : 'Enter a valid date.';
                    },
                  ),
                  PaymentMethodDropdown(
                    decoration:
                        const InputDecoration(labelText: 'Payment account'),
                    onChanged: (value) => _account = value,
                    validator: (value) =>
                        value == null ? 'Choose an account.' : null,
                  ),
                  ValidatedTextField(
                    controller: _reference,
                    decoration: const InputDecoration(
                      labelText: 'Reference (optional)',
                    ),
                    maxLength: 500,
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
              if (!AppFormValidation.validate(_form.currentState!)) return;
              Navigator.pop(context, <String, Object?>{
                'paidDate': _date.text.trim(),
                'account': _account!,
                'reference': _reference.text.trim(),
              });
            },
            child: const Text('Record payment'),
          ),
        ],
      );
}
