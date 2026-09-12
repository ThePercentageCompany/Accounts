import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/auth/google_session.dart';
import 'package:tpc_invoice/core/auth/google_workspace_service.dart';
import 'package:tpc_invoice/core/sync/sync_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('GoogleSession initial state is unauthenticated', () {
    final session = GoogleSession();
    expect(session.user, isNull);
    expect(session.authorized, isFalse);
    expect(session.workspace, isNull);
    expect(session.isAuthorizing, isFalse);
  });

  test('GoogleSession signOut clears all local cache, SharedPreferences, and SyncManager', () async {
    final session = GoogleSession();
    session.authorized = true;
    session.cachedEmail = 'test@tpc.ae';
    session.cachedDisplayName = 'Test User';
    session.workspace = const WorkspaceConfig(
      spreadsheetId: 'sheet_123',
      driveFolderId: 'folder_123',
      companyName: 'The Percentage Company',
    );

    // Simulate cached data in SharedPreferences and SyncManager
    final sync = session.syncManager;
    await sync.initialize();
    await sync.saveCachedRecords('sheet_123', 'Invoices', [{'id': 'inv_1', 'number': 'INV-001'}]);
    await sync.enqueueOperation(
      spreadsheetId: 'sheet_123',
      tabName: 'Invoices',
      recordId: 'inv_1',
      action: 'upsert',
      data: {'id': 'inv_1'},
    );
    expect(sync.pendingCount, 1);

    await session.signOut();

    expect(session.authorized, isFalse);
    expect(session.workspace, isNull);
    expect(session.cachedEmail, isNull);
    expect(session.cachedDisplayName, isNull);
    expect(session.isOffline, isFalse);
    expect(sync.pendingCount, 0);

    // Verify cache was wiped
    final records = await sync.loadCachedRecords('sheet_123', 'Invoices');
    expect(records.isEmpty, isTrue);
  });

  test('GoogleSession useOfflineDemo activates offline mode with local demo workspace', () async {
    final session = GoogleSession();
    await session.useOfflineDemo();

    expect(session.authorized, isTrue);
    expect(session.isOffline, isTrue);
    expect(session.workspace, isNotNull);
    expect(session.workspace!.spreadsheetId, 'local_demo_workspace');
    expect(session.effectiveEmail, 'local@thepercentage.co');
    expect(session.effectiveDisplayName, 'Local Demo User');
  });

  test('GoogleSession signOut strictly preserves local repositories data in SharedPreferences', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tpc_demo_v1', '{"company":{"name":"My Preserved Co"},"invoices":[]}');
    await prefs.setString('tpc_quotations_v1', '[{"id":"q1","title":"Web Dev"}]');
    await prefs.setString('tpc_office_demo_v2', '{"employees":[{"id":"e1","name":"Alex"}]}');

    final session = GoogleSession();
    await session.useOfflineDemo();
    await session.signOut();

    // Verify local storage is intact
    expect(prefs.getString('tpc_demo_v1'), contains('My Preserved Co'));
    expect(prefs.getString('tpc_quotations_v1'), contains('Web Dev'));
    expect(prefs.getString('tpc_office_demo_v2'), contains('Alex'));
  });

  test('SyncManager migrateAndSyncLocalDataToCloud migrates all local data into pending cloud sync queue', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tpc_demo_v1', '{"company":{"name":"TPC Middle East"},"customers":[{"id":"c1","name":"Acme Corp"}],"invoices":[{"id":"inv_10","number":"INV-010"}]}');
    await prefs.setString('tpc_quotations_v1', '[{"id":"q1","number":"QT-001"}]');
    await prefs.setString('tpc_office_demo_v2', '{"employees":[{"id":"e1","name":"Sarah"}],"shareholders":[{"id":"sh1","name":"Founder"}],"entries":[{"id":"f1","description":"Server hosting"}]}');

    final sync = SyncManager.instance;
    await sync.initialize();
    await sync.migrateAndSyncLocalDataToCloud(
      spreadsheetId: 'sheet_cloud_456',
      token: 'mock_token',
    );

    // Verify all tabs were cached and enqueued
    final customers = await sync.loadCachedRecords('sheet_cloud_456', 'Customers');
    final invoices = await sync.loadCachedRecords('sheet_cloud_456', 'Invoices');
    final quotes = await sync.loadCachedRecords('sheet_cloud_456', 'Quotations');
    final employees = await sync.loadCachedRecords('sheet_cloud_456', 'Employees');
    final shareholders = await sync.loadCachedRecords('sheet_cloud_456', 'Shareholders');
    final finance = await sync.loadCachedRecords('sheet_cloud_456', 'Finance');

    expect(customers.any((c) => c['id'] == 'c1'), isTrue);
    expect(invoices.any((i) => i['id'] == 'inv_10'), isTrue);
    expect(quotes.any((q) => q['id'] == 'q1'), isTrue);
    expect(employees.any((e) => e['id'] == 'e1'), isTrue);
    expect(shareholders.any((s) => s['id'] == 'sh1'), isTrue);
    expect(finance.any((f) => f['id'] == 'f1'), isTrue);
    expect(sync.pendingQueue.isNotEmpty, isTrue);
  });
}

