export 'package:tpc_invoice/core/widgets/forms/date_time_field.dart';
export 'package:tpc_invoice/core/widgets/forms/currency_field.dart';
import 'package:flutter/material.dart';

/// Shared form surface: existing desktop dialogs, reachable mobile actions.
class AdaptiveFormDialog extends StatelessWidget {
  const AdaptiveFormDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.expanded = false,
  });
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (expanded &&
        MediaQuery.sizeOf(context).width >= 1100 &&
        MediaQuery.sizeOf(context).height >= 600) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 1320,
          height: MediaQuery.sizeOf(context).height - 48,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.headlineSmall,
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
                  padding: const EdgeInsets.all(20),
                  child: content,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
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
    if (MediaQuery.sizeOf(context).width >= 600 &&
        MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom >=
            480) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight:
                MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom -
                48,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: content,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(20),
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = value.toUpperCase();
    final positive = [
      'PAID',
      'READY',
      'ACTIVE',
      'ISSUED',
      'ACCEPTED',
    ].contains(status);
    final warning = [
      'DRAFT',
      'UNPAID',
      'PENDING',
      'PARTIALLY_PAID',
    ].contains(status);
    final color = dark
        ? colors.onSurface
        : positive
        ? const Color(0xFF20843A)
        : warning
        ? const Color(0xFF986A08)
        : colors.primary;
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(value.replaceAll('_', ' ').toLowerCase()),
      side: BorderSide.none,
      backgroundColor: dark
          ? colors.surfaceContainerHighest
          : color.withValues(alpha: .09),
      labelStyle: TextStyle(color: color),
    );
  }
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
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 24),
              if (!mobile && actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ),
              ...children.where((child) => !action(child)),
            ],
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

/// Shared readable detail groups for saved business records. Values remain
/// authoritative; presentation never recalculates accounting amounts.
class RecordDetails extends StatelessWidget {
  const RecordDetails({super.key, required this.record});
  final Map<String, dynamic> record;
  static const _internal = {
    'createdAt',
    'createdBy',
    'updatedAt',
    'updatedBy',
    'recordVersion',
    'syncStatus',
    'isDeleted',
    'idempotencyKey',
  };
  static const _money = {
    'subtotal',
    'discount',
    'taxAmount',
    'total',
    'paidAmount',
    'balance',
    'amount',
    'unitPrice',
    'lineTotal',
    'cost',
    'netSalary',
    'grossSalary',
    'basicSalary',
    'allowances',
    'deductions',
    'bonus',
    'refundAmount',
    'principal',
    'outstandingBalance',
    'agreedCapital',
    'accumulatedDepreciation',
    'netBookValue',
    'residualValue',
    'disposalProceeds',
    'totalDebit',
    'totalCredit',
    'debit',
    'credit',
  };
  String group(String key) {
    if (const {
      'notes',
      'paymentTerms',
      'reason',
      'description',
    }.contains(key)) {
      return 'Notes & description';
    }
    if (_money.contains(key) ||
        const {
          'currency',
          'taxRate',
          'quantity',
          'rate',
          'hours',
          'percentage',
        }.contains(key)) {
      return 'Amounts & quantities';
    }
    if (RegExp(
      r'email|phone|address|website|trn|bank|iban|swift',
      caseSensitive: false,
    ).hasMatch(key)) {
      return 'Contact & business details';
    }
    return 'Record details';
  }

  String label(String key) {
    const labels = {
      'taxAmount': 'VAT amount',
      'trn': 'TRN',
      'iban': 'IBAN',
      'paymentTerms': 'Terms & conditions',
      'issueDate': 'Issue date',
      'dueDate': 'Due date',
      'validUntil': 'Valid until',
    };
    return labels[key] ??
        key
            .replaceAllMapped(
              RegExp(r'([a-z])([A-Z])'),
              (m) => '${m[1]} ${m[2]}',
            )
            .replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<MapEntry<String, dynamic>>>{};
    for (final entry in record.entries) {
      if (entry.key.startsWith('_') ||
          entry.key.endsWith('Id') ||
          _internal.contains(entry.key) ||
          entry.value == null ||
          '${entry.value}'.trim().isEmpty) {
        continue;
      }
      groups.putIfAbsent(group(entry.key), () => []).add(entry);
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final heading in const [
          'Record details',
          'Amounts & quantities',
          'Contact & business details',
          'Notes & description',
        ])
          if (groups[heading]?.isNotEmpty == true)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  width: .8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(heading, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = heading == 'Notes & description'
                          ? 1
                          : constraints.maxWidth >= 780
                          ? 3
                          : constraints.maxWidth >= 450
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 20) / columns;
                      return Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          for (final entry in groups[heading]!)
                            SizedBox(
                              width: width,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label(entry.key),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  if (const {
                                    'status',
                                    'paymentStatus',
                                    'ledgerStatus',
                                    'employmentStatus',
                                  }.contains(entry.key))
                                    StatusChip(value: '${entry.value}')
                                  else
                                    SelectionArea(
                                      child: Text(
                                        _money.contains(entry.key) &&
                                                entry.value is num
                                            ? '${entry.value.toStringAsFixed(2)}'
                                            : '${entry.value}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: entry.key == 'total'
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
      ],
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
    final selected = items.any((item) => item.value == initialValue)
        ? initialValue
        : null;
    if (MediaQuery.sizeOf(context).width >= 600 || items.length <= 2) {
      return DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: decoration,
        items: items,
        onChanged: onChanged,
        validator: validator,
        isExpanded: true,
      );
    }
    return FormField<String>(
      initialValue: selected,
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
