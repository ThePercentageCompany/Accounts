import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/offline/fixed_decimal.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:tpc_invoice/core/widgets/forms/validated_text_field.dart';

class CompanyLoanEditor extends StatefulWidget {
  const CompanyLoanEditor({super.key, this.record, this.repayment = false});
  final Map<String, dynamic>? record;
  final bool repayment;
  @override
  State<CompanyLoanEditor> createState() => _CompanyLoanEditorState();
}

class _CompanyLoanEditorState extends State<CompanyLoanEditor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late String lenderType = '${widget.record?['lenderType'] ?? 'BANK'}';
  late String account = '${widget.record?['paymentAccount'] ?? 'Bank'}';
  TextEditingController field(String key, [String fallback = '']) =>
      fields.putIfAbsent(
          key,
          () => TextEditingController(
              text: widget.repayment
                  ? fallback
                  : '${widget.record?[key] ?? fallback}'));
  String text(String key) => fields[key]?.text.trim() ?? '';
  double number(String key) => double.parse(text(key));

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget amount(String key, String label,
          {String fallback = '0',
          bool positive = false,
          double maximum = 1e12}) =>
      TextFormField(
        controller: field(key, fallback),
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          final s = value?.trim() ?? '', n = double.tryParse(s);
          if (n == null ||
              !n.isFinite ||
              n < 0 ||
              n > maximum ||
              positive && n == 0 ||
              !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)) {
            return 'Enter ${positive ? 'a positive' : 'a nonnegative'} amount with up to two decimals.';
          }
          if (widget.repayment &&
              key == 'principalPayment' &&
              decimalUnits(s) >
                  decimalUnits(widget.record?['outstandingBalance'])) {
            return 'Principal exceeds the outstanding balance.';
          }
          if (widget.repayment &&
              key == 'interestPayment' &&
              (double.tryParse(text('principalPayment')) ?? 0) == 0 &&
              n == 0) {
            return 'Enter principal or interest paid.';
          }
          return null;
        },
      );

  Widget date(String key, String label, {bool optional = false}) =>
      CalendarFormField(
          controller: field(key),
          optional: optional,
          decoration: InputDecoration(labelText: label),
          validator: (value) {
            final s = value?.trim() ?? '';
            if (optional && s.isEmpty) return null;
            final parsed = DateTime.tryParse(s);
            if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) ||
                parsed == null ||
                !parsed.toIso8601String().startsWith(s)) {
              return 'Enter a valid date.';
            }
            final minimum = widget.repayment
                ? '${widget.record?['lastRepaymentDate'] ?? ''}'.isNotEmpty
                    ? '${widget.record?['lastRepaymentDate']}'
                    : '${widget.record?['date'] ?? ''}'
                : key == 'dueDate'
                    ? text('date')
                    : '';
            return minimum.isNotEmpty && s.compareTo(minimum) < 0
                ? 'Date must be on or after $minimum.'
                : null;
          });

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
          title:
              Text(widget.repayment ? 'Record loan repayment' : 'Company loan'),
          content: SizedBox(
              width: 480,
              child: Form(
                  key: form,
                  child: SingleChildScrollView(
                      child: PopupFormFields(children: [
                    if (widget.repayment) ...[
                      Text(
                          '${widget.record?['lenderName']} · Outstanding principal: ${widget.record?['outstandingBalance']}'),
                      const Text(
                          'Enter the principal and interest paid from the lender statement. Principal reduces the loan; interest is an expense.'),
                      date('lastRepaymentDate', 'Repayment date'),
                      amount('principalPayment', 'Principal paid'),
                      amount('interestPayment', 'Interest paid'),
                    ] else ...[
                      const Text(
                          'Record borrowing in company accounting currency. Posting adds funds and a loan liability.'),
                      TextFormField(
                          controller: field('lenderName'),
                          maxLength: 200,
                          decoration:
                              const InputDecoration(labelText: 'Lender name'),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter lender name.'
                              : null),
                      DropdownButtonFormField<String>(
                          initialValue: lenderType,
                          decoration:
                              const InputDecoration(labelText: 'Lender type'),
                          items: const [
                            DropdownMenuItem(
                                value: 'BANK', child: Text('Bank')),
                            DropdownMenuItem(
                                value: 'INSTITUTION',
                                child: Text('Private institution')),
                            DropdownMenuItem(
                                value: 'INDIVIDUAL',
                                child: Text('Individual lender')),
                          ],
                          onChanged: (v) => setState(() => lenderType = v!)),
                      date('date', 'Receipt date'),
                      amount('principal', 'Loan principal',
                          fallback: '', positive: true),
                      amount('interestRate', 'Annual interest rate (%)',
                          maximum: 100),
                      amount('installmentAmount',
                          'Planned monthly installment (optional; 0 = none)'),
                      date('dueDate', 'Maturity date (optional)',
                          optional: true),
                      const Text(
                          'Rate and installment are reference details. Interest is entered from the lender statement when recording payments; no automatic interest accrual.'),
                      TextFormField(
                          controller: field('notes'),
                          maxLength: 2000,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Notes (optional)')),
                    ],
                    DropdownButtonFormField<String>(
                        initialValue: account,
                        decoration: InputDecoration(
                            labelText: widget.repayment
                                ? 'Paid from'
                                : 'Received into'),
                        items: const [
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'Bank', child: Text('Bank'))
                        ],
                        onChanged: (v) => setState(() => account = v!)),
                    TextFormField(
                        controller: field(widget.repayment
                            ? 'paymentReference'
                            : 'reference'),
                        maxLength: 500,
                        decoration: const InputDecoration(
                            labelText: 'Reference (optional)')),
                  ])))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (!AppFormValidation.validate(form.currentState!)) return;
                  Navigator.pop(context, <String, Object?>{
                    'paymentAccount': account,
                    if (widget.repayment) ...{
                      'lastRepaymentDate': text('lastRepaymentDate'),
                      'principalPayment': number('principalPayment'),
                      'interestPayment': number('interestPayment'),
                      'paymentReference': text('paymentReference'),
                    } else ...{
                      'lenderName': text('lenderName'),
                      'lenderType': lenderType,
                      'date': text('date'),
                      'principal': number('principal'),
                      'interestRate': number('interestRate'),
                      'installmentAmount': number('installmentAmount'),
                      'dueDate': text('dueDate'),
                      'reference': text('reference'),
                      'notes': text('notes'),
                    },
                  });
                },
                child:
                    Text(widget.repayment ? 'Record payment' : 'Save draft')),
          ]);
}
