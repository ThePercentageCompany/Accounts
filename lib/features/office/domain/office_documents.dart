import 'dart:typed_data';
abstract interface class OfficeDocuments {
 Future<Uint8List> payslip(Map<String,dynamic> payroll);
 Future<Uint8List> financialReport(String company,String month,Map<String,int> summary,List<Map<String,dynamic>> entries);
}
