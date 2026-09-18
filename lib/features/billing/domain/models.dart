import 'dart:convert';
import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';
part 'models.freezed.dart';
part 'models.g.dart';

/// Supports both older raw-base64 logos and the MIME-qualified data URLs used
/// for new uploads. Invalid logo data must never prevent an invoice from
/// rendering.
Uint8List? companyLogoBytes(String value) {
  if (value.trim().isEmpty) return null;
  try {
    final raw = value.contains(';base64,') ? value.split(';base64,').last : value;
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}

@freezed
abstract class Customer with _$Customer {
  const Customer._();
  const factory Customer({required String id, required String name,
    @Default('') String email, @Default('') String phone,
    @Default('') String address, @Default('') String trn,
    @Default(0) int version}) = _Customer;
  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    address: json['address']?.toString() ?? '',
    trn: json['trn']?.toString() ?? '',
    version: (json['version'] as num?)?.toInt() ?? int.tryParse(json['version']?.toString() ?? '0') ?? 0,
  );
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'trn': trn,
    'version': version,
  };
}

@freezed
abstract class Company with _$Company {
  const Company._();
  const factory Company({
    @Default('The Percentage FZ LLC') String name,
    @Default('Dubai U.A.E') String address,
    @Default('+971 56 331 9030') String phone,
    @Default('thepercentagecompany1@gmail.com') String email,
    @Default('') String trn,
    @Default('TPC') String prefix,
    @Default('The Percentage FZ LLC') String accountHolder,
    @Default('Mashreq Bank') String bank,
    @Default('019102062841') String accountNumber,
    @Default('') String iban,
    @Default('Thanks for your business.') String notes,
    @Default('Due on Receipt') String terms,
    @Default('') String logo,
    @Default('') String logoDriveUrl,
    @Default([]) List<Map<String, dynamic>> shareholders,
    @Default(0) int version,
  }) = _Company;
  factory Company.fromJson(Map<String, dynamic> json) => Company(
    name: json['name']?.toString() ?? 'The Percentage FZ LLC',
    address: json['address']?.toString() ?? 'Dubai U.A.E',
    phone: json['phone']?.toString() ?? '+971 56 331 9030',
    email: json['email']?.toString() ?? 'thepercentagecompany1@gmail.com',
    trn: json['trn']?.toString() ?? '',
    prefix: json['prefix']?.toString() ?? 'TPC',
    accountHolder: json['accountHolder']?.toString() ?? 'The Percentage FZ LLC',
    bank: json['bank']?.toString() ?? 'Mashreq Bank',
    accountNumber: json['accountNumber']?.toString() ?? '019102062841',
    iban: json['iban']?.toString() ?? '',
    notes: json['notes']?.toString() ?? 'Thanks for your business.',
    terms: json['terms']?.toString() ?? 'Due on Receipt',
    logo: json['logo']?.toString() ?? '',
    logoDriveUrl: json['logoDriveUrl']?.toString() ?? '',
    shareholders: (json['shareholders'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
    version: (json['version'] as num?)?.toInt() ?? int.tryParse(json['version']?.toString() ?? '0') ?? 0,
  );
  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'phone': phone,
    'email': email,
    'trn': trn,
    'prefix': prefix,
    'accountHolder': accountHolder,
    'bank': bank,
    'accountNumber': accountNumber,
    'iban': iban,
    'notes': notes,
    'terms': terms,
    'logo': logo,
    'logoDriveUrl': logoDriveUrl,
    'shareholders': shareholders,
    'version': version,
  };
}

@freezed
abstract class LineItem with _$LineItem {
  const LineItem._();
  const factory LineItem({required String description,
    @Default('1') String quantity, @Default('0.00') String rate}) = _LineItem;
  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
    description: json['description']?.toString() ?? '',
    quantity: json['quantity']?.toString() ?? '1',
    rate: json['rate']?.toString() ?? '0.00',
  );
  @override
  Map<String, dynamic> toJson() => {
    'description': description,
    'quantity': quantity,
    'rate': rate,
  };
}

