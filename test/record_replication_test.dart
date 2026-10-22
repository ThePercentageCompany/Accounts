import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';
import 'package:tpc_invoice/core/cache/record_delta.dart';
import 'package:tpc_invoice/core/offline/offline_store.dart';

Map<String,dynamic> row(String id,int version,{String? name}) =>
    {'recordId':id,'recordVersion':version,'name':name??id,'status':'ACTIVE'};
Map<String,dynamic> snapshot(List<Map<String,dynamic>> rows,{String cursor='1'}) =>
    {'records':rows,'syncCursor':cursor,'syncScope':'scope'};
Map<String,dynamic> page(List<Map<String,dynamic>> rows,{String cursor='2',String through='2',bool more=false,List<Map<String,dynamic>> removed=const []}) =>
    {'reset':false,'records':rows,'removed':removed,'cursor':cursor,'through':through,'hasMore':more,'syncScope':'scope'};
Map<String,dynamic> envelope(String key,Map<String,dynamic> data,{int? syncedAt,String account='account'}) =>
    {'schema':2,'key':key,'resource':jsonEncode(['/v1/companies/a/records/Customers',{}]),
      'account':account,'scope':'scope','syncedAt':syncedAt??DateTime.now().millisecondsSinceEpoch,
      'complete':true,'data':data};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('delta merges newer revisions, ignores stale revisions and propagates deletion',() async {
    final base=snapshot([row('a',3),row('b',1)]);
    final result=await fetchRecordDelta(base,(_,__,___) async =>page([row('a',2),row('c',1)],removed:[{'recordId':'b','recordVersion':2}]));
    expect((result!['records'] as List).map((r)=>r['recordId']),['a','c']);
    expect(result['records'][0]['recordVersion'],3);
    expect(result['syncCursor'],'2');
    expect(base['records'],hasLength(2));
    expect(base['syncCursor'],'1');
  });
  test('a failed second page publishes no partial result or cursor',() async {
    final base=snapshot([row('a',1)]);var requests=0;
    await expectLater(fetchRecordDelta(base,(_,__,___) async {
      if(requests++==0)return page([row('a',2)],cursor:'2',through:'3',more:true);
      throw StateError('Disconnected');
    }),throwsStateError);
    expect(base['syncCursor'],'1');expect(base['records'][0]['recordVersion'],1);
  });
  test('pagination fixes the high-water mark and retains deletion revisions',() async {
    var count=0;
    final result=await fetchRecordDelta(snapshot([row('a',1)]),(after,through,scope) async {
      expect(scope,'scope');
      if(count++==0) {expect(through,isNull);return page([],cursor:'2',through:'3',more:true,removed:[{'recordId':'a','recordVersion':3}]);}
      expect(after,'2');expect(through,'3');return page([row('a',2)],cursor:'3',through:'3');
    });
    expect(result!['records'],isEmpty);
  });
  test('scope changes and expired cursors request a fresh authorized bootstrap',() async {
    expect(await fetchRecordDelta(snapshot([]),(_,__,___) async =>{'reset':true}),isNull);
    await expectLater(fetchRecordDelta(snapshot([]),(_,__,___) async =>{...page([]),'syncScope':'another actor'}),throwsException);
  });
  test('non-advancing and changing sync windows are rejected',() async {
    await expectLater(fetchRecordDelta(snapshot([]),(_,__,___) async =>page([],cursor:'1',more:true)),throwsException);
    var count=0;
    await expectLater(fetchRecordDelta(snapshot([]),(_,__,___) async => count++==0
      ? page([],cursor:'2',through:'3',more:true) : page([],cursor:'4',through:'4')),throwsException);
  });
  test('normalized snapshots atomically persist record deltas and cursor',() async {
    final factory=newIdbFactoryMemory(),store=IndexedCacheStore(newIdbFactoryMemory());
    final indexed=IndexedCacheStore(factory,databaseName:'normalized');
    final initial=envelope('key',snapshot([row('a',1),row('b',1)]));
    await indexed.write('key',initial);
    final next=await fetchRecordDelta(initial['data'] as Map<String,dynamic>,(_,__,___) async =>page([row('a',2)],removed:[{'recordId':'b','recordVersion':2}]));
    await indexed.write('key',envelope('key',next!));
    final reopened=IndexedCacheStore(factory,databaseName:'normalized');
    final saved=await reopened.read('key');
    expect(saved!['data']['syncCursor'],'2');expect(saved['data']['records'],hasLength(1));
    expect(saved['data']['records'][0]['recordVersion'],2);
    expect(saved['data'].containsKey('_recordDelta'),isFalse);
    expect(await reopened.recordPage('key'),hasLength(1));
    await store.removeScope('unused');
  });
  test('failed normalized write rolls back rows and cursor together',() async {
    final indexed=IndexedCacheStore(newIdbFactoryMemory());
    await indexed.write('key',envelope('key',snapshot([row('a',1)])));
    await expectLater(indexed.write('key',envelope('key',snapshot([row('a',2),row('a',3)],cursor:'3'))),throwsStateError);
    final retained=await indexed.read('key');
    expect(retained!['data']['syncCursor'],'1');expect(retained['data']['records'][0]['recordVersion'],1);
  });
  test('legacy cache migration preserves data and leaves durable outbox untouched',() async {
    final factory=newIdbFactoryMemory();
    final legacy=await factory.open('legacy',version:1,onUpgradeNeeded:(event)=>event.database.createObjectStore('responses'));
    final tx=legacy.transaction('responses',idbModeReadWrite);
    final original=envelope('key',snapshot([row('a',1)]));
    await tx.objectStore('responses').put(original,'key');await tx.completed;legacy.close();
    final outbox=IndexedOfflineStore(factory);
    await outbox.change('actor', (p)=>p['operations'].add({'operationId':'keep'}));
    final indexed=IndexedCacheStore(factory,databaseName:'legacy');
    expect((await indexed.read('key'))!['data']['records'],hasLength(1));
    await indexed.write('key',original);
    expect(await indexed.recordPage('key'),hasLength(1));
    await indexed.removeAccount('account');
    expect(await indexed.read('key'),isNull);expect(await indexed.recordPage('key'),isEmpty);
    expect((await outbox.read('actor'))['operations'][0]['operationId'],'keep');
  });
  test('indexed search is scoped, case insensitive and refuses stale disk snapshots',() async {
    final indexed=IndexedCacheStore(newIdbFactoryMemory());final now=DateTime.now().millisecondsSinceEpoch;
    await indexed.write('actor-a',envelope('actor-a',snapshot([row('a',1,name:'Al Noor Trading'),row('b',1,name:'Different')]),syncedAt:now));
    await indexed.write('actor-b',envelope('actor-b',snapshot([row('hidden',1,name:'Al Noor Trading')]),account:'other',syncedAt:now));
    expect(await indexed.searchRecordIds('actor-a','NOOR',expectedSyncedAt:now),{'a'});
    expect(await indexed.searchRecordIds('actor-a','noor',expectedSyncedAt:now+1),isNull);
    expect(await indexed.searchRecordIds('absent','noor',expectedSyncedAt:now),isNull);
    await indexed.removeAccount('account');
    expect(await indexed.recordPage('actor-a'),isEmpty);expect(await indexed.recordPage('actor-b'),hasLength(1));
  });
  test('large snapshots exceed the old blob limit and support indexed keyset pages',() async {
    final indexed=IndexedCacheStore(newIdbFactoryMemory());
    final records=List.generate(5000,(i)=>{...row(i.toString().padLeft(5,'0'),1,name:'Customer $i'),
      'status':i.isEven?'ACTIVE':'DRAFT','description':List.filled(900,'x').join()});
    expect(utf8.encode(jsonEncode(records)).length,greaterThan(4*1024*1024));
    await indexed.write('large',envelope('large',snapshot(records)));
    final first=await indexed.recordPage('large',status:'DRAFT',limit:100);
    final second=await indexed.recordPage('large',status:'DRAFT',afterId:first.last['recordId'] as String,limit:100);
    expect(first,hasLength(100));expect(second,hasLength(100));
    expect(first.every((r)=>r['status']=='DRAFT'),isTrue);
    expect(first.map((r)=>r['recordId']).toSet().intersection(second.map((r)=>r['recordId']).toSet()),isEmpty);
    expect((await indexed.read('large'))!['data']['records'],hasLength(5000));
  },timeout:const Timeout(Duration(minutes:2)));
}
