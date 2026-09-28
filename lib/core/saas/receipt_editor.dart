import 'package:flutter/material.dart';

bool _validDate(String value) {
  final date = DateTime.tryParse(value);
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      date != null &&
      date.toIso8601String().startsWith(value);
}

class ReceiptEditor extends StatefulWidget {
  const ReceiptEditor({super.key, required this.invoices});
  final List<Map<String, dynamic>> invoices;
  @override
  State<ReceiptEditor> createState() => _ReceiptEditorState();
}

class _ReceiptEditorState extends State<ReceiptEditor> {
  final form = GlobalKey<FormState>();
  String? invoiceId;
  String account = 'Bank';
  final date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final amount = TextEditingController();
  final reference = TextEditingController();

  Map<String, dynamic>? get invoice =>
      widget.invoices.where((row) => row['recordId'] == invoiceId).firstOrNull;
  @override
  void dispose() {
    date.dispose();
    amount.dispose();
    reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record customer payment'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: invoiceId,
                decoration: const InputDecoration(labelText: 'Open invoice'),
                items: [
                  for (final row in widget.invoices)
                    DropdownMenuItem(
                      value: row['recordId'] as String,
                      child: Text(
                        '${row['number']} · ${row['currency']} ${row['balance']}',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  invoiceId = value;
                  amount.text = '${invoice?['balance'] ?? ''}';
                }),
                validator: (value) =>
                    value == null ? 'Choose an open invoice.' : null,
              ),
              TextFormField(
                controller: date,
                decoration: const InputDecoration(labelText: 'Payment date'),
                validator: (value) => _validDate(value?.trim() ?? '')
                    ? null
                    : 'Enter a valid date.',
              ),
              TextFormField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount'),
                validator: (value) {
                  final text = value?.trim() ?? '',
                      number = double.tryParse(text),
                      balance = double.tryParse('${invoice?['balance']}');
                  if (number == null ||
                      number <= 0 ||
                      !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
                    return 'Enter a positive amount, up to two decimals.';
                  }
                  if (balance != null && number > balance) {
                    return 'Amount cannot exceed the outstanding balance.';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: account,
                decoration: const InputDecoration(labelText: 'Deposit account'),
                items: const [
                  DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                ],
                onChanged: (value) => account = value ?? 'Bank',
              ),
              TextFormField(
                controller: reference,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Reference (optional)',
                ),
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
          final selected = invoice!;
          Navigator.pop(context, <String, Object?>{
            'invoiceId': invoiceId!,
            'customerId': selected['customerId'] as String,
            'paymentDate': date.text.trim(),
            'amount': double.parse(amount.text.trim()),
            'currency': selected['currency'] as String,
            'paymentAccount': account,
            'reference': reference.text.trim(),
          });
        },
        child: const Text('Record payment'),
      ),
    ],
  );
}
