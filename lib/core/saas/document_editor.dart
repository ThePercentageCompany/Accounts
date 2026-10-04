import 'package:flutter/material.dart';
import 'package:invoice_kit/invoice_kit.dart' as kit;
import 'invoice_document.dart';
import 'mobile_components.dart';

class DocumentEditor extends StatefulWidget {
  const DocumentEditor({
    super.key,
    required this.quotation,
    required this.customers,
    this.record,
    this.items = const [],
    this.company = const {},
  });
  final bool quotation;
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic>? record;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> company;
  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DraftLine {
  _DraftLine([Map<String, dynamic> values = const {}])
      : productId = values['productId'] as String?,
        fields = {
          for (final key in [
            'description',
            'quantity',
            'unitPrice',
            'discount',
            'taxRate',
          ])
            key: TextEditingController(
              text:
                  '${values[key] ?? (key == 'quantity' ? '1' : key == 'taxRate' ? '5' : key == 'discount' ? '0' : '')}',
            ),
        };
  final Map<String, TextEditingController> fields;
  final String? productId;
  Map<String, dynamic> get values => {
        if (productId?.isNotEmpty == true) 'productId': productId,
        'description': fields['description']!.text.trim(),
        for (final key in ['quantity', 'unitPrice', 'discount', 'taxRate'])
          key: num.tryParse(fields[key]!.text) ?? 0,
      };
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
  }
}

class _DocumentEditorState extends State<DocumentEditor> {
  final form = GlobalKey<FormState>();
  late String? customerId = widget.record?['customerId'] as String?;
  late final issueDate = TextEditingController(
    text:
        '${widget.record?['issueDate'] ?? DateTime.now().toIso8601String().substring(0, 10)}',
  );
  String get endKey => widget.quotation ? 'validUntil' : 'dueDate';
  late final endDate = TextEditingController(
    text:
        '${widget.record?[endKey] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10)}',
  );
  late final currency = TextEditingController(
    text:
        '${widget.record?['currency'] ?? widget.company['currency'] ?? 'AED'}',
  );
  late final notes = TextEditingController(
    text: '${widget.record?['notes'] ?? ''}',
  );
  late final terms = TextEditingController(
    text: '${widget.record?['paymentTerms'] ?? ''}',
  );
  late final lines = widget.items.isEmpty
      ? [_DraftLine()]
      : widget.items.map(_DraftLine.new).toList();
  final retired = <_DraftLine>[];
  DocumentStyle style = DocumentStyle.modern;
  bool preview = false;
  String get title => widget.quotation ? 'quotation' : 'invoice';
  List<Map<String, dynamic>> get values =>
      lines.map((line) => line.values).toList();
  Map<String, dynamic> get header => {
        if (widget.record != null) ...widget.record!,
        'customerId': customerId,
        'issueDate': issueDate.text,
        endKey: endDate.text,
        'currency': currency.text.trim().toUpperCase(),
        'notes': notes.text.trim(),
        'paymentTerms': terms.text.trim(),
      };
  Map<String, dynamic> get customer =>
      widget.customers
          .where((row) => row['recordId'] == customerId)
          .firstOrNull ??
      {};
  bool validDate(String value) {
    final parsed = DateTime.tryParse(value);
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
        parsed != null &&
        parsed.toIso8601String().startsWith(value);
  }

