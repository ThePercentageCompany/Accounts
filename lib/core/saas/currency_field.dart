import 'package:flutter/material.dart';

/// Currency choices shared by document creation and company settings.
class CurrencyFormField extends StatelessWidget {
  const CurrencyFormField({
    super.key,
    required this.controller,
    this.label = 'Currency',
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback? onChanged;

  static const currencies = {
    'AED': 'UAE dirham',
    'USD': 'US dollar',
    'EUR': 'Euro',
    'GBP': 'British pound',
    'SAR': 'Saudi riyal',
    'QAR': 'Qatari riyal',
    'OMR': 'Omani rial',
    'BHD': 'Bahraini dinar',
    'KWD': 'Kuwaiti dinar',
    'INR': 'Indian rupee',
    'PKR': 'Pakistani rupee',
    'BDT': 'Bangladeshi taka',
    'LKR': 'Sri Lankan rupee',
    'NPR': 'Nepalese rupee',
    'AUD': 'Australian dollar',
    'CAD': 'Canadian dollar',
    'NZD': 'New Zealand dollar',
    'CHF': 'Swiss franc',
    'CNY': 'Chinese yuan',
    'JPY': 'Japanese yen',
    'SGD': 'Singapore dollar',
    'HKD': 'Hong Kong dollar',
    'MYR': 'Malaysian ringgit',
    'THB': 'Thai baht',
    'PHP': 'Philippine peso',
    'IDR': 'Indonesian rupiah',
    'ZAR': 'South African rand',
    'EGP': 'Egyptian pound',
    'TRY': 'Turkish lira',
    'BRL': 'Brazilian real',
  };

  @override
  Widget build(BuildContext context) {
    final code = controller.text.trim().toUpperCase();
    final valid = RegExp(r'^[A-Z]{3}$').hasMatch(code);
    final choices = {
      ...currencies,
      if (valid && !currencies.containsKey(code)) code: 'Saved currency',
    };
    return DropdownButtonFormField<String>(
      initialValue: valid ? code : null,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final entry in choices.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text('${entry.key} — ${entry.value}',
                overflow: TextOverflow.ellipsis),
          ),
      ],
      validator: (value) => value == null ? 'Choose a currency.' : null,
      onChanged: (value) {
        if (value == null) return;
        controller.text = value;
        onChanged?.call();
      },
    );
  }
}
