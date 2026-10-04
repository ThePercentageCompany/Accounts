import 'mobile_components.dart';
import 'document_editor.dart';
import 'package:flutter/material.dart';

class QuotationEditor extends StatelessWidget {
  const QuotationEditor({
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
    quotation: true,
    customers: customers,
    record: record,
    items: items,
    company: company,
  );
}

class QuotationLineEditor extends StatefulWidget {
  const QuotationLineEditor({super.key, required this.quotations, this.record});
  final List<Map<String, dynamic>> quotations;
  final Map<String, dynamic>? record;
  @override
  State<QuotationLineEditor> createState() => _QuotationLineEditorState();
}

class _QuotationLineEditorState extends State<QuotationLineEditor> {
  final form = GlobalKey<FormState>();
  late String? quotationId = widget.record?['quotationId'] as String?;
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
                    : const ['discount', 'taxRate'].contains(key)
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

  String? number(String key, String? input) {
    final text = input?.trim() ?? '';
    if (key == 'lineNumber') {
      return (int.tryParse(text) ?? 0) > 0
          ? null
          : 'Enter a positive whole number.';
    }
    final value = double.tryParse(text);
    return value == null ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text) ||
            (const ['quantity', 'unitPrice'].contains(key) && value <= 0) ||
            (key == 'taxRate' && value > 100)
        ? 'Enter a valid amount, up to two decimals.'
        : null;
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: Text(
      widget.record == null ? 'Add quotation line' : 'Edit quotation line',
    ),
    content: SizedBox(
      width: 520,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableRecordField(
                initialValue: quotationId,
                decoration: const InputDecoration(labelText: 'Draft quotation'),
                items: [
                  for (final row in widget.quotations)
                    DropdownMenuItem(
                      value: row['recordId'] as String,
                      child: Text(
                        '${row['number']?.toString().isNotEmpty == true ? row['number'] : row['issueDate']}',
                      ),
                    ),
                ],
                onChanged: widget.record == null
                    ? (value) => quotationId = value
                    : null,
                validator: (value) =>
                    value == null ? 'Choose a quotation.' : null,
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
                      : (value) => number(key, value),
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
            'quotationId': quotationId!,
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
