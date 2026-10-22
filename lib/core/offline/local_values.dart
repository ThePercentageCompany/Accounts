import 'fixed_decimal.dart';

/// Derived display fields only. The immutable request still goes to the server
/// with its original values for validation and authoritative calculation.
Map<String, dynamic> localDerivedValues(String table, Map row) {
  BigInt minor(Object? value) => decimalUnits(value);

  double money(BigInt value) => value.toDouble() / 100;
  try {
    if (['Income', 'Expenses'].contains(table)) {
      if (!row.containsKey('amount')) return {};
      final amount = minor(row['amount']), rate = minor(row['taxRate']);
      final tax = (amount * rate + BigInt.from(5000)) ~/ BigInt.from(10000);
      return {'taxAmount': money(tax), 'total': money(amount + tax)};
    }
    if (['Invoices', 'Quotations'].contains(table) && row['items'] is List) {
      var subtotal = BigInt.zero, discount = BigInt.zero, tax = BigInt.zero;
      for (final line in row['items'] as List) {
        final gross =
            (minor(line['quantity']) * minor(line['unitPrice']) +
                BigInt.from(50)) ~/
            BigInt.from(100);
        final reduction = minor(line['discount']);
        subtotal += gross;
        discount += reduction;
        tax +=
            ((gross - reduction) * minor(line['taxRate']) +
                BigInt.from(5000)) ~/
            BigInt.from(10000);
      }
      final total = subtotal - discount + tax;
      return {
        'subtotal': money(subtotal),
        'discount': money(discount),
        'taxAmount': money(tax),
        'total': money(total),
        if (table == 'Invoices') 'paidAmount': 0,
        if (table == 'Invoices') 'balance': money(total),
      };
    }
  } on FormatException {
    // Invalid drafts remain reviewable and receive the server's validation error.
  }
  return {};
}
