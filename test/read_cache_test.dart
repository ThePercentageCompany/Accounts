import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';
import 'package:tpc_invoice/core/cache/read_cache.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

const customers = '/v1/companies/c/records/Customers';
const invoices = '/v1/companies/c/records/Invoices';
Map<String, dynamic> records([String name = 'Customer']) => {
  'records': [
    {'recordId': 'stable', 'name': name},
  ],
};
Future<void> settle() => Future<void>.delayed(Duration.zero);

class UnavailableStore extends MemoryCacheStore {
  @override
  Future<Map<String, dynamic>?> read(String key) async =>
      throw StateError('Unavailable');
  @override
  Future<void> write(String key, Map<String, dynamic> value) async =>
      throw StateError('Quota exceeded');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryCacheStore store;
  late ReadCache cache;
  late DateTime time;
  ReadCache create({CacheStore? storage}) {
    final result = ReadCache(
      store: storage ?? store,
      now: () => time,
      automatic: false,
      isOfflineError: (e) => e is SaasApiException && e.code == 'NETWORK',
      isAuthorizationError: (e) => e is SaasApiException && e.status == 403,
    );
    result.configure(scope: 'owner-company', account: 'owner');
    return result;
  }

  setUp(() {
    store = MemoryCacheStore();
    time = DateTime.now();
    cache = create();
  });
  tearDown(() => cache.dispose());

