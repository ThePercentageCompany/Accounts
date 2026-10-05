import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/accounting/data/record_write_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final batchError in [true, false]) {
    test(
      'rejected draft permits a fresh creation (batch error: $batchError)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final ids = <String>[];
        final api = SaasApi(
          origin: 'https://api.test',
          client: MockClient((request) async {
            final op = jsonDecode(request.body)['operations'][0];
            ids.add(op['operationId'] as String);
            if (ids.length == 1) {
              final error = {
                'code': 'INVALID_RECORD',
                'message': 'Record contains unsupported fields.',
              };
              return http.Response(
                jsonEncode(
                  batchError
                      ? {'error': error}
                      : {
                          'results': [
                            {
                              'operationId': op['operationId'],
                              'status': 'FAILED',
                              'error': error,
                            },
                          ],
                        },
                ),
                batchError ? 400 : 200,
              );
            }
            return http.Response(
              jsonEncode({
                'results': [
                  {'operationId': op['operationId'], 'status': 'APPLIED'},
                ],
              }),
              200,
            );
          }),
        );
        final queue = RecordWriteQueue(api, prefs, 'owner', 'c' * 43);
        await queue.enqueue('Invoices', 'create', {
          'currency': 'AED',
        }, expectedVersion: 0);
        await expectLater(queue.flush(), throwsA(isA<SaasApiException>()));
        expect(queue.pending, isEmpty);
        await queue.enqueue('Invoices', 'create', {
          'currency': 'USD',
        }, expectedVersion: 0);
        await queue.flush();
        expect(ids[0], isNot(ids[1]));
        expect(queue.pending, isEmpty);
        api.close();
      },
    );
  }
  test(
    'employee pending writes use employee endpoint and isolated storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          expect(request.url.path, '/v1/employee/sync');
          final op = jsonDecode(request.body)['operations'][0];
          return http.Response(
            jsonEncode({
              'results': [
                {'operationId': op['operationId'], 'status': 'APPLIED'},
              ],
            }),
            200,
          );
        }),
      );
      final employee = RecordWriteQueue(
        api,
        prefs,
        'employee_${'e' * 43}',
        'c' * 43,
        employee: true,
      );
      final owner = RecordWriteQueue(api, prefs, 'owner', 'c' * 43);
      await employee.enqueue('Customers', 'create', {
        'name': 'Customer',
      }, expectedVersion: 0);
      expect(owner.pending, isEmpty);
      await employee.flush();
      expect(employee.pending, isEmpty);
      api.close();
    },
  );
  test(
    'receipt payment retains the server-validated allocation inputs',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((request) async {
          final operation = jsonDecode(request.body)['operations'][0] as Map;
          expect(operation['action'], 'receive');
          expect(operation.containsKey('recordId'), isFalse);
          expect(operation['expectedVersion'], 0);
          expect(operation['values']['invoiceId'], 'i' * 43);
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'operationId': operation['operationId'],
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
      await queue.enqueue('Receipts', 'receive', {
        'invoiceId': 'i' * 43,
        'customerId': 'u' * 43,
        'paymentDate': '2026-09-28',
        'amount': 25.0,
        'currency': 'AED',
        'paymentAccount': 'Bank',
        'reference': 'Transfer',
      }, expectedVersion: 0);
      await queue.flush();
      expect(queue.pending, isEmpty);
      api.close();
    },
  );
  test('invoice issuing persists no client-controlled values', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = SaasApi(
      origin: 'https://api.test',
      client: MockClient((request) async {
        final operation = jsonDecode(request.body)['operations'][0] as Map;
        expect(operation['action'], 'issue');
        expect(operation.containsKey('values'), isFalse);
        return http.Response(
          jsonEncode({
            'results': [
              {
                'operationId': operation['operationId'],
                'status': 'APPLIED',
                'recordId': 'i' * 43,
                'version': 3,
              },
            ],
          }),
          200,
        );
      }),
    );
    final queue = RecordWriteQueue(api, prefs, 'owner', 'c' * 43);
    await queue.enqueue(
      'Invoices',
      'issue',
      {},
      recordId: 'i' * 43,
      expectedVersion: 2,
    );
    await queue.flush();
    expect(queue.pending, isEmpty);
    api.close();
  });
  test(
    'posting persists its identity without client values and retains rejected requests',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = SaasApi(
        origin: 'https://api.test',
        client: MockClient((r) async {
          final op = jsonDecode(r.body)['operations'][0];
          expect(op['action'], 'post');
          expect(op.containsKey('values'), isFalse);
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'operationId': op['operationId'],
                  'status': 'FAILED',
                  'error': {
                    'code': 'PERIOD_CLOSED',
                    'message': 'Period closed.',
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      final queue = RecordWriteQueue(api, prefs, 'owner', 'c' * 43);
      await queue.enqueue(
        'Income',
        'post',
        {},
        recordId: 'r' * 43,
        expectedVersion: 1,
      );
      final before = queue.pending.single;
      await expectLater(queue.flush(), throwsA(isA<SaasApiException>()));
      expect(queue.pending.single, before);
      expect(queue.canDiscardRejected, isTrue);
      await queue.discardRejected();
      expect(queue.pending, isEmpty);
      api.close();
    },
  );
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
    expect(queue.canDiscardRejected, isTrue);
    await queue.discardRejected();
    expect(queue.pending, isEmpty);
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
    expect(queue.canDiscardRejected, isFalse);
    await expectLater(
      queue.discardRejected(),
      throwsA(isA<SaasApiException>()),
    );
    final restored = RecordWriteQueue(api, prefs, 'owner', 'c' * 43);
    await restored.flush();
    expect(bodies.first, bodies.last);
    expect(restored.pending, isEmpty);
    api.close();
  });
}
