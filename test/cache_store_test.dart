import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';
import 'package:tpc_invoice/core/cache/read_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  CacheStore create() =>
      kIsWeb ? createCacheStore() : IndexedCacheStore(newIdbFactoryMemory());
  Map<String, dynamic> entry(String key, String account, String scope) => {
    'schema': 2,
    'key': key,
    'account': account,
    'scope': scope,
    'resource': normalizedResource('/v1/companies/c/records/$key'),
    'syncedAt': DateTime.now().millisecondsSinceEpoch,
    'complete': true,
    'data': {'records': []},
  };
  test(
    'IndexedDB commits metadata and invalidation preserves saved empty results',
    () async {
      final store = create();
      expect(store, isA<IndexedCacheStore>());
      await store.write(
        'Customers',
        entry('Customers', 'store-test-user', 'scope'),
      );
      expect((await store.read('Customers'))!['data'], {'records': []});
      await store.invalidateScope('scope', (p) => p.endsWith('/Customers'));
      final saved = (await store.read('Customers'))!;
      expect(saved['invalidated'], isTrue);
      expect(saved['syncedAt'], greaterThan(0));
      await store.removeAccount('store-test-user');
      expect(await store.read('Customers'), isNull);
    },
  );
  test(
    'logout removal follows queued saves and does not delete another account',
    () async {
      final store = create();
      final writing = store.write(
        'private',
        entry('private', 'store-logout-user', 'scope'),
      );
      final removing = store.removeAccount('store-logout-user');
      await Future.wait([writing, removing]);
      expect(await store.read('private'), isNull);
      await store.write(
        'other',
        entry('other', 'store-other-user', 'other-scope'),
      );
      await store.removeScope('scope');
      expect(await store.read('other'), isNotNull);
      await store.removeAccount('store-other-user');
    },
  );
  test('bounded persistent retention evicts oldest entries', () async {
    final store = create();
    for (var i = 0; i < 130; i++) {
      await store.write(
        'bounded-$i',
        entry('bounded-$i', 'store-bound-user', 'bounded-scope'),
      );
    }
    expect(await store.read('bounded-0'), isNull);
    expect(await store.read('bounded-129'), isNotNull);
    await store.removeAccount('store-bound-user');
  });
  test('browser tabs coordinate scoped invalidation and logout', () async {
    final a = ReadCache(store: MemoryCacheStore(), automatic: false);
    final b = ReadCache(store: MemoryCacheStore(), automatic: false);
    for (final cache in [a, b]) {
      cache.configure(
        scope: 'browser-coordinate-scope',
        account: 'browser-coordinate-user',
      );
    }
    const customerPath = '/v1/companies/c/records/Customers';
    const invoicePath = '/v1/companies/c/records/Invoices';
    await a.read(customerPath, () async => {'records': []});
    await b.read(customerPath, () async => {'records': []});
    await b.read(invoicePath, () async => {'records': []});
    a.invalidate((p) => p == customerPath, broadcastPaths: [customerPath]);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(b.state(customerPath)!.stale, isTrue);
    expect(b.state(invoicePath)!.stale, isFalse);
    await a.logout();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(b.scope, isNull);
    expect(b.state(customerPath), isNull);
    a.dispose();
    b.dispose();
  }, skip: !kIsWeb);
}