  test(
    'first read persists; fresh navigation and restart restore without refetch',
    () async {
      var calls = 0;
      Future<Map<String, dynamic>> load() async {
        calls++;
        return records();
      }

      await cache.read(customers, load);
      await settle();
      expect(store.entries.length, 1);
      await cache.read(customers, load);
      final restored = create();
      expect(await restored.read(customers, load), records());
      expect(calls, 1);
      restored.dispose();
    },
  );
  test('concurrent cold reads and forced refreshes deduplicate', () async {
    var calls = 0;
    final response = Completer<Map<String, dynamic>>();
    Future<Map<String, dynamic>> load() {
      calls++;
      return response.future;
    }

    final one = cache.read(customers, load), two = cache.read(customers, load);
    await settle();
    expect(calls, 1);
    response.complete(records());
    await Future.wait([one, two]);
    final forced = Completer<Map<String, dynamic>>();
    Future<Map<String, dynamic>> refresh() {
      calls++;
      return forced.future;
    }

    final a = cache.read(customers, refresh, force: true),
        b = cache.read(customers, refresh, force: true);
    expect(calls, 2);
    forced.complete(records('Changed'));
    await Future.wait([a, b]);
  });
  test('cached empty results are usable and never loop on entry', () async {
    var calls = 0;
    Future<Map<String, dynamic>> load() async {
      calls++;
      return {'records': []};
    }

    await cache.read(customers, load);
    await cache.read(customers, load);
    expect(calls, 1);
    expect(cache.state(customers)!.data, {'records': []});
  });
  test('stale display stays visible until background changes arrive', () async {
    await cache.read(customers, () async => records());
    time = time.add(const Duration(minutes: 3));
    final response = Completer<Map<String, dynamic>>();
    expect(await cache.read(customers, () => response.future), records());
    expect(cache.state(customers)!.refreshing, isTrue);
    response.complete(records('Updated'));
    await settle();
    expect(cache.state(customers)!.data, records('Updated'));
    expect(cache.state(customers)!.refreshing, isFalse);
  });
  test(
    'offline restart and failed background refresh preserve saved records',
    () async {
      await cache.read(customers, () async => records());
      await settle();
      time = time.add(const Duration(minutes: 3));
      final restored = create();
      expect(
        await restored.read(
          customers,
          () async => throw const SaasApiException('NETWORK', 'Offline'),
        ),
        records(),
      );
      await settle();
      expect(restored.state(customers)!.offline, isTrue);
      expect(restored.state(customers)!.data, records());
      restored.dispose();
    },
  );
  test(
    'different account and company never restore a previous snapshot',
    () async {
      await cache.read(customers, () async => records('Private'));
      await settle();
      cache.configure(scope: 'another-company', account: 'owner');
      expect(cache.state(customers), isNull);
      expect(
        await cache.read(customers, () async => records('Other company')),
        records('Other company'),
      );
      cache.configure(scope: 'another-account', account: 'someone-else');
      expect(
        await cache.read(customers, () async => records('Other account')),
        records('Other account'),
      );
    },
  );
  test(
    'delayed response cannot overwrite a new company or repersist after logout',
    () async {
      final response = Completer<Map<String, dynamic>>();
      final pending = cache.read(customers, () => response.future);
      await settle();
      cache.configure(scope: 'other-company', account: 'owner');
      await cache.read(customers, () async => records('New context'));
      response.complete(records('Old context'));
      await expectLater(pending, throwsStateError);
      expect(cache.state(customers)!.data, records('New context'));
      final later = Completer<Map<String, dynamic>>();
      final refresh = cache.read(customers, () => later.future, force: true);
      await cache.logout();
      later.complete(records('Must not persist'));
      await expectLater(refresh, throwsStateError);
      await settle();
      expect(store.entries, isEmpty);
    },
  );
  test(
    'normalized query keys isolate date ranges, sort, pages and filters',
    () async {
      var calls = 0;
      Future<Map<String, dynamic>> load() async {
        calls++;
        return records('$calls');
      }

      const first = '$customers?search=a&sort=name&page=1&from=2026-01-01';
      await cache.read(first, load);
      await cache.read(
        '$customers?from=2026-01-01&page=1&sort=name&search=a',
        load,
      );
      await cache.read(
        '$customers?search=a&sort=name&page=2&from=2026-01-01',
        load,
      );
      await cache.read(
        '$customers?search=b&sort=name&page=1&from=2026-01-01',
        load,
      );
      expect(calls, 3);
    },
  );
  test(
    'full snapshots remove deleted records; invalidation preserves unrelated data',
    () async {
      await cache.read(customers, () async => records());
      await cache.read(invoices, () async => records('Invoice'));
      cache.invalidate((path) => path == customers);
      expect(cache.state(invoices)!.stale, isFalse);
      await cache.read(customers, () async => {'records': []}, force: true);
      expect(cache.state(customers)!.data, {'records': []});
    },
  );
  test(
    'invalidated persisted entries remain viewable offline but refresh on restart',
    () async {
      await cache.read(customers, () async => records());
      await settle();
      cache.invalidate((p) => p == customers);
      await settle();
      final restored = create();
      var calls = 0;
      expect(
        await restored.read(customers, () async {
          calls++;
          throw const SaasApiException('NETWORK', 'Offline');
        }),
        records(),
      );
      await settle();
      expect(calls, 1);
      restored.dispose();
    },
  );
  test(
    'corrupted, incompatible and unavailable storage falls back safely',
    () async {
      final key = jsonEncode(['owner-company', normalizedResource(customers)]);
      store.entries[key] = {
        'schema': 2,
        'scope': 'owner-company',
        'account': 'owner',
        'resource': normalizedResource(customers),
        'complete': true,
        'syncedAt': 'broken',
      };
      expect(await cache.read(customers, () async => records()), records());
      final unavailable = create(storage: UnavailableStore());
      expect(
        await unavailable.read(customers, () async => records()),
        records(),
      );
      await settle();
      unavailable.dispose();
    },
  );
  test(
    'authorization failures purge protected snapshots and stop synchronization',
    () async {
      await cache.read(customers, () async => records());
      await settle();
      cache.activate(customers);
      await expectLater(
        cache.read(
          customers,
          () async =>
              throw const SaasApiException('DENIED', 'Denied', status: 403),
          force: true,
        ),
        throwsA(isA<SaasApiException>()),
      );
      await settle();
      expect(cache.scope, isNull);
      expect(cache.state(customers), isNull);
      expect(store.entries, isEmpty);
    },
  );
  test(
    'mutation API invalidates applied resources and dependent reports only',
    () async {
      final company = 'c' * 43;
      var reads = 0;
      final api = SaasApi(
        origin: 'https://api.test',
        cacheStore: store,
        client: MockClient((r) async {
          if (r.method == 'GET') {
            reads++;
            return http.Response(jsonEncode(records()), 200);
          }
          return http.Response(
            jsonEncode({
              'results': [
                {'operationId': 'operation_00000001', 'status': 'APPLIED'},
              ],
            }),
            200,
          );
        }),
      );
      api.useVerifiedWorkspace(company, ownerId: 'owner');
      await api.records(company, 'Customers');
      await api.records(company, 'Invoices');
      await api.sync(company, [
        {
          'operationId': 'operation_00000001',
          'table': 'Customers',
          'action': 'create',
          'expectedVersion': 0,
          'values': {'name': 'New'},
        },
      ]);
      expect(
        api.cache.state(api.recordsPath(company, 'Customers'))!.stale,
        isTrue,
      );
      expect(
        api.cache.state(api.recordsPath(company, 'Invoices'))!.stale,
        isFalse,
      );
      await api.records(company, 'Invoices');
      expect(reads, 2);
      api.close();
    },
  );
  test(
    'active stale resources resume; hidden tabs and unrelated modules do not poll',
    () async {
      var visible = false, calls = 0;
      final active = ReadCache(
        store: store,
        now: () => time,
        automatic: false,
        isVisible: () => visible,
      );
      active.configure(scope: 'active-scope', account: 'owner');
      Future<Map<String, dynamic>> load() async {
        calls++;
        return records();
      }

      await active.read(customers, load);
      await active.read(invoices, load);
      active.activate(customers);
      time = time.add(const Duration(minutes: 3));
      await active.resume();
      expect(calls, 2);
      visible = true;
      await active.resume();
      await settle();
      expect(calls, 3);
      active.deactivate(customers);
      time = time.add(const Duration(minutes: 3));
      await active.resume();
      expect(calls, 3);
      active.dispose();
    },
  );
  test(
    'rate limits preserve data and manual refresh respects Retry-After',
    () async {
      var calls = 0;
      final limited = ReadCache(
        store: store,
        now: () => time,
        automatic: false,
        retryDelay: (e) => e is SaasApiException ? e.retryAfter : null,
      );
      limited.configure(scope: 'limited-scope', account: 'owner');
      await limited.read(customers, () async => records());
      Future<Map<String, dynamic>> fail() async {
        calls++;
        throw const SaasApiException(
          'RATE_LIMITED',
          'Wait',
          status: 429,
          retryAfter: Duration(minutes: 5),
        );
      }

      expect(await limited.read(customers, fail, force: true), records());
      expect(await limited.read(customers, fail, force: true), records());
      expect(calls, 1);
      time = time.add(const Duration(minutes: 6));
      await limited.read(customers, fail, force: true);
      expect(calls, 2);
      limited.dispose();
    },
  );
}
