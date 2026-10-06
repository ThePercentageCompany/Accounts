import 'package:tpc_invoice/core/widgets/forms/validated_text_field.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:tpc_invoice/core/widgets/forms/category_field.dart';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/widgets/forms/payment_method_dropdown.dart';

class CashEntryEditor extends StatefulWidget {
  const CashEntryEditor({super.key, required this.expense, this.record});
  final bool expense;
  final Map<String, dynamic>? record;
  @override
  State<CashEntryEditor> createState() => _CashEntryEditorState();
}

class _CashEntryEditorState extends State<CashEntryEditor> {
  final _form = GlobalKey<FormState>();
  late final fields = {
    for (final key in [
      'date',
      'description',
      'category',
      'supplier',
      'amount',
      'taxRate',
      'paidDate',
      'dueDate',
      'account',
      'reference',
    ])
      key: TextEditingController(
        text:
            '${widget.record?[key] ?? (key == 'taxRate' ? '0' : key == 'date' ? DateTime.now().toIso8601String().substring(0, 10) : '')}',
      ),
  };
  late String? status = widget.record == null
      ? 'UNPAID'
      : switch ('${widget.record?['paymentStatus'] ?? ''}'.toUpperCase()) {
          'PAID' => 'PAID',
          'UNPAID' => 'UNPAID',
          _ => null,
        };
  static const labels = {
    'date': 'Entry date',
    'description': 'Description',
    'category': 'Category',
    'supplier': 'Supplier',
    'amount': 'Amount before tax',
    'taxRate': 'Tax rate (%)',
    'paidDate': 'Payment date',
    'dueDate': 'Due date (optional)',
    'account': 'Account',
    'reference': 'Reference',
  };
  String? _validate(String key, String? input) {
    final value = (input ?? '').trim();
    if (key == 'description' && value.isEmpty) return 'Enter a description.';
    if (['date', 'paidDate', 'dueDate'].contains(key)) {
      if (value.isEmpty &&
          (key == 'dueDate' || key == 'paidDate' && status != 'PAID')) {
        return null;
      }
      final date = DateTime.tryParse(value);
      if (!AppValidators.datePattern.hasMatch(value) ||
          date == null ||
          date.toIso8601String().substring(0, 10) != value) {
        return 'Use a valid YYYY-MM-DD date.';
      }
    }
    if (key == 'amount' || key == 'taxRate') {
      final number = double.tryParse(value);
      if (!AppValidators.decimalPattern.hasMatch(value) ||
          number == null ||
          number > (key == 'taxRate' ? 100 : 1e12) ||
          (key == 'amount' && number <= 0)) {
        return key == 'taxRate'
            ? 'Enter a rate from 0 to 100, up to two decimals.'
            : 'Enter a positive amount, up to two decimals.';
      }
    }
    return null;
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title: Text(
          '${widget.record == null ? 'Add' : 'Edit'} ${widget.expense ? 'expense' : 'income'}',
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: PopupFormFields(
                children: [
                  const Text(
                    'Tax and total are calculated by your company service when saved.',
                  ),
                  for (final key in [
                    'date',
                    'description',
                    'category',
                    if (widget.expense) 'supplier',
                    'amount',
                    'taxRate',
                  ])
                    _field(key),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration:
                        const InputDecoration(labelText: 'Payment status'),
                    validator: (value) =>
                        value == null ? 'Choose a payment status.' : null,
                    items: const [
                      DropdownMenuItem(value: 'UNPAID', child: Text('Unpaid')),
                      DropdownMenuItem(value: 'PAID', child: Text('Paid')),
                    ],
                    onChanged: (v) => setState(() => status = v!),
                  ),
                  if (status == 'PAID') _field('paidDate'),
                  _field('dueDate'),
                  _field('account'),
                  _field('reference'),
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
                for (final key in [
                  'date',
                  'description',
                  'category',
                  if (widget.expense) 'supplier',
                  'dueDate',
                  'account',
                  'reference',
                ])
                  key: fields[key]!.text.trim(),
                'amount': double.parse(fields['amount']!.text.trim()),
                'taxRate': double.parse(fields['taxRate']!.text.trim()),
                'paymentStatus': status,
                'paidDate':
                    status == 'PAID' ? fields['paidDate']!.text.trim() : '',
              });
            },
            child: const Text('Save entry'),
          ),
        ],
      );
  Widget _field(String key) => key == 'account'
      ? PaymentMethodDropdown(
          value: fields[key]!.text,
          required: false,
          allowLegacyValue: true,
          decoration: InputDecoration(labelText: labels[key]),
          onChanged: (value) => fields[key]!.text = value ?? '',
        )
      : key == 'category'
          ? CategoryFormField(
              controller: fields[key]!,
              kind: widget.expense ? CategoryKind.expense : CategoryKind.income,
            )
          : ['date', 'paidDate', 'dueDate'].contains(key)
              ? CalendarFormField(
                  controller: fields[key]!,
                  optional: key == 'dueDate',
                  decoration: InputDecoration(labelText: labels[key]),
                  validator: (value) => _validate(key, value),
                )
              : ValidatedTextField(
                  controller: fields[key],
                  required:
                      const ['description', 'amount', 'taxRate'].contains(key),
                  kind: AppValidators.kindForKey(key),
                  decoration: InputDecoration(labelText: labels[key]),
                  maxLength: key == 'description' ? 1000 : 200,
                  validator: (value) => _validate(key, value),
                  keyboardType: ['amount', 'taxRate'].contains(key)
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                );
}
