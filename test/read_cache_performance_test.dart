import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';
import 'package:tpc_invoice/core/cache/read_cache.dart';

void main() {
  test('saved snapshots return while a stale refresh is still pending',
      () async {
    final store = MemoryCacheStore();
    var now = DateTime(2026, 10, 14);
    final first = ReadCache(store: store, now: () => now, automatic: false);
    first.configure(scope: 'company-a', account: 'owner-a');
    await first.read(
        '/records',
        () async => {
              'records': [
                {
                  'name': 'Saved',
                  'items': [1, 2]
                }
              ]
            });
    await Future<void>.delayed(Duration.zero);
    first.dispose();
    now = now.add(const Duration(minutes: 3));
    final cache = ReadCache(store: store, now: () => now, automatic: false);
    cache.configure(scope: 'company-a', account: 'owner-a');
    final network = Completer<Map<String, dynamic>>();
    final saved = await cache.read('/records', () => network.future);
    expect(saved['records'][0]['name'], 'Saved');
    expect(cache.state('/records')!.refreshing, isTrue);
    saved['records'][0]['items'].add(3);
    expect(cache.state('/records')!.data!['records'][0]['items'], [1, 2]);
    network.complete({'records': []});
    await Future<void>.delayed(Duration.zero);
    expect(cache.state('/records')!.data!['records'], isEmpty);
    cache.dispose();
  });

  test('unrelated active resources are not fetched after task invalidation',
      () async {
    final cache = ReadCache(automatic: false);
    cache.configure(scope: 'company-a', account: 'owner-a');
    var reportReads = 0, taskReads = 0;
    await cache.read('/reports/balance', () async {
      reportReads++;
      return {'balance': 10};
    });
    await cache.read('/tasks', () async {
      taskReads++;
      return {'records': []};
    });
    cache.activate('/reports/balance');
    cache.activate('/tasks');
    cache.invalidate((path) => path == '/tasks');
    await Future<void>.delayed(Duration.zero);
    expect(reportReads, 1);
    expect(taskReads, 2);
    cache.dispose();
  });
}
