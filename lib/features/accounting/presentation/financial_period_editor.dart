import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:flutter/material.dart';

class FinancialPeriodEditor extends StatefulWidget {
  const FinancialPeriodEditor({super.key, this.record});
  final Map<String, dynamic>? record;
  @override
  State<FinancialPeriodEditor> createState() => _FinancialPeriodEditorState();
}

class _FinancialPeriodEditorState extends State<FinancialPeriodEditor> {
  final _form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: '${widget.record?['name'] ?? ''}',
  );
  late final start = TextEditingController(
    text: '${widget.record?['startDate'] ?? ''}',
  );
  late final end = TextEditingController(
    text: '${widget.record?['endDate'] ?? ''}',
  );
  bool close = false;
  String? _date(String? value) {
    final text = (value ?? '').trim();
    final date = DateTime.tryParse(text);
    return !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
            date == null ||
            date.toIso8601String().substring(0, 10) != text
        ? 'Use a valid YYYY-MM-DD date.'
        : null;
  }

  @override
  void dispose() {
    name.dispose();
    start.dispose();
    end.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: Text(
      widget.record == null ? 'Add financial period' : 'Edit financial period',
    ),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Period name'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a name.' : null,
              ),
              CalendarFormField(
                controller: start,
                decoration: const InputDecoration(labelText: 'Start date'),
                validator: _date,
              ),
              CalendarFormField(
                controller: end,
                decoration: const InputDecoration(labelText: 'End date'),
                validator: (v) =>
                    _date(v) ??
                    ((v ?? '').trim().compareTo(start.text.trim()) < 0
                        ? 'End date must be on or after the start date.'
                        : null),
              ),
              if (widget.record != null) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: close,
                  onChanged: (v) => setState(() => close = v!),
                  title: const Text('Close this period'),
                ),
                const Text(
                  'Closing prevents further journal postings in this date range. Draft journals must be resolved first. Closed periods cannot be reopened from this screen.',
                ),
              ],
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
        onPressed: () async {
          if (!_form.currentState!.validate()) return;
          if (close) {
            final yes = await showDialog<bool>(
              context: context,
              builder: (context) => AdaptiveFormDialog(
                title: const Text('Close financial period?'),
                content: const Text(
                  'This locks journal posting for the selected dates.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Close period'),
                  ),
                ],
              ),
            );
            if (yes != true || !context.mounted) return;
          }
          if (context.mounted) {
            Navigator.pop(context, <String, Object?>{
              'name': name.text.trim(),
              'startDate': start.text.trim(),
              'endDate': end.text.trim(),
              'status': close ? 'CLOSED' : 'OPEN',
            });
          }
        },
        child: const Text('Save period'),
      ),
    ],
  );
}
