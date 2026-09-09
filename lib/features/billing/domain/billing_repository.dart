import 'dart:typed_data';
import 'models.dart';
abstract interface class BillingRepository {
  bool get isDemo;
  Future<BillingData> load();
  Future<void> saveCustomer(Customer customer);
  Future<void> saveCompany(Company company);
  Future<Invoice> saveDraft(Invoice invoice);
  Future<Invoice> issue(Invoice invoice);
  Future<Invoice> pay(Invoice invoice, Payment payment);
  Future<Invoice> voidInvoice(Invoice invoice);
  Future<String> archive(Invoice invoice, Uint8List bytes, {String? paymentId});
}
