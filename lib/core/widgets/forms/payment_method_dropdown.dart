import 'package:flutter/material.dart';

/// Payment accounts are authoritative in this project's posting API. Never
/// map a method such as "Cheque" onto a ledger account without server support.
class PaymentMethodDropdown extends StatelessWidget {
  const PaymentMethodDropdown(
      {super.key,
      this.value,
      required this.onChanged,
      this.decoration = const InputDecoration(labelText: 'Payment account'),
      this.validator,
      this.required = true,
      this.options = paymentAccounts,
      this.enabled = true,
      this.allowLegacyValue = false});
  static const paymentAccounts = ['Cash', 'Bank'];
  static const defaultMethods = [
    'Cash',
    'Bank Transfer',
    'Cheque',
    'Credit Card',
    'Debit Card',
    'Online Payment',
    'UPI / Digital Payment',
    'Other'
  ];
  final String? value;
  final ValueChanged<String?> onChanged;
  final InputDecoration decoration;
  final FormFieldValidator<String>? validator;
  final bool required, enabled, allowLegacyValue;
  final List<String> options;
  @override
  Widget build(BuildContext context) {
    // Retain unknown historical values visibly, without silently normalizing
    // them or permitting their submission under today's posting contract.
    final legacy =
        value != null && value!.isNotEmpty && !options.contains(value);
    return DropdownButtonFormField<String>(
      initialValue: value?.isEmpty == true ? null : value,
      isExpanded: true,
      decoration: decoration.copyWith(
          errorMaxLines: 3,
          suffixText: decoration.suffixText ?? (required ? '*' : null)),
      hint: const Text('Select payment method'),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      items: [
        for (final option in options.toSet())
          DropdownMenuItem(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis)),
        if (legacy)
          DropdownMenuItem(
              value: value,
              enabled: allowLegacyValue,
              child: Text('$value (legacy)', overflow: TextOverflow.ellipsis))
      ],
      onChanged: enabled ? onChanged : null,
      validator: (selected) => selected == null || selected.isEmpty
          ? required
              ? 'Select a payment method.'
              : null
          : !options.contains(selected) &&
                  !(allowLegacyValue && selected == value)
              ? 'Select a supported payment account to continue.'
              : validator?.call(selected),
    );
  }
}
