import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/saas/workspace_record_cache.dart';

void main() {
  test('snapshots persist and stay isolated by owner and company', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cache = WorkspaceRecordCache(prefs, 'owner-company');
    await cache.save('Customers', [
      {'name': 'Customer', 'recordVersion': 2}
    ]);
    expect(
        WorkspaceRecordCache(prefs, 'owner-company')
            .read('Customers')!
            .single['recordVersion'],
        2);
    expect(WorkspaceRecordCache(prefs, 'another-company').read('Customers'),
        isNull);
    expect(cache.read('Invoices'), isNull);
    await cache.clear('Customers');
    expect(cache.read('Customers'), isNull);
  });
  test('expired and corrupt snapshots are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'tpc_workspace_cache_v1_scope_Customers':
          '{"savedAt":"2020-01-01T00:00:00Z","records":[]}',
      'tpc_workspace_cache_v1_scope_Invoices': 'broken',
    });
    final cache =
        WorkspaceRecordCache(await SharedPreferences.getInstance(), 'scope');
    expect(cache.read('Customers'), isNull);
    expect(cache.read('Invoices'), isNull);
  });
}
