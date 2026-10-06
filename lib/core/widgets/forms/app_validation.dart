import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppInputKind {
  text,
  name,
  email,
  phone,
  integer,
  decimal,
  money,
  percentage,
  reference
}

abstract final class AppValidators {
  static final decimalPattern = RegExp(r'^\d+(\.\d{1,2})?$');
  static final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final invoicePrefixPattern = RegExp(r'^[A-Z0-9-]{1,12}$');
  static final accountIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,100}$');
  static final accountCodePattern = RegExp(r'^[A-Za-z0-9.-]{1,24}$');
  static String? calendar(String? value, {String mode = 'date'}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null; // Requiredness remains a property of the form.
    if (mode == 'month') {
      return RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(v)
          ? null
          : 'Use a valid YYYY-MM month.';
    }
    if (mode == 'time') {
      return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v)
          ? null
          : 'Use a valid HH:mm time.';
    }
    final parsed = DateTime.tryParse(v);
    if (mode == 'dateTime') {
      return RegExp(r'^\d{4}-\d{2}-\d{2}T([01]\d|2[0-3]):[0-5]\d$')
                  .hasMatch(v) &&
              parsed != null &&
              parsed.toIso8601String().startsWith(v)
          ? null
          : 'Enter a valid date and time.';
    }
    return datePattern.hasMatch(v) &&
            parsed != null &&
            parsed.toIso8601String().substring(0, 10) == v
        ? null
        : 'Enter a valid date.';
  }

  static String? required(String? value) =>
      (value ?? '').trim().isEmpty ? 'This field is required.' : null;
  static String? text(String? value,
      {bool required = false, int? maxLength, bool multiline = true}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return required ? 'This field is required.' : null;
    if (RegExp(multiline
            ? r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'
            : r'[\x00-\x1F\x7F]')
        .hasMatch(v)) {
      return 'Remove invalid control characters.';
    }
    if (maxLength != null && v.characters.length > maxLength) {
      return 'Use at most $maxLength characters.';
    }
    return null;
  }

  static String? name(String? value,
          {bool required = true, int maxLength = 200}) =>
      text(value, required: required, maxLength: maxLength, multiline: false);
  static String? reference(String? value,
      {bool required = false, int maxLength = 500, RegExp? pattern}) {
    final error =
        text(value, required: required, maxLength: maxLength, multiline: false);
    if (error != null) return error;
    final v = (value ?? '').trim();
    return v.isNotEmpty && pattern != null && !pattern.hasMatch(v)
        ? 'Use the required reference format.'
        : null;
  }

  static String? email(String? value, {bool required = false}) {
    final v = (value ?? '').trim();
    final error = text(v, required: required, maxLength: 254, multiline: false);
    if (error != null || v.isEmpty) return error;
    return emailPattern.hasMatch(v) ? null : 'Invalid email address';
  }

  static String? phone(String? value, {bool required = false}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return required ? 'This field is required.' : null;
    final digits = v.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^\+?[0-9 ()\-]+$').hasMatch(v) &&
            digits.length >= 7 &&
            digits.length <= 15
        ? null
        : 'Enter a valid phone number, including country code if needed.';
  }

  static String? integer(String? value,
      {bool required = true, int min = 0, int? max}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return required ? 'This field is required.' : null;
    final number = int.tryParse(v);
    if (!RegExp(r'^\d+$').hasMatch(v) || number == null) {
      return 'Enter a whole number.';
    }
    return number < min || max != null && number > max
        ? 'Enter a whole number from $min${max == null ? '' : ' to $max'}.'
        : null;
  }

  static String? decimal(String? value,
      {bool required = true,
      int decimalPlaces = 2,
      num min = 0,
      num max = 1e12,
      bool positive = false}) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return required ? 'This field is required.' : null;
    final number = num.tryParse(v);
    final pattern =
        RegExp('^${min < 0 ? '-?' : ''}\\d+(\\.\\d{1,$decimalPlaces})?\$');
    if (!pattern.hasMatch(v) || number == null || !number.isFinite) {
      return 'Enter a valid number with up to $decimalPlaces decimals.';
    }
    if (number < min || number > max || positive && number <= 0) {
      return positive
          ? 'Enter a positive amount.'
          : 'Enter a value from $min to $max.';
    }
    return null;
  }

  static String? money(String? value,
          {bool required = true,
          bool positive = false,
          num min = 0,
          num max = 1e12}) =>
      decimal(value,
          required: required, positive: positive, min: min, max: max);
  static String? percentage(String? value, {bool required = true}) =>
      decimal(value, required: required, max: 100);
  static AppInputKind kindForKey(String key) => switch (key) {
        'email' => AppInputKind.email,
        'phone' || 'mobile' => AppInputKind.phone,
        'name' ||
        'title' ||
        'bankName' ||
        'accountHolder' ||
        'supplier' =>
          AppInputKind.name,
        'taxRate' || 'interestRate' => AppInputKind.percentage,
        'usefulLife' ||
        'life' ||
        'count' ||
        'stock' ||
        'units' =>
          AppInputKind.integer,
        'quantity' => AppInputKind.decimal,
        'amount' ||
        'capital' ||
        'agreedCapital' ||
        'principal' ||
        'cost' ||
        'residualValue' ||
        'unitPrice' ||
        'discount' ||
        'basicSalary' ||
        'allowances' ||
        'overtimeRate' ||
        'bonus' ||
        'deductions' =>
          AppInputKind.money,
        'invoicePrefix' ||
        'quotationPrefix' ||
        'passportNumber' ||
        'emiratesId' ||
        'reference' ||
        'paymentReference' ||
        'assetCode' ||
        'serialNumber' ||
        'taxNumber' ||
        'iban' ||
        'swift' ||
        'accountNumber' =>
          AppInputKind.reference,
        _ => AppInputKind.text,
      };
  static String? validate(AppInputKind kind, String? value,
          {bool required = false, int? maxLength}) =>
      switch (kind) {
        AppInputKind.text =>
          text(value, required: required, maxLength: maxLength),
        AppInputKind.name =>
          name(value, required: required, maxLength: maxLength ?? 200),
        AppInputKind.email => email(value, required: required),
        AppInputKind.phone => phone(value, required: required),
        AppInputKind.integer => integer(value, required: required),
        AppInputKind.decimal => decimal(value, required: required),
        AppInputKind.money => money(value, required: required),
        AppInputKind.percentage => percentage(value, required: required),
        AppInputKind.reference =>
          reference(value, required: required, maxLength: maxLength ?? 500),
      };
}

