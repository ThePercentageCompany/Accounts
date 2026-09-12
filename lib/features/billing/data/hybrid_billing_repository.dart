import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/google_session.dart';
import '../../../core/auth/google_workspace_service.dart';
import '../../../core/sync/sync_manager.dart';
import '../domain/billing_repository.dart';
import '../domain/models.dart';
import '../domain/totals.dart';

/// Unified offline-first + auto-cloud-sync billing repository.
///
/// Every mutation:
///   1. Writes to local SharedPreferences storage immediately (0ms, always)
///   2. Updates the SyncManager tab cache (which also mirrors to local storage)
///   3. Enqueues a Google Sheets cloud op when a real workspace is connected
///   4. Triggers a non-blocking background sync when an OAuth token is available
///
/// Replaces both [LocalRepository] and [GoogleDirectBillingRepository].
class HybridBillingRepository implements BillingRepository {
  final GoogleSession session;
  final GoogleWorkspaceService _service = GoogleWorkspaceService();
  final SyncManager _sync = SyncManager.instance;

  HybridBillingRepository(this.session);

  @override
  bool get isDemo => !_hasCloudWorkspace;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get _hasCloudWorkspace {
    final id = session.workspace?.spreadsheetId;
    return id != null && id.isNotEmpty && id != 'local_demo_workspace';
  }

  String get _spreadsheetId =>
      _hasCloudWorkspace ? session.workspace!.spreadsheetId : 'local_demo_workspace';

  String get _driveFolderId => session.workspace?.driveFolderId ?? '';

  void _scheduleBackgroundSync() {
    if (!_hasCloudWorkspace) return;
    Future.microtask(() async {
      try {
        final token = await session.tryGetToken();
        if (token != null) {
          await _sync.triggerBackgroundSync(
            token: token,
            spreadsheetId: _spreadsheetId,
          );
        }
      } catch (_) {}
    });
  }

  /// Upserts into SyncManager cache (which mirrors to local storage) and
  /// optionally enqueues a cloud op.
  Future<void> _upsert(String tab, String id, Map<String, dynamic> data) async {
    await _sync.upsertCachedRecord(_spreadsheetId, tab, id, data);
    if (_hasCloudWorkspace) {
      await _sync.enqueueOperation(
        spreadsheetId: _spreadsheetId,
        tabName: tab,
        recordId: id,
        action: 'upsert',
        data: data,
      );
    }
  }

