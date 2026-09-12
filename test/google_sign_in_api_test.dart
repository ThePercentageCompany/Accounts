import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/auth/google_session.dart';
import 'package:tpc_invoice/core/auth/google_workspace_service.dart';

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
}

