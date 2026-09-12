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
}