  /// Deletes from SyncManager cache (which mirrors to local storage) and
  /// optionally enqueues a cloud op.
  Future<void> _delete(String tab, String id) async {
    await _sync.deleteCachedRecord(_spreadsheetId, tab, id);
    if (_hasCloudWorkspace) {
      await _sync.enqueueOperation(
        spreadsheetId: _spreadsheetId,
        tabName: tab,
        recordId: id,
        action: 'delete',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // BillingRepository interface
  // ---------------------------------------------------------------------------

  @override
  Future<BillingData> load() async {
    final sid = _spreadsheetId;

    // Load from SyncManager tab cache for instant response
    var cachedCustomers = await _sync.loadCachedRecords(sid, 'Customers');
    var cachedInvoices = await _sync.loadCachedRecords(sid, 'Invoices');
    var cachedSettings = await _sync.loadCachedRecords(sid, 'Settings');

    // Cold start: seed cache from legacy local storage keys
    if (cachedCustomers.isEmpty && cachedInvoices.isEmpty && cachedSettings.isEmpty) {
      await _seedCacheFromLocalStorage(sid);
      cachedCustomers = await _sync.loadCachedRecords(sid, 'Customers');
      cachedInvoices = await _sync.loadCachedRecords(sid, 'Invoices');
      cachedSettings = await _sync.loadCachedRecords(sid, 'Settings');
    }

    Company company = const Company();
    for (final s in cachedSettings) {
      if (s['id'] == 'company') {
        final val = s['value'] ?? s;
        if (val is Map) company = Company.fromJson(Map<String, dynamic>.from(val));
      }
    }
    if (company.name.isEmpty &&
        session.workspace?.companyName != null &&
        session.workspace!.companyName.isNotEmpty) {
      company = company.copyWith(name: session.workspace!.companyName);
    }

    _scheduleBackgroundSync();

    return BillingData(
      customers: cachedCustomers.map((x) => Customer.fromJson(x)).toList(),
      invoices: cachedInvoices.map((x) => Invoice.fromJson(x)).toList(),
      company: company,
    );
  }

  /// Seeds the SyncManager tab cache from the legacy local storage key
  /// (`tpc_demo_v1`) on first load so existing offline data is not lost.
  Future<void> _seedCacheFromLocalStorage(String spreadsheetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final billingRaw = prefs.getString('tpc_demo_v1');
      if (billingRaw == null || billingRaw.isEmpty) return;
      final billingMap = jsonDecode(billingRaw) as Map<String, dynamic>;

      final customers = (billingMap['customers'] as List? ?? [])
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      final invoices = (billingMap['invoices'] as List? ?? [])
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      final company = billingMap['company'] as Map<String, dynamic>?;

      if (customers.isNotEmpty) {
        await _sync.saveCachedRecords(spreadsheetId, 'Customers', customers);
      }
      if (invoices.isNotEmpty) {
        await _sync.saveCachedRecords(spreadsheetId, 'Invoices', invoices);
      }
      if (company != null && company.isNotEmpty) {
        await _sync.saveCachedRecords(spreadsheetId, 'Settings', [
          {'id': 'company', 'value': company}
        ]);
      }
    } catch (_) {}
  }

  @override
  Future<void> saveCustomer(Customer customer) async {
    final updated = customer.copyWith(version: customer.version + 1);
    await _upsert('Customers', updated.id, updated.toJson());
    _scheduleBackgroundSync();
  }

  @override
  Future<void> deleteCustomer(String customerId) async {
    await _delete('Customers', customerId);
    _scheduleBackgroundSync();
  }

  @override
  Future<void> saveCompany(Company company) async {
    final updated = company.copyWith(version: company.version + 1);
    final payload = {'id': 'company', 'value': updated.toJson()};
    await _upsert('Settings', 'company', payload);

    // Keep workspace company name in sync
    if (_hasCloudWorkspace &&
        session.workspace != null &&
        company.name.isNotEmpty &&
        session.workspace!.companyName != company.name) {
      final ws = WorkspaceConfig(
        spreadsheetId: session.workspace!.spreadsheetId,
        spreadsheetUrl: session.workspace!.spreadsheetUrl,
        driveFolderId: session.workspace!.driveFolderId,
        folderUrl: session.workspace!.folderUrl,
        companyName: company.name,
      );
      await session.setWorkspace(ws);
    }

    // Archive company logo to Drive (background, non-blocking)
    if (company.logo.isNotEmpty && _hasCloudWorkspace) {
      Future.microtask(() async {
        try {
          final token = await session.tryGetToken();
          if (token != null && _driveFolderId.isNotEmpty) {
            String raw = company.logo;
            String mime = 'image/png';
            if (raw.contains(';base64,')) {
              final parts = raw.split(';base64,');
              mime = parts.first.replaceFirst('data:', '');
              raw = parts.last;
            }
            final bytes = base64Decode(raw);
            final ext = mime.contains('jpeg') || mime.contains('jpg') ? 'jpg' : 'png';
            final cleanName = company.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
            await _service.uploadImageFile(
              token,
              _driveFolderId,
              '${cleanName.isNotEmpty ? cleanName : "company"}_logo.$ext',
              bytes,
              mimeType: mime,
              subfolder: 'Assets',
            );
          }
        } catch (_) {}
      });
    }

    _scheduleBackgroundSync();
  }

  @override
  Future<Invoice> saveDraft(Invoice invoice) async {
    if (invoice.status != 'draft') throw StateError('Only drafts can be edited.');
    Totals.of(invoice);
    final updated = invoice.copyWith(version: invoice.version + 1);
    await _upsert('Invoices', updated.id, updated.toJson());
    _scheduleBackgroundSync();
    return updated;
  }

  @override
  Future<void> deleteDraft(String invoiceId) async {
    final records = await _sync.loadCachedRecords(_spreadsheetId, 'Invoices');
    final match = records.where((x) => x['id']?.toString() == invoiceId).firstOrNull;
    if (match != null && match['status'] != 'draft') {
      throw StateError('Only draft invoices can be deleted.');
    }
    await _delete('Invoices', invoiceId);
    _scheduleBackgroundSync();
  }

  @override
  Future<Invoice> issue(Invoice invoice) async {
    final allRecords = await _sync.loadCachedRecords(_spreadsheetId, 'Invoices');
    final current = allRecords.where((x) => x['id']?.toString() == invoice.id).firstOrNull;
    final currentInvoice = current != null ? Invoice.fromJson(current) : invoice;
    if (currentInvoice.number.isNotEmpty) return currentInvoice;

    final allInvoices = allRecords.map((x) => Invoice.fromJson(x)).toList();
    final prefix = invoice.company.prefix.isNotEmpty ? invoice.company.prefix : 'INV';
    final year = DateTime.now().year;
    final seq = allInvoices.where((x) => x.number.isNotEmpty).length + 1;
    final generatedNumber = '$prefix-$year-${seq.toString().padLeft(6, '0')}';

    final issued = currentInvoice.copyWith(
      number: generatedNumber,
      status: 'issued',
      issuedAt: DateTime.now().toUtc().toIso8601String(),
      version: currentInvoice.version + 1,
    );
    Totals.of(issued);
    await _upsert('Invoices', issued.id, issued.toJson());
    _scheduleBackgroundSync();
    return issued;
  }

  @override
  Future<Invoice> pay(Invoice invoice, Payment payment) async {
    final records = await _sync.loadCachedRecords(_spreadsheetId, 'Invoices');
    final current = records.where((x) => x['id']?.toString() == invoice.id).firstOrNull;
    final currentInvoice = current != null ? Invoice.fromJson(current) : invoice;

    if (currentInvoice.status != 'issued') throw StateError('Only issued invoices accept payments.');
    if (currentInvoice.payments.any((x) => x.id == payment.id)) return currentInvoice;

    final changed = currentInvoice.copyWith(
      payments: [...currentInvoice.payments, payment],
      version: currentInvoice.version + 1,
    );
    Totals.of(changed);
    await _upsert('Invoices', changed.id, changed.toJson());
    _scheduleBackgroundSync();
    return changed;
  }

  @override
  Future<Invoice> voidInvoice(Invoice invoice) async {
    final records = await _sync.loadCachedRecords(_spreadsheetId, 'Invoices');
    final current = records.where((x) => x['id']?.toString() == invoice.id).firstOrNull;
    final currentInvoice = current != null ? Invoice.fromJson(current) : invoice;

    if (currentInvoice.payments.isNotEmpty) {
      throw StateError('Invoices with payments cannot be voided.');
    }
    final changed = currentInvoice.copyWith(status: 'void', version: currentInvoice.version + 1);
    await _upsert('Invoices', changed.id, changed.toJson());
    _scheduleBackgroundSync();
    return changed;
  }

  @override
  Future<String> archive(Invoice invoice, Uint8List bytes, {String? paymentId}) async {
    if (!_hasCloudWorkspace) {
      throw StateError('Drive archive is available in connected mode.');
    }
    final token = await session.tryGetToken();
    if (token == null) return '';

    final fileName = paymentId != null && paymentId.isNotEmpty
        ? '${invoice.number.isNotEmpty ? invoice.number : invoice.id}_Receipt_$paymentId.pdf'
        : '${invoice.number.isNotEmpty ? invoice.number : invoice.id}.pdf';

    final link = await _service.uploadPdfFile(
      token, _driveFolderId, fileName, bytes, subfolder: 'Invoices',
    );
    if (link.isNotEmpty) {
      final updated = invoice.copyWith(driveUrl: link, archivedVersion: invoice.version);
      await _upsert('Invoices', updated.id, updated.toJson());
    }
    return link;
  }
}
