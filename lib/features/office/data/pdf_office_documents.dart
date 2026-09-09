import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../billing/domain/totals.dart';
import '../domain/office_documents.dart';
class PdfOfficeDocuments implements OfficeDocuments {
 @override Future<Uint8List> payslip(Map<String,dynamic> p)async{
  final doc=pw.Document(),employee=p['employee'] as Map;
  doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(40),build:(_)=>[
   pw.Text(p['company']['name'],style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:24),pw.Text('${p['status']=='draft'?'DRAFT ':''}PAYSLIP / ${p['month']}',style:const pw.TextStyle(fontSize:23)),pw.SizedBox(height:20),
   pw.Text('${employee['name']} / ${employee['code']}'),pw.Text('${employee['department']} / ${employee['title']}'),pw.SizedBox(height:20),
   pw.TableHelper.fromTextArray(headers:['Salary detail','AED'],data:[for(final x in {'Salary base':'baseCents','Overtime':'overtimeCents','Bonus':'bonusCents','Unpaid absence deduction':'absenceCents','Other deductions':'deductionCents','Net salary':'netCents'}.entries)[x.key,money((p[x.value] as num).toInt())]]),
   pw.SizedBox(height:20),pw.Text('Salary divisor: ${p['divisor']} / Base days: ${p['baseDays']} / Unpaid days: ${p['absentDays']}'),pw.Text('Status: ${p['status']}'),if(p['paidDate']!='')pw.Text('Paid: ${p['paidDate']} / ${p['account']} / ${p['reference']}'),pw.SizedBox(height:16),pw.Text(p['adjustmentNote']??''),
  ]));return doc.save();
 }
 @override Future<Uint8List> financialReport(String company,String month,Map<String,int> summary,List<Map<String,dynamic>> entries)async{
  final doc=pw.Document();doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(36),build:(_)=>[
   pw.Text(company,style:const pw.TextStyle(fontSize:20)),pw.Text('Cash movement report / $month',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:20),
   pw.TableHelper.fromTextArray(headers:['Measure','Amount'],data:[for(final e in summary.entries)[e.key,money(e.value)]]),pw.SizedBox(height:24),pw.Text('Other income and supplier expense entries'),pw.SizedBox(height:10),
   pw.TableHelper.fromTextArray(headers:['Date','Party / category','Type','Status','Amount'],data:[for(final e in entries.where((e)=>e['date'].toString().startsWith(month)))[e['date'],'${e['party']} / ${e['category']}',e['kind'],e['status'],money((e['amountCents'] as num).toInt())]]),pw.SizedBox(height:18),pw.Text('Bank and cash figures are period movements, not reconciled balances. Outstanding amounts include all dates. Invoice and payroll detail remains in the respective modules.'),
  ]));return doc.save();
 }
}
