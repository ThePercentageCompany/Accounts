import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:tpc_invoice/core/widgets/forms/validated_text_field.dart';

class TransferEditor extends StatefulWidget {
  const TransferEditor({super.key, this.record, this.action});
  final Map<String, dynamic>? record;
  final String? action;
  @override
  State<TransferEditor> createState() => _TransferEditorState();
}

class _TransferEditorState extends State<TransferEditor> {
  final form = GlobalKey<FormState>();
  late final date = TextEditingController(
      text: widget.action == null ? '${widget.record?['date'] ?? ''}' : '');
  late final amount =
      TextEditingController(text: '${widget.record?['amount'] ?? ''}');
  late final description = TextEditingController(
      text: widget.action == null
          ? '${widget.record?['description'] ?? ''}'
          : '');
  late final reference = TextEditingController(
      text:
          widget.action == null ? '${widget.record?['reference'] ?? ''}' : '');
  late String from = '${widget.record?['fromAccount'] ?? 'cash'}';
  bool get match => widget.action == 'transferMatch';
  bool get reverse => widget.action == 'transferReverse';
  @override
  void dispose() {
    date.dispose();
    amount.dispose();
    description.dispose();
    reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title: Text(match
            ? 'Match bank statement'
            : reverse
                ? 'Reverse transfer'
                : 'Cash / Bank transfer'),
        content: SizedBox(
            width: 440,
            child: Form(
                key: form,
                child: SingleChildScrollView(
                    child: PopupFormFields(children: [
                  if (!match && !reverse) ...[
                    const Text(
                        'Use the company accounting currency. A transfer moves existing money and does not change profit. Personal withdrawals belong in an owner account.'),
                    DropdownButtonFormField<String>(
                        initialValue: from,
                        decoration:
                            const InputDecoration(labelText: 'Direction'),
                        items: const [
                          DropdownMenuItem(
                              value: 'cash',
                              child: Text('Cash → Bank (deposit)')),
                          DropdownMenuItem(
                              value: 'bank',
                              child: Text('Bank → Cash (withdrawal)')),
                        ],
                        onChanged: (v) => setState(() => from = v!)),
                    TextFormField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount'),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          return n == null ||
                                  !n.isFinite ||
                                  n <= 0 ||
                                  n > 1e12 ||
                                  !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v!)
                              ? 'Enter a positive amount with up to two decimals.'
                              : null;
                        }),
                  ],
                  CalendarFormField(
                      controller: date,
                      decoration: InputDecoration(
                          labelText: match
                              ? 'Bank statement date'
                              : reverse
                                  ? 'Reversal date'
                                  : 'Transfer date'),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        final parsed = DateTime.tryParse(text);
                        return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) &&
                                parsed != null &&
                                parsed.toIso8601String().startsWith(text)
                            ? null
                            : 'Enter a valid date.';
                      }),
                  if (!match)
                    TextFormField(
                        controller: description,
                        maxLength: 500,
                        decoration: InputDecoration(
                            labelText:
                                reverse ? 'Reversal reason' : 'Description'),
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Required.' : null),
                  if (!reverse)
                    TextFormField(
                        controller: reference,
                        maxLength: 500,
                        decoration: InputDecoration(
                            labelText: match
                                ? 'Statement reference'
                                : 'Reference (optional)'),
                        validator: (v) => match && (v?.trim().isEmpty ?? true)
                            ? 'Required.'
                            : null),
                ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (!AppFormValidation.validate(form.currentState!)) return;
                Navigator.pop(context, <String, Object?>{
                  if (match) ...{
                    'bankStatus': 'CLEARED',
                    'statementDate': date.text.trim(),
                    'statementReference': reference.text.trim()
                  } else if (reverse) ...{
                    'reversalDate': date.text.trim(),
                    'reversalReason': description.text.trim()
                  } else ...{
                    'date': date.text.trim(),
                    'fromAccount': from,
                    'toAccount': from == 'cash' ? 'bank' : 'cash',
                    'amount': double.parse(amount.text),
                    'description': description.text.trim(),
                    'reference': reference.text.trim()
                  },
                });
              },
              child: Text(match
                  ? 'Mark cleared'
                  : reverse
                      ? 'Reverse transfer'
                      : 'Save draft')),
        ],
      );
}
