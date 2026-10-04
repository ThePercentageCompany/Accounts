import 'mobile_components.dart';
import 'document_editor.dart';
import 'package:flutter/material.dart';

class InvoiceEditor extends StatelessWidget {
  const InvoiceEditor({
    super.key,
    required this.customers,
    this.record,
    this.items = const [],
    this.company = const {},
  });
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic>? record;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> company;
  @override
  Widget build(BuildContext context) => DocumentEditor(
    quotation: false,
    customers: customers,
    record: record,
    items: items,
    company: company,
  );
}

class InvoiceLineEditor extends StatefulWidget {
  const InvoiceLineEditor({super.key, required this.invoices, this.record});
  final List<Map<String, dynamic>> invoices;
  final Map<String, dynamic>? record;
  @override
  State<InvoiceLineEditor> createState() => _InvoiceLineEditorState();
}

class _InvoiceLineEditorState extends State<InvoiceLineEditor> {
  final form = GlobalKey<FormState>();
  late String? invoiceId = widget.record?['invoiceId'] as String?;
  late final fields = <String, TextEditingController>{
    for (final key in [
      'lineNumber',
      'description',
      'quantity',
      'unitPrice',
      'discount',
      'taxRate',
    ])
      key: TextEditingController(
        text:
            '${widget.record?[key] ?? (key == 'quantity'
                    ? '1'
                    : ['discount', 'taxRate'].contains(key)
                    ? '0'
                    : '')}',
      ),
  };
  @override
  void dispose() {
    for (final value in fields.values) {
      value.dispose();
    }
    super.dispose();
  }

  String? validateNumber(String key, String? input) {
    final value = input?.trim() ?? '';
    if (key == 'lineNumber') {
      final number = int.tryParse(value);
      return number != null && number > 0
          ? null
          : 'Enter a positive whole number.';
    }
    final number = double.tryParse(value);
    if (number == null ||
        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value) ||
        (['quantity', 'unitPrice'].contains(key) && number <= 0) ||
        (key == 'taxRate' && number > 100)) {
      return 'Enter a valid amount, up to two decimals.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: Text(
      widget.record == null ? 'Add invoice line' : 'Edit invoice line',
    ),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableRecordField(
                initialValue: invoiceId,
                decoration: const InputDecoration(labelText: 'Draft invoice'),
                items: [
                  for (final invoice in widget.invoices)
                    DropdownMenuItem(
                      value: invoice['recordId'] as String,
                      child: Text(
                        '${invoice['number']?.toString().isNotEmpty == true ? invoice['number'] : invoice['issueDate']}',
                      ),
                    ),
                ],
                onChanged: widget.record == null
                    ? (value) => invoiceId = value
                    : null,
                validator: (value) =>
                    value == null ? 'Choose an invoice.' : null,
              ),
              LineEstimate(fields: fields),
              for (final key in fields.keys)
                TextFormField(
                  controller: fields[key],
                  keyboardType:
                      [
                        'quantity',
                        'unitPrice',
                        'discount',
                        'taxRate',
                        'lineNumber',
                      ].contains(key)
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  textInputAction: TextInputAction.next,
                  maxLength: key == 'description' ? 1000 : 30,
                  decoration: InputDecoration(
                    labelText: switch (key) {
                      'lineNumber' => 'Line number',
                      'description' => 'Description',
                      'quantity' => 'Quantity',
                      'unitPrice' => 'Unit price',
                      'discount' => 'Discount',
                      _ => 'Tax rate (%)',
                    },
                  ),
                  validator: key == 'description'
                      ? (value) => (value?.trim().isEmpty ?? true)
                            ? 'Enter a description.'
                            : null
                      : (value) => validateNumber(key, value),
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
          if (!form.currentState!.validate()) return;
          Navigator.pop(context, <String, Object?>{
            'invoiceId': invoiceId!,
            'lineNumber': int.parse(fields['lineNumber']!.text),
            'description': fields['description']!.text.trim(),
            for (final key in ['quantity', 'unitPrice', 'discount', 'taxRate'])
              key: double.parse(fields[key]!.text),
          });
        },
        child: const Text('Save line'),
      ),
    ],
  );
}
