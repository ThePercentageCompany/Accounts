import 'dart:convert';
import 'package:idb_shim/idb.dart';
import 'cache_store.dart';

String recordDisplayTitle(String table, Map row) {
  if (table == 'JournalLines') {
    final name = '${row['accountName'] ?? ''}'.trim();
    final id = '${row['accountId'] ?? ''}'.trim();
    final line = '${row['lineNumber'] ?? ''}'.trim();
    return '${name.isNotEmpty ? name : id.isNotEmpty ? id : 'Journal entry'}${line.isEmpty ? '' : ' · Line $line'}';
  }
  if (['Invoices', 'Quotations'].contains(table) && '${row['number'] ?? ''}'.trim().isEmpty) {
    return 'Draft ${table == 'Invoices' ? 'invoice' : 'quotation'} · ${row['issueDate'] ?? ''}';
  }
  return '${row['name'] ?? row['fullName'] ?? row['number'] ?? row['description'] ?? row['date'] ?? row['month'] ?? 'Record'}';
}

String recordSearchText(String table, Map row) => [recordDisplayTitle(table, row),
  row['shareholderName'] ?? '', row['status'] ?? '', row['paymentStatus'] ?? '',
  row['email'] ?? '', row['phone'] ?? ''].join(' ').toLowerCase();

abstract class RecordIndexQueries {
  Future<Set<String>?> searchRecordIds(String collection, String search,
      {required int expectedSyncedAt});
  Future<List<Map<String, dynamic>>> recordPage(String collection,
      {String? status, String? afterId, int limit = 100});
}

/// Normalized confirmed snapshots. The outbox database is deliberately separate:
/// optional snapshot pruning must never evict unacknowledged commands.
class IndexedRecordCache implements CacheStore, RecordIndexQueries {
  IndexedRecordCache(this.factory, {this.databaseName = 'tpc_read_cache_v2'});
  final IdbFactory factory;
  final String databaseName;
  Future<Database>? _opening;
  Future<void> _writes = Future.value();
  Future<Database> _db() => _opening ??= factory.open(databaseName, version: 2,
    onUpgradeNeeded: (event) {
      if (event.oldVersion < 1) event.database.createObjectStore('responses');
      if (event.oldVersion < 2) {
        final rows = event.database.createObjectStore('record_rows', keyPath: ['collection','id']);
        rows.createIndex('collection', 'collection');
        rows.createIndex('status', ['collection','status','id']);
        rows.createIndex('date', ['collection','date','id']);
        rows.createIndex('search', 'tokens', multiEntry: true);
      }
    }).then((db) {
      db.onVersionChange.listen((_) { db.close(); _opening = null; });
      return db;
    }, onError: (Object error) { _opening = null; throw error; });

