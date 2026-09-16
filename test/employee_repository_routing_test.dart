import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/auth/google_session.dart';
import 'package:tpc_invoice/core/auth/google_workspace_service.dart';
import 'package:tpc_invoice/core/sync/sync_manager.dart';
import 'package:tpc_invoice/features/billing/data/hybrid_billing_repository.dart';
import 'package:tpc_invoice/features/billing/domain/models.dart';
import 'package:tpc_invoice/features/office/data/hybrid_office_repository.dart';
import 'package:tpc_invoice/features/quotations/data/hybrid_quotation_repository.dart';
import 'package:tpc_invoice/features/quotations/domain/quotation.dart';

class _EmployeeSession extends GoogleSession {
  _EmployeeSession() {
    workspace = const WorkspaceConfig(
      spreadsheetId: 'owner-sheet',
      driveFolderId: 'owner-drive',
      companyName: 'Owner Company',
      isEmployee: true,
      employeeId: 'employee-1',
    );
  }

  int syncCalls = 0;
  bool failUpload = false;
  final List<Map<String, String>> uploads = [];

  @override
  bool get isCodeEmployeeSession => true;

  @override
  Future<String?> tryGetToken() =>
      throw StateError('An employee must not request a Google token.');

  @override
  Future<void> syncNow() async {
    syncCalls++;
  }

  @override
  Future<String> uploadEmployeeFile({
    required String tabName,
    required String recordId,
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (failUpload) throw StateError('Owner Drive is offline. Retry the upload.');
    uploads.add({'tab': tabName, 'recordId': recordId, 'name': name});
    return 'https://drive.google.com/file/d/owner-file/view';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sync = SyncManager.instance;
  late _EmployeeSession session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await sync.clearAll();
    await sync.useEmployeeScope('employee-1');
    session = _EmployeeSession();
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    await sync.clearAll();
    await sync.useEmployeeScope(null);
    session.dispose();
  });

  test('employee loads never import owner or demo legacy data', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tpc_demo_v1', jsonEncode({
      'customers': [{'id': 'private-customer', 'name': 'Owner only'}],
      'company': {'name': 'Unrelated Company'},
    }));
    await prefs.setString('tpc_office_demo_v2', jsonEncode({
      'employees': [{'id': 'private-employee'}],
      'entries': [{'id': 'private-entry'}],
    }));
    await prefs.setString('tpc_quotations_v1', jsonEncode([
      {'id': 'private-quotation'},
    ]));

    final billing = await HybridBillingRepository(session).load();
    final office = await HybridOfficeRepository(session).command('officeLoad');
    final quotations = await HybridQuotationRepository(session).load();

    expect(billing.customers, isEmpty);
    expect(billing.company.name, 'Owner Company');
    expect(billing.company.bank, isEmpty);
    expect(office['employees'], isEmpty);
    expect(office['entries'], isEmpty);
    expect(quotations, isEmpty);
    expect(session.syncCalls, greaterThanOrEqualTo(3));
  });

  test('employee changes queue under the employee with original base version', () async {
    await sync.saveCachedRecords('owner-sheet', 'Customers', [
      const Customer(id: 'customer-1', name: 'Before', version: 4).toJson(),
    ]);
    final repo = HybridBillingRepository(session);
    await repo.saveCustomer(const Customer(id: 'customer-1', name: 'After', version: 4));
    await Future<void>.delayed(Duration.zero);

    expect(sync.pendingQueue.single.actorId, 'employee-1');
    expect(sync.pendingQueue.single.expectedVersion, 4);
    expect(sync.pendingQueue.single.data?['name'], 'After');
    expect(session.syncCalls, greaterThan(0));

    await repo.deleteCustomer('customer-1');
    expect(sync.pendingQueue.single.action, 'delete');
    expect(sync.pendingQueue.single.expectedVersion, 4);
  });

  test('employee cannot overwrite company settings', () async {
    await expectLater(
      HybridBillingRepository(session).saveCompany(const Company(name: 'Changed')),
      throwsStateError,
    );
    expect(sync.pendingQueue, isEmpty);
  });

  test('employee quotation archives upload through the owner gateway and sync the URL', () async {
    final repo = HybridQuotationRepository(session);
    const quotation = Quotation(
      id: 'quote-1', date: '2026-09-17', validUntil: '2026-10-17',
      customer: Customer(id: 'customer-1', name: 'Customer'),
      company: Company(name: 'Owner Company'),
    );
    final saved = await repo.save(quotation);
    final url = await repo.archive(saved, Uint8List.fromList([1, 2, 3]));
    expect(session.uploads.single['tab'], 'Quotations');
    expect(session.uploads.single['recordId'], 'quote-1');
    expect(sync.pendingQueue.single.data?['driveUrl'], url);
  });

  test('employee document upload failure preserves the original record', () async {
    await sync.saveCachedRecords('owner-sheet', 'Finance', [
      {'id': 'expense-1', 'version': 2, 'documents': []},
    ]);
    session.failUpload = true;
    await expectLater(
      HybridOfficeRepository(session).command('documentUpload', {
        'table': 'Finance', 'id': 'expense-1', 'version': 2,
        'documentId': 'document-1', 'name': 'receipt.pdf',
        'bytes': base64Encode([1, 2, 3]),
      }),
      throwsStateError,
    );
    final records = await sync.loadCachedRecords('owner-sheet', 'Finance');
    expect(records.single['version'], 2);
    expect(records.single['documents'], isEmpty);
    expect(sync.pendingQueue, isEmpty);
  });

  test('employee report archive uses the gateway report permission target', () async {
    await HybridOfficeRepository(session).command('reportArchive', {
      'month': '2026-09', 'pdf': base64Encode([1, 2, 3]),
    });
    expect(session.uploads.single['tab'], 'Reports');
    expect(session.uploads.single['recordId'], '2026-09');
  });
}
