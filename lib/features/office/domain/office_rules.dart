import '../../billing/domain/totals.dart';
import '../../billing/domain/models.dart';
import 'office_repository.dart';
Map<String,dynamic> calculatePayroll(Map<String,dynamic> employee,List<Map<String,dynamic>> rows,Map<String,dynamic> d){
 final salary=scaled(employee['basic'].toString(),2)+scaled(employee['allowances'].toString(),2);
 final divisor=int.parse(d['divisor'].toString()),days=double.parse(d['baseDays'].toString()),scheduled=int.parse(d['scheduledDays'].toString());
 if(divisor<1||divisor>31||days<=0||days>divisor||days*2!=(days*2).round()||scheduled<1||scheduled>31)throw StateError('Check divisor, base days and scheduled days.');
 final counted=rows.where((r)=>!['off','holiday'].contains(r['status'])).length;
 final absent=rows.fold<double>(0,(n,r)=>n+(['absent','unpaidLeave'].contains(r['status'])?1.0:(r['status']=='halfDay'?0.5:0.0)));
 final base=(salary*days/divisor).round(),absence=(salary*absent/divisor).round();
 final overtime=(rows.fold<int>(0,(n,r)=>n+scaled(r['overtimeHours'].toString(),2))*scaled(d['overtimeRate'].toString(),2)/100).round();
 final bonus=scaled(d['bonus'].toString(),2),deduction=scaled(d['deductions'].toString(),2);
 final net=base+overtime+bonus-absence-deduction;
 if(absent>days||net<0)throw StateError('Deductions exceed salary.');
 return {'baseCents':base,'absenceCents':absence,'overtimeCents':overtime,'bonusCents':bonus,'deductionCents':deduction,'netCents':net,'absentDays':absent,'markedDays':counted,'missingDays':scheduled-counted};
}
Map<String,int> financialSummary(List<Invoice> invoices,OfficeData office,String month){
 var receipts=0,otherIncome=0,expenses=0,salaries=0,receivable=0,payable=0,payrollDue=0,bank=0,cash=0;
 void flow(String account,int cents){if(account=='Cash'){cash+=cents;}else{bank+=cents;}}
 for(final i in invoices.where((i)=>i.status=='issued')){
  receivable+=Totals.of(i).balance;
  for(final p in i.payments.where((p)=>p.date.startsWith(month))){receipts+=p.cents;flow(p.account,p.cents);}
 }
 for(final e in office.entries){
  final amount=(e['amountCents'] as num).toInt();
  if(e['status']=='unpaid')payable+=amount;
  if(e['status']!='paid'||!(e['paidDate'] as String).startsWith(month))continue;
  if(e['kind']=='income'||e['kind']=='capital'){otherIncome+=amount;flow(e['account'],amount);}else{expenses+=amount;flow(e['account'],-amount);}
 }
 for(final p in office.payroll){
  final amount=(p['netCents'] as num).toInt();
  if(p['status']=='approved')payrollDue+=amount;
  if(p['status']=='paid'&&(p['paidDate'] as String).startsWith(month)){salaries+=amount;flow(p['account'],-amount);}
 }
 return {'Invoice collections':receipts,'Other income':otherIncome,'Expenses paid':expenses,'Payroll paid':salaries,'Net cash movement':receipts+otherIncome-expenses-salaries,'Bank movement':bank,'Cash movement':cash,'Customer outstanding (all dates)':receivable,'Supplier bills due (all dates)':payable,'Approved payroll due (all dates)':payrollDue};
}
