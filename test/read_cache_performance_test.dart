import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';
import 'package:tpc_invoice/core/cache/read_cache.dart';

void main() {
  test('refresh returns persisted data without waiting on network', () async {
    final store = MemoryCacheStore();
    final first = ReadCache(store: store, automatic: false);
    first.configure(scope: 'company-a', account: 'owner-a');
    await first.read(
        '/records',
        () async => {
              'records': ['saved']
            });
    await Future<void>.delayed(Duration.zero);
    first.dispose();
    final cache = ReadCache(store: store, automatic: false);
    addTearDown(cache.dispose);
    cache.configure(scope: 'company-a', account: 'owner-a');
    final network = Completer<Map<String, dynamic>>();
    final saved =
        await cache.read('/records', () => network.future, force: true);
    expect(saved['records'], ['saved']);
    expect(cache.state('/records')!.data!['records'], ['saved']);
    expect(cache.state('/records')!.refreshing, isTrue);
    final memory =
        await cache.read('/records', () => network.future, force: true);
    expect(memory['records'], ['saved']);
    network.complete({
      'records': ['updated']
    });
    await Future<void>.delayed(Duration.zero);
    expect(cache.state('/records')!.data!['records'], ['updated']);
  });
  for (final active in [false, true]) {
    for (final obsoleteFails in [false, true]) {
      test(
          'invalidated read follows replacement (active: $active, '
          'obsolete fails: $obsoleteFails)', () async {
        final cache = ReadCache(store: MemoryCacheStore(), automatic: false);
        addTearDown(cache.dispose);
        cache.configure(scope: 'company-a', account: 'owner-a');
        final old = Completer<Map<String, dynamic>>();
        final replacement = Completer<Map<String, dynamic>>();
        var calls = 0;
        Future<Map<String, dynamic>> loader() =>
            ++calls == 1 ? old.future : replacement.future;
        final waiting = cache.read('/records', loader);
        await Future<void>.delayed(Duration.zero);
        if (active) cache.activate('/records');
        cache.invalidate((path) => path == '/records');
        if (obsoleteFails) {
          old.completeError(StateError('Obsolete network failure'));
        } else {
          old.complete({
            'records': ['old']
          });
        }
        await Future<void>.delayed(Duration.zero);
        expect(calls, 2);
        expect(cache.state('/records')!.data, isNull);
        expect(cache.state('/records')!.error, isNull);
        expect(cache.state('/records')!.refreshing, isTrue);
        replacement.complete({
          'records': ['current']
        });
        expect(await waiting, {
          'records': ['current']
        });
        expect(cache.state('/records')!.data, {
          'records': ['current']
        });
        expect(cache.state('/records')!.refreshing, isFalse);
        expect(cache.state('/records')!.failures, 0);
      });
    }
  }

  test('late response uses an already completed replacement', () async {
    final cache = ReadCache(store: MemoryCacheStore(), automatic: false);
    addTearDown(cache.dispose);
    cache.configure(scope: 'company-a', account: 'owner-a');
    final old = Completer<Map<String, dynamic>>();
    var calls = 0;
    Future<Map<String, dynamic>> loader() async =>
        ++calls == 1 ? old.future : {'value': 'current'};
    final waiting = cache.read('/records', loader);
    await Future<void>.delayed(Duration.zero);
    cache.activate('/records');
    cache.invalidate((_) => true);
    await Future<void>.delayed(Duration.zero);
    old.complete({'value': 'old'});
    expect(await waiting, {'value': 'current'});
    expect(calls, 2);
  });

  test('workspace switch still rejects the previous workspace response',
      () async {
    final cache = ReadCache(store: MemoryCacheStore(), automatic: false);
    addTearDown(cache.dispose);
    cache.configure(scope: 'company-a', account: 'owner-a');
    final old = Completer<Map<String, dynamic>>();
    final waiting = cache.read('/records', () => old.future);
    final rejected = expectLater(waiting, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    cache.configure(scope: 'company-b', account: 'owner-b');
    await cache.read('/records', () async => {'value': 'company-b'});
    old.complete({'value': 'company-a'});
    await rejected;
    expect(cache.state('/records')!.data, {'value': 'company-b'});
  });

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
