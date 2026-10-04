import 'package:flutter/material.dart';

enum CategoryKind { income, expense, asset }

class CategoryFormField extends StatelessWidget {
  const CategoryFormField({
    super.key,
    required this.controller,
    required this.kind,
  });

  final TextEditingController controller;
  final CategoryKind kind;

  static const categories = {
    CategoryKind.income: [
      'Sales',
      'Services',
      'Consulting',
      'Commission',
      'Rental income',
      'Interest income',
      'Other income',
    ],
    CategoryKind.expense: [
      'Office supplies',
      'Rent',
      'Utilities',
      'Internet & telephone',
      'Travel & transport',
      'Marketing & advertising',
      'Professional fees',
      'Repairs & maintenance',
      'Insurance',
      'Software & subscriptions',
      'Bank charges',
      'Other expenses',
    ],
    CategoryKind.asset: [
      'Computers & IT equipment',
      'Office equipment',
      'Furniture & fixtures',
      'Vehicles',
      'Machinery & equipment',
      'Buildings',
      'Leasehold improvements',
      'Other assets',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final saved = controller.text.trim();
    final choices = <String>{...categories[kind]!, if (saved.isNotEmpty) saved};
    return DropdownButtonFormField<String>(
      initialValue: saved.isEmpty ? null : saved,
      decoration: const InputDecoration(labelText: 'Category'),
      isExpanded: true,
      menuMaxHeight: 320,
      items: [
        if (kind != CategoryKind.asset)
          const DropdownMenuItem(value: '', child: Text('Uncategorized')),
        for (final category in choices)
          DropdownMenuItem(
            value: category,
            child: Text(category, overflow: TextOverflow.ellipsis),
          ),
      ],
      validator: kind == CategoryKind.asset
          ? (value) =>
                value == null || value.isEmpty ? 'Choose a category.' : null
          : null,
      onChanged: (value) {
        if (value != null) controller.text = value;
      },
    );
  }
}
