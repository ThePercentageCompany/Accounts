import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:flutter/material.dart';

class ShareholderEditor extends StatefulWidget {
  const ShareholderEditor({super.key, this.record});
  final Map<String, dynamic>? record;
  @override
  State<ShareholderEditor> createState() => _ShareholderEditorState();
}

class _ShareholderEditorState extends State<ShareholderEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: '${widget.record?['name'] ?? ''}',
  );
  late final email = TextEditingController(
    text: '${widget.record?['email'] ?? ''}',
  );
  late final phone = TextEditingController(
    text: '${widget.record?['phone'] ?? ''}',
  );
  late final role = TextEditingController(
    text: '${widget.record?['role'] ?? 'Shareholder'}',
  );
  late final capital = TextEditingController(
    text: '${widget.record?['agreedCapital'] ?? 0}',
  );
  late final date = TextEditingController(
    text: '${widget.record?['investmentDate'] ?? ''}',
  );
  late String status = '${widget.record?['status'] ?? 'ACTIVE'}';
  @override
  void dispose() {
    for (final c in [name, email, phone, role, capital, date]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: Text(widget.record == null ? 'Add shareholder' : 'Edit shareholder'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Required.' : null,
            ),
            TextFormField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
            TextFormField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            TextFormField(
              controller: role,
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            TextFormField(
              controller: capital,
              decoration: const InputDecoration(labelText: 'Agreed capital'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final t = v?.trim() ?? '', n = double.tryParse(t);
                return n == null ||
                        n < 0 ||
                        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)
                    ? 'Enter a nonnegative amount.'
                    : null;
              },
            ),
            CalendarFormField(
              controller: date,
              decoration: const InputDecoration(
                labelText: 'Investment date (optional)',
              ),
              optional: true,
              validator: (v) {
                final t = v?.trim() ?? '';
                return t.isEmpty ||
                        (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t) &&
                            DateTime.tryParse(t) != null)
                    ? null
                    : 'Use YYYY-MM-DD.';
              },
            ),
            SearchableRecordField(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
              ],
              onChanged: (v) => status = v ?? 'ACTIVE',
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
            'name': name.text.trim(),
            'email': email.text.trim(),
            'phone': phone.text.trim(),
            'role': role.text.trim(),
            'status': status,
            'agreedCapital': double.parse(capital.text.trim()),
            'investmentDate': date.text.trim(),
          });
        },
        child: const Text('Save shareholder'),
      ),
    ],
  );
}

class CapitalContributionEditor extends StatefulWidget {
  const CapitalContributionEditor({
    super.key,
    required this.shareholders,
    this.record,
  });
  final List<Map<String, dynamic>> shareholders;
  final Map<String, dynamic>? record;
  @override
  State<CapitalContributionEditor> createState() =>
      _CapitalContributionEditorState();
}

class _CapitalContributionEditorState extends State<CapitalContributionEditor> {
  final form = GlobalKey<FormState>();
  late String? shareholderId = widget.record?['shareholderId'] as String?;
  late String account = '${widget.record?['destinationAccount'] ?? 'Bank'}';
  late final date = TextEditingController(
    text:
        '${widget.record?['date'] ?? DateTime.now().toIso8601String().substring(0, 10)}',
  );
  late final amount = TextEditingController(
    text: '${widget.record?['amount'] ?? ''}',
  );
  late final reference = TextEditingController(
    text: '${widget.record?['reference'] ?? ''}',
  );
  @override
  void dispose() {
    date.dispose();
    amount.dispose();
    reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: Text(
      widget.record == null
          ? 'Add capital contribution'
          : 'Edit capital contribution',
    ),
    content: SizedBox(
      width: 480,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchableRecordField(
              initialValue: shareholderId,
              decoration: const InputDecoration(labelText: 'Shareholder'),
              items: [
                for (final s in widget.shareholders)
                  DropdownMenuItem(
                    value: s['recordId'] as String,
                    child: Text('${s['name']}'),
                  ),
              ],
              onChanged: (v) => shareholderId = v,
              validator: (v) => v == null ? 'Choose a shareholder.' : null,
            ),
            CalendarFormField(
              controller: date,
              decoration: const InputDecoration(labelText: 'Contribution date'),
              validator: (v) {
                final t = v?.trim() ?? '';
                return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t) &&
                        DateTime.tryParse(t) != null
                    ? null
                    : 'Use YYYY-MM-DD.';
              },
            ),
            TextFormField(
              controller: amount,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final t = v?.trim() ?? '', n = double.tryParse(t);
                return n == null ||
                        n <= 0 ||
                        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)
                    ? 'Enter a positive amount.'
                    : null;
              },
            ),
            SearchableRecordField(
              initialValue: account,
              decoration: const InputDecoration(labelText: 'Received into'),
              items: const [
                DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
              ],
              onChanged: (v) => account = v ?? 'Bank',
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(context, <String, Object?>{
            'date': date.text.trim(),
            'capitalAccountId': '',
            'shareholderId': shareholderId!,
            'kind': 'CAPITAL_CONTRIBUTION',
            'amount': double.parse(amount.text.trim()),
            'method': 'PAID',
            'destinationAccount': account,
            'assetId': '',
            'reference': reference.text.trim(),
          });
        },
        child: const Text('Save draft'),
      ),
    ],
  );
}

