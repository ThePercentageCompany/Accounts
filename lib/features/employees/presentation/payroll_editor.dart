import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:flutter/material.dart';

class PayrollEditor extends StatefulWidget {
  const PayrollEditor({
    super.key,
    required this.employees,
    this.record,
    this.preview,
  });
  final List<Map<String, dynamic>> employees;
  final Map<String, dynamic>? record;
  final Future<Map<String, dynamic>> Function(Map<String, Object?>)? preview;
  @override
  State<PayrollEditor> createState() => _PayrollEditorState();
}

class _PayrollEditorState extends State<PayrollEditor> {
  final form = GlobalKey<FormState>();
  Map<String, dynamic>? totals;
  String? previewError;
  bool calculating = false;
  int revision = 0;
  void invalidate() {
    if (!mounted) return;
    setState(() {
      revision++;
      totals = null;
      previewError = null;
    });
  }

  @override
  void initState() {
    super.initState();
    month.addListener(invalidate);
    bonus.addListener(invalidate);
    deductions.addListener(invalidate);
  }

  Map<String, Object?> values() => {
    'month': month.text.trim(),
    'employeeId': employeeId!,
    'bonus': double.parse(bonus.text.trim()),
    'deductions': double.parse(deductions.text.trim()),
  };
  Future<void> calculate() async {
    if (!form.currentState!.validate() ||
        widget.preview == null ||
        calculating) {
      return;
    }
    final requestedRevision = revision;
    setState(() {
      calculating = true;
      previewError = null;
      totals = null;
    });
    try {
      final result = await widget.preview!(values());
      if (mounted && requestedRevision == revision) {
        setState(
          () => totals = Map<String, dynamic>.from(result['totals'] as Map),
        );
      }
    } catch (error) {
      if (mounted && requestedRevision == revision) {
        setState(() => previewError = '$error');
      }
    } finally {
      if (mounted) setState(() => calculating = false);
    }
  }

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
            !value.isFinite ||
            value < 0 ||
            value > 1e12 ||
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
                  ? (value) {
                      employeeId = value;
                      invalidate();
                    }
                  : null,
              validator: (value) =>
                  value == null ? 'Choose an employee.' : null,
            ),
            if (employeeId != null) ...[
              for (final employee in widget.employees.where(
                (row) => row['recordId'] == employeeId,
              ))
                Text(
                  'Monthly basic salary: ${employee['basicSalary'] == null || employee['basicSalary'] == '' ? 'Not set' : employee['basicSalary']} | Allowances: ${employee['allowances'] == null || employee['allowances'] == '' ? '0' : employee['allowances']}',
                ),
              const Text(
                'Full monthly compensation. Approved overtime for the selected month is added by the server; salary is not prorated.',
              ),
            ],
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
            if (widget.preview != null) ...[
              LoadingButton.outlined(
                onPressed: calculating ? null : calculate,
                child: Text(
                  calculating ? 'Calculating payroll…' : 'Calculate payroll',
                ),
              ),
              if (previewError != null)
                Text(
                  previewError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (totals != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Payroll preview',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        for (final entry in const {
                          'basicSalary': 'Basic salary',
                          'allowances': 'Allowances',
                          'overtimeAmount': 'Approved overtime',
                          'bonus': 'Bonus',
                          'deductions': 'Deductions',
                          'grossSalary': 'Gross salary',
                          'netSalary': 'Net salary',
                        }.entries)
                          Text(
                            '${entry.value}: ${(num.tryParse('${totals![entry.key]}') ?? 0).toStringAsFixed(2)}',
                          ),
                        const Text(
                          'Saving refreshes amounts. Approval checks that salary and overtime have not changed.',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      LoadingButton.text(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      LoadingButton(
        onPressed: calculating
            ? null
            : () async {
                if (!form.currentState!.validate()) return;
                if (widget.preview != null && totals == null) {
                  await calculate();
                  return;
                }
                Navigator.pop(context, values());
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
      LoadingButton.text(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      LoadingButton(
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
