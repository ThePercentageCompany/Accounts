import 'dart:convert';
import 'record_index.dart';
import 'package:tpc_invoice/core/cache/cache_store_factory_stub.dart'
    if (dart.library.js_interop) 'package:tpc_invoice/core/cache/cache_store_factory_web.dart';

abstract class CacheStore {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> value);
  Future<void> removeEntry(String key);
  Future<void> removeAccount(String account);
  Future<void> removeScope(String scope);
  Future<void> invalidateScope(
    String scope,
    bool Function(String path) affected,
  );
}

CacheStore createCacheStore() => platformCacheStore();

/// Confirmed snapshots use normalized, indexed records. Cache migration and
/// pruning never modify the durable outbox database.
class IndexedCacheStore extends IndexedRecordCache {
  IndexedCacheStore(super.factory, {super.databaseName});
}
class MemoryCacheStore implements CacheStore {
  final entries = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> read(String key) async => entries[key];
  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    entries[key] = value;
  }

  @override
  Future<void> removeAccount(String account) async =>
      entries.removeWhere((_, v) => v['account'] == account);
  @override
  Future<void> removeEntry(String key) async {
    entries.remove(key);
  }

  @override
  Future<void> removeScope(String scope) async =>
      entries.removeWhere((_, v) => v['scope'] == scope);
  @override
  Future<void> invalidateScope(
    String scope,
    bool Function(String path) affected,
  ) async {
    for (final row in entries.values) {
      if (row['scope'] == scope &&
          affected(
            (jsonDecode(row['resource'] as String) as List).first as String,
          )) {
        row['invalidated'] = true;
      }
    }
  }
}
