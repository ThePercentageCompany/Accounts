import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/features/billing/domain/models.dart';
import 'package:tpc_invoice/features/billing/domain/totals.dart';
import 'package:tpc_invoice/features/billing/data/invoice_pdf.dart';
import 'package:tpc_invoice/features/billing/data/local_repository.dart';

Invoice sample()=>const Invoice(id:'sample',date:'2026-09-05',customer:Customer(id:'welltech',name:'Well-Tech'),company:Company(),discount:'500.00',items:[LineItem(description:'E-Commerce Management',rate:'2500.00'),LineItem(description:'Amazon Ads',rate:'227.00'),LineItem(description:'Review Products',rate:'1413.75'),LineItem(description:'Server Cost',rate:'62.76')]);
void main(){
 test('Provided invoice totals match exactly',(){final t=Totals.of(sample());expect(t.subtotal,420351);expect(t.total,370351);expect(t.balance,370351);});
 test('Line rounding and tax use integer minor units',(){final i=sample().copyWith(items:[const LineItem(description:'Fraction',quantity:'0.125',rate:'0.04')],discount:'0');expect(lineTotal(i.items.first),1);expect(Totals.of(sample().copyWith(taxRate:'5')).tax,18518);});
 test('Reject invalid decimals and negative numbers',(){for(final s in ['-1','NaN','Infinity','1.001','1e2']){expect(()=>scaled(s,2),throwsFormatException);}});
 test('Reject overpayment',(){expect(()=>Totals.of(sample().copyWith(payments:[const Payment(id:'p',cents:400000,date:'2026-09-05')])),throwsFormatException);});
 test('Nested serialization round trips Freezed models',(){final i=sample();expect(i.toJson()['customer'],isA<Map<String,dynamic>>());expect(Invoice.fromJson(i.toJson()),i);});
 test('PDF renderer emits a PDF for 30 long lines',() async {final bytes=await PdfInvoiceDocumentService().render(sample().copyWith(items:List.generate(30,(n)=>LineItem(description:'Item $n: extended service description for multipage invoice layout.',quantity:'2',rate:'125.75'))));expect(String.fromCharCodes(bytes.take(5)),'%PDF-');expect(bytes.length,greaterThan(1000));});
  test('LocalRepository deleteDraft and deleteCustomer CRUD operations', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalRepository();
    await repo.load();
    const testCustomer = Customer(id: 'cust_crud_test', name: 'Test Client');
    await repo.saveCustomer(testCustomer);
    var data = await repo.load();
    expect(data.customers.any((c) => c.id == 'cust_crud_test'), isTrue);

    await repo.deleteCustomer('cust_crud_test');
    data = await repo.load();
    expect(data.customers.any((c) => c.id == 'cust_crud_test'), isFalse);

    final draft = sample().copyWith(id: 'inv_draft_test', status: 'draft');
    await repo.saveDraft(draft);
    data = await repo.load();
    expect(data.invoices.any((i) => i.id == 'inv_draft_test'), isTrue);

    await repo.deleteDraft('inv_draft_test');
    data = await repo.load();
    expect(data.invoices.any((i) => i.id == 'inv_draft_test'), isFalse);
  });
}
