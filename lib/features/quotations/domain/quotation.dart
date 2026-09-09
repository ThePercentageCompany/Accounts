import '../../billing/domain/models.dart';
import '../../billing/domain/totals.dart';

class Quotation {
  final String id;
  final String number;
  final String date;
  final String validUntil;
  final Customer customer;
  final Company company;
  final List<LineItem> items;
  final String discount;
  final String taxRate;
  final String status; // 'draft', 'sent', 'accepted', 'declined', 'expired', 'converted'
  final String notes;
  final String terms;
  final String convertedInvoiceId;
  final int version;
  final String driveUrl;
  final String issuedAt;

  const Quotation({
    required this.id,
    required this.date,
    required this.customer,
    required this.company,
    this.items = const [],
    this.discount = '0.00',
    this.taxRate = '5.00',
    this.number = '',
    this.status = 'draft',
    this.validUntil = '',
    this.notes = 'This quotation is valid for 30 days from issue date.',
    this.terms = '50% advance upon confirmation, 50% on project completion.',
    this.convertedInvoiceId = '',
    this.version = 0,
    this.driveUrl = '',
    this.issuedAt = '',
  });

  Quotation copyWith({
    String? id,
    String? number,
    String? date,
    String? validUntil,
    Customer? customer,
    Company? company,
    List<LineItem>? items,
    String? discount,
    String? taxRate,
    String? status,
    String? notes,
    String? terms,
    String? convertedInvoiceId,
    int? version,
    String? driveUrl,
    String? issuedAt,
  }) {
    return Quotation(
      id: id ?? this.id,
      number: number ?? this.number,
      date: date ?? this.date,
      validUntil: validUntil ?? this.validUntil,
      customer: customer ?? this.customer,
      company: company ?? this.company,
      items: items ?? this.items,
      discount: discount ?? this.discount,
      taxRate: taxRate ?? this.taxRate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      convertedInvoiceId: convertedInvoiceId ?? this.convertedInvoiceId,
      version: version ?? this.version,
      driveUrl: driveUrl ?? this.driveUrl,
      issuedAt: issuedAt ?? this.issuedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'date': date,
        'validUntil': validUntil,
        'customer': customer.toJson(),
        'company': company.toJson(),
        'items': items.map((e) => e.toJson()).toList(),
        'discount': discount,
        'taxRate': taxRate,
        'status': status,
        'notes': notes,
        'terms': terms,
        'convertedInvoiceId': convertedInvoiceId,
        'version': version,
        'driveUrl': driveUrl,
        'issuedAt': issuedAt,
      };

  factory Quotation.fromJson(Map<String, dynamic> json) => Quotation(
        id: json['id'] as String? ?? '',
        number: json['number'] as String? ?? '',
        date: json['date'] as String? ?? '',
        validUntil: json['validUntil'] as String? ?? '',
        customer: Customer.fromJson(Map<String, dynamic>.from(json['customer'] as Map? ?? {})),
        company: Company.fromJson(Map<String, dynamic>.from(json['company'] as Map? ?? {})),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => LineItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        discount: json['discount'] as String? ?? '0.00',
        taxRate: json['taxRate'] as String? ?? '5.00',
        status: json['status'] as String? ?? 'draft',
        notes: json['notes'] as String? ?? '',
        terms: json['terms'] as String? ?? '',
        convertedInvoiceId: json['convertedInvoiceId'] as String? ?? '',
        version: json['version'] as int? ?? 0,
        driveUrl: json['driveUrl'] as String? ?? '',
        issuedAt: json['issuedAt'] as String? ?? '',
      );
}

class QuotationTotals {
  final int subtotal;
  final int discount;
  final int tax;
  final int total;

  const QuotationTotals({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  factory QuotationTotals.of(Quotation q) {
    final sub = q.items.fold<int>(0, (a, b) => a + lineTotal(b));
    if (sub > 1000000000) throw const FormatException('Quotation total exceeds AED 10 million.');
    final discount = scaled(q.discount, 2);
    if (discount > sub) throw const FormatException('Discount cannot exceed item total.');
    final rate = scaled(q.taxRate, 2);
    if (rate > 10000) throw const FormatException('Tax rate must be between 0 and 100.');
    final tax = ((sub - discount) * rate + 5000) ~/ 10000;
    final total = sub - discount + tax;
    return QuotationTotals(subtotal: sub, discount: discount, tax: tax, total: total);
  }
}
