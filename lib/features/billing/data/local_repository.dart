import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models.dart';
import '../domain/totals.dart';
import '../domain/billing_repository.dart';

// Single-device preview only. Production numbering and persistence belong to Sheets.
class LocalRepository implements BillingRepository {
  BillingData _data = const BillingData();
  @override bool get isDemo => true;
  Future<void> _write() async {
    if (!await (await SharedPreferences.getInstance()).setString('tpc_demo_v1', jsonEncode(_data.toJson()))) {
      throw StateError('Could not save to this device.');
    }
  }
  @override Future<BillingData> load() async {
    final text = (await SharedPreferences.getInstance()).getString('tpc_demo_v1');
    _data = text == null ? const BillingData(customers:[Customer(id:'sample', name:'Well-Tech')]) : BillingData.fromJson(jsonDecode(text));
    return _data;
  }
  @override Future<void> saveCustomer(Customer c) async {
    _data = _data.copyWith(customers:[..._data.customers.where((x)=>x.id != c.id),c.copyWith(version:c.version+1)]);
    await _write();
  }
  @override Future<void> deleteCustomer(String customerId) async {
    _data = _data.copyWith(customers: _data.customers.where((x) => x.id != customerId).toList());
    await _write();
  }
  @override Future<void> saveCompany(Company c) async { _data = _data.copyWith(company:c.copyWith(version:c.version+1)); await _write(); }
  Future<Invoice> _put(Invoice i) async {
    _data = _data.copyWith(invoices:[..._data.invoices.where((x)=>x.id != i.id),i]); await _write(); return i;
  }
  @override Future<Invoice> saveDraft(Invoice i) async {
    if (i.status != 'draft') throw StateError('Only drafts can be edited.');
    Totals.of(i);
    return _put(i.copyWith(version:i.version+1));
  }
  @override Future<void> deleteDraft(String invoiceId) async {
    final target = _data.invoices.where((x) => x.id == invoiceId).firstOrNull;
    if (target != null && target.status != 'draft') {
      throw StateError('Only draft invoices can be deleted.');
    }
    _data = _data.copyWith(invoices: _data.invoices.where((x) => x.id != invoiceId).toList());
    await _write();
  }
  @override Future<Invoice> issue(Invoice i) async {
    final current = _data.invoices.firstWhere((x)=>x.id == i.id);
    if(current.number.isNotEmpty) return current;
    final seq = _data.invoices.where((x)=>x.number.isNotEmpty).length+1;
    return _put(current.copyWith(number:'DEMO-${i.company.prefix}-${DateTime.now().year}-${seq.toString().padLeft(6,'0')}',status:'issued',version:current.version+1,issuedAt:DateTime.now().toUtc().toIso8601String()));
  }
  @override Future<Invoice> pay(Invoice i, Payment p) async {
    if(i.status != 'issued') throw StateError('Only issued invoices accept payments.');
    if(i.payments.any((x)=>x.id == p.id)) return i;
    final changed=i.copyWith(payments:[...i.payments,p],version:i.version+1);
    Totals.of(changed); return _put(changed);
  }
  @override Future<Invoice> voidInvoice(Invoice i) async {
    if(i.payments.isNotEmpty) throw StateError('Invoices with payments cannot be voided.');
    return _put(i.copyWith(status:'void',version:i.version+1));
  }
  @override Future<String> archive(Invoice i, Uint8List bytes, {String? paymentId}) async => throw StateError('Drive archive is available in connected mode.');
}
