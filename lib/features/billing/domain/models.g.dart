// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Customer _$CustomerFromJson(Map<String, dynamic> json) => _Customer(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String? ?? '',
  phone: json['phone'] as String? ?? '',
  address: json['address'] as String? ?? '',
  trn: json['trn'] as String? ?? '',
  version: (json['version'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CustomerToJson(_Customer instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'phone': instance.phone,
  'address': instance.address,
  'trn': instance.trn,
  'version': instance.version,
};

_Company _$CompanyFromJson(Map<String, dynamic> json) => _Company(
  name: json['name'] as String? ?? 'The Percentage FZ LLC',
  address: json['address'] as String? ?? 'Dubai U.A.E',
  phone: json['phone'] as String? ?? '+971 56 331 9030',
  email: json['email'] as String? ?? 'thepercentagecompany1@gmail.com',
  trn: json['trn'] as String? ?? '',
  prefix: json['prefix'] as String? ?? 'TPC',
  accountHolder: json['accountHolder'] as String? ?? 'The Percentage FZ LLC',
  bank: json['bank'] as String? ?? 'Mashreq Bank',
  accountNumber: json['accountNumber'] as String? ?? '019102062841',
  iban: json['iban'] as String? ?? '',
  notes: json['notes'] as String? ?? 'Thanks for your business.',
  terms: json['terms'] as String? ?? 'Due on Receipt',
  logo: json['logo'] as String? ?? '',
  shareholders:
      (json['shareholders'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
  version: (json['version'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CompanyToJson(_Company instance) => <String, dynamic>{
  'name': instance.name,
  'address': instance.address,
  'phone': instance.phone,
  'email': instance.email,
  'trn': instance.trn,
  'prefix': instance.prefix,
  'accountHolder': instance.accountHolder,
  'bank': instance.bank,
  'accountNumber': instance.accountNumber,
  'iban': instance.iban,
  'notes': instance.notes,
  'terms': instance.terms,
  'logo': instance.logo,
  'shareholders': instance.shareholders,
  'version': instance.version,
};

_LineItem _$LineItemFromJson(Map<String, dynamic> json) => _LineItem(
  description: json['description'] as String,
  quantity: json['quantity'] as String? ?? '1',
  rate: json['rate'] as String? ?? '0.00',
);

Map<String, dynamic> _$LineItemToJson(_LineItem instance) => <String, dynamic>{
  'description': instance.description,
  'quantity': instance.quantity,
  'rate': instance.rate,
};

_Payment _$PaymentFromJson(Map<String, dynamic> json) => _Payment(
  id: json['id'] as String,
  cents: (json['cents'] as num).toInt(),
  date: json['date'] as String,
  account: json['account'] as String? ?? 'Bank',
  reference: json['reference'] as String? ?? '',
);

Map<String, dynamic> _$PaymentToJson(_Payment instance) => <String, dynamic>{
  'id': instance.id,
  'cents': instance.cents,
  'date': instance.date,
  'account': instance.account,
  'reference': instance.reference,
};

_Invoice _$InvoiceFromJson(Map<String, dynamic> json) => _Invoice(
  id: json['id'] as String,
  date: json['date'] as String,
  customer: Customer.fromJson(json['customer'] as Map<String, dynamic>),
  company: Company.fromJson(json['company'] as Map<String, dynamic>),
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => LineItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  discount: json['discount'] as String? ?? '0.00',
  taxRate: json['taxRate'] as String? ?? '0',
  number: json['number'] as String? ?? '',
  status: json['status'] as String? ?? 'draft',
  dueDate: json['dueDate'] as String? ?? '',
  notes: json['notes'] as String? ?? '',
  terms: json['terms'] as String? ?? 'Due on Receipt',
  payments:
      (json['payments'] as List<dynamic>?)
          ?.map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  version: (json['version'] as num?)?.toInt() ?? 0,
  driveUrl: json['driveUrl'] as String? ?? '',
  archivedVersion: (json['archivedVersion'] as num?)?.toInt() ?? 0,
  issuedAt: json['issuedAt'] as String? ?? '',
);

Map<String, dynamic> _$InvoiceToJson(_Invoice instance) => <String, dynamic>{
  'id': instance.id,
  'date': instance.date,
  'customer': instance.customer.toJson(),
  'company': instance.company.toJson(),
  'items': instance.items.map((e) => e.toJson()).toList(),
  'discount': instance.discount,
  'taxRate': instance.taxRate,
  'number': instance.number,
  'status': instance.status,
  'dueDate': instance.dueDate,
  'notes': instance.notes,
  'terms': instance.terms,
  'payments': instance.payments.map((e) => e.toJson()).toList(),
  'version': instance.version,
  'driveUrl': instance.driveUrl,
  'archivedVersion': instance.archivedVersion,
  'issuedAt': instance.issuedAt,
};

_BillingData _$BillingDataFromJson(Map<String, dynamic> json) => _BillingData(
  company: json['company'] == null
      ? const Company()
      : Company.fromJson(json['company'] as Map<String, dynamic>),
  customers:
      (json['customers'] as List<dynamic>?)
          ?.map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  invoices:
      (json['invoices'] as List<dynamic>?)
          ?.map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$BillingDataToJson(_BillingData instance) =>
    <String, dynamic>{
      'company': instance.company.toJson(),
      'customers': instance.customers.map((e) => e.toJson()).toList(),
      'invoices': instance.invoices.map((e) => e.toJson()).toList(),
    };
