import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:flutter/material.dart';

class PayrollEditor extends StatefulWidget {
  const PayrollEditor({super.key, required this.employees, this.record});
  final List<Map<String, dynamic>> employees;
  final Map<String, dynamic>? record;
  @override
  State<PayrollEditor> createState() => _PayrollEditorState();
}

class _PayrollEditorState extends State<PayrollEditor> {
  final form = GlobalKey<FormState>();
  late String? employeeId = widget.record?['employeeId'] as String?;
  late final month = TextEditingController(
    text:
        '${widget.record?['month'] ?? DateTime.now().toIso8601String().substring(0, 7)}',
  );
  late final bonus = TextEditingController(
    text: '${widget.record?['bonus'] ?? 0}',
  );
  late final deductions = TextEditingController(
    text: '${widget.record?['deductions'] ?? 0}',
  );
  @override
  void dispose() {
    month.dispose();
    bonus.dispose();
    deductions.dispose();
    super.dispose();
  }

  String? amount(String? input) {
    final text = input?.trim() ?? '', value = double.tryParse(text);
    return value == null ||
            value < 0 ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)
        ? 'Enter a nonnegative amount, up to two decimals.'
        : null;
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: Text(
      widget.record == null ? 'Create payroll draft' : 'Edit payroll draft',
    ),
    content: SizedBox(
      width: 680,
      child: Form(
        key: form,
        child: PopupFormFields(
          children: [
            SearchableRecordField(
              initialValue: employeeId,
              decoration: const InputDecoration(labelText: 'Employee'),
              items: [
                for (final row in widget.employees)
                  DropdownMenuItem(
                    value: row['recordId'] as String,
                    child: Text('${row['fullName']}'),
                  ),
              ],
              onChanged: widget.record == null
                  ? (value) => employeeId = value
                  : null,
              validator: (value) =>
                  value == null ? 'Choose an employee.' : null,
            ),
            CalendarFormField(
              controller: month,
              mode: CalendarFieldMode.month,
              enabled: widget.record == null,
              decoration: const InputDecoration(
                labelText: 'Payroll month (YYYY-MM)',
              ),
              validator: (value) =>
                  RegExp(
                    r'^\d{4}-(0[1-9]|1[0-2])$',
                  ).hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Use YYYY-MM.',
            ),
            TextFormField(
              controller: bonus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Bonus'),
              validator: amount,
            ),
            TextFormField(
              controller: deductions,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Deductions'),
              validator: amount,
            ),
          ],
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
            'month': month.text.trim(),
            'employeeId': employeeId!,
            'bonus': double.parse(bonus.text.trim()),
            'deductions': double.parse(deductions.text.trim()),
          });
        },
        child: const Text('Save draft'),
      ),
    ],
  );
}

class PayrollPaymentEditor extends StatefulWidget {
  const PayrollPaymentEditor({super.key, required this.amount});
  final Object? amount;
  @override
  State<PayrollPaymentEditor> createState() => _PayrollPaymentEditorState();
}

class _PayrollPaymentEditorState extends State<PayrollPaymentEditor> {
  final form = GlobalKey<FormState>();
  String account = 'Bank';
  final date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final reference = TextEditingController();
  @override
  void dispose() {
    date.dispose();
    reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: const Text('Pay approved payroll'),
    content: Form(
      key: form,
      child: PopupFormFields(
        children: [
          Text('Net salary: ${widget.amount}'),
          CalendarFormField(
            controller: date,
            decoration: const InputDecoration(labelText: 'Payment date'),
            validator: (value) {
              final text = value?.trim() ?? '',
                  parsed = DateTime.tryParse(text);
              return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) &&
                      parsed != null &&
                      parsed.toIso8601String().startsWith(text)
                  ? null
                  : 'Enter a valid date.';
            },
          ),
          SearchableRecordField(
            initialValue: account,
            decoration: const InputDecoration(labelText: 'Payment account'),
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(context, <String, Object?>{
            'paidDate': date.text.trim(),
            'paymentAccount': account,
            'paymentReference': reference.text.trim(),
          });
        },
        child: const Text('Record payment'),
      ),
    ],
  );
}