class DecimalInputFormatter extends TextInputFormatter {
  DecimalInputFormatter({this.decimalPlaces = 2, this.signed = false});
  final int decimalPlaces;
  final bool signed;
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (!newValue.composing.isCollapsed) return newValue;
    final pattern =
        RegExp('^${signed ? '-?' : ''}\\d*(\\.\\d{0,$decimalPlaces})?\$');
    return pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}

abstract final class AppInputFormatters {
  static final search = LengthLimitingTextInputFormatter(200);
  static final integerOnly = FilteringTextInputFormatter.digitsOnly;
  static final decimal = DecimalInputFormatter();
  static final money = DecimalInputFormatter();
  static final phone = TextInputFormatter.withFunction((oldValue, newValue) =>
      RegExp(r'^\+?[0-9 ()\-]*$').hasMatch(newValue.text)
          ? newValue
          : oldValue);
  static final text = FilteringTextInputFormatter.deny(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'));
  static List<TextInputFormatter> forKind(AppInputKind kind) => [
        switch (kind) {
          AppInputKind.integer => integerOnly,
          AppInputKind.decimal ||
          AppInputKind.money ||
          AppInputKind.percentage =>
            decimal,
          AppInputKind.phone => phone,
          _ => text,
        }
      ];
}

abstract final class AppFormValidation {
  static bool validate(FormState form) {
    final valid = form.validate();
    if (valid) return true;
    Element? first;
    void find(Element element) {
      if (first != null) return;
      if (element is StatefulElement &&
          element.state is FormFieldState &&
          (element.state as FormFieldState).hasError) {
        first = element;
      } else {
        element.visitChildren(find);
      }
    }

    (form.context as Element).visitChildren(find);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final field = first;
      if (field == null || !field.mounted) return;
      if (Scrollable.maybeOf(field) != null) {
        Scrollable.ensureVisible(field,
            duration: const Duration(milliseconds: 200));
      }
      void focus(Element child) {
        if (child.widget is EditableText) {
          (child.widget as EditableText).focusNode.requestFocus();
        } else {
          child.visitChildren(focus);
        }
      }

      field.visitChildren(focus);
    });
    return false;
  }
}