class ShareholderLoanEditor extends StatefulWidget {
  const ShareholderLoanEditor({
    super.key,
    required this.shareholders,
    this.record,
  });
  final List<Map<String, dynamic>> shareholders;
  final Map<String, dynamic>? record;
  @override
  State<ShareholderLoanEditor> createState() => _ShareholderLoanEditorState();
}

class _ShareholderLoanEditorState extends State<ShareholderLoanEditor> {
  final form = GlobalKey<FormState>();
  late String? shareholderId = widget.record?['shareholderId'] as String?;
  late String account = '${widget.record?['paymentAccount'] ?? 'Bank'}';
  late final date = TextEditingController(
    text:
        '${widget.record?['date'] ?? DateTime.now().toIso8601String().substring(0, 10)}',
  );
  late final dueDate = TextEditingController(
    text: '${widget.record?['dueDate'] ?? ''}',
  );
  late final principal = TextEditingController(
    text: '${widget.record?['principal'] ?? ''}',
  );
  late final reference = TextEditingController(
    text: '${widget.record?['reference'] ?? ''}',
  );
  @override
  void dispose() {
    for (final c in [date, dueDate, principal, reference]) {
      c.dispose();
    }
    super.dispose();
  }

  bool validDate(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      DateTime.tryParse(value) != null;
  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: Text(
      widget.record == null ? 'Add shareholder loan' : 'Edit shareholder loan',
    ),
    content: SizedBox(
      width: 480,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchableRecordField(
              initialValue: shareholderId,
              decoration: const InputDecoration(labelText: 'Shareholder'),
              items: [
                for (final s in widget.shareholders)
                  DropdownMenuItem(
                    value: s['recordId'] as String,
                    child: Text('${s['name']}'),
                  ),
              ],
              onChanged: (v) => shareholderId = v,
              validator: (v) => v == null ? 'Choose a shareholder.' : null,
            ),
            CalendarFormField(
              controller: date,
              decoration: const InputDecoration(labelText: 'Receipt date'),
              validator: (v) =>
                  validDate(v?.trim() ?? '') ? null : 'Use YYYY-MM-DD.',
            ),
            CalendarFormField(
              controller: dueDate,
              optional: true,
              decoration: const InputDecoration(
                labelText: 'Due date (optional)',
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                return t.isEmpty || validDate(t) ? null : 'Use YYYY-MM-DD.';
              },
            ),
            TextFormField(
              controller: principal,
              decoration: const InputDecoration(labelText: 'Principal'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final t = v?.trim() ?? '', n = double.tryParse(t);
                return n == null ||
                        n <= 0 ||
                        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)
                    ? 'Enter a positive amount.'
                    : null;
              },
            ),
            SearchableRecordField(
              initialValue: account,
              decoration: const InputDecoration(labelText: 'Received into'),
              items: const [
                DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
              ],
              onChanged: (v) => account = v ?? 'Bank',
            ),
            TextFormField(
              controller: reference,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Reference (optional)',
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'This release supports interest-free shareholder loans.',
              ),
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
            'shareholderId': shareholderId!,
            'date': date.text.trim(),
            'kind': 'LOAN_TO_COMPANY',
            'principal': double.parse(principal.text.trim()),
            'interestRate': 0,
            'dueDate': dueDate.text.trim(),
            'paymentAccount': account,
            'reference': reference.text.trim(),
          });
        },
        child: const Text('Save draft'),
      ),
    ],
  );
}

class ShareholderLoanRepaymentEditor extends StatefulWidget {
  const ShareholderLoanRepaymentEditor({super.key, required this.amount});
  final Object? amount;
  @override
  State<ShareholderLoanRepaymentEditor> createState() =>
      _ShareholderLoanRepaymentEditorState();
}

class _ShareholderLoanRepaymentEditorState
    extends State<ShareholderLoanRepaymentEditor> {
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
    title: const Text('Repay shareholder loan'),
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Full outstanding principal: ${widget.amount}'),
          CalendarFormField(
            controller: date,
            decoration: const InputDecoration(labelText: 'Repayment date'),
            validator: (v) {
              final t = v?.trim() ?? '';
              return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t) &&
                      DateTime.tryParse(t) != null
                  ? null
                  : 'Use YYYY-MM-DD.';
            },
          ),
          SearchableRecordField(
            initialValue: account,
            decoration: const InputDecoration(labelText: 'Paid from'),
            items: const [
              DropdownMenuItem(value: 'Bank', child: Text('Bank')),
              DropdownMenuItem(value: 'Cash', child: Text('Cash')),
            ],
            onChanged: (v) => account = v ?? 'Bank',
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
            'lastRepaymentDate': date.text.trim(),
            'paymentAccount': account,
            'paymentReference': reference.text.trim(),
          });
        },
        child: const Text('Record full repayment'),
      ),
    ],
  );
}
