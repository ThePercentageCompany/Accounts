import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/network/draft_navigation_stub.dart'
    if (dart.library.js_interop) 'package:tpc_invoice/core/network/draft_navigation_web.dart';
import 'package:invoice_kit/invoice_kit.dart' as kit;
import 'package:tpc_invoice/features/documents/data/invoice_document.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';

class DocumentEditor extends StatefulWidget {
  const DocumentEditor({
    super.key,
    required this.quotation,
    required this.customers,
    this.record,
    this.items = const [],
    this.company = const {},
    this.onSave,
  });
  final bool quotation;
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic>? record;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> company;
  final Future<void> Function(Map<String, Object?>)? onSave;
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
                '${values[key] ?? (key == 'quantity'
                        ? '1'
                        : key == 'taxRate'
                        ? '5'
                        : key == 'discount'
                        ? '0'
                        : '')}',
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
  bool _saving = false, _allowClose = false;
  String? _saveError;
  late final String _initialDraft;
  late final DraftNavigationGuard _navigationGuard;
  String get _fingerprint => '$header|$values';
  @override
  void initState() {
    super.initState();
    _initialDraft = _fingerprint;
    _navigationGuard = DraftNavigationGuard(
      () => !_allowClose && (_saving || _fingerprint != _initialDraft),
    );
  }

  Future<void> _discard() async {
    if (_saving) return;
    if (_fingerprint != _initialDraft) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: const Text(
            'Your changes in this editor have not been saved.',
          ),
          actions: [
            LoadingButton.text(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            LoadingButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _allowClose = true);
    await Future<void>.delayed(Duration.zero);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (preview) {
      setState(() => preview = false);
      return;
    }
    if (!form.currentState!.validate()) return;
    final draft = <String, Object?>{
      'customerId': customerId!,
      'issueDate': issueDate.text,
      endKey: endDate.text,
      'currency': currency.text.trim().toUpperCase(),
      'notes': notes.text.trim(),
      'paymentTerms': terms.text.trim(),
      'items': values,
    };
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSave?.call(draft);
      if (!mounted) return;
      setState(() => _allowClose = true);
      await Future<void>.delayed(Duration.zero);
      if (mounted) Navigator.pop(context, draft);
    } catch (error) {
      if (mounted) setState(() => _saveError = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
    _navigationGuard.dispose();
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
                        validator: (value) => number(line, entry.key, value),
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
                'Line total: ${currency.text.toUpperCase()} ${estimateDocument([line.values])['total']!.toStringAsFixed(2)}',
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
            validator: (value) => value == null ? 'Choose a customer.' : null,
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
                  decoration: const InputDecoration(labelText: 'Issue date'),
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
                  labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
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
            action: LoadingButton.textIcon(
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
                  labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
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

  Widget livePreview() => ListenableBuilder(
    listenable: Listenable.merge([
      currency,
      issueDate,
      endDate,
      notes,
      terms,
      for (final line in lines) ...line.fields.values,
    ]),
    builder: (context, _) {
      final totals = estimateDocument(values);
      final colors = Theme.of(context).colorScheme;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.quotation ? 'Quotation' : 'Invoice'} preview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.description_outlined, size: 20),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '${widget.company['name'] ?? 'Your company'}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            if ('${widget.company['address'] ?? ''}'.isNotEmpty)
              Text('${widget.company['address']}'),
            const SizedBox(height: 16),
            Text(
              widget.quotation ? 'QUOTATION' : 'INVOICE',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('Draft · ${issueDate.text}'),
            if (endDate.text.isNotEmpty)
              Text(
                '${widget.quotation ? 'Valid until' : 'Due date'}: ${endDate.text}',
              ),
            const Divider(height: 32),
            const Text(
              'BILL TO',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Text(
              '${customer['name'] ?? 'Select a customer'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if ('${customer['address'] ?? ''}'.isNotEmpty)
              Text('${customer['address']}'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(10),
              color: colors.surfaceContainerHighest,
              child: const Row(
                children: [
                  Expanded(child: Text('Description')),
                  SizedBox(width: 42, child: Text('Qty')),
                  SizedBox(
                    width: 85,
                    child: Text('Amount', textAlign: TextAlign.right),
                  ),
                ],
              ),
            ),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        line.fields['description']!.text.isEmpty
                            ? 'Item description'
                            : line.fields['description']!.text,
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(line.fields['quantity']!.text),
                    ),
                    SizedBox(
                      width: 85,
                      child: Text(
                        (estimateDocument([line.values])['total'] ?? 0)
                            .toStringAsFixed(2),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            for (final entry in {
              'subtotal': 'Subtotal',
              'discount': 'Discount',
              'taxAmount': 'VAT',
              'total': 'Total',
            }.entries)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.all(10),
                color: entry.key == 'total' ? colors.primaryContainer : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontWeight: entry.key == 'total'
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(
                      '${currency.text} ${(totals[entry.key] ?? 0).toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            if (terms.text.isNotEmpty) ...[
              const Text(
                'Terms & conditions',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(terms.text),
            ],
            if (notes.text.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(notes.text),
            ],
            const SizedBox(height: 28),
            Text(
              'Unsaved preview · Final totals are calculated when saved.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowClose,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _discard();
    },
    child: AdaptiveFormDialog(
      expanded: true,
      title: Text('${widget.record == null ? 'Create' : 'Edit'} draft $title'),
      content: AbsorbPointer(
        absorbing: _saving,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width >= 1200 ? 1280 : 820,
          height: 620,
          child: Column(
            children: [
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Wrap(
                alignment: WrapAlignment.end,
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
                  PopupMenuButton<DocumentStyle>(
                    tooltip: 'PDF style',
                    initialValue: style,
                    icon: const Icon(Icons.tune),
                    onSelected: (value) => setState(() => style = value),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: DocumentStyle.modern,
                        child: Text('Modern'),
                      ),
                      const PopupMenuItem(
                        value: DocumentStyle.classic,
                        child: Text('Classic'),
                      ),
                    ],
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
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 1040) return editor();
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: editor(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 2,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: livePreview(),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : _discard,
          child: const Text('Cancel'),
        ),
        LoadingButton(
          busy: _saving,
          onPressed: _saving ? null : _save,
          child: Text(preview ? 'Back to editing' : 'Save draft'),
        ),
      ],
    ),
  );
}
