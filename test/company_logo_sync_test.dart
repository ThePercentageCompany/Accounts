import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/auth/google_session.dart';
import 'package:tpc_invoice/core/auth/google_workspace_service.dart';
import 'package:tpc_invoice/core/sync/sheet_schema.dart';
import 'package:tpc_invoice/core/sync/sync_manager.dart';
import 'package:tpc_invoice/features/billing/data/company_logo_storage.dart';
import 'package:tpc_invoice/features/billing/data/google_direct_repository.dart';
import 'package:tpc_invoice/features/billing/data/hybrid_billing_repository.dart';
import 'package:tpc_invoice/features/billing/domain/billing_repository.dart';
import 'package:tpc_invoice/features/billing/domain/models.dart';

const _url = 'https://drive.google.com/file/d/company-logo/view';
const _logo = 'data:image/png;base64,iVBORw0KGgo=';

class _Session extends GoogleSession {
  _Session() {
    workspace = const WorkspaceConfig(
      spreadsheetId: 'company-sheet',
      driveFolderId: 'company-folder',
      companyName: 'Company',
    );
  }

  String? availableToken = 'test-token';
  bool employeeGateway = false;
  int gatewayDownloads = 0;

  @override
  bool get isCodeEmployeeSession => employeeGateway;

  @override
  Future<String?> tryGetToken() async => availableToken;

  @override
  Future<void> setWorkspace(WorkspaceConfig config, {bool migrateLocalData = false}) async {
    workspace = config;
  }

  @override
  Future<Map<String, dynamic>> downloadEmployeeFile(String url) async {
    gatewayDownloads++;
    return {'mimeType': 'image/png', 'base64': _logo.split(',').last};
  }
}

class _Service extends GoogleWorkspaceService {
  int downloads = 0;
  int uploads = 0;
  bool failDownload = false;
  bool failUpload = false;
  Completer<void>? uploading;
  Completer<void>? releaseUpload;
  void Function()? onUpload;

  @override
  Future<Map<String, dynamic>> downloadDriveFile(String token, String url) async {
    downloads++;
    if (failDownload) throw StateError('Offline');
    return {'mimeType': 'image/png', 'base64': _logo.split(',').last};
  }

