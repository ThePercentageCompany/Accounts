import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/office/domain/office_rules.dart';
import 'package:tpc_invoice/features/office/domain/office_repository.dart';
import 'package:tpc_invoice/features/billing/domain/models.dart';
void main(){
 test('Payroll absence and overtime arithmetic',(){
  final result=calculatePayroll({'basic':'3000','allowances':'600'},[{'status':'present','overtimeHours':'2'},{'status':'absent','overtimeHours':'0'}],{'divisor':'30','baseDays':'30','scheduledDays':'2','overtimeRate':'10','bonus':'100','deductions':'50'});
  expect(result['netCents'],355000);expect(result['missingDays'],0);
 });
 test('Finance includes invoice payments and payroll exactly once',(){
  const invoice=Invoice(id:'i',date:'2026-09-01',customer:Customer(id:'c',name:'c'),company:Company(),status:'issued',items:[LineItem(description:'Work',rate:'100')],payments:[Payment(id:'p',cents:10000,date:'2026-09-09',account:'Bank')]);
  const office=OfficeData(entries:[{'id':'e','kind':'expense','status':'paid','amountCents':2000,'paidDate':'2026-09-09','account':'Cash'}],payroll:[{'id':'salary','status':'paid','netCents':3000,'paidDate':'2026-09-09','account':'Bank'}]);
  final s=financialSummary([invoice],office,'2026-09');expect(s['Net cash movement'],5000);expect(s['Bank movement'],7000);expect(s['Cash movement'],-2000);expect(s['Customer outstanding (all dates)'],0);
 });
  test('Financial report separates transaction date from payment month',(){
   const data=OfficeData(entries:[{'kind':'expense','status':'unpaid','amountCents':5000,'paidDate':'','account':'Bank'},{'kind':'income','status':'paid','amountCents':10000,'paidDate':'2026-08-31','account':'Bank'}]);
   final result=financialSummary([],data,'2026-09');expect(result['Other income'],0);expect(result['Supplier bills due (all dates)'],5000);
  });
  test('Capital investment correctly contributes to financial summary',(){
   const data=OfficeData(entries:[{'kind':'capital','status':'paid','amountCents':250000,'paidDate':'2026-09-10','account':'Bank'},{'kind':'expense','status':'paid','amountCents':50000,'paidDate':'2026-09-10','account':'Bank'}]);
   final result=financialSummary([],data,'2026-09');
   expect(result['Other income'],250000);
   expect(result['Expenses paid'],50000);
   expect(result['Net cash movement'],200000);
  });
}