  String? number(_DraftLine line, String key, String? input) {
    final text = input?.trim() ?? '';
    final value = num.tryParse(text);
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text) ||
        value == null ||
        value > 1e12 ||
        (key == 'quantity' && value <= 0) ||
        (key == 'taxRate' && value > 100)) {
      return key == 'taxRate'
          ? 'Use 0 to 100%.'
          : 'Use a valid amount (2 decimals).';
    }
    if (key == 'discount') {
      final subtotal = estimateDocument([
        {...line.values, 'discount': 0, 'taxRate': 0},
      ])['subtotal']!;
      if (value > subtotal) return 'Discount exceeds line amount.';
    }
    return null;
  }

  @override
  void dispose() {
    for (final field in [issueDate, endDate, currency, notes, terms]) {
      field.dispose();
    }
    for (final line in [...lines, ...retired]) {
      line.dispose();
    }
    super.dispose();
  }

  Widget section(String name, {Widget? action}) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(name, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (action != null) action,
          ],
        ),
      );

  Widget lineCard(_DraftLine line, int index) => Card(
        key: ObjectKey(line),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Item ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move item up',
                    onPressed: index == 0
                        ? null
                        : () => setState(() {
                              lines.removeAt(index);
                              lines.insert(index - 1, line);
                            }),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Move item down',
                    onPressed: index == lines.length - 1
                        ? null
                        : () => setState(() {
                              lines.removeAt(index);
                              lines.insert(index + 1, line);
                            }),
                    icon: const Icon(Icons.arrow_downward, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Duplicate item',
                    onPressed: lines.length == 100
                        ? null
                        : () => setState(() {
                              lines.insert(index + 1, _DraftLine(line.values));
                            }),
                    icon: const Icon(Icons.copy_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Remove item',
                    onPressed: lines.length == 1
                        ? null
                        : () => setState(() {
                              retired.add(lines.removeAt(index));
                            }),
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              ),
              TextFormField(
                controller: line.fields['description'],
                maxLength: 1000,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) => value?.trim().isNotEmpty == true
                    ? null
                    : 'Enter a description.',
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth < 460
                      ? (constraints.maxWidth - 12) / 2
                      : (constraints.maxWidth - 36) / 4;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final entry in {
                        'quantity': 'Quantity',
                        'unitPrice': 'Unit price',
                        'discount': 'Discount amount',
                        'taxRate': 'VAT (%)',
                      }.entries)
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            controller: line.fields[entry.key],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(labelText: entry.value),
                            validator: (value) =>
                                number(line, entry.key, value),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              ListenableBuilder(
                listenable: Listenable.merge(line.fields.values.toList()),
                builder: (context, _) => Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Line total: ${currency.text.toUpperCase()} ${estimateDocument([
                          line.values
                        ])['total']!.toStringAsFixed(2)}',
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget summary() => ListenableBuilder(
        listenable: Listenable.merge([
          currency,
          for (final line in lines) ...line.fields.values,
        ]),
        builder: (context, _) {
          final totals = estimateDocument(values);
          return Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final entry in {
                    'subtotal': 'Subtotal',
                    'discount': 'Discount',
                    'taxAmount': 'VAT',
                    'total': 'Estimated total',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                fontWeight: entry.key == 'total'
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                          ),
                          Text(
                            '${currency.text.toUpperCase()} ${totals[entry.key]!.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );

  Widget editor() => SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              section('Customer & dates'),
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
                onChanged: (value) => setState(() => customerId = value),
                validator: (value) =>
                    value == null ? 'Choose a customer.' : null,
              ),
              if (customer.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    [
                      customer['address'],
                      customer['email'],
                      if ('${customer['taxNumber'] ?? ''}'.isNotEmpty)
                        'TRN: ${customer['taxNumber']}',
                    ].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
                  ),
                ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fields = <Widget>[
                    CalendarFormField(
                      controller: issueDate,
                      decoration:
                          const InputDecoration(labelText: 'Issue date'),
                      validator: (value) => validDate(value ?? '')
                          ? null
                          : 'Select a valid issue date.',
                    ),
                    const SizedBox(height: 12),
                    CalendarFormField(
                      controller: endDate,
                      optional: !widget.quotation,
                      decoration: InputDecoration(
                        labelText: widget.quotation
                            ? 'Valid until'
                            : 'Due date (optional)',
                      ),
                      validator: (value) =>
                          !widget.quotation && (value?.isEmpty ?? true)
                              ? null
                              : validDate(value ?? '') &&
                                      value!.compareTo(issueDate.text) >= 0
                                  ? null
                                  : widget.quotation
                                      ? 'Valid until cannot precede issue date.'
                                      : 'Due date cannot precede issue date.',
                    ),
                  ];
                  if (constraints.maxWidth < 600) {
                    return Column(children: fields);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: fields.first),
                      const SizedBox(width: 12),
                      Expanded(child: fields.last),
                    ],
                  );
                },
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final days in [7, 14, 30, 60])
                    ActionChip(
                      label: Text('$days days'),
                      labelStyle:
                          Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                      onPressed: () {
                        final date = DateTime.tryParse(issueDate.text);
                        if (date != null) {
                          endDate.text = date
                              .add(Duration(days: days))
                              .toIso8601String()
                              .substring(0, 10);
                        }
                      },
                    ),
                ],
              ),
              CurrencyFormField(
                controller: currency,
                onChanged: () => setState(() {}),
              ),
              section(
                'Items',
                action: TextButton.icon(
                  key: const Key('add-document-item'),
                  onPressed: lines.length == 100
                      ? null
                      : () => setState(() => lines.add(_DraftLine())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
              ),
              for (var i = 0; i < lines.length; i++) lineCard(lines[i], i),
              summary(),
              section('Notes & terms'),
              TextFormField(
                controller: notes,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              TextFormField(
                controller: terms,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Payment terms'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final text in [
                    'Payment due within 30 days.',
                    '50% advance, balance on completion.',
                  ])
                    ActionChip(
                      label: Text(text),
                      labelStyle:
                          Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                      onPressed: () => terms.text = text,
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title:
            Text('${widget.record == null ? 'Create' : 'Edit'} draft $title'),
        content: SizedBox(
          width: 820,
          height: 620,
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.edit_outlined),
                        label: Text('Edit'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.picture_as_pdf_outlined),
                        label: Text('Preview'),
                      ),
                    ],
                    selected: {preview},
                    onSelectionChanged: (selected) {
                      if (selected.first && !form.currentState!.validate()) {
                        return;
                      }
                      setState(() => preview = selected.first);
                    },
                  ),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<DocumentStyle>(
                      isExpanded: true,
                      initialValue: style,
                      decoration: const InputDecoration(labelText: 'PDF style'),
                      items: const [
                        DropdownMenuItem(
                          value: DocumentStyle.modern,
                          child: Text('Modern'),
                        ),
                        DropdownMenuItem(
                          value: DocumentStyle.classic,
                          child: Text('Classic'),
                        ),
                      ],
                      onChanged: (value) => setState(() => style = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: preview
                    ? kit.InvoiceGenerator.preview(
                        data: documentData(
                          quotation: widget.quotation,
                          record: header,
                          company: widget.company,
                          customer: customer,
                          items: values,
                          estimate: true,
                        ),
                        template: BusinessDocumentTemplate(style: style),
                      )
                    : editor(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (preview) {
                setState(() => preview = false);
                return;
              }
              if (!form.currentState!.validate()) return;
              Navigator.pop(context, <String, Object?>{
                'customerId': customerId!,
                'issueDate': issueDate.text,
                endKey: endDate.text,
                'currency': currency.text.trim().toUpperCase(),
                'notes': notes.text.trim(),
                'paymentTerms': terms.text.trim(),
                'items': values,
              });
            },
            child: Text(preview ? 'Back to editing' : 'Save draft'),
          ),
        ],
      );
}
