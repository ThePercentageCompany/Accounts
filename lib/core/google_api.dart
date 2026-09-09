import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth/google_session.dart';
class GoogleApi {
  final GoogleSession session;
  GoogleApi(this.session);
  Future<Map<String,dynamic>> command(String action,[Map<String,dynamic>? data]) async {
    const deployment=String.fromEnvironment('SCRIPT_DEPLOYMENT_ID');
    if(deployment.isEmpty)throw StateError('Set SCRIPT_DEPLOYMENT_ID in Google configuration.');
    final response=await http.post(Uri.https('script.googleapis.com','/v1/scripts/$deployment:run'),headers:{'Authorization':'Bearer ${await session.token()}','Content-Type':'application/json'},body:jsonEncode({'function':'execute','parameters':[{'action':action,'data':data??{}}],'devMode':false})).timeout(const Duration(seconds:90));
    if(response.statusCode==401){session.expire();throw StateError('Google session expired. Reconnect Google.');}
    final body=jsonDecode(response.body) as Map<String,dynamic>;
    if(response.statusCode!=200||body['error']!=null)throw StateError('Google execution failed. Check account permission and API deployment; refresh before retrying.');
    final result=Map<String,dynamic>.from(body['response']['result'] as Map);
    if(result['ok']!=true)throw StateError(result['error']?.toString()??'Operation failed');
    return Map<String,dynamic>.from(result['result'] as Map);
  }
}
