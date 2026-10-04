export 'date_time_field.dart';
import 'package:flutter/material.dart';

/// Shared form surface: existing desktop dialogs, reachable mobile actions.
class AdaptiveFormDialog extends StatelessWidget {
  const AdaptiveFormDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 600 &&
        MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom >=
            480) {
      return AlertDialog(title: title, content: content, actions: actions);
    }
    return Dialog.fullscreen(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.titleLarge,
                      child: title,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close without saving',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(width: double.infinity, child: content),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 12, runSpacing: 8, children: actions),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordSummary extends StatelessWidget {
  const RecordSummary({super.key, required this.record});
  final Map<String, dynamic> record;
  @override
  Widget build(BuildContext context) {
    final amount =
        record['total'] ??
        record['totalAmount'] ??
        record['amount'] ??
        record['unitPrice'];
    final date = record['issueDate'] ?? record['date'] ?? record['dueDate'];
    final status =
        record['status'] ??
        record['paymentStatus'] ??
        record['employmentStatus'];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (amount != null)
          Text(
            '${record['currency'] ?? ''} $amount'.trim(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        if (date != null) Text('$date'),
        if (status != null) StatusChip(value: '$status'),
        if (record['email'] != null) Text('${record['email']}'),
        if (record['quantity'] != null) Text('Qty ${record['quantity']}'),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.value});
  final String value;
  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text(value.replaceAll('_', ' ').toLowerCase()),
    side: BorderSide.none,
    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
    labelStyle: TextStyle(
      color: Theme.of(context).colorScheme.onSecondaryContainer,
    ),
  );
}

class LineEstimate extends StatelessWidget {
  const LineEstimate({super.key, required this.fields});
  final Map<String, TextEditingController> fields;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge(fields.values.toList()),
    builder: (context, _) {
      double number(String key) =>
          double.tryParse(fields[key]?.text ?? '') ?? 0;
      final subtotal =
          number('quantity') * number('unitPrice') - number('discount');
      final total = subtotal * (1 + number('taxRate') / 100);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Line estimate',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text('Subtotal: ${subtotal.toStringAsFixed(2)}'),
              Text('Including tax: ${total.toStringAsFixed(2)}'),
              const Text('Final totals are calculated by the company service.'),
            ],
          ),
        ),
      );
    },
  );
}

class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.shape,
    this.collapsedShape,
    this.backgroundColor,
    this.collapsedBackgroundColor,
  });
  final Widget title;
  final Widget subtitle;
  final List<Widget> children;
  final ShapeBorder? shape;
  final ShapeBorder? collapsedShape;
  final Color? backgroundColor;
  final Color? collapsedBackgroundColor;
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 600;
    bool action(Widget child) => child is ButtonStyleButton;
    final actions = children.where(action).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ExpansionTile(
            key: key,
            title: title,
            subtitle: subtitle,
            shape: shape,
            collapsedShape: collapsedShape,
            backgroundColor: backgroundColor,
            collapsedBackgroundColor: collapsedBackgroundColor,
            children: mobile
                ? children.where((child) => !action(child)).toList()
                : children,
          ),
          if (mobile && actions.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.more_horiz),
                label: const Text('Actions'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (context) => SafeArea(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Record actions',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            for (final action
                                in actions.cast<ButtonStyleButton>())
                              OutlinedButton(
                                onPressed: action.onPressed == null
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        action.onPressed!();
                                      },
                                child: action.child ?? const Text('Open'),
                              ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Uses already loaded options; opening a sheet never reads the API.
Future<String?> selectRecord(
  BuildContext context,
  String label,
  List<DropdownMenuItem<String>> items,
  String? selected,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      var query = '';
      return StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Search $label',
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (value) =>
                          setState(() => query = value.toLowerCase()),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final item in items)
                          if (item.child is! Text ||
                              ((item.child as Text).data ?? '')
                                  .toLowerCase()
                                  .contains(query))
                            ListTile(
                              title: item.child,
                              selected: item.value == selected,
                              trailing: item.value == selected
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () => Navigator.pop(context, item.value),
                            ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class SearchableRecordField extends StatelessWidget {
  const SearchableRecordField({
    super.key,
    this.initialValue,
    required this.decoration,
    required this.items,
    required this.onChanged,
    this.validator,
  });
  final String? initialValue;
  final InputDecoration decoration;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;
  final FormFieldValidator<String>? validator;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 600 || items.length <= 2) {
      return DropdownButtonFormField<String>(
        initialValue: initialValue,
        decoration: decoration,
        items: items,
        onChanged: onChanged,
        validator: validator,
        isExpanded: true,
      );
    }
    return FormField<String>(
      initialValue: initialValue,
      validator: validator,
      builder: (field) => InkWell(
        onTap: onChanged == null
            ? null
            : () async {
                final value = await selectRecord(
                  context,
                  decoration.labelText ?? 'records',
                  items,
                  field.value,
                );
                if (value != null && context.mounted) {
                  field.didChange(value);
                  onChanged!(value);
                }
              },
        child: InputDecorator(
          decoration: decoration.copyWith(
            errorText: field.errorText,
            suffixIcon: const Icon(Icons.expand_more),
          ),
          child:
              items
                  .where((item) => item.value == field.value)
                  .firstOrNull
                  ?.child ??
              const Text('Choose an option'),
        ),
      ),
    );
  }
}