  Future<T> _serialize<T>(Future<T> Function() work) {
    final next = _writes.then((_) => work());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }
  KeyRange _range(String key) => KeyRange.bound([key], [key, <Object>[]]);
  // This hash only narrows the search index. Exact collection comparison below
  // enforces isolation even if two buckets collide; it is not an access token.
  String _bucket(String key) {
    var hash = 2166136261;
    for (final unit in key.codeUnits) { hash = ((hash ^ unit) * 16777619) & 0xffffffff; }
    return hash.toRadixString(16);
  }
  Map<String, dynamic> _entry(String key, String table, Map row, int ordinal) {
    final text = recordSearchText(table, row), bucket = _bucket(key);
    final tokens = <String>{};
    for (var i=0; i+3<=text.length; i++) { tokens.add('$bucket:${text.substring(i,i+3)}'); }
    final result = <String,dynamic>{'collection':key,'id':'${row['recordId']}',
      'status':'${row['status'] ?? row['paymentStatus'] ?? ''}',
      'date':'${row['issueDate'] ?? row['date'] ?? row['dueDate'] ?? ''}',
      'ordinal':ordinal,'text':text,'tokens':tokens.toList(),'payload':row};
    result['bytes'] = utf8.encode(jsonEncode(result)).length;
    return result;
  }
  @override
  Future<Map<String,dynamic>?> read(String key) async {
    await _writes;
    final db = await _db();
    final tx = db.transactionList(['responses','record_rows'], idbModeReadOnly);
    tx.completed.ignore();
    final raw = await tx.objectStore('responses').getObject(key);
    if (raw == null) { await tx.completed; return null; }
    final metadata = Map<String,dynamic>.from(raw as Map);
    if (metadata['_indexedRecords'] == true) {
      final records = (await tx.objectStore('record_rows').index('collection').getAll(key))
          .map((r) => Map<String,dynamic>.from(r as Map)).toList()
        ..sort((a,b) => (a['ordinal'] as int).compareTo(b['ordinal'] as int));
      metadata['data'] = {...Map<String,dynamic>.from(metadata['data'] as Map),
        'records':records.map((r) => r['payload']).toList()};
    }
    await tx.completed;
    return metadata;
  }
  @override
  Future<void> write(String key, Map<String,dynamic> value) => _serialize(() async {
    final db = await _db();
    final tx = db.transactionList(['responses','record_rows'], idbModeReadWrite);
    final done = tx.completed; done.ignore();
    try {
      final responses = tx.objectStore('responses'), rows = tx.objectStore('record_rows');
      final old = await responses.getObject(key) as Map?;
      final data = Map<String,dynamic>.from(value['data'] as Map);
      final changes = data.remove('_recordDelta') as Map?;
      final records = data['records'];
      final metadata = <String,dynamic>{...value,'data':data};
      var bytes = 0;
      if (records is List) {
        data.remove('records');
        final resource = (jsonDecode(value['resource'] as String) as List).first as String;
        final table = Uri.parse(resource).path.split('/').last;
        final incremental = old?['_indexedRecords'] == true && changes != null &&
          changes['fromCursor'] == (old?['data'] as Map?)?['syncCursor'];
        final changedIds = incremental ? Set<String>.from(changes['ids'] as List) : null;
        bytes = incremental ? (old?['_rowBytes'] as int? ?? 0) : 0;
        var nextOrdinal = incremental ? (old?['_nextOrdinal'] as int? ?? records.length) : records.length;
        if (!incremental) await rows.delete(_range(key));
        final seen = <String>{};
        for (var i=0;i<records.length;i++) {
          final row = records[i] as Map, id = '${row['recordId']}';
          if (!seen.add(id)) throw StateError('Duplicate local record identity.');
          if (changedIds != null && !changedIds.contains(id)) continue;
          final previous = incremental ? await rows.getObject([key,id]) as Map? : null;
          final ordinal = incremental ? (previous?['ordinal'] as int? ?? nextOrdinal++) : i;
          final entry = _entry(key,table,row,ordinal);
          bytes += (entry['bytes'] as int) - (previous?['bytes'] as int? ?? 0);
          await rows.put(entry);
        }
        if (changedIds != null) {
          for (final id in changedIds.difference(seen)) {
            final previous = await rows.getObject([key,id]) as Map?;
            bytes -= previous?['bytes'] as int? ?? 0;
            await rows.delete([key,id]);
          }
        }
        metadata['_indexedRecords'] = true;
        metadata['_rowBytes'] = bytes;
        metadata['_nextOrdinal'] = nextOrdinal;
      } else if (old?['_indexedRecords'] == true) { await rows.delete(_range(key)); }
      metadata['_bytes'] = bytes + utf8.encode(jsonEncode(metadata)).length;
      if ((metadata['_bytes'] as int) > 64*1024*1024) throw StateError('Offline snapshot exceeds local storage budget.');
      await responses.put(metadata,key);
      final entries = (await responses.getAll()).map((r)=>Map<String,dynamic>.from(r as Map)).toList()
        ..sort((a,b)=>(a['syncedAt'] as int).compareTo(b['syncedAt'] as int));
      var total = entries.fold<int>(0,(sum,row)=>sum+(row['_bytes'] as int? ?? utf8.encode(jsonEncode(row)).length));
      var count = entries.length;
      final cutoff = DateTime.now().subtract(const Duration(days:7)).millisecondsSinceEpoch;
      for (final entry in entries) {
        if (entry['syncedAt'] < cutoff || count>128 || total>64*1024*1024) {
          await responses.delete(entry['key']); await rows.delete(_range(entry['key'] as String));
          total -= entry['_bytes'] as int? ?? utf8.encode(jsonEncode(entry)).length; count--;
        }
      }
      await done;
    } catch (_) { try { tx.abort(); } catch (_) {} rethrow; }
  });
  Future<void> _remove(bool Function(Map row) matches) => _serialize(() async {
    final db = await _db(), tx = (await _db()).transactionList(['responses','record_rows'],idbModeReadWrite);
    tx.completed.ignore();
    final responses = tx.objectStore('responses');
    for (final raw in await responses.getAll()) {
      final row = raw as Map;
      if (matches(row)) { await responses.delete(row['key']); await tx.objectStore('record_rows').delete(_range(row['key'] as String)); }
    }
    await tx.completed; assert(db.version==2);
  });
  @override
  Future<void> removeEntry(String key) => _remove((row)=>row['key']==key);
  @override
  Future<void> removeScope(String scope) => _remove((row)=>row['scope']==scope);
  @override
  Future<void> removeAccount(String account) => _remove((row)=>row['account']==account);
  @override
  Future<void> invalidateScope(String scope,bool Function(String) affected) => _serialize(() async {
    final db = await _db(), tx = (await _db()).transaction('responses',idbModeReadWrite);
    tx.completed.ignore(); final store = tx.objectStore('responses');
    for (final raw in await store.getAll()) {
      final row = Map<String,dynamic>.from(raw as Map);
      if (row['scope']==scope && affected((jsonDecode(row['resource'] as String) as List).first as String)) {
        row['invalidated']=true; await store.put(row,row['key']);
      }
    }
    await tx.completed; assert(db.version==2);
  });
  @override
  Future<Set<String>?> searchRecordIds(String collection,String search,{required int expectedSyncedAt}) async {
    await _writes; final db=await _db();
    final tx=db.transactionList(['responses','record_rows'],idbModeReadOnly); tx.completed.ignore();
    final metadata=await tx.objectStore('responses').getObject(collection) as Map?;
    if(metadata?['_indexedRecords']!=true || metadata?['syncedAt']!=expectedSyncedAt ||
        metadata?['syncedAt'] < DateTime.now().subtract(const Duration(days:7)).millisecondsSinceEpoch) { await tx.completed; return null; }
    final text=search.toLowerCase(),rows=tx.objectStore('record_rows');
    final stream=text.length>=3 ? rows.index('search').openCursor(key:'${_bucket(collection)}:${text.substring(0,3)}',autoAdvance:true)
        : rows.openCursor(range:_range(collection),autoAdvance:true);
    final ids=<String>{};
    await for(final cursor in stream) {
      final row=cursor.value as Map;
      if(row['collection']==collection && (row['text'] as String).contains(text)) ids.add(row['id'] as String);
    }
    await tx.completed; return ids;
  }
  @override
  Future<List<Map<String,dynamic>>> recordPage(String collection,{String? status,String? afterId,int limit=100}) async {
    if(limit<1||limit>500)throw ArgumentError.value(limit,'limit');
    await _writes; final db=await _db();
    final tx=db.transactionList(['responses','record_rows'],idbModeReadOnly);tx.completed.ignore();
    final metadata=await tx.objectStore('responses').getObject(collection) as Map?;
    if(metadata==null || metadata['_indexedRecords']!=true ||
        (metadata['syncedAt'] as int)<DateTime.now().subtract(const Duration(days:7)).millisecondsSinceEpoch) {await tx.completed;return [];}
    final rows=tx.objectStore('record_rows');
    final range=status==null ? KeyRange.bound([collection,afterId??''],[collection,<Object>[]],afterId!=null)
      : KeyRange.bound([collection,status,afterId??''],[collection,status,<Object>[]],afterId!=null);
    final stream=status==null ? rows.openCursor(range:range,autoAdvance:true) : rows.index('status').openCursor(range:range,autoAdvance:true);
    final result=await stream.take(limit).map((cursor)=>Map<String,dynamic>.from((cursor.value as Map)['payload'] as Map)).toList();
    await tx.completed;return result;
  }
}
