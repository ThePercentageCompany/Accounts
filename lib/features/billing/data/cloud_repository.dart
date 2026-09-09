import 'dart:convert';
import 'dart:typed_data';
import '../../../core/google_api.dart';
import '../domain/billing_repository.dart';
import '../domain/models.dart';
class CloudRepository implements BillingRepository {
  final GoogleApi api;
  CloudRepository(this.api);
  @override bool get isDemo=>false;
  Future<Map<String,dynamic>> command(String action,[Map<String,dynamic>? data])=>api.command(action,data);
  @override Future<BillingData> load() async => BillingData.fromJson(await command('load'));
  @override Future<void> saveCustomer(Customer c) async { await command('saveCustomer', c.toJson()); }
  @override Future<void> saveCompany(Company c) async { await command('saveCompany', c.toJson()); }
  @override Future<Invoice> saveDraft(Invoice i) async => Invoice.fromJson(await command('saveDraft', i.toJson()));
  @override Future<Invoice> issue(Invoice i) async => Invoice.fromJson(await command('issue', {'id':i.id,'version':i.version}));
  @override Future<Invoice> pay(Invoice i, Payment p) async => Invoice.fromJson(await command('pay', {'id':i.id,'version':i.version,'payment':p.toJson()}));
  @override Future<Invoice> voidInvoice(Invoice i) async => Invoice.fromJson(await command('void', {'id':i.id,'version':i.version}));
  @override Future<String> archive(Invoice i, Uint8List bytes, {String? paymentId}) async =>
    (await command('archive', {'id':i.id,'version':i.version,'pdf':base64Encode(bytes),if(paymentId!=null)'paymentId':paymentId}))['url'] as String;
}
