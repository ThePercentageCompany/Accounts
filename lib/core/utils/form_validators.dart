import 'package:flutter/services.dart';

class FormValidators {
  FormValidators._();

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _phone = RegExp(r'^[0-9+()\-\s]{7,24}$');
  static final _wholeNumber = RegExp(r'^\d+$');
  static final _decimal = RegExp(r'^\d+(?:\.\d{1,2})?$');

  static String? email(String? value, {bool required = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? 'Email address is required' : null;
    return _email.hasMatch(text) ? null : 'Enter a valid email address';
  }

  static String? phone(String? value, {bool required = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? 'Phone number is required' : null;
    return _phone.hasMatch(text) ? null : 'Enter a valid phone number';
  }

  static String? amount(String? value, {bool required = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? 'Amount is required' : null;
    if (!_decimal.hasMatch(text)) return 'Use a positive amount with up to 2 decimals';
    return null;
  }

  static String? wholeNumber(String? value, {bool required = false, int? min, int? max}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? 'Number is required' : null;
    if (!_wholeNumber.hasMatch(text)) return 'Numbers only';
    final number = int.parse(text);
    if (min != null && number < min) return 'Must be at least $min';
    if (max != null && number > max) return 'Must be at most $max';
    return null;
  }

  static List<TextInputFormatter> get decimalInput => [
        TextInputFormatter.withFunction((oldValue, newValue) =>
            RegExp(r'^\d*(?:\.\d{0,2})?$').hasMatch(newValue.text)
                ? newValue
                : oldValue),
      ];

  static List<TextInputFormatter> get wholeNumberInput =>
      [FilteringTextInputFormatter.digitsOnly];

  static List<TextInputFormatter> get phoneInput => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]')),
      ];
}
