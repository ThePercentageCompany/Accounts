import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/offline/offline_outbox.dart';
import 'package:tpc_invoice/core/offline/offline_store.dart';
import 'package:tpc_invoice/core/offline/preferences_store.dart';
import 'package:tpc_invoice/core/offline/task_projection.dart';
import 'package:tpc_invoice/core/offline/provisional_report.dart';

void main() {
  late OfflineOutbox box;
  setUp(() {
    box = OfflineOutbox(
        store: IndexedOfflineStore(newIdbFactoryMemory()),
        scope: 'owner/company',
        automatic: false,
        isCurrent: () => true,
        verifyIdentity: () async {},
        changed: (_) {},
        send: (op) async => {
              'results': [
                {
                  'operationId': op['operationId'],
                  'status': 'APPLIED',
                  'recordId': op['recordId'] ?? 'server-id',
                  'version': 2
                }
              ]
            });
  });
  tearDown(() => box.dispose());
  final original = <String, dynamic>{
    'recordId': 'task',
    'recordVersion': 1,
    'title': 'Task',
    'status': 'TODO',
    'priority': 'MEDIUM',
    'dueDate': '2026-10-15'
  };
  Map<String, dynamic> page() => {
        'records': [original],
        'total': 1,
        'summary': {'todo': 1, 'inProgress': 0},
        'dateCounts': {'2026-10-15': 1}
      };

  test(
      'local task status updates filtered totals without changing the snapshot',
      () async {
    await box.enqueue('Tasks', 'update', {'status': 'IN_PROGRESS'},
        recordId: 'task', expectedVersion: 1, base: original);
    final snapshot = page();
    final projected = projectTaskPage(box, snapshot, {'status': 'TODO'});
    expect(projected['records'], isEmpty);
    expect(projected['total'], 0);
    expect(projected['summary']['todo'], 0);
    expect(projected['summary']['inProgress'], 1);
    expect(snapshot['records'], [original]);
    expect(snapshot['summary']['todo'], 1);
  });

  test('fresh snapshots do not count an acknowledged task twice', () async {
    await box.enqueue('Tasks', 'update', {'status': 'IN_PROGRESS'},
        recordId: 'task', expectedVersion: 1, base: original);
    await box.sync();
    final snapshot = {
      'records': [],
      'total': 0,
      'summary': {'todo': 0, 'inProgress': 1},
      'dateCounts': {}
    };
    final projected = projectTaskPage(box, snapshot, {'status': 'TODO'},
        syncedAt: DateTime.now().add(const Duration(seconds: 1)));
    expect(projected['summary']['inProgress'], 1);
    expect(projected['total'], 0);
  });

  test(
      'draft totals appear locally while immutable requests keep original input',
      () async {
    await box.enqueue(
        'Invoices',
        'create',
        {
          'items': [
            {'quantity': 2, 'unitPrice': 12.50, 'discount': 1, 'taxRate': 5}
          ]
        },
        expectedVersion: 0);
    final invoice = box.overlay('Invoices', []).single;
    expect(invoice['subtotal'], 25);
    expect(invoice['total'], 25.20);
    expect(invoice['taxAmount'], 1.20);
    expect((box.pending.single['values'] as Map).containsKey('total'), isFalse);
  });

  test('paid income provisionally updates profit and cash with balanced VAT',
      () async {
    final base = <String, dynamic>{
      'recordId': 'income',
      'recordVersion': 1,
      'date': '2026-10-15',
      'amount': 100,
      'taxRate': 5,
      'taxAmount': 5,
      'total': 105,
      'paymentStatus': 'PAID',
      'paidDate': '2026-10-15',
      'account': 'cash'
    };
    await box.enqueue('Income', 'post', {},
        recordId: 'income', expectedVersion: 1, base: base, local: false);
    final snapshot = <String, dynamic>{
      'from': '2026-01-01',
      'asOf': '2026-12-31',
      'totalIncome': '0.00',
      'totalExpenses': '0.00',
      'netProfit': '0.00',
      'totalAssets': '0.00',
      'totalLiabilities': '0.00',
      'totalEquity': '0.00',
      'cash': '0.00',
      'receivables': '0.00',
      'trends': [
        {
          'from': '2026-10-01',
          'asOf': '2026-10-31',
          'income': '0.00',
          'expenses': '0.00',
          'netProfit': '0.00'
        }
      ]
    };
    final report = projectFinancialReport(
        box, snapshot, 'dashboard', (table) => box.overlay(table, []));
    expect(report['netProfit'], '100.00');
    expect(report['cash'], '105.00');
    expect(report['receivables'], '0.00');
    expect(report['totalLiabilities'], '5.00');
    expect(report['totalAssets'], '105.00');
    expect(report['totalEquity'], '100.00');
    expect(report['trends'][0]['netProfit'], '100.00');
    expect(report['provisional'], isTrue);
    expect(report['pendingCalculation'], 0);
    expect(snapshot['netProfit'], '0.00');
    expect(snapshot['trends'][0]['income'], '0.00');
  });

  test('unavailable posting previews are identified and never guessed',
      () async {
    await box.enqueue(
        'Assets', 'depreciate', {'lastDepreciationDate': '2026-10-15'},
        recordId: 'asset',
        expectedVersion: 1,
        base: {'recordId': 'asset'},
        local: false);
    final report = projectFinancialReport(
        box,
        {'asOf': '2026-12-31', 'netProfit': '20.00'},
        'dashboard',
        (table) => box.overlay(table, []));
    expect(report['netProfit'], '20.00');
    expect(report['pendingCalculation'], 1);
  });

  test('native operations and snapshots survive new store instances', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferencesOfflineStore();
    await store.change('owner/company', (partition) {
      (partition['operations'] as List).add({'operationId': 'durable'});
    });
    expect(
        (await PreferencesOfflineStore().read('owner/company'))['operations'][0]
            ['operationId'],
        'durable');
    expect(
        (await PreferencesOfflineStore().read('other/company'))['operations'],
        isEmpty);
    final cache = PreferencesCacheStore();
    await cache.write('saved', {
      'key': 'saved',
      'account': 'owner',
      'scope': 'company',
      'resource': '["/records",{}]',
      'syncedAt': DateTime.now().millisecondsSinceEpoch,
      'data': {'records': []}
    });
    expect((await PreferencesCacheStore().read('saved'))!['data']['records'],
        isEmpty);
    await cache.removeAccount('owner');
    expect(await cache.read('saved'), isNull);
  });
}
