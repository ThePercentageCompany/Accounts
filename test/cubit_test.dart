import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/features/billing/data/local_repository.dart';
import 'package:tpc_invoice/features/billing/domain/models.dart';
import 'package:tpc_invoice/features/billing/presentation/billing_cubit.dart';
void main(){
 test('Local demo persists customer and invoice, issue retry keeps number',() async {
  SharedPreferences.setMockInitialValues({});final r=LocalRepository();final c=BillingCubit(r);await c.refresh();
  const customer=Customer(id:'c',name:'Customer');await c.run(()=>r.saveCustomer(customer));
  final draft=await r.saveDraft(const Invoice(id:'i',date:'2026-09-09',customer:customer,company:Company(),items:[LineItem(description:'Service',rate:'10')]));
  final issued=await r.issue(draft);final retry=await r.issue(draft);expect(retry.number,issued.number);expect(issued.number,startsWith('DEMO-'));
  final data=await LocalRepository().load();expect(data.customers.any((x)=>x.id=='c'),true);expect(data.invoices.length,1);await c.close();
 });
 test('Cubit surfaces failure and clears busy state',() async {
  SharedPreferences.setMockInitialValues({});final c=BillingCubit(LocalRepository());await c.refresh();
  final ok=await c.run(() async=>throw StateError('Failed'));expect(ok,false);expect(c.state.busy,false);expect(c.state.error,contains('Failed'));await c.close();
 });
}
