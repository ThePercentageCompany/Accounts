import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:tpc_invoice/core/offline/offline_store.dart';
import 'package:tpc_invoice/core/offline/offline_outbox.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

class BrokenStore implements OfflineStore {
  @override
  Future<Map<String, dynamic>> read(String scope) async => emptyPartition();
  @override
  Future<Map<String, dynamic>> change(
    String scope,
    void Function(Map<String, dynamic>) edit,
  ) async =>
      throw StateError('QuotaExceededError');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late OfflineStore store;
  var run = 0;
  late String partition;
  late DateTime now;
  late bool current;
  late List<Map<String, Object?>> sent;
  OfflineOutbox create({
    String? scope,
    OfflineStore? storage,
    Future<Map<String, dynamic>> Function(Map<String, Object?>)? sender,
    Future<void> Function()? verify,
  }) {
    final box = OfflineOutbox(
      store: storage ?? store,
      scope: scope ?? partition,
      automatic: false,
      clock: () => now,
      random: () => 0.5,
      isCurrent: () => current,
      verifyIdentity: verify ?? () async {},
      changed: (_) {},
      send: sender ??
          (op) async {
            sent.add(Map.of(op));
            return {
              'results': [
                {
                  'operationId': op['operationId'],
                  'status': 'APPLIED',
                  'recordId': op['recordId'] ?? 'server-${sent.length}',
                  'version': (op['expectedVersion'] as int) + 1,
                },
              ],
            };
          },
    );
    addTearDown(box.dispose);
    return box;
  }

  setUp(() {
    partition = 'test-${DateTime.now().microsecondsSinceEpoch}-${run++}';
    store = kIsWeb
        ? createOfflineStore()
        : IndexedOfflineStore(newIdbFactoryMemory());
    now = DateTime(2026, 10, 6);
    current = true;
    sent = [];
  });

  test(
    'atomic record and operation survive recreation; IDs and dependencies reconcile',
    () async {
      final first = create();
      await first.enqueue(
          'Customers',
          'create',
          {
            'name': 'Local',
          },
          expectedVersion: 0);
      final id = first.overlay('Customers', []).single['recordId'] as String;
      await first.enqueue(
        'Customers',
        'update',
        {'name': 'Edited'},
        recordId: id,
        expectedVersion: 0,
      );
      await first.enqueue(
          'Invoices',
          'create',
          {
            'customerId': id,
            'items': [
              {'description': 'Line', 'quantity': 1},
            ],
          },
          expectedVersion: 0);
      final restored = create();
      await restored.reload();
      expect(restored.pending.length, 3);
      expect(restored.overlay('Customers', []).single['name'], 'Edited');
      await restored.sync();
      expect(restored.pending, isEmpty);
      expect(sent[1]['recordId'], 'server-1');
      expect(sent[1]['expectedVersion'], 1);
      expect((sent[2]['values'] as Map)['customerId'], 'server-1');
      expect(restored.overlay('Customers', []).single['syncStatus'], 'SYNCED');
    },
  );

  test(
    'tombstone stays durable until acknowledgement; rejection remains visible',
    () async {
      final box = create(
        sender: (op) async => {
          'results': [
            {
              'operationId': op['operationId'],
              'status': 'FAILED',
              'error': {
                'code': 'RECORD_REFERENCED',
                'message': 'Customer has invoices.',
              },
            },
          ],
        },
      );
      await box.enqueue(
        'Customers',
        'delete',
        {},
        recordId: 'server',
        expectedVersion: 2,
        base: {'recordId': 'server', 'name': 'Customer'},
      );
      expect(box.overlay('Customers', []), isEmpty);
      final restored = create();
      await restored.reload();
      expect(restored.data['records']['Customers:server']['isDeleted'], true);
      await box.sync();
      expect(box.overlay('Customers', []).single['syncStatus'], 'FAILED');
      expect(box.pending.single['error'], 'Customer has invoices.');
    },
  );

  test(
      'stale editor IDs and dependent references resolve after acknowledgement',
      () async {
    final box = create();
    await box.enqueue('Customers', 'create', {'name': 'First'},
        expectedVersion: 0);
    final temporaryId =
        box.overlay('Customers', []).single['recordId'] as String;
    await box.sync();
    await box.enqueue('Customers', 'update', {'name': 'Later'},
        recordId: temporaryId, expectedVersion: 0);
    expect(box.pending.single['recordId'], 'server-1');
    expect(box.pending.single['expectedVersion'], 1);
    await box.enqueue('Invoices', 'create', {'customerId': temporaryId},
        expectedVersion: 0);
    expect((box.pending.last['values'] as Map)['customerId'], 'server-1');
  });

  test('API displays durable local rows with no server snapshot or connection',
      () async {
    final api = SaasApi(
        origin: 'https://api.test',
        offlineStore: store,
        offlineAutomatic: false,
        client: MockClient(
            (_) async => throw http.ClientException('Disconnected')));
    addTearDown(api.close);
    api.useVerifiedWorkspace('c' * 43, ownerId: 'owner');
    final box = api.outbox('owner', 'c' * 43);
    await box.enqueue('Customers', 'create', {'name': 'Device only'},
        expectedVersion: 0);
    final rows = (await api.records('c' * 43, 'Customers'))['records'] as List;
    expect(rows.single['name'], 'Device only');
    expect(rows.single['syncStatus'], 'PENDING');
    api.detachWorkspace();
    expect(box.overlay('Customers', []), isEmpty);
    expect(box.pending.length, 1);
  });

