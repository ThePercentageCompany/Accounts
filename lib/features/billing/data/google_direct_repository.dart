import 'dart:convert';
import 'dart:typed_data';
import '../../../core/auth/google_session.dart';
import '../../../core/auth/google_workspace_service.dart';
import '../../../core/sync/sync_manager.dart';
import '../domain/billing_repository.dart';
import '../domain/models.dart';
import '../domain/totals.dart';

class GoogleDirectBillingRepository implements BillingRepository {
  final GoogleSession session;
  final GoogleWorkspaceService _service = GoogleWorkspaceService();
  final SyncManager _sync = SyncManager.instance;

  GoogleDirectBillingRepository(this.session);

  @override
  bool get isDemo => false;

  String get _spreadsheetId {
    final id = session.workspace?.spreadsheetId;
    if (id == null || id.isEmpty) {
      throw StateError('No Google Spreadsheet linked. Complete onboarding first.');
    }
    return id;
  }

  String get _driveFolderId => session.workspace?.driveFolderId ?? '';

  void _scheduleBackgroundSync() {
    Future.microtask(() async {
      try {
        final token = await session.tryGetToken();
        if (token != null) {
          await _sync.triggerBackgroundSync(token: token, spreadsheetId: _spreadsheetId);
        }
      } catch (_) {}
    });
  }

  @override
  Future<BillingData> load() async {
    final spreadsheetId = _spreadsheetId;

    // 1. Read cached data first for INSTANT (0ms) UI response
    final cachedCustomers = await _sync.loadCachedRecords(spreadsheetId, 'Customers');
    final cachedInvoices = await _sync.loadCachedRecords(spreadsheetId, 'Invoices');
    final cachedSettings = await _sync.loadCachedRecords(spreadsheetId, 'Settings');

    Company company = const Company();
    for (final s in cachedSettings) {
      if (s['id'] == 'company') {
        final val = s['value'] ?? s;
        if (val is Map) {
          company = Company.fromJson(Map<String, dynamic>.from(val));
        }
      }
    }
    if (company.name.isEmpty && session.workspace?.companyName != null && session.workspace!.companyName.isNotEmpty) {
      company = company.copyWith(name: session.workspace!.companyName);
    }

    final localData = BillingData(
      customers: cachedCustomers.map((x) => Customer.fromJson(x)).toList(),
      invoices: cachedInvoices.map((x) => Invoice.fromJson(x)).toList(),
      company: company,
    );

    // 2. Schedule non-blocking background sync
    _scheduleBackgroundSync();

    return localData;
  }

  @override
  Future<void> saveCustomer(Customer customer) async {
    final updated = customer.copyWith(version: customer.version + 1);
    await _sync.upsertCachedRecord(_spreadsheetId, 'Customers', updated.id, updated.toJson());
    await _sync.enqueueOperation(
      spreadsheetId: _spreadsheetId,
      tabName: 'Customers',
      recordId: updated.id,
      action: 'upsert',
      data: updated.toJson(),
    );
    _scheduleBackgroundSync();
  }

  @override
  Future<void> deleteCustomer(String customerId) async {
    await _sync.deleteCachedRecord(_spreadsheetId, 'Customers', customerId);
    await _sync.enqueueOperation(
      spreadsheetId: _spreadsheetId,
      tabName: 'Customers',
      recordId: customerId,
      action: 'delete',
    );
    _scheduleBackgroundSync();
  }

