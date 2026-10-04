import 'mobile_components.dart';
import 'package:flutter/material.dart';

bool _date(String value) {
  final parsed = DateTime.tryParse(value);
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      parsed != null &&
      parsed.toIso8601String().startsWith(value);
}

class QuotationEditor extends StatefulWidget {
  const QuotationEditor({super.key, required this.customers, this.record});
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic>? record;
  @override
  State<QuotationEditor> createState() => _QuotationEditorState();
}

class _QuotationEditorState extends State<QuotationEditor> {
  final form = GlobalKey<FormState>();
  late String? customerId = widget.record?['customerId'] as String?;
  late final fields = <String, TextEditingController>{
    'issueDate': TextEditingController(
      text:
          '${widget.record?['issueDate'] ?? DateTime.now().toIso8601String().substring(0, 10)}',
    ),
    'validUntil': TextEditingController(
      text:
          '${widget.record?['validUntil'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10)}',
    ),
    'currency': TextEditingController(
      text: '${widget.record?['currency'] ?? 'AED'}',
    ),
    'notes': TextEditingController(text: '${widget.record?['notes'] ?? ''}'),
    'paymentTerms': TextEditingController(
      text: '${widget.record?['paymentTerms'] ?? ''}',
    ),
  };
  @override
  void dispose() {
    for (final value in fields.values) {
      value.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title: Text(
          widget.record == null
              ? 'Create draft quotation'
              : 'Edit draft quotation',
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
                    initialValue: customerId,
                    decoration: const InputDecoration(labelText: 'Customer'),
                    items: [
                      for (final row in widget.customers)
                        DropdownMenuItem(
                          value: row['recordId'] as String,
                          child: Text('${row['name']}'),
                        ),
                    ],
                    onChanged: (value) => customerId = value,
                    validator: (value) =>
                        value == null ? 'Choose a customer.' : null,
                  ),
                  for (final key in fields.keys)
                    TextFormField(
                      controller: fields[key],
                      keyboardType: [
                        'quantity',
                        'unitPrice',
                        'discount',
                        'taxRate',
                        'lineNumber'
                      ].contains(key)
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      textInputAction: TextInputAction.next,
                      readOnly: MediaQuery.sizeOf(context).width < 600 &&
                          ['issueDate', 'dueDate', 'validUntil'].contains(key),
                      onTap:
                          ['issueDate', 'dueDate', 'validUntil'].contains(key)
                              ? () => pickControllerDate(context, fields[key]!)
                              : null,
                      maxLength: const ['notes', 'paymentTerms'].contains(key)
                          ? 1000
                          : 20,
                      decoration: InputDecoration(
                        suffixIcon: ['issueDate', 'dueDate', 'validUntil']
                                .contains(key)
                            ? IconButton(
                                tooltip: 'Select date',
                                icon: const Icon(Icons.calendar_today_outlined),
                                onPressed: () =>
                                    pickControllerDate(context, fields[key]!),
                              )
                            : null,
                        labelText: switch (key) {
                          'issueDate' => 'Issue date',
                          'validUntil' => 'Valid until',
                          'currency' => 'Currency',
                          'notes' => 'Notes',
                          _ => 'Payment terms',
                        },
                      ),
                      validator: (input) {
                        final value = input?.trim() ?? '';
                        if (key == 'issueDate' && !_date(value)) {
                          return 'Enter a valid date.';
                        }
                        if (key == 'validUntil' &&
                            (!_date(value) ||
                                value.compareTo(
                                        fields['issueDate']!.text.trim()) <
                                    0)) {
                          return 'Valid until cannot precede issue date.';
                        }
                        if (key == 'currency' &&
                            !RegExp(r'^[A-Z]{3}$')
                                .hasMatch(value.toUpperCase())) {
                          return 'Use a three-letter currency code.';
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
              if (!form.currentState!.validate()) return;
              Navigator.pop(context, <String, Object?>{
                'customerId': customerId!,
                'issueDate': fields['issueDate']!.text.trim(),
                'validUntil': fields['validUntil']!.text.trim(),
                'currency': fields['currency']!.text.trim().toUpperCase(),
                'notes': fields['notes']!.text.trim(),
                'paymentTerms': fields['paymentTerms']!.text.trim(),
              });
            },
            child: const Text('Save draft'),
          ),
        ],
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
        text: '${widget.record?[key] ?? (key == 'quantity' ? '1' : const [
            'discount',
            'taxRate'
          ].contains(key) ? '0' : '')}',
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
                    decoration:
                        const InputDecoration(labelText: 'Draft quotation'),
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
                      keyboardType: [
                        'quantity',
                        'unitPrice',
                        'discount',
                        'taxRate',
                        'lineNumber'
                      ].contains(key)
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      textInputAction: TextInputAction.next,
                      readOnly: MediaQuery.sizeOf(context).width < 600 &&
                          ['issueDate', 'dueDate', 'validUntil'].contains(key),
                      onTap:
                          ['issueDate', 'dueDate', 'validUntil'].contains(key)
                              ? () => pickControllerDate(context, fields[key]!)
                              : null,
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
                for (final key in [
                  'quantity',
                  'unitPrice',
                  'discount',
                  'taxRate'
                ])
                  key: double.parse(fields[key]!.text),
              });
            },
            child: const Text('Save line'),
          ),
        ],
      );
}
