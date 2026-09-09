import 'models.dart';

int scaled(String value, int decimals) {
  if (!RegExp('^\\d+(\\.\\d{1,$decimals})?\$').hasMatch(value.trim())) {
    throw FormatException('Enter a positive number with up to $decimals decimal places.');
  }
  final p = value.trim().split('.');
  final result = int.parse(p[0]) * (decimals == 2 ? 100 : 1000) +
    int.parse((p.length == 2 ? p[1] : '').padRight(decimals, '0'));
  if (result > (decimals == 3 ? 1000000 : 100000000)) throw const FormatException('Amount or quantity is too large.');
  return result;
}
int lineTotal(LineItem item) => (scaled(item.quantity, 3) * scaled(item.rate, 2) + 500) ~/ 1000;
String money(int cents) => 'AED ${(cents / 100).toStringAsFixed(2)}';
class Totals {
  final int subtotal, discount, tax, total, paid, balance;
  const Totals(this.subtotal, this.discount, this.tax, this.total, this.paid, this.balance);
  factory Totals.of(Invoice invoice) {
    final sub = invoice.items.fold<int>(0, (a,b) => a + lineTotal(b));
    if (sub > 1000000000) throw const FormatException('Invoice total exceeds AED 10 million.');
    final discount = scaled(invoice.discount, 2);
    if (discount > sub) throw const FormatException('Discount cannot exceed item total.');
    final rate = scaled(invoice.taxRate, 2);
    if (rate > 10000) throw const FormatException('Tax rate must be between 0 and 100.');
    final tax = ((sub - discount) * rate + 5000) ~/ 10000;
    final total = sub - discount + tax;
    final paid = invoice.payments.fold<int>(0, (a,b) => a + b.cents);
    if (paid > total) throw const FormatException('Payments cannot exceed the total.');
    return Totals(sub, discount, tax, total, paid, total-paid);
  }
}
