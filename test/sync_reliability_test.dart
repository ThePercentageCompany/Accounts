import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/auth/google_workspace_service.dart';
import 'package:tpc_invoice/core/sync/sync_manager.dart';

class _WorkspaceService extends GoogleWorkspaceService {
  Map<String, List<Map<String, dynamic>>> records = {};
  final reads = <String>[];
  final uploads = <Map<String, dynamic>>[];
  final readStarted = Completer<void>();
  final uploadStarted = Completer<void>();
  Completer<void>? readGate;
  Completer<void>? uploadGate;
  Object? readError;
  Object? uploadError;

  @override
  Future<Map<String, List<Map<String, dynamic>>>> readAllTabsBatch(
      String accessToken, String spreadsheetId, List<String> tabNames) async {
    reads.add(spreadsheetId);
    final snapshot = {
      for (final entry in records.entries)
        entry.key:
            entry.value.map((row) => Map<String, dynamic>.of(row)).toList(),
    };
    if (!readStarted.isCompleted) readStarted.complete();
    if (readGate != null) await readGate!.future;
    if (readError != null) throw readError!;
    return snapshot;
  }

  @override
  Future<void> upsertTabRecord(String accessToken, String spreadsheetId,
      String sheetName, String id, Map<String, dynamic> record) async {
    uploads.add(Map<String, dynamic>.of(record));
    if (!uploadStarted.isCompleted) uploadStarted.complete();
    if (uploadGate != null) await uploadGate!.future;
    if (uploadError != null) throw uploadError!;
    records[sheetName] = [
      ...?records[sheetName]?.where((row) => row['id'] != id),
      Map<String, dynamic>.of(record),
    ];
  }

  @override
  Future<void> deleteTabRecord(String accessToken, String spreadsheetId,
      String sheetName, String id) async {
    if (uploadError != null) throw uploadError!;
    records[sheetName]?.removeWhere((row) => row['id'] == id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _WorkspaceService service;
  late SyncManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = _WorkspaceService();
    manager = SyncManager(service: service);
    await manager.initialize();
  });

  tearDown(() => manager.dispose());

  Future<void> enqueue(String id, String name) => manager.enqueueOperation(
        spreadsheetId: 'sheet',
        tabName: 'Employees',
        recordId: id,
        action: 'upsert',
        data: {'id': id, 'name': name},
      );

  Future<List<dynamic>> mirroredEmployees() async {
    final prefs = await SharedPreferences.getInstance();
    return (jsonDecode(prefs.getString('tpc_office_demo_v2')!)
        as Map)['employees'] as List;
  }

  test('concurrent local edits retain both records and their offline mirror',
      () async {
    await Future.wait([
      manager.upsertCachedRecord('sheet', 'Employees', 'one', {'id': 'one'}),
      manager.upsertCachedRecord('sheet', 'Employees', 'two', {'id': 'two'}),
    ]);

    expect(
        await manager.loadCachedRecords('sheet', 'Employees'),
        unorderedEquals([
          {'id': 'one'},
          {'id': 'two'}
        ]));
    expect(
        await mirroredEmployees(),
        unorderedEquals([
          {'id': 'one'},
          {'id': 'two'}
        ]));
  });

