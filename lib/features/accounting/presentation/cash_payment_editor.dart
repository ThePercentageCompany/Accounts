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
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) &&
                          date != null &&
                          date.toIso8601String().startsWith(text)
                      ? null
                      : 'Enter a valid date.';
                },
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Payment account'),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                ],
                onChanged: (value) => _account = value,
                validator: (value) =>
                    value == null ? 'Choose an account.' : null,
              ),
              TextFormField(
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
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
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
