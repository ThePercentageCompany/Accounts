import 'dart:convert';
import 'package:idb_shim/idb.dart';
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

/// Serialized writes keep logout cleanup ordered after any previously queued save.
class IndexedCacheStore implements CacheStore {
  IndexedCacheStore(this.factory, {this.databaseName = 'tpc_read_cache_v2'});
  final IdbFactory factory;
  final String databaseName;
  Future<Database>? _opening;
  Future<void> _writes = Future.value();
  Future<Database> _db() => _opening ??= factory.open(
    databaseName,
    version: 1,
    onUpgradeNeeded: (event) => event.database.createObjectStore('responses'),
  );
  Future<void> _serialize(Future<void> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.catchError((Object _) {});
    return result;
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    await _writes;
    final db = await _db();
    final tx = db.transaction('responses', idbModeReadOnly);
    final value = await tx.objectStore('responses').getObject(key);
    await tx.completed;
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  @override
  Future<void> write(
    String key,
    Map<String, dynamic> value,
  ) => _serialize(() async {
    // A large response can still be used in memory; it must not exhaust storage.
    if (utf8.encode(jsonEncode(value)).length > 4 * 1024 * 1024) return;
    final db = await _db();
    final tx = db.transaction('responses', idbModeReadWrite);
    final store = tx.objectStore('responses');
    await store.put(value, key);
    final all = await store.getAll();
    final entries = all.map((v) => Map<String, dynamic>.from(v as Map)).toList()
      ..sort((a, b) => (a['syncedAt'] as int).compareTo(b['syncedAt'] as int));
    var bytes = entries.fold<int>(
      0,
      (n, e) => n + utf8.encode(jsonEncode(e)).length,
    );
    var count = entries.length;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    for (final entry in entries) {
      if (entry['syncedAt'] < cutoff ||
          count > 128 ||
          bytes > 20 * 1024 * 1024) {
        await store.delete(entry['key']);
        count--;
        bytes -= utf8.encode(jsonEncode(entry)).length;
      }
    }
    await tx.completed;
  });

  Future<void> _remove(String field, String value) => _serialize(() async {
    final db = await _db();
    final tx = db.transaction('responses', idbModeReadWrite);
    final store = tx.objectStore('responses');
    for (final raw in await store.getAll()) {
      final row = raw as Map;
      if (row[field] == value) await store.delete(row['key']);
    }
    await tx.completed;
  });
  @override
  Future<void> removeAccount(String account) => _remove('account', account);
  @override
  Future<void> removeEntry(String key) => _serialize(() async {
    final db = await _db();
    final tx = db.transaction('responses', idbModeReadWrite);
    await tx.objectStore('responses').delete(key);
    await tx.completed;
  });
  @override
  Future<void> removeScope(String scope) => _remove('scope', scope);
  @override
  Future<void> invalidateScope(
    String scope,
    bool Function(String path) affected,
  ) => _serialize(() async {
    final db = await _db();
    final tx = db.transaction('responses', idbModeReadWrite);
    final store = tx.objectStore('responses');
    for (final raw in await store.getAll()) {
      try {
        final row = Map<String, dynamic>.from(raw as Map);
        if (row['scope'] == scope &&
            affected(
              (jsonDecode(row['resource'] as String) as List).first as String,
            )) {
          row['invalidated'] = true;
          await store.put(row, row['key']);
        }
      } catch (_) {}
    }
    await tx.completed;
  });
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
