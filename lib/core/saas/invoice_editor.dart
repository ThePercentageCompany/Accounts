import 'mobile_components.dart';
import 'package:flutter/material.dart';

bool _validDate(String value) {
  final date = DateTime.tryParse(value);
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      date != null &&
      date.toIso8601String().startsWith(value);
}

class InvoiceEditor extends StatefulWidget {
  const InvoiceEditor({super.key, required this.customers, this.record});
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic>? record;
  @override
  State<InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends State<InvoiceEditor> {
  final form = GlobalKey<FormState>();
  late String? customerId = widget.record?['customerId'] as String?;
  late final fields = <String, TextEditingController>{
    'issueDate': TextEditingController(
      text:
          '${widget.record?['issueDate'] ?? DateTime.now().toIso8601String().substring(0, 10)}',
    ),
    'dueDate': TextEditingController(
      text: '${widget.record?['dueDate'] ?? ''}',
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
          widget.record == null ? 'Create draft invoice' : 'Edit draft invoice',
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
                    initialValue: customerId,
                    decoration: const InputDecoration(labelText: 'Customer'),
                    items: [
                      for (final customer in widget.customers)
                        DropdownMenuItem(
                          value: customer['recordId'] as String,
                          child: Text('${customer['name']}'),
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
                      maxLength:
                          ['notes', 'paymentTerms'].contains(key) ? 1000 : 20,
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
                          'dueDate' => 'Due date (optional)',
                          'currency' => 'Currency',
                          'notes' => 'Notes',
                          _ => 'Payment terms',
                        },
                      ),
                      validator: (input) {
                        final value = input?.trim() ?? '';
                        if (key == 'issueDate' && !_validDate(value)) {
                          return 'Enter a valid date.';
                        }
                        if (key == 'dueDate' &&
                            value.isNotEmpty &&
                            (!_validDate(value) ||
                                value.compareTo(
                                        fields['issueDate']!.text.trim()) <
                                    0)) {
                          return 'Due date cannot precede issue date.';
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
                'dueDate': fields['dueDate']!.text.trim(),
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
        text: '${widget.record?[key] ?? (key == 'quantity' ? '1' : [
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
                    decoration:
                        const InputDecoration(labelText: 'Draft invoice'),
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
