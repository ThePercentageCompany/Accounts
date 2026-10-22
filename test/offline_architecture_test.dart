import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';
import 'package:tpc_invoice/core/cache/read_cache.dart';
import 'package:tpc_invoice/core/cache/workspace_dependencies.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/network/workspace_change_buffer.dart';
import 'package:tpc_invoice/core/offline/fixed_decimal.dart';
import 'package:tpc_invoice/core/offline/local_values.dart';
import 'package:tpc_invoice/core/offline/offline_outbox.dart';
import 'package:tpc_invoice/core/offline/offline_store.dart';
import 'package:tpc_invoice/core/offline/provisional_report.dart';
import 'package:tpc_invoice/features/workspace/presentation/sync_change_editor.dart';

class _Store implements OfflineStore {
  final partitions = <String, Map<String, dynamic>>{};
  bool fail = false;
  @override
  Future<Map<String, dynamic>> read(String scope) async =>
      copyJson(partitions[scope] ?? emptyPartition());
  @override
  Future<Map<String, dynamic>> change(
    String scope,
    void Function(Map<String, dynamic>) edit,
  ) async {
    final next = await read(scope);
    edit(next);
    if (fail) throw StateError('Quota exceeded');
    partitions[scope] = copyJson(next);
    return next;
  }
}

