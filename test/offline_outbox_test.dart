import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/offline/offline_outbox.dart';
import 'package:tpc_invoice/core/offline/offline_store.dart';

void main() {
  late OfflineStore store;
  late OfflineOutbox box;
  setUp(() {
    store = IndexedOfflineStore(newIdbFactoryMemory());
  });
  tearDown(() {
    box.dispose();
  });
  OfflineOutbox create(
          Future<Map<String, dynamic>> Function(Map<String, Object?>) send) =>
      OfflineOutbox(
          store: store,
          scope: 'test-company',
          automatic: false,
          isCurrent: () => true,
          verifyIdentity: () async {},
          send: send,
          changed: (_) {});
  Map<String, dynamic> ack(Map op, String id, int version) => {
        'results': [
          {
            'operationId': op['operationId'],
            'status': 'APPLIED',
            'recordId': id,
            'version': version
          }
        ]
      };

  test('saving another record does not wait for an in-flight network request',
      () async {
    final started = Completer<void>(), release = Completer<void>();
    var sends = 0;
    box = create((op) async {
      sends++;
      if (sends == 1) {
        started.complete();
        await release.future;
      }
      return ack(op, 'server-$sends', 1);
    });
    await box.enqueue('Customers', 'create', {'name': 'First'},
        expectedVersion: 0);
    final syncing = box.sync();
    await started.future;
    await box
        .enqueue('Projects', 'create', {'name': 'Second'}, expectedVersion: 0)
        .timeout(const Duration(seconds: 1));
    expect(box.overlay('Projects', []).single['name'], 'Second');
    expect((await store.read('test-company'))['operations'], hasLength(2));
    release.complete();
    await syncing;
    expect(box.pending, isEmpty);
    expect(sends, 2);
  });

  test('dependent edits resolve temporary IDs and use acknowledged versions',
      () async {
    final sent = <Map<String, Object?>>[];
    box = create((op) async {
      sent.add(op);
      return ack(op, 'server-customer', sent.length);
    });
    await box.enqueue('Customers', 'create', {'name': 'First'},
        expectedVersion: 0);
    final local = box.overlay('Customers', []).single;
    await box.enqueue('Customers', 'update', {'name': 'Edited'},
        recordId: local['recordId'], expectedVersion: 0, base: local);
    await box.sync();
    expect(sent, hasLength(2));
    expect(sent[1]['recordId'], 'server-customer');
    expect(sent[1]['expectedVersion'], 1);
    expect(box.overlay('Customers', []).single['name'], 'Edited');
    expect(box.pending, isEmpty);
  });

  test('rejected parent holds dependencies but unrelated records keep syncing',
      () async {
    final sent = <String>[];
    box = create((op) async {
      sent.add(op['table'] as String);
      if (op['table'] == 'Customers') {
        throw const SaasApiException('INVALID_RECORD', 'Invalid customer',
            status: 400);
      }
      return ack(op, 'server-task', 1);
    });
    await box.enqueue('Customers', 'create', {'name': ''}, expectedVersion: 0);
    final localId = box.overlay('Customers', []).single['recordId'];
    await box.enqueue('Invoices', 'create', {'customerId': localId},
        expectedVersion: 0);
    await box.enqueue('Tasks', 'create', {'title': 'Unrelated'},
        expectedVersion: 0);
    await box.sync();
    expect(sent, ['Customers', 'Tasks']);
    expect(box.pending, hasLength(2));
    expect(box.pending.first['state'], 'failed');
    await box.discardRejected(
        operationId: box.pending.first['operationId'] as String);
    expect(box.pending, isEmpty);
    expect(box.overlay('Invoices', []), isEmpty);
    expect(box.overlay('Tasks', []).single['title'], 'Unrelated');
  });

  test('network failure survives reopening and retries the identical operation',
      () async {
    late Map<String, Object?> original;
    box = create((op) async {
      original = op;
      throw const SaasApiException('NETWORK', 'Offline');
    });
    await box.enqueue(
        'Expenses', 'create', {'description': 'Travel', 'total': 50},
        expectedVersion: 0);
    await box.sync();
    expect(box.pending.single['state'], 'pending');
    box.dispose();
    box = create((op) async {
      expect(op, original);
      return ack(op, 'server-expense', 1);
    });
    await box.reload();
    expect(box.overlay('Expenses', []).single['total'], 50);
    await box.retry();
    expect(box.pending, isEmpty);
  });

  test(
      'MoneyTransfers table deployment mismatch can retry after backend update',
      () async {
    var deployed = false;
    String? originalId;
    box = create((op) async {
      originalId ??= op['operationId'] as String;
      expect(op['operationId'], originalId);
      if (!deployed) {
        throw const SaasApiException(
            'TABLE_FORBIDDEN', 'This business table is unavailable.',
            status: 403);
      }
      return ack(op, 'server-transfer', 1);
    });
    await box.enqueue(
        'MoneyTransfers',
        'create',
        {
          'date': '2026-10-11',
          'fromAccount': 'cash',
          'toAccount': 'bank',
          'amount': 100,
          'description': 'Deposit'
        },
        expectedVersion: 0);
    await box.sync();
    expect(box.pending.single['state'], 'failed');
    deployed = true;
    await box.retry();
    expect(box.pending, isEmpty);
    expect(box.overlay('MoneyTransfers', []).single['recordId'],
        'server-transfer');
  });

  test(
      'correction creates a new request and clears stale background acknowledgement',
      () async {
    var fail = true;
    box = create((op) async {
      if (fail) {
        throw const SaasApiException('INVALID_RECORD', 'Correct the name',
            status: 400);
      }
      return ack(op, 'server-project', 1);
    });
    await box.enqueue('Projects', 'create', {'name': ''}, expectedVersion: 0);
    await box.sync();
    final oldId = box.pending.single['operationId'] as String;
    await store.change('test-company', (p) {
      p['operations'][0]
          ['backgroundAck'] = {'operationId': oldId, 'status': 'FAILED'};
    });
    await box.correctRejected(oldId, {'name': 'Corrected'}, expectedVersion: 0);
    expect(box.pending.single['operationId'], isNot(oldId));
    expect(box.pending.single.containsKey('backgroundAck'), isFalse);
    fail = false;
    await box.sync();
    expect(box.pending, isEmpty);
  });

  test('stored queue remains isolated from another company', () async {
    box = create((op) async => ack(op, 'server', 1));
    await box.enqueue('Payroll', 'create', {'month': '2026-10'},
        expectedVersion: 0);
    expect((await store.read('other-company'))['operations'], isEmpty);
    expect((await store.read('test-company'))['operations'], hasLength(1));
  });

  test('expired authentication pauses delivery but not local editing',
      () async {
    var authenticated = false, sends = 0;
    box = OfflineOutbox(
        store: store,
        scope: 'test-company',
        automatic: false,
        isCurrent: () => true,
        verifyIdentity: () async {
          if (!authenticated) {
            throw const SaasApiException('SESSION_EXPIRED', 'Sign in',
                status: 401);
          }
        },
        send: (op) async {
          sends++;
          return ack(op, 'server-$sends', 1);
        },
        changed: (_) {});
    await box.enqueue('Customers', 'create', {'name': 'First'},
        expectedVersion: 0);
    await box.sync();
    expect(box.authenticationRequired, isTrue);
    await box.enqueue('Projects', 'create', {'name': 'Still editable'},
        expectedVersion: 0);
    expect(box.pending, hasLength(2));
    expect(sends, 0);
    authenticated = true;
    await box.retry();
    expect(box.pending, isEmpty);
    expect(sends, 2);
  });

  test('retrying a rejected posting retains its no-values envelope', () async {
    var reject = true;
    box = create((op) async {
      expect(op.containsKey('values'), isFalse);
      if (reject) {
        throw const SaasApiException('PERIOD_CLOSED', 'Choose an open period',
            status: 409);
      }
      return ack(op, 'invoice', 2);
    });
    await box.enqueue('Invoices', 'issue', {},
        recordId: 'invoice', expectedVersion: 1, local: false);
    await box.sync();
    await box.correctRejected(box.pending.single['operationId'] as String, {},
        expectedVersion: 1);
    reject = false;
    await box.sync();
    expect(box.pending, isEmpty);
  });

  test('failed device writes never appear as successfully saved local records',
      () async {
    final failing = _FailingStore(store);
    box = OfflineOutbox(
        store: failing,
        scope: 'test-company',
        automatic: false,
        isCurrent: () => true,
        verifyIdentity: () async {},
        send: (op) async => ack(op, 'server', 1),
        changed: (_) {});
    await expectLater(
        box.enqueue('Customers', 'create', {'name': 'Not persisted'},
            expectedVersion: 0),
        throwsStateError);
    expect(box.pending, isEmpty);
    expect(box.overlay('Customers', []), isEmpty);
    expect(box.storageError, isNotNull);
    expect((await store.read('test-company'))['operations'], isEmpty);
  });
}

class _FailingStore implements OfflineStore {
  _FailingStore(this.delegate);
  final OfflineStore delegate;
  @override
  Future<Map<String, dynamic>> read(String scope) => delegate.read(scope);
  @override
  Future<Map<String, dynamic>> change(
      String scope, void Function(Map<String, dynamic>) edit) async {
    throw StateError('Device quota exceeded');
  }
}