  @override
  Future<String> uploadImageFile(String token, String folder, String name,
      Uint8List bytes, {String mimeType = 'image/png', String? subfolder = 'Assets'}) async {
    uploads++;
    uploading?.complete();
    if (releaseUpload != null) await releaseUpload!.future;
    if (failUpload) throw StateError('Upload failed');
    onUpload?.call();
    return _url;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Session session;
  late _Service service;
  final sync = SyncManager.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await sync.clearAll();
    await sync.useEmployeeScope(null);
    session = _Session();
    service = _Service();
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    await sync.clearAll();
    session.dispose();
  });

  test('Sheets round trip preserves logo reference without image bytes', () {
    const company = Company(name: 'Company', logo: _logo, logoDriveUrl: _url);
    final row = SheetSchema.recordToRow('Settings', {'id': 'company', 'value': company.toJson()});
    expect(row, contains(_url));
    expect(jsonEncode(row), isNot(contains('base64')));
    final record = SheetSchema.rowToRecord('Settings', row);
    final restored = Company.fromJson(Map<String, dynamic>.from(record['value'] as Map));
    expect(restored.logoDriveUrl, _url);
    expect(restored.logo, isEmpty);
    expect(Company.fromJson(restored.toJson()).logoDriveUrl, _url);
  });

  test('fresh device downloads private logo and survives later offline sheet refresh', () async {
    final store = CompanyLogoStorage(session, service);
    const company = Company(logoDriveUrl: _url);
    expect((await store.hydrate(company)).logo, _logo);
    service.failDownload = true;
    session.availableToken = null;
    expect((await CompanyLogoStorage(session, service).hydrate(company)).logo, _logo);
    expect(service.downloads, 1);
  });

  test('cached bytes do not replace a different remote logo', () async {
    final store = CompanyLogoStorage(session, service);
    await store.hydrate(const Company(logoDriveUrl: _url));
    service.failDownload = true;
    const changedUrl = 'https://drive.google.com/file/d/changed-logo/view';
    final company = await store.hydrate(const Company(logoDriveUrl: changedUrl));
    expect(company.logo, isEmpty);
    expect(company.logoDriveUrl, changedUrl);
  });

  test('employee logo download uses the authenticated gateway', () async {
    session.employeeGateway = true;
    session.availableToken = null;
    final company = await CompanyLogoStorage(session, service)
        .hydrate(const Company(logoDriveUrl: _url));
    expect(company.logo, _logo);
    expect(session.gatewayDownloads, 1);
    expect(service.downloads, 0);
  });

  test('metadata edit reuses stored Drive reference without another upload', () async {
    final store = CompanyLogoStorage(session, service);
    const previous = Company(name: 'Company', logoDriveUrl: _url);
    final hydrated = await store.hydrate(previous);
    session.availableToken = null;
    final saved = await store.prepareForSave(hydrated.copyWith(name: 'Renamed'), previous);
    expect(saved.logoDriveUrl, _url);
    expect(service.uploads, 0);
  });

  test('unavailable logo retains remote reference on unrelated save', () async {
    service.failDownload = true;
    final store = CompanyLogoStorage(session, service);
    const previous = Company(logoDriveUrl: _url);
    final unloaded = await store.hydrate(previous);
    final saved = await store.prepareForSave(unloaded.copyWith(name: 'Renamed'), previous);
    expect(saved.logoDriveUrl, _url);
    final removed = await store.prepareForSave(
      unloaded.copyWith(logo: '', logoDriveUrl: ''), previous);
    expect(removed.logoDriveUrl, isEmpty);
  });

  for (final direct in [false, true]) {
    final kind = direct ? 'direct' : 'hybrid';
    BillingRepository repository() => direct
        ? GoogleDirectBillingRepository(session, service: service)
        : HybridBillingRepository(session, service: service);

    test('$kind upload failure preserves saved settings and pending queue', () async {
      const original = Company(name: 'Company', logoDriveUrl: _url, version: 3);
      await sync.saveCachedRecords('company-sheet', 'Settings', [
        {'id': 'company', 'value': original.toJson()},
      ]);
      service.failUpload = true;
      await expectLater(repository().saveCompany(original.copyWith(logo: _logo)), throwsStateError);
      final records = await sync.loadCachedRecords('company-sheet', 'Settings');
      expect(records.single['value'], original.toJson());
      expect(sync.pendingQueue, isEmpty);
    });

    test('$kind waits for upload and keeps a newer edit after concurrent saves', () async {
      service.uploading = Completer<void>();
      service.releaseUpload = Completer<void>();
      service.onUpload = () => session.availableToken = null;
      final repo = repository();
      const original = Company(name: 'Company', logo: _logo);
      final first = repo.saveCompany(original);
      await service.uploading!.future;
      expect(await sync.loadCachedRecords('company-sheet', 'Settings'), isEmpty);
      expect(sync.pendingQueue, isEmpty);
      final second = repo.saveCompany(original.copyWith(phone: 'new phone'));
      service.releaseUpload!.complete();
      await Future.wait([first, second]);
      final records = await sync.loadCachedRecords('company-sheet', 'Settings');
      final saved = records.single['value'] as Map;
      expect(saved['phone'], 'new phone');
      expect(saved['logoDriveUrl'], _url);
      expect(saved['version'], 2);
      expect(service.uploads, 1);

      // Simulate Sheets returning only its short Drive reference.
      final row = SheetSchema.recordToRow('Settings', records.single);
      await sync.saveCachedRecords('company-sheet', 'Settings', [SheetSchema.rowToRecord('Settings', row)]);
      expect((await repo.load()).company.logo, _logo);
    });
  }
}