Map<String, dynamic> _ack(Map op, {String? id}) => {
  'results': [
    {
      'operationId': op['operationId'],
      'status': 'APPLIED',
      'recordId': id ?? op['recordId'] ?? 'server_${op['operationId']}',
      'version': (op['expectedVersion'] as int) + 1,
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;
  late OfflineOutbox box;
  late List<Map<String, Object?>> sent;
  late Future<Map<String, dynamic>> Function(Map<String, Object?>) send;
  late bool current;
  late DateTime now;
  setUp(() {
    store = _Store();
    sent = [];
    current = true;
    now = DateTime(2026, 10, 22);
    send = (op) async => _ack(op);
    box = OfflineOutbox(
      store: store,
      scope: 'workspace-a',
      isCurrent: () => current,
      verifyIdentity: () async {},
      send: (op) {
        sent.add(copyJson(op));
        return send(op);
      },
      changed: (_) {},
      automatic: false,
      clock: () => now,
      random: () => .99,
    );
  });
  tearDown(() => box.dispose());

  test(
    'local record and operation commit before any network request',
    () async {
      await box.enqueue('Customers', 'create', {
        'name': 'Offline',
      }, expectedVersion: 0);
      expect(sent, isEmpty);
      expect(box.overlay('Customers', []).single['name'], 'Offline');
      expect(box.overlay('Customers', []).single['_syncLabel'], 'Pending sync');
      final saved = await store.read('workspace-a');
      expect(saved['operations'], hasLength(1));
      expect(saved['records'], hasLength(1));
      expect((await store.read('workspace-b'))['operations'], isEmpty);
    },
  );
  test(
    'storage failure publishes neither record nor queue acknowledgement',
    () async {
      store.fail = true;
      await expectLater(
        box.enqueue('Customers', 'create', {
          'name': 'Unsaved',
        }, expectedVersion: 0),
        throwsStateError,
      );
      expect(box.pending, isEmpty);
      expect(box.overlay('Customers', []), isEmpty);
      expect(box.storageError, isNotNull);
    },
  );
  test('transient record failure does not block unrelated records', () async {
    await box.enqueue('Customers', 'create', {
      'name': 'First',
    }, expectedVersion: 0);
    await box.enqueue('Customers', 'create', {
      'name': 'Second',
    }, expectedVersion: 0);
    final firstId = box.pending.first['operationId'];
    send = (op) async {
      if (op['operationId'] == firstId) {
        throw const SaasApiException(
          'BUSINESS_WRITE_PENDING',
          'Try later',
          status: 409,
        );
      }
      return _ack(op);
    };
    await box.sync();
    expect(sent, hasLength(2));
    expect(box.pending.single['operationId'], firstId);
    expect(box.pending.single['state'], 'pending');
    expect(box.activeOperationId, isNull);
  });
  test(
    'retry preserves the immutable command after an uncertain outcome',
    () async {
      await box.enqueue('Customers', 'create', {
        'name': 'Saved',
      }, expectedVersion: 0);
      send = (_) async => throw const SaasApiException('NETWORK', 'Offline');
      await box.sync();
      final original = copyJson(sent.single);
      send = (op) async => _ack(op);
      await box.retry();
      expect(sent.last, original);
      expect(box.pending, isEmpty);
    },
  );
  test(
    'dependent operations wait and resolve temporary customer identifiers',
    () async {
      await box.enqueue('Customers', 'create', {
        'name': 'Customer',
      }, expectedVersion: 0);
      final customerId = box.localRecords('Customers').single['recordId'];
      await box.enqueue('Invoices', 'create', {
        'customerId': customerId,
        'status': 'DRAFT',
      }, expectedVersion: 0);
      send = (op) async => _ack(
        op,
        id: op['table'] == 'Customers'
            ? 'confirmed_customer'
            : 'confirmed_invoice',
      );
      await box.sync();
      expect(sent, hasLength(2));
      expect((sent.last['values'] as Map)['customerId'], 'confirmed_customer');
      expect(box.pending, isEmpty);
    },
  );
  test(
    'conflicts retain changes and require explicit corrected revision',
    () async {
      await box.enqueue(
        'Invoices',
        'update',
        {'notes': 'My edit'},
        recordId: 'invoice',
        expectedVersion: 3,
        base: {'recordId': 'invoice', 'status': 'DRAFT'},
      );
      send = (_) async => {
        'results': [
          {
            'operationId': box.pending.single['operationId'],
            'status': 'FAILED',
            'error': {
              'code': 'VERSION_CONFLICT',
              'message': 'Changed',
              'status': 409,
            },
          },
        ],
      };
      await box.sync();
      final oldId = box.pending.single['operationId'];
      expect(box.hasConflict, isTrue);
      expect(box.operationStatus(box.pending.single), 'Conflict');
      await box.retry();
      expect(sent, hasLength(1));
      await box.correctRejected(oldId as String, {
        'notes': 'Reviewed',
      }, expectedVersion: 4);
      expect(box.pending.single['operationId'], isNot(oldId));
      expect(box.pending.single['expectedVersion'], 4);
      expect((box.pending.single['values'] as Map)['notes'], 'Reviewed');
    },
  );
  test('authentication failure pauses all writes', () async {
    await box.enqueue('Customers', 'create', {'name': 'A'}, expectedVersion: 0);
    await box.enqueue('Customers', 'create', {'name': 'B'}, expectedVersion: 0);
    send = (_) async =>
        throw const SaasApiException('UNAUTHORIZED', 'Sign in', status: 401);
    await box.sync();
    expect(sent, hasLength(1));
    expect(box.authenticationRequired, isTrue);
    expect(box.pending, hasLength(2));
  });
  test(
    'server error status is preserved inside a successful batch response',
    () async {
      await box.enqueue('Customers', 'create', {
        'name': 'A',
      }, expectedVersion: 0);
      send = (op) async => {
        'results': [
          {
            'operationId': op['operationId'],
            'status': 'FAILED',
            'error': {
              'code': 'UPSTREAM_TIMEOUT',
              'message': 'Try again',
              'status': 503,
            },
          },
        ],
      };
      await box.sync();
      expect(box.pending.single['state'], 'pending');
      expect(box.hasFailed, isFalse);
    },
  );
  test('backoff including jitter is capped at five minutes', () async {
    await box.enqueue('Customers', 'create', {'name': 'A'}, expectedVersion: 0);
    await store.change(
      'workspace-a',
      (p) => p['operations'][0]['attempts'] = 20,
    );
    send = (_) async => throw const SaasApiException(
      'SERVICE_UNAVAILABLE',
      'Retry',
      status: 503,
    );
    await box.sync();
    expect(
      (box.pending.single['retryAt'] as int) - now.millisecondsSinceEpoch,
      lessThanOrEqualTo(300000),
    );
    expect(sent, hasLength(1));
  });
  test(
    'in-flight synchronization status clears after acknowledgement',
    () async {
      await box.enqueue('Customers', 'create', {
        'name': 'A',
      }, expectedVersion: 0);
      final started = Completer<void>(),
          response = Completer<Map<String, dynamic>>();
      send = (_) {
        started.complete();
        return response.future;
      };
      final running = box.sync();
      await started.future;
      expect(box.operationStatus(box.pending.single), 'Syncing');
      expect(box.overlay('Customers', []).single['_syncLabel'], 'Syncing');
      response.complete(_ack(sent.single));
      await running;
      expect(box.activeOperationId, isNull);
      expect(box.status, 'Synced');
      expect(
        box.overlay('Customers', []).single.containsKey('_syncLabel'),
        isFalse,
      );
    },
  );
  test(
    'workspace change prevents a queued operation from being sent',
    () async {
      await box.enqueue('Customers', 'create', {
        'name': 'A',
      }, expectedVersion: 0);
      current = false;
      await box.sync();
      expect(sent, isEmpty);
      expect(box.pending, hasLength(1));
    },
  );
  test(
    'journal posting stays draft locally until server confirmation',
    () async {
      await box.enqueue(
        'Journals',
        'update',
        {'status': 'POSTED'},
        recordId: 'journal',
        expectedVersion: 1,
        base: {'recordId': 'journal', 'status': 'DRAFT'},
      );
      final row = box.overlay('Journals', []).single;
      expect(row['status'], 'DRAFT');
      expect(row['_pendingAction'], 'post');
      expect((box.pending.single['values'] as Map)['status'], 'POSTED');
      await box.sync();
      expect(box.overlay('Journals', []).single['status'], 'POSTED');
    },
  );

  test(
    'draft expenses have no accounting effect; pending posting is labelled',
    () async {
      final expense = {
        'recordId': 'expense',
        'status': 'DRAFT',
        'date': '2026-10-22',
        'amount': 500,
        'total': 500,
        'taxAmount': 0,
        'exchangeRate': 1,
      };
      final report = <String, dynamic>{
        'asOf': '2026-10-22',
        'accounts': [],
        'totalExpenses': '0.00',
        'totalAssets': '0.00',
        'totalLiabilities': '0.00',
      };
      await box.enqueue('Expenses', 'create', {
        'amount': 500,
      }, expectedVersion: 0);
      expect(
        projectFinancialReport(
          box,
          report,
          'profit-and-loss',
          (_) => [expense],
        ),
        report,
      );
      await box.enqueue(
        'Expenses',
        'post',
        {},
        recordId: 'expense',
        expectedVersion: 1,
        base: expense,
        local: false,
      );
      final projected = projectFinancialReport(
        box,
        report,
        'profit-and-loss',
        (_) => [expense],
      );
      expect(projected['provisional'], isTrue);
      expect(projected['totalExpenses'], '500.00');
      expect(report['totalExpenses'], '0.00');
    },
  );
  test(
    'unsupported precision is pending calculation instead of a guessed amount',
    () async {
      final expense = {
        'recordId': 'expense',
        'date': '2026-10-22',
        'total': '500.001',
        'taxAmount': 0,
      };
      await box.enqueue(
        'Expenses',
        'post',
        {},
        recordId: 'expense',
        expectedVersion: 1,
        base: expense,
        local: false,
      );
      final projected = projectFinancialReport(
        box,
        {'accounts': [], 'totalExpenses': '0.00'},
        'profit-and-loss',
        (_) => [expense],
      );
      expect(projected['pendingCalculation'], 1);
      expect(projected['totalExpenses'], '0.00');
    },
  );
  test(
    'uncertain submitted postings cannot double-count refreshed statements',
    () async {
      final expense = {
        'recordId': 'expense',
        'date': '2026-10-22',
        'total': 500,
        'taxAmount': 0,
      };
      await box.enqueue(
        'Expenses',
        'post',
        {},
        recordId: 'expense',
        expectedVersion: 1,
        base: expense,
        local: false,
      );
      send = (_) async =>
          throw const SaasApiException('NETWORK', 'Response lost');
      await box.sync();
      expect(box.pending.single['submitted'], isTrue);
      final report = projectFinancialReport(
        box,
        {'accounts': [], 'totalExpenses': '500.00'},
        'profit-and-loss',
        (_) => [expense],
      );
      expect(report['totalExpenses'], '500.00');
      expect(report['pendingCalculation'], 1);
      expect(report['provisional'], isTrue);
    },
  );

  test(
    'exact decimal arithmetic handles signs, large amounts and small rates',
    () {
      expect(decimalUnits('-1.23'), BigInt.from(-123));
      expect(decimalUnits('0.10') + decimalUnits('0.20'), decimalUnits('0.30'));
      expect(convertMinor('1000000000000.00', 1e-8), BigInt.from(1000000));
      expect(convertMinor('1.00', '1.005'), BigInt.from(101));
      expect(convertMinor('-1.00', '1.005'), BigInt.from(-101));
      expect(() => decimalUnits('1.001'), throwsFormatException);
      expect(() => convertMinor('1', double.nan), throwsFormatException);
      expect(() => convertMinor('1', 0), throwsFormatException);
      expect(localDerivedValues('Expenses', {'amount': '1.001'}), isEmpty);
    },
  );

  test('realtime bursts coalesce and duplicate IDs are suppressed', () {
    final calls = <Set<String>>[];
    final buffer = WorkspaceChangeBuffer(calls.add);
    addTearDown(buffer.dispose);
    buffer.add({
      'id': 1,
      'sections': ['Invoices'],
    });
    buffer.add({
      'id': 1,
      'sections': ['Invoices'],
    });
    buffer.add({
      'id': 2,
      'sections': ['Expenses'],
    });
    buffer.flush();
    expect(calls, [
      {'Invoices', 'Expenses'},
    ]);
    buffer.add({
      'id': 2,
      'sections': ['Expenses'],
    });
    buffer.flush();
    expect(calls, hasLength(1));
  });
  test('out-of-order revisions for different sections are never dropped', () {
    final calls = <Set<String>>[];
    final buffer = WorkspaceChangeBuffer(calls.add);
    addTearDown(buffer.dispose);
    buffer.add({
      'id': 20,
      'revision': 20,
      'sections': ['Invoices'],
    });
    buffer.flush();
    buffer.add({
      'id': 19,
      'revision': 19,
      'sections': ['Customers'],
    });
    buffer.flush();
    expect(calls, [
      {'Invoices'},
      {'Customers'},
    ]);
  });
  test('unknown events invalidate all and disposal cancels pending work', () {
    final calls = <Set<String>>[];
    final buffer = WorkspaceChangeBuffer(calls.add);
    buffer.add({
      'id': 1,
      'sections': ['Invoices'],
    });
    buffer.add({'id': 2, 'sections': []});
    buffer.flush();
    expect(calls.single, isEmpty);
    buffer.add({
      'id': 3,
      'sections': ['Expenses'],
    });
    buffer.dispose();
    buffer.flush();
    expect(calls, hasLength(1));
  });

  test(
    'resource revisions isolate tasks from financial projection changes',
    () async {
      final cache = ReadCache(
        store: MemoryCacheStore(),
        automatic: false,
        isLocalDependency: WorkspaceDependencies.localAffects,
        projectData: (_, snapshot) => snapshot == null ? null : {...snapshot},
      );
      addTearDown(cache.dispose);
      cache.configure(scope: 'scope', account: 'account');
      const report = '/v1/companies/a/reports/profit-and-loss?asOf=2026-10-22';
      const tasks = '/v1/companies/a/tasks';
      await cache.read(report, () async => {'totalExpenses': '0.00'});
      final before = cache.state(report)!.data;
      cache.localChanged('/v1/companies/a/records/Tasks');
      expect(cache.localRevisionFor(tasks), greaterThan(0));
      expect(cache.localRevisionFor(report), 0);
      expect(identical(cache.state(report)!.data, before), isTrue);
      cache.localChanged('/v1/companies/a/records/Expenses');
      expect(cache.localRevisionFor(report), greaterThan(0));
      expect(identical(cache.state(report)!.data, before), isFalse);
      final taskRevision = cache.localRevisionFor(tasks);
      cache.localChanged('/v1/companies/a/records/Invoices');
      expect(cache.localRevisionFor(tasks), taskRevision);
      expect(
        cache.localRevisionFor('/v1/companies/a/records/Receipts'),
        cache.localRevision,
      );
      cache.localChanged('/v1/companies/a/records/');
      expect(cache.localRevisionFor(tasks), cache.localRevision);
    },
  );
  test(
    'IndexedDB transactions survive recreation and roll back on failure',
    () async {
      final factory = newIdbFactoryMemory();
      final first = IndexedOfflineStore(
        factory,
        databaseName: 'atomic-offline-test',
      );
      await first.change('workspace', (p) {
        p['operations'].add({'operationId': 'durable'});
        p['records']['Customers:local'] = {'name': 'Durable customer'};
      });
      final reopened = IndexedOfflineStore(
        factory,
        databaseName: 'atomic-offline-test',
      );
      expect((await reopened.read('workspace'))['operations'], hasLength(1));
      await expectLater(
        reopened.change('workspace', (p) {
          p['operations'].clear();
          p['records'].clear();
          throw StateError('Interrupted save');
        }),
        throwsStateError,
      );
      final retained = await first.read('workspace');
      expect(retained['operations'], hasLength(1));
      expect(
        retained['records']['Customers:local']['name'],
        'Durable customer',
      );
      expect((await reopened.read('another-workspace'))['records'], isEmpty);
    },
  );
  test(
    'IndexedDB quota guard preserves already committed pending work',
    () async {
      final indexed = IndexedOfflineStore(newIdbFactoryMemory());
      await indexed.change(
        'workspace',
        (p) => p['operations'].add({'operationId': 'keep'}),
      );
      await expectLater(
        indexed.change(
          'workspace',
          (p) => p['oversized'] = List.filled(8 * 1024 * 1024 + 1, 'x').join(),
        ),
        throwsStateError,
      );
      final retained = await indexed.read('workspace');
      expect(retained.containsKey('oversized'), isFalse);
      expect(retained['operations'][0]['operationId'], 'keep');
    },
  );
  test('workspace switch blocks conflict correction and discard', () async {
    await box.enqueue(
      'Customers',
      'create',
      {'name': 'Keep'},
      expectedVersion: 0,
      rejected: true,
    );
    current = false;
    await expectLater(
      box.correctRejected(box.pending.single['operationId'] as String, {
        'name': 'Wrong workspace',
      }, expectedVersion: 0),
      throwsStateError,
    );
    await expectLater(box.discardRejected(), throwsStateError);
    expect(box.pending, hasLength(1));
  });
  testWidgets(
    'conflict editor displays saved and authoritative values before correction',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SyncChangeEditor(
              section: 'Invoices',
              values: {'notes': 'My saved notes'},
              serverValues: {'notes': 'Changed by another user'},
            ),
          ),
        ),
      );
      expect(find.text('Your saved change'), findsOneWidget);
      expect(find.text('Latest server value'), findsOneWidget);
      expect(find.text('Changed by another user'), findsOneWidget);
      expect(find.text('Save correction'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('record summaries show pending status separately from draft status', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RecordSummary(
      record: {'status': 'DRAFT', 'syncStatus': 'PENDING', '_syncLabel': 'Pending sync'},
    ))));
    expect(find.text('draft'), findsOneWidget);
    expect(find.text('Pending sync'), findsOneWidget);
    expect(find.text('posted'), findsNothing);
  });
}
