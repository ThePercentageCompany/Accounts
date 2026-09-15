import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/utils/form_validators.dart';

void main() {
  group('FormValidators', () {
    test('accepts valid email addresses and rejects malformed values', () {
      expect(FormValidators.email('accounts@example.com'), isNull);
      expect(FormValidators.email('accounts.example.com'), isNotNull);
      expect(FormValidators.email('', required: true), isNotNull);
    });

    test('accepts practical phone numbers and rejects letters', () {
      expect(FormValidators.phone('+971 50 123 4567'), isNull);
      expect(FormValidators.phone('call me'), isNotNull);
    });

    test('accepts only non-negative monetary values with two decimals', () {
      expect(FormValidators.amount('1250'), isNull);
      expect(FormValidators.amount('1250.50'), isNull);
      expect(FormValidators.amount('1250.567'), isNotNull);
      expect(FormValidators.amount('-10'), isNotNull);
    });
  });
}