  test(
    'uncertain response retries identical payload after backoff without duplication',
    () async {
      var attempts = 0;
      final applied = <String>{};
      final payloads = <Map<String, Object?>>[];
      final box = create(
        sender: (op) async {
          payloads.add(Map.of(op));
          applied.add(op['operationId'] as String);
          if (++attempts == 1) {
            throw const SaasApiException('NETWORK', 'Response lost.');
          }
          return {
            'results': [
              {
                'operationId': op['operationId'],
                'status': 'APPLIED',
                'recordId': 'server',
                'version': 1,
              },
            ],
          };
        },
      );
      await box.enqueue(
          'Customers',
          'create',
          {
            'name': 'Keep',
          },
          expectedVersion: 0);
      await box.sync();
      expect(box.pending.single['state'], 'pending');
      await box.sync();
      expect(attempts, 1);
      now = now.add(const Duration(minutes: 10));
      await box.sync();
      expect(box.pending, isEmpty);
      expect(payloads[0], payloads[1]);
      expect(applied.length, 1);
    },
  );

  test(
    'authentication pauses; workspace/account switch never submits pending work',
    () async {
      var expired = true;
      final box = create(
        verify: () async {
          if (expired) {
            throw const SaasApiException(
              'UNAUTHORIZED',
              'Sign in.',
              status: 401,
            );
          }
        },
      );
      await box.enqueue(
          'Customers',
          'create',
          {
            'name': 'Original',
          },
          expectedVersion: 0);
      await box.sync();
      expect(box.authenticationRequired, true);
      await box.sync();
      expect(sent, isEmpty);
      current = false;
      expired = false;
      box.resumeAuthentication();
      await box.sync();
      expect(sent, isEmpty);
      current = true;
      await box.retry();
      expect(sent.length, 1);
      final other = create(scope: 'different-account/workspace');
      await other.reload();
      expect(other.pending, isEmpty);
      expect(other.overlay('Customers', []), isEmpty);
    },
  );

  test(
    'conflict requires explicit correction and fresh version with new operation ID',
    () async {
      var conflict = true;
      final box = create(
        sender: (op) async {
          sent.add(Map.of(op));
          return {
            'results': [
              conflict
                  ? {
                      'operationId': op['operationId'],
                      'status': 'FAILED',
                      'error': {
                        'code': 'VERSION_CONFLICT',
                        'message': 'Another user changed this record.',
                      },
                    }
                  : {
                      'operationId': op['operationId'],
                      'status': 'APPLIED',
                      'recordId': 'server',
                      'version': 6,
                    },
            ],
          };
        },
      );
      await box.enqueue(
        'Customers',
        'update',
        {'name': 'Edit'},
        recordId: 'server',
        expectedVersion: 2,
      );
      await box.sync();
      final old = box.pending.single['operationId'] as String;
      await box.retry();
      expect(sent.length, 1);
      expect(box.hasFailed, true);
      await box.correctRejected(old, {'name': 'Reviewed'}, expectedVersion: 5);
      expect(box.pending.single['operationId'], isNot(old));
      conflict = false;
      await box.sync();
      expect(sent.last['expectedVersion'], 5);
      expect(box.pending, isEmpty);
    },
  );

  test(
    'two workers share exclusive coordination and read fresh committed state',
    () async {
      final wait = Completer<void>();
      var requests = 0;
      Future<Map<String, dynamic>> sender(Map<String, Object?> op) async {
        requests++;
        await wait.future;
        return {
          'results': [
            {
              'operationId': op['operationId'],
              'status': 'APPLIED',
              'recordId': 'server',
              'version': 1,
            },
          ],
        };
      }

      final one = create(sender: sender), two = create(sender: sender);
      await one.enqueue(
          'Customers',
          'create',
          {
            'name': 'One',
          },
          expectedVersion: 0);
      final work = one.sync();
      while (requests == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      await two.sync();
      expect(requests, 1);
      wait.complete();
      await work;
      await two.sync();
      expect(requests, 1);
    },
  );

  test('quota failure never publishes or acknowledges a local save', () async {
    final box = create(storage: BrokenStore());
    await expectLater(
      box.enqueue(
          'Customers',
          'create',
          {
            'name': 'Not saved',
          },
          expectedVersion: 0),
      throwsStateError,
    );
    expect(box.pending, isEmpty);
    expect(box.overlay('Customers', []), isEmpty);
    expect(box.storageError, isNotNull);
  });

  test(
    'write transaction abort preserves the previous record and operation set',
    () async {
      await store.change('atomic', (p) => p['sequence'] = 1);
      await expectLater(
        store.change('atomic', (p) {
          p['operations'].add({'partial': true});
          p['records']['partial'] = {};
          throw StateError('Abort before commit');
        }),
        throwsStateError,
      );
      final value = await store.read('atomic');
      expect(value['sequence'], 1);
      expect(value['operations'], isEmpty);
      expect(value['records'], isEmpty);
    },
  );
}
