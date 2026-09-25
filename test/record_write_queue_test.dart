import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/saas/saas_api.dart';
import 'package:tpc_invoice/core/saas/record_write_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('partial HTTP success removes only applied operations', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = SaasApi(
      origin: 'https://api.test',
      client: MockClient((r) async {
        final ops = jsonDecode(r.body)['operations'] as List;
        return http.Response(
          jsonEncode({
            'results': [
              {
                'operationId': ops[0]['operationId'],
                'status': 'APPLIED',
                'recordId': 'r' * 43,
                'version': 1,
              },
              {
                'operationId': ops[1]['operationId'],
                'status': 'FAILED',
                'error': {
                  'code': 'VERSION_CONFLICT',
                  'message': 'Refresh before editing.',
                },
              },
            ],
          }),
          200,
        );
      }),
    );
    final queue = RecordWriteQueue(api, prefs, 'owner', 'c' * 43);
    final ops = [
      for (final id in ['a' * 16, 'b' * 16])
        <String, Object?>{
          'operationId': id,
          'table': 'Customers',
          'action': 'create',
          'expectedVersion': 0,
          'values': {'name': id},
        },
    ];
    for (final op in ops) {
      await prefs.setString(
        '${queue.storageKey}_${op['operationId']}',
        jsonEncode(op),
      );
    }
    await expectLater(queue.flush(), throwsA(isA<SaasApiException>()));
    expect(queue.pending, [ops[1]]);
    expect(
      RecordWriteQueue(api, prefs, 'other-owner', 'c' * 43).pending,
      isEmpty,
    );
    api.close();
  });
  test('unknown response keeps exact operation across restarts', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final bodies = <String>[];
    final api = SaasApi(
      origin: 'https://api.test',
      client: MockClient((r) async {
        bodies.add(r.body);
        final op = jsonDecode(r.body)['operations'][0];
        if (bodies.length == 1) throw http.ClientException('Offline');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'operationId': op['operationId'],
                'status': 'APPLIED',
                'recordId': 'r' * 43,
                'version': 1,
              },
            ],
          }),
          200,
        );
      }),
    );
    final queue = RecordWriteQueue(api, prefs, 'owner', 'c' * 43);
    await queue.enqueue('Customers', 'create', {
      'name': 'Customer',
    }, expectedVersion: 0);
    await expectLater(queue.flush(), throwsA(isA<SaasApiException>()));
    final restored = RecordWriteQueue(api, prefs, 'owner', 'c' * 43);
    await restored.flush();
    expect(bodies.first, bodies.last);
    expect(restored.pending, isEmpty);
    api.close();
  });
}