@freezed
abstract class Payment with _$Payment {
  const Payment._();
  const factory Payment({required String id, required int cents,
    required String date, @Default('Bank') String account, @Default('') String reference}) = _Payment;
  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id']?.toString() ?? '',
    cents: (json['cents'] as num?)?.toInt() ?? int.tryParse(json['cents']?.toString() ?? '0') ?? 0,
    date: json['date']?.toString() ?? '',
    account: json['account']?.toString() ?? 'Bank',
    reference: json['reference']?.toString() ?? '',
  );
  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'cents': cents,
    'date': date,
    'account': account,
    'reference': reference,
  };
}

@freezed
abstract class Invoice with _$Invoice {
  const Invoice._();
  const factory Invoice({required String id, required String date,
    required Customer customer, required Company company,
    @Default([]) List<LineItem> items,
    @Default('0.00') String discount, @Default('0') String taxRate,
    @Default('') String number, @Default('draft') String status,
    @Default('') String dueDate, @Default('') String notes,
    @Default('Due on Receipt') String terms,
    @Default([]) List<Payment> payments,
    @Default(0) int version, @Default('') String driveUrl,
    @Default(0) int archivedVersion,
    @Default('') String issuedAt,
  }) = _Invoice;
  factory Invoice.fromJson(Map<String, dynamic> json) {
    final custRaw = json['customer'];
    final compRaw = json['company'];
    final itemsRaw = json['items'];
    final paymentsRaw = json['payments'];

    return Invoice(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      customer: custRaw is Map
          ? Customer.fromJson(Map<String, dynamic>.from(custRaw))
          : const Customer(id: '', name: ''),
      company: compRaw is Map
          ? Company.fromJson(Map<String, dynamic>.from(compRaw))
          : const Company(),
      items: itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((e) => LineItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      discount: json['discount']?.toString() ?? '0.00',
      taxRate: json['taxRate']?.toString() ?? '0',
      number: json['number']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      dueDate: json['dueDate']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      terms: json['terms']?.toString() ?? 'Due on Receipt',
      payments: paymentsRaw is List
          ? paymentsRaw
              .whereType<Map>()
              .map((e) => Payment.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      version: (json['version'] as num?)?.toInt() ?? int.tryParse(json['version']?.toString() ?? '0') ?? 0,
      driveUrl: json['driveUrl']?.toString() ?? '',
      archivedVersion: (json['archivedVersion'] as num?)?.toInt() ?? int.tryParse(json['archivedVersion']?.toString() ?? '0') ?? 0,
      issuedAt: json['issuedAt']?.toString() ?? '',
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'customer': customer.toJson(),
    'company': company.toJson(),
    'items': items.map((e) => e.toJson()).toList(),
    'discount': discount,
    'taxRate': taxRate,
    'number': number,
    'status': status,
    'dueDate': dueDate,
    'notes': notes,
    'terms': terms,
    'payments': payments.map((e) => e.toJson()).toList(),
    'version': version,
    'driveUrl': driveUrl,
    'archivedVersion': archivedVersion,
    'issuedAt': issuedAt,
  };
}

@freezed
abstract class BillingData with _$BillingData {
  const BillingData._();
  const factory BillingData({@Default(Company()) Company company,
    @Default([]) List<Customer> customers,
    @Default([]) List<Invoice> invoices}) = _BillingData;
  factory BillingData.fromJson(Map<String, dynamic> json) {
    final compRaw = json['company'];
    final custRaw = json['customers'];
    final invRaw = json['invoices'];

    return BillingData(
      company: compRaw is Map
          ? Company.fromJson(Map<String, dynamic>.from(compRaw))
          : const Company(),
      customers: custRaw is List
          ? custRaw
              .whereType<Map>()
              .map((e) => Customer.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      invoices: invRaw is List
          ? invRaw
              .whereType<Map>()
              .map((e) => Invoice.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
  Map<String, dynamic> toJson() => {
    'company': company.toJson(),
    'customers': customers.map((e) => e.toJson()).toList(),
    'invoices': invoices.map((e) => e.toJson()).toList(),
  };
}
