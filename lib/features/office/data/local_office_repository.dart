import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/office_repository.dart';
import '../domain/office_rules.dart';
import '../../billing/domain/totals.dart';
import '../../billing/domain/models.dart';
// Single-device demo. Connected mode validates all writes in Apps Script.
class LocalOfficeRepository implements OfficeRepository {
 @override bool get isDemo=>true;
 @override Future<Map<String,dynamic>> command(String action,[Map<String,dynamic>? payload])async{
  final prefs=await SharedPreferences.getInstance();
  final root=Map<String,dynamic>.from(jsonDecode(prefs.getString('tpc_office_demo_v2')??'{"employees":[],"attendance":[],"payroll":[],"entries":[]}'));
  List<Map<String,dynamic>> list(String k)=>(root[k] as List).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
  final d=Map<String,dynamic>.from(payload??{});
  if(action=='officeLoad'){
    root.putIfAbsent('employees', () => []);
    root.putIfAbsent('attendance', () => []);
    root.putIfAbsent('payroll', () => []);
    root.putIfAbsent('entries', () => []);
    root.putIfAbsent('shareholders', () => []);
    root.putIfAbsent('capitalTransactions', () => []);
    root.putIfAbsent('shareholderLoans', () => []);
    root.putIfAbsent('assets', () => []);
    root.putIfAbsent('journals', () => []);
    return root;
  }
  var key='',record=<String,dynamic>{};
  Map<String,dynamic>? find(String k,String id){for(final r in list(k)){if(r['id']==id)return r;}return null;}
  void version(Map<String,dynamic>? old){if((old?['version']??0)!=(d['version']??0))throw StateError('Record changed. Refresh and reopen.');}
  
  if(action=='employeeSave'){
   key='employees';final old=find(key,d['id']);version(old);
   if(list(key).any((e)=>e['id']!=d['id']&&e['code']==d['code']))throw StateError('Employee code already exists.');
   scaled(d['basic'].toString(),2);scaled(d['allowances'].toString(),2);
   record={...d,'documents':old?['documents']??[],'version':(d['version'] as int)+1};
  }else if(action=='attendanceSave'){
   key='attendance';final id='${d['employeeId']}_${d['date']}';final old=find(key,id);version(old);
   if(list('payroll').any((p)=>p['employee']['id']==d['employeeId']&&p['month']==d['date'].toString().substring(0,7)&&p['status']!='draft'))throw StateError('Attendance is locked by approved payroll.');
   final employee=find('employees',d['employeeId'])!;
   if(d['date'].toString().compareTo(employee['joinDate'])<0||(employee['endDate']!=''&&d['date'].toString().compareTo(employee['endDate'])>0))throw StateError('Date outside employment.');
   if(scaled(d['overtimeHours'].toString(),2)>2400)throw StateError('Overtime exceeds 24 hours.');
   record={...d,'id':id,'version':(d['version'] as int)+1};
  }else if(action=='payrollGenerate'){
   key='payroll';final id='${d['employeeId']}_${d['month']}';final old=find(key,id);version(old);
   if(old!=null&&old['status']!='draft')throw StateError('Payroll already approved.');
   final employee=find('employees',d['employeeId'])!;
   final rows=list('attendance').where((a)=>a['employeeId']==d['employeeId']&&a['date'].toString().startsWith(d['month'])).toList()..sort((a,b)=>a['date'].toString().compareTo(b['date']));
   final billing=prefs.getString('tpc_demo_v1');final company=billing==null?const Company().toJson():jsonDecode(billing)['company'];
   record={...d,'id':id,'employee':employee,'attendanceSnapshot':rows,'company':company,...calculatePayroll(employee,rows,d),'status':'draft','version':(d['version'] as int)+1,'paidDate':'','account':'Bank','driveUrl':'','archivedVersion':0,'reference':''};
  }else if(action=='payrollApprove'||action=='payrollPay'){
   key='payroll';record=find(key,d['id'])!;
   if(action=='payrollPay'&&record['status']=='paid')return record;
   if(action=='payrollApprove'&&record['status']!='draft')return record;
   version(record);
   if(action=='payrollApprove'){
    if(record['missingDays']!=0)throw StateError('Marked scheduled days must match expected days.');
    if(find('employees',record['employee']['id'])!['version']!=record['employee']['version'])throw StateError('Employee changed. Regenerate draft.');
    final rows=list('attendance').where((a)=>a['employeeId']==record['employee']['id']&&a['date'].toString().startsWith(record['month'])).toList()..sort((a,b)=>a['date'].toString().compareTo(b['date']));
    if(jsonEncode(rows)!=jsonEncode(record['attendanceSnapshot']))throw StateError('Attendance changed. Regenerate draft.');
    record['status']='approved';
   }else{if(record['status']!='approved')throw StateError('Approve first.');record.addAll({'status':'paid','paidDate':d['paidDate'],'account':d['account'],'reference':d['reference']});}
   record['version']=(record['version'] as int)+1;
  }else if(action=='financeSave'){
   key='entries';final old=find(key,d['id']);version(old);
   if(old!=null&&old['status']!='unpaid')throw StateError('Posted entries are locked.');
   final amount=scaled(d['amount'].toString(),2);if(amount<=0)throw StateError('Amount must exceed zero.');
   record={...d,'amountCents':amount,'status':d['kind']=='income'?'paid':d['status'],'documents':old?['documents']??[],'version':(d['version'] as int)+1};
  }else if(action=='financePay'||action=='financeVoid'){
   key='entries';record=find(key,d['id'])!;if(record['status']==(action=='financePay'?'paid':'void'))return record;version(record);
   if(record['status']!='unpaid')throw StateError('Only unpaid bills can change.');
   record.addAll({'status':action=='financePay'?'paid':'void','paidDate':d['paidDate']??'','account':d['account']??record['account'],'version':(record['version'] as int)+1});
  }else if(action=='shareholderSave'){
   key='shareholders';final id=d['id']??'SHR_${DateTime.now().millisecondsSinceEpoch}';
   final old=find(key,id);if(old!=null)version(old);
   record={...d,'id':id,'version':((d['version'] as int?)??0)+1};
  }else if(action=='shareholderDelete'){
   key='shareholders';final id=d['id'] as String;
   root[key]=list(key).where((x)=>x['id']!=id).toList();
   await prefs.setString('tpc_office_demo_v2',jsonEncode(root));
   return {'id':id};
  }else if(action=='capitalTransactionSave'){
   key='capitalTransactions';final id=d['id']??'CAP_${DateTime.now().millisecondsSinceEpoch}';
   final old=find(key,id);if(old!=null)version(old);
   final amountCents=scaled(d['amount'].toString(),2);
   if(amountCents<=0)throw StateError('Contribution amount must be greater than zero.');
   
   // Auto generate balanced journal entry
   final journal=createCapitalJournal(
     transactionId: id,
     shareholderName: d['shareholderName']??'Shareholder',
     date: d['date']??DateTime.now().toIso8601String().substring(0,10),
     transactionType: d['transactionType']??'capitalContribution',
     contributionType: d['contributionType']??'bank',
     amountCents: amountCents,
     assetName: d['assetName'],
     accountName: d['bankAccountId']??'Bank Account',
   );
   root['journals']=[...list('journals'), journal];
   
   record={...d,'id':id,'amountCents':amountCents,'journalId':journal['id'],'version':((d['version'] as int?)??0)+1};
  }else if(action=='capitalTransactionDelete'){
   key='capitalTransactions';final id=d['id'] as String;
   root[key]=list(key).where((x)=>x['id']!=id).toList();
   await prefs.setString('tpc_office_demo_v2',jsonEncode(root));
   return {'id':id};
  }else if(action=='shareholderLoanSave'){
   key='shareholderLoans';final id=d['id']??'LOAN_${DateTime.now().millisecondsSinceEpoch}';
   final old=find(key,id);if(old!=null)version(old);
   final amountCents=scaled(d['amount'].toString(),2);
   if(amountCents<=0)throw StateError('Loan amount must be greater than zero.');
   
   final journal=createShareholderLoanJournal(
     loanId: id,
     shareholderName: d['shareholderName']??'Shareholder',
     date: d['date']??DateTime.now().toIso8601String().substring(0,10),
     type: d['type']??'loanReceived',
     amountCents: amountCents,
     paymentAccount: d['paymentAccount']??'Bank',
   );
   root['journals']=[...list('journals'), journal];

   record={...d,'id':id,'amountCents':amountCents,'journalId':journal['id'],'version':((d['version'] as int?)??0)+1};
  }else if(action=='shareholderLoanDelete'){
   key='shareholderLoans';final id=d['id'] as String;
   root[key]=list(key).where((x)=>x['id']!=id).toList();
   await prefs.setString('tpc_office_demo_v2',jsonEncode(root));
   return {'id':id};
  }else if(action=='assetSave'){
   key='assets';final id=d['id']??'AST_${DateTime.now().millisecondsSinceEpoch}';
   final old=find(key,id);if(old!=null)version(old);
   final costCents=scaled(d['cost'].toString(),2);
   final accDepCents=(d['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0;
   final bookValueCents=(costCents - accDepCents).clamp(0, costCents);

   // Auto create asset acquisition journal if new asset
   if(old==null){
     final journal=createAssetPurchaseJournal(
       assetId: id,
       assetName: d['name']??'Asset',
       category: d['category']??'Fixed Assets',
       date: d['purchaseDate']??DateTime.now().toIso8601String().substring(0,10),
       acquisitionType: d['acquisitionType']??'companyPurchase',
       costCents: costCents,
       paymentAccount: d['paymentAccount']??'Bank',
       shareholderName: d['shareholderName'],
     );
     root['journals']=[...list('journals'), journal];
   }

   record={
     ...d,
     'id': id,
     'costCents': costCents,
     'accumulatedDepreciationCents': accDepCents,
     'bookValueCents': bookValueCents,
     'version': ((d['version'] as int?) ?? 0) + 1,
   };
  }else if(action=='assetDelete'){
   key='assets';final id=d['id'] as String;
   root[key]=list(key).where((x)=>x['id']!=id).toList();
   await prefs.setString('tpc_office_demo_v2',jsonEncode(root));
   return {'id':id};
  }else if(action=='runDepreciation'){
   key='assets';
   final assetsList=list(key);
   final updatedAssets=<Map<String,dynamic>>[];
   final newJournals=<Map<String,dynamic>>[];
   final today=DateTime.now().toIso8601String().substring(0,10);

   for(final a in assetsList){
     if(a['status']=='active'){
       final cost=(a['costCents'] as num?)?.toInt() ?? 0;
       final residual=scaled((a['residualValue']??0).toString(),2);
       final months=(a['usefulLifeMonths'] as num?)?.toInt() ?? 36;
       final currentAccDep=(a['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0;
       
       final depCalc=calculateDepreciation(costCents: cost, residualValueCents: residual, usefulLifeMonths: months);
       final monthlyDep=depCalc['monthlyCents'] ?? 0;

       if(monthlyDep > 0 && currentAccDep < (cost - residual)){
         final newAccDep=(currentAccDep + monthlyDep).clamp(0, cost - residual);
         final newBookVal=(cost - newAccDep).clamp(0, cost);
         
         final jrn=createDepreciationJournal(
           assetId: a['id'] as String,
           assetName: a['name'] as String? ?? 'Asset',
           date: today,
           depreciationCents: monthlyDep,
         );
         newJournals.add(jrn);

         updatedAssets.add({
           ...a,
           'accumulatedDepreciationCents': newAccDep,
           'accumulatedDepreciation': newAccDep / 100.0,
           'bookValueCents': newBookVal,
           'bookValue': newBookVal / 100.0,
           'version': ((a['version'] as int?) ?? 0) + 1,
         });
         continue;
       }
     }
     updatedAssets.add(a);
   }

   root['assets']=updatedAssets;
   root['journals']=[...list('journals'), ...newJournals];
   await prefs.setString('tpc_office_demo_v2',jsonEncode(root));
   return {'status':'success','depreciatedCount':newJournals.length};
  }else{throw StateError('Unrecognized office command.');}
  
  root[key]=[...list(key).where((x)=>x['id']!=record['id']),record];
  if(!await prefs.setString('tpc_office_demo_v2',jsonEncode(root)))throw StateError('Device storage failed.');return record;
 }
}