  test(
      'failed uploads remain queued with an error and do not pull old cloud data',
      () async {
    service.uploadError = StateError('Failed to upload (403)');
    final authFailures = <Object>[];
    manager.onAuthorizationFailure = (error) async => authFailures.add(error);
    await enqueue('one', 'Local employee');

    await manager.triggerBackgroundSync(token: 'token', spreadsheetId: 'sheet');

    expect(manager.status, SyncStatus.error);
    expect(manager.lastError, contains('(403)'));
    expect(manager.lastSyncedTime, isNull);
    expect(manager.pendingCount, 1);
    expect(authFailures, isEmpty);
    expect(service.reads, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(
        jsonDecode(prefs.getString('tpc_pending_sync_queue')!), hasLength(1));
    expect(
        (await manager.loadCachedRecords('sheet', 'Employees')).single['name'],
        'Local employee');
  });

  test('expired credentials notify the session without pulling cloud data', () async {
    service.uploadError = StateError('Invalid authentication credentials (401)');
    final authFailures = <Object>[];
    manager.onAuthorizationFailure = (error) async => authFailures.add(error);
    await enqueue('one', 'Local employee');

    await manager.triggerBackgroundSync(token: 'expired', spreadsheetId: 'sheet');

    expect(authFailures, hasLength(1));
    expect(service.reads, isEmpty);
    expect(manager.status, SyncStatus.error);
    expect(manager.pendingCount, 1);
  });

  test(
      'edits and deletes during a pull survive in cache and mirror until uploaded',
      () async {
    service.records = {
      'Employees': [
        {'id': 'one', 'name': 'Old name'},
        {'id': 'two', 'name': 'Deleted employee'},
      ],
    };
    service.readGate = Completer<void>();
    service.uploadGate = Completer<void>();
    final syncing =
        manager.triggerBackgroundSync(token: 'token', spreadsheetId: 'sheet');
    await service.readStarted.future;
    await enqueue('one', 'New name');
    await manager.enqueueOperation(
        spreadsheetId: 'sheet',
        tabName: 'Employees',
        recordId: 'two',
        action: 'delete');
    service.readGate!.complete();
    await service.uploadStarted.future;

    expect(manager.isBackgroundSyncing, isTrue);
    expect(manager.status, SyncStatus.syncing);
    expect(await manager.loadCachedRecords('sheet', 'Employees'), [
      {'id': 'one', 'name': 'New name'},
    ]);
    expect(await mirroredEmployees(), [
      {'id': 'one', 'name': 'New name'},
    ]);
    service.uploadGate!.complete();
    await syncing;

    expect(manager.pendingCount, 0);
    expect(manager.status, SyncStatus.synced);
    expect(service.records['Employees'], [
      {'id': 'one', 'name': 'New name'}
    ]);
  });

  test(
      'acknowledging an older upload does not discard a newer edit of the same row',
      () async {
    await enqueue('one', 'First edit');
    service.uploadGate = Completer<void>();
    final syncing =
        manager.triggerBackgroundSync(token: 'token', spreadsheetId: 'sheet');
    await service.uploadStarted.future;
    await enqueue('one', 'Latest edit');
    service.uploadGate!.complete();
    await syncing;

    expect(service.uploads.map((row) => row['name']),
        ['First edit', 'Latest edit']);
    expect(manager.pendingCount, 0);
    expect(
        (await manager.loadCachedRecords('sheet', 'Employees')).single['name'],
        'Latest edit');
    expect((await mirroredEmployees()).single['name'], 'Latest edit');
  });

  test(
      'failed cloud reads preserve local data and do not report a successful sync',
      () async {
    await manager
        .upsertCachedRecord('sheet', 'Employees', 'one', {'id': 'one'});
    service.readError = StateError('Sheets unavailable (503)');
    var refreshed = false;

    await manager.triggerBackgroundSync(
        token: 'token',
        spreadsheetId: 'sheet',
        onDataRefreshed: () => refreshed = true);

    expect(manager.status, SyncStatus.error);
    expect(manager.lastError, contains('(503)'));
    expect(manager.lastSyncedTime, isNull);
    expect(refreshed, isFalse);
    expect(await manager.loadCachedRecords('sheet', 'Employees'), [
      {'id': 'one'}
    ]);
    expect(await mirroredEmployees(), [
      {'id': 'one'}
    ]);
  });

  test('cloud deletions clear cache and mirror and notify consumers', () async {
    await manager
        .upsertCachedRecord('sheet', 'Employees', 'one', {'id': 'one'});
    service.records = {'Employees': []};
    var refreshes = 0;

    await manager.triggerBackgroundSync(
        token: 'token',
        spreadsheetId: 'sheet',
        onDataRefreshed: () => refreshes++);

    expect(await manager.loadCachedRecords('sheet', 'Employees'), isEmpty);
    expect(await mirroredEmployees(), isEmpty);
    expect(refreshes, 1);
    expect(manager.dataRevision, 1);
    expect(manager.status, SyncStatus.synced);
  });

  test('a sync requested while busy retains the requested workspace', () async {
    service.readGate = Completer<void>();
    final syncing =
        manager.triggerBackgroundSync(token: 'first', spreadsheetId: 'sheet');
    await service.readStarted.future;
    await manager.triggerBackgroundSync(
        token: 'second', spreadsheetId: 'other-sheet');
    service.readGate!.complete();
    await syncing;

    expect(service.reads, ['sheet', 'other-sheet']);
    expect(manager.isBackgroundSyncing, isFalse);
  });
}
