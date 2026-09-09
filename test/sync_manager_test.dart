import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/sync/sync_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SyncManager initializes with clean state', () async {
    final manager = SyncManager.instance;
    await manager.initialize();

    expect(manager.pendingCount, 0);
    expect(manager.status, SyncStatus.synced);
  });

  test('SyncManager caches and retrieves tab records', () async {
    final manager = SyncManager.instance;
    await manager.initialize();

    const spreadsheetId = 'sheet_test_123';
    const tabName = 'Invoices';

    await manager.saveCachedRecords(spreadsheetId, tabName, [
      {'id': 'inv_1', 'number': 'INV-001', 'total': 100},
      {'id': 'inv_2', 'number': 'INV-002', 'total': 250},
    ]);

    final records = await manager.loadCachedRecords(spreadsheetId, tabName);
    expect(records.length, 2);
    expect(records[0]['id'], 'inv_1');
    expect(records[1]['number'], 'INV-002');

    // Test upsert
    await manager.upsertCachedRecord(spreadsheetId, tabName, 'inv_3', {
      'id': 'inv_3',
      'number': 'INV-003',
      'total': 500,
    });

    final updatedRecords = await manager.loadCachedRecords(spreadsheetId, tabName);
    expect(updatedRecords.length, 3);
    expect(updatedRecords.any((r) => r['id'] == 'inv_3'), isTrue);

    // Test delete
    await manager.deleteCachedRecord(spreadsheetId, tabName, 'inv_1');
    final afterDelete = await manager.loadCachedRecords(spreadsheetId, tabName);
    expect(afterDelete.length, 2);
    expect(afterDelete.any((r) => r['id'] == 'inv_1'), isFalse);
  });

  test('SyncManager enqueues offline operations and updates status', () async {
    final manager = SyncManager.instance;
    await manager.initialize();

    const spreadsheetId = 'sheet_test_123';
    await manager.enqueueOperation(
      spreadsheetId: spreadsheetId,
      tabName: 'Customers',
      recordId: 'cust_99',
      action: 'upsert',
      data: {'id': 'cust_99', 'name': 'Acme Corp'},
    );

    expect(manager.pendingCount, 1);
    expect(manager.status, SyncStatus.pendingChanges);

    // Compacts duplicate updates for same record
    await manager.enqueueOperation(
      spreadsheetId: spreadsheetId,
      tabName: 'Customers',
      recordId: 'cust_99',
      action: 'upsert',
      data: {'id': 'cust_99', 'name': 'Acme Corporation Updated'},
    );

    expect(manager.pendingCount, 1);
    expect(manager.pendingQueue.first.data?['name'], 'Acme Corporation Updated');
  });
}
