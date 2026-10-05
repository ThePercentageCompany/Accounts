import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';

class InvoiceReturnEditor extends StatefulWidget {
  const InvoiceReturnEditor({
    super.key,
    required this.invoice,
    required this.items,
    required this.returns,
  });
  final Map<String, dynamic> invoice;
  final List<Map<String, dynamic>> items, returns;
  @override
  State<InvoiceReturnEditor> createState() => _InvoiceReturnEditorState();
}

class _InvoiceReturnEditorState extends State<InvoiceReturnEditor> {
  final form = GlobalKey<FormState>();
  final date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final reason = TextEditingController();
  String account = 'Bank';
  String? error;
  late final quantities = {
    for (final item in widget.items)
      '${item['recordId']}': TextEditingController(text: '0'),
  };
  int cents(Object? value) {
    final parsed = num.tryParse('$value') ?? 0;
    return parsed.isFinite && parsed.abs() <= 1e12 ? (parsed * 100).round() : 0;
  }

  double get estimatedCredit {
    var total = BigInt.zero;
    for (final item in widget.items) {
      final qty = BigInt.from(cents(item['quantity']));
      if (qty <= BigInt.zero) continue;
      final before = qty - BigInt.from(cents(remaining(item)));
      final entered = BigInt.from(
        cents(quantities['${item['recordId']}']!.text),
      );
      final candidate = before + entered;
      final after = candidate < before
          ? before
          : candidate > qty
          ? qty
          : candidate;
      final gross =
          (qty * BigInt.from(cents(item['unitPrice'])) + BigInt.from(50)) ~/
          BigInt.from(100);
      final net = gross - BigInt.from(cents(item['discount']));
      final tax = BigInt.from(cents(item['taxAmount']));
      for (final amount in [net, tax]) {
        total +=
            (amount * after + qty ~/ BigInt.two) ~/ qty -
            (amount * before + qty ~/ BigInt.two) ~/ qty;
      }
    }
    return total.toDouble() / 100;
  }

  num remaining(Map<String, dynamic> item) =>
      (cents(item['quantity']) -
          widget.returns
              .where((r) => r['invoiceItemId'] == item['recordId'])
              .fold<int>(0, (sum, r) => sum + cents(r['quantity']))) /
      100;
  @override
  void dispose() {
    date.dispose();
    reason.dispose();
    for (final controller in quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: Text('Return items · ${widget.invoice['number']}'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'The issued invoice stays unchanged. Selected quantities create a posted credit note using the original prices, discounts and tax. Credit reduces the balance first; any excess is refunded.',
              ),
              CalendarFormField(
                controller: date,
                validator: (value) =>
                    DateTime.tryParse(value ?? '') == null ||
                        (value ?? '').compareTo(
                              '${widget.invoice['issueDate']}',
                            ) <
                            0
                    ? 'Choose a date on or after the invoice date.'
                    : null,
                decoration: const InputDecoration(labelText: 'Return date'),
              ),
              TextFormField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Return reason'),
                maxLength: 1000,
                validator: (v) => (v?.trim().length ?? 0) < 3
                    ? 'Enter a return reason.'
                    : null,
              ),
              for (final item in widget.items)
                if (remaining(item) > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      controller: quantities['${item['recordId']}'],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        helperMaxLines: 3,
                        labelText: '${item['description']}',
                        helperText:
                            'Remaining: ${remaining(item)} · Return quantity (0 to skip)',
                      ),
                      onChanged: (_) => setState(() => error = null),
                      validator: (v) {
                        final amount = num.tryParse(v ?? '');
                        if (amount == null ||
                            !amount.isFinite ||
                            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v ?? '') ||
                            amount < 0 ||
                            amount > remaining(item)) {
                          return 'Enter 0 to ${remaining(item)} (up to 2 decimals).';
                        }
                        return null;
                      },
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Estimated credit: ${widget.invoice['currency']} ${estimatedCredit.toStringAsFixed(2)}\n'
                  'Estimated refund: ${widget.invoice['currency']} ${(estimatedCredit - (num.tryParse('${widget.invoice['balance']}') ?? 0)).clamp(0, double.infinity).toStringAsFixed(2)}',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: account,
                decoration: const InputDecoration(
                  labelText: 'Refund from (if already paid)',
                ),
                items: const [
                  DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                ],
                onChanged: (v) => account = v!,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Posting records any refund immediately. Confirm only when the corresponding Cash/Bank refund is made.',
                ),
              ),
              if (error != null) Text(error!),
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
          if (!form.currentState!.validate()) return;
          final items = [
            for (final entry in quantities.entries)
              if ((num.tryParse(entry.value.text) ?? 0) > 0)
                {
                  'invoiceItemId': entry.key,
                  'quantity': num.parse(entry.value.text),
                },
          ];
          if (items.isEmpty) {
            setState(
              () => error = 'Enter a return quantity for at least one item.',
            );
            return;
          }
          Navigator.pop(context, <String, Object?>{
            'date': date.text,
            'reason': reason.text.trim(),
            'refundAccount': account,
            'returnItems': items,
          });
        },
        child: const Text('Post credit note'),
      ),
    ],
  );
}