  @override
  Future<void> saveCompany(Company company) async {
    final updated = company.copyWith(version: company.version + 1);
    final payload = {'id': 'company', 'value': updated.toJson()};
    await _sync.upsertCachedRecord(_spreadsheetId, 'Settings', 'company', payload);
    await _sync.enqueueOperation(
      spreadsheetId: _spreadsheetId,
      tabName: 'Settings',
      recordId: 'company',
      action: 'upsert',
      data: payload,
    );
    if (session.workspace != null && company.name.isNotEmpty && session.workspace!.companyName != company.name) {
      final updatedWs = WorkspaceConfig(
        spreadsheetId: session.workspace!.spreadsheetId,
        spreadsheetUrl: session.workspace!.spreadsheetUrl,
        driveFolderId: session.workspace!.driveFolderId,
        folderUrl: session.workspace!.folderUrl,
        companyName: company.name,
      );
      await session.setWorkspace(updatedWs);
    }

    // Archive company logo into Assets/ subfolder in Drive in background
    if (company.logo.isNotEmpty) {
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
    await _sync.upsertCachedRecord(_spreadsheetId, 'Invoices', updated.id, updated.toJson());
    await _sync.enqueueOperation(
      spreadsheetId: _spreadsheetId,
      tabName: 'Invoices',
      recordId: updated.id,
      action: 'upsert',
      data: updated.toJson(),
    );
    _scheduleBackgroundSync();
    return updated;
  }

  @override
  Future<void> deleteDraft(String invoiceId) async {
    final current = await _findInvoice(invoiceId);
    if (current != null && current.status != 'draft') {
      throw StateError('Only draft invoices can be deleted.');
    }
    await _sync.deleteCachedRecord(_spreadsheetId, 'Invoices', invoiceId);
    await _sync.enqueueOperation(
      spreadsheetId: _spreadsheetId,
      tabName: 'Invoices',
      recordId: invoiceId,
      action: 'delete',
    );
    _scheduleBackgroundSync();
  }

  @override
  Future<Invoice> issue(Invoice invoice) async {
    final current = await _findInvoice(invoice.id) ?? invoice;
    if (current.number.isNotEmpty) return current;

    // Generate sequential invoice number from cached/remote list
    final allRecords = await _sync.loadCachedRecords(_spreadsheetId, 'Invoices');
    final allInvoices = allRecords.map((x) => Invoice.fromJson(x)).toList();

    final prefix = invoice.company.prefix.isNotEmpty ? invoice.company.prefix : 'INV';
    final year = DateTime.now().year;
    final seq = allInvoices.where((x) => x.number.isNotEmpty).length + 1;
    final generatedNumber = '$prefix-$year-${seq.toString().padLeft(6, '0')}';

    final issued = current.copyWith(
      number: generatedNumber,
      status: 'issued',
      issuedAt: DateTime.now().toUtc().toIso8601String(),
      version: current.version + 1,
    );

    Totals.of(issued);
    await _sync.upsertCachedRecord(_spreadsheetId, 'Invoices', issued.id, issued.toJson());
    await _sync.enqueueOperation(
      spreadsheetId: _spreadsheetId,
      tabName: 'Invoices',
      recordId: issued.id,
      action: 'upsert',
      data: issued.toJson(),
    );
    _scheduleBackgroundSync();
    return issued;
  }

  @override
  Future<Invoice> pay(Invoice invoice, Payment payment) async {
    final current = await _findInvoice(invoice.id) ?? invoice;
    if (current.status != 'issued') throw StateError('Only issued invoices accept payments.');
    if (current.payments.any((x) => x.id == payment.id)) return current;

    final changed = current.copyWith(
      payments: [...current.payments, payment],
      version: current.version + 1,
    );
    Totals.of(changed);

    await _sync.upsertCachedRecord(_spreadsheetId, 'Invoices', changed.id, changed.toJson());
    await _sync.enqueueOperation(
      spreadsheetId: _spreadsheetId,
      tabName: 'Invoices',
      recordId: changed.id,
      action: 'upsert',
      data: changed.toJson(),
    );
    _scheduleBackgroundSync();
    return changed;
  }

  @override
  Future<Invoice> voidInvoice(Invoice invoice) async {
    final current = await _findInvoice(invoice.id) ?? invoice;
    if (current.payments.isNotEmpty) throw StateError('Invoices with payments cannot be voided.');

    final changed = current.copyWith(
      status: 'void',
      version: current.version + 1,
    );
    await _sync.upsertCachedRecord(_spreadsheetId, 'Invoices', changed.id, changed.toJson());
    await _sync.enqueueOperation(
      spreadsheetId: _spreadsheetId,
      tabName: 'Invoices',
      recordId: changed.id,
      action: 'upsert',
      data: changed.toJson(),
    );
    _scheduleBackgroundSync();
    return changed;
  }

  @override
  Future<String> archive(Invoice invoice, Uint8List bytes, {String? paymentId}) async {
    final token = await session.tryGetToken();
    if (token == null) {
      return ''; // Saved locally, Drive upload requires active connection
    }
    final String fileName;
    if (paymentId != null && paymentId.isNotEmpty) {
      fileName = '${invoice.number.isNotEmpty ? invoice.number : invoice.id}_Receipt_$paymentId.pdf';
    } else {
      fileName = '${invoice.number.isNotEmpty ? invoice.number : invoice.id}.pdf';
    }
    final link = await _service.uploadPdfFile(token, _driveFolderId, fileName, bytes, subfolder: 'Invoices');

    if (link.isNotEmpty) {
      final updated = invoice.copyWith(
        driveUrl: link,
        archivedVersion: invoice.version,
      );
      await _sync.upsertCachedRecord(_spreadsheetId, 'Invoices', updated.id, updated.toJson());
      try {
        await _service.upsertTabRecord(token, _spreadsheetId, 'Invoices', updated.id, updated.toJson());
      } catch (_) {}
    }
    return link;
  }

  Future<Invoice?> _findInvoice(String id) async {
    final records = await _sync.loadCachedRecords(_spreadsheetId, 'Invoices');
    final match = records.where((x) => x['id']?.toString() == id);
    if (match.isEmpty) return null;
    return Invoice.fromJson(match.first);
  }
}
