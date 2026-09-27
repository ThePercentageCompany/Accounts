import 'package:flutter/material.dart';

class CashReversalEditor extends StatefulWidget {
  const CashReversalEditor({super.key});
  @override
  State<CashReversalEditor> createState() => _CashReversalEditorState();
}

class _CashReversalEditorState extends State<CashReversalEditor> {
  final _form = GlobalKey<FormState>();
  final _date = TextEditingController();
  final _reason = TextEditingController();
  @override
  void dispose() {
    _date.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reverse unpaid entry'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The original history stays unchanged. An opposite journal will cancel its ledger effect. This entry cannot be paid or reused afterward.',
              ),
              TextFormField(
                controller: _date,
                decoration: const InputDecoration(
                  labelText: 'Reversal date (YYYY-MM-DD)',
                ),
                validator: (v) {
                  final text = v?.trim() ?? '',
                      date = DateTime.tryParse(v?.trim() ?? '');
                  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) &&
                          date != null &&
                          date.toIso8601String().startsWith(text)
                      ? null
                      : 'Enter a valid date.';
                },
              ),
              TextFormField(
                controller: _reason,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Reason'),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Enter a reason.' : null,
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
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, <String, Object?>{
            'date': _date.text.trim(),
            'description': _reason.text.trim(),
          });
        },
        child: const Text('Reverse entry'),
      ),
    ],
  );
}
