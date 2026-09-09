import 'package:freezed_annotation/freezed_annotation.dart';
part 'models.freezed.dart';
part 'models.g.dart';

@freezed
abstract class Customer with _$Customer {
  const factory Customer({required String id, required String name,
    @Default('') String email, @Default('') String phone,
    @Default('') String address, @Default('') String trn,
    @Default(0) int version}) = _Customer;
  factory Customer.fromJson(Map<String,dynamic> json) => _$CustomerFromJson(json);
}

@freezed
abstract class Company with _$Company {
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
    @Default(0) int version,
  }) = _Company;
  factory Company.fromJson(Map<String,dynamic> json) => _$CompanyFromJson(json);
}

@freezed
abstract class LineItem with _$LineItem {
  const factory LineItem({required String description,
    @Default('1') String quantity, @Default('0.00') String rate}) = _LineItem;
  factory LineItem.fromJson(Map<String,dynamic> json) => _$LineItemFromJson(json);
}

@freezed
abstract class Payment with _$Payment {
  const factory Payment({required String id, required int cents,
    required String date, @Default('Bank') String account, @Default('') String reference}) = _Payment;
  factory Payment.fromJson(Map<String,dynamic> json) => _$PaymentFromJson(json);
}

@freezed
abstract class Invoice with _$Invoice {
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
  factory Invoice.fromJson(Map<String,dynamic> json) => _$InvoiceFromJson(json);
}

@freezed
abstract class BillingData with _$BillingData {
  const factory BillingData({@Default(Company()) Company company,
    @Default([]) List<Customer> customers,
    @Default([]) List<Invoice> invoices}) = _BillingData;
  factory BillingData.fromJson(Map<String,dynamic> json) => _$BillingDataFromJson(json);
}
