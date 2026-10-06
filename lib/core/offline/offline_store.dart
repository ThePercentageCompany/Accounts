import 'dart:convert';
import 'package:idb_shim/idb.dart';
import 'package:tpc_invoice/core/offline/store_factory_stub.dart'
    if (dart.library.js_interop) 'package:tpc_invoice/core/offline/store_factory_web.dart';

Map<String, dynamic> copyJson(Map value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

Map<String, dynamic> emptyPartition() => {
      'schema': 2,
      'sequence': 0,
      'operations': <dynamic>[],
      'records': <String, dynamic>{},
      'ids': <String, dynamic>{},
    };

abstract class OfflineStore {
  Future<Map<String, dynamic>> read(String scope);
  Future<Map<String, dynamic>> change(
    String scope,
    void Function(Map<String, dynamic>) edit,
  );
}

OfflineStore createOfflineStore() => platformOfflineStore();

/// One read/write transaction commits the record overlay AND the outbox. Reads
/// and edits contain only IDB requests: no network/timer awaits inside a tx.
class IndexedOfflineStore implements OfflineStore {
  IndexedOfflineStore(this.factory, {this.databaseName = 'tpc_offline_v1'});
  final IdbFactory factory;
  final String databaseName;
  Future<Database>? _opening;
  Future<Database> _open() => _opening ??= factory.open(
        databaseName,
        version: 2,
        onUpgradeNeeded: (event) {
          if (event.oldVersion < 1) {
            event.database.createObjectStore('partitions');
          }
          // v2 adds record overlays; existing queue envelopes are upgraded on read.
        },
      ).then(
        (db) {
          db.onVersionChange.listen((_) {
            db.close();
            _opening = null;
          });
          return db;
        },
        onError: (Object error) {
          _opening = null;
          throw error;
        },
      );

  Map<String, dynamic> _decode(Object? value) {
    final data = value == null ? emptyPartition() : copyJson(value as Map);
    if ((data['schema'] as int? ?? 1) > 2) {
      throw StateError(
        'Offline storage was written by a newer app. Update this app.',
      );
    }
    data['schema'] = 2;
    data.putIfAbsent('records', () => <String, dynamic>{});
    data.putIfAbsent('ids', () => <String, dynamic>{});
    data.putIfAbsent('sequence', () => 0);
    data.putIfAbsent('operations', () => <dynamic>[]);
    return data;
  }

  @override
  Future<Map<String, dynamic>> read(String scope) async {
    final db = await _open();
    final tx = db.transaction('partitions', idbModeReadOnly);
    final value = await tx.objectStore('partitions').getObject(scope);
    await tx.completed;
    return _decode(value);
  }

  @override
  Future<Map<String, dynamic>> change(
    String scope,
    void Function(Map<String, dynamic>) edit,
  ) async {
    final db = await _open();
    final tx = db.transaction('partitions', idbModeReadWrite);
    // Observe completion even if put fails (e.g. quota) to avoid an unhandled
    // transaction error. No save is acknowledged before completion.
    final completion = tx.completed;
    completion.ignore();
    try {
      final store = tx.objectStore('partitions');
      final data = _decode(await store.getObject(scope));
      edit(data);
      if (utf8.encode(jsonEncode(data)).length > 8 * 1024 * 1024) {
        throw StateError(
          'Device storage limit reached. Sync or export pending changes first.',
        );
      }
      await store.put(data, scope);
      await completion;
      return copyJson(data);
    } catch (_) {
      try {
        tx.abort();
      } catch (_) {
        /* Already aborted by the storage engine. */
      }
      rethrow;
    }
  }
}
