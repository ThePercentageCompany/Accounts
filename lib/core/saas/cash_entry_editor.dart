import 'package:flutter/material.dart';

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
            '${widget.record?[key] ?? (key == 'taxRate'
                    ? '0'
                    : key == 'date'
                    ? DateTime.now().toIso8601String().substring(0, 10)
                    : '')}',
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
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
          date == null ||
          date.toIso8601String().substring(0, 10) != value) {
        return 'Use a valid YYYY-MM-DD date.';
      }
    }
    if (key == 'amount' || key == 'taxRate') {
      final number = double.tryParse(value);
      if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value) ||
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      '${widget.record == null ? 'Add' : 'Edit'} ${widget.expense ? 'expense' : 'income'}',
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                decoration: const InputDecoration(labelText: 'Payment status'),
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
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
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
            'paidDate': status == 'PAID' ? fields['paidDate']!.text.trim() : '',
          });
        },
        child: const Text('Save entry'),
      ),
    ],
  );
  Widget _field(String key) => TextFormField(
    controller: fields[key],
    decoration: InputDecoration(labelText: labels[key]),
    maxLength: key == 'description' ? 1000 : 200,
    validator: (value) => _validate(key, value),
    keyboardType: ['amount', 'taxRate'].contains(key)
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
  );
}
