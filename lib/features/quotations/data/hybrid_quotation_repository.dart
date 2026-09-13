import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/google_session.dart';
import '../../../core/auth/google_workspace_service.dart';
import '../../../core/sync/sync_manager.dart';
import '../../billing/domain/models.dart';
import '../domain/quotation.dart';
import '../domain/quotation_repository.dart';

/// Unified offline-first + auto-cloud-sync quotation repository.
///
/// Replaces both [LocalQuotationRepository] and [GoogleDirectQuotationRepository].
class HybridQuotationRepository implements QuotationRepository {
  final GoogleSession session;
  final GoogleWorkspaceService _service = GoogleWorkspaceService();
  final SyncManager _sync = SyncManager.instance;

  HybridQuotationRepository(this.session);

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

  Future<void> _upsert(String id, Map<String, dynamic> data) async {
    await _sync.upsertCachedRecord(_spreadsheetId, 'Quotations', id, data);
    if (_hasCloudWorkspace) {
      await _sync.enqueueOperation(
        spreadsheetId: _spreadsheetId,
        tabName: 'Quotations',
        recordId: id,
        action: 'upsert',
        data: data,
      );
    }
  }

  Future<void> _delete(String id) async {
    await _sync.deleteCachedRecord(_spreadsheetId, 'Quotations', id);
    if (_hasCloudWorkspace) {
      await _sync.enqueueOperation(
        spreadsheetId: _spreadsheetId,
        tabName: 'Quotations',
        recordId: id,
        action: 'delete',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // QuotationRepository interface
  // ---------------------------------------------------------------------------

  @override
  Future<List<Quotation>> load() async {
    final sid = _spreadsheetId;
    var cached = await _sync.loadCachedRecords(sid, 'Quotations');

    // Cold start: seed cache from legacy local storage key
    if (cached.isEmpty) {
      await _seedCacheFromLocalStorage(sid);
      cached = await _sync.loadCachedRecords(sid, 'Quotations');
    }

    _scheduleBackgroundSync();
    return cached.map((x) => Quotation.fromJson(x)).toList();
  }

  Future<void> _seedCacheFromLocalStorage(String spreadsheetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('tpc_quotations_v1');
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      if (list.isNotEmpty) {
        await _sync.saveCachedRecords(spreadsheetId, 'Quotations', list);
      }
    } catch (_) {}
  }

  @override
  Future<Quotation> save(Quotation quotation) async {
    // Sanitize line items & numbers to prevent calculation errors
    final sanitized = _sanitize(quotation);
    QuotationTotals.of(sanitized);
    final updated = sanitized.copyWith(version: sanitized.version + 1);
    await _upsert(updated.id, updated.toJson());
    _scheduleBackgroundSync();
    return updated;
  }

  @override
  Future<Quotation> issue(Quotation quotation) async {
    final all = await load();
    final sanitized = _sanitize(quotation);

    // Determine sequential number if this is a draft or placeholder number
    String num = sanitized.number;
    final isOfficial = num.isNotEmpty && !num.endsWith('-001') && sanitized.status != 'draft';

    if (!isOfficial) {
      final prefix = sanitized.company.prefix.isNotEmpty ? sanitized.company.prefix : 'TPC';
      final year = DateTime.now().year;
      final seq = all.where((x) => x.number.isNotEmpty && x.status != 'draft').length + 1;
      num = 'QT-$prefix-$year-${seq.toString().padLeft(6, '0')}';
    }

    final issued = sanitized.copyWith(
      number: num,
      status: sanitized.status == 'draft' ? 'sent' : sanitized.status,
      issuedAt: sanitized.issuedAt.isNotEmpty ? sanitized.issuedAt : DateTime.now().toUtc().toIso8601String(),
      version: sanitized.version + 1,
    );
    QuotationTotals.of(issued);
    await _upsert(issued.id, issued.toJson());
    _scheduleBackgroundSync();
    return issued;
  }

  Quotation _sanitize(Quotation q) {
    String cleanNum(String? val, {int decimals = 2, String fallback = '0.00'}) {
      if (val == null || val.trim().isEmpty) return fallback;
      final c = val.replaceAll(',', '').replaceAll('%', '').trim();
      final d = double.tryParse(c);
      if (d == null || d.isNaN || d.isInfinite || d < 0) return fallback;
      return d.toStringAsFixed(decimals);
    }

    final cleanItems = q.items.map((item) {
      final desc = item.description.trim().isNotEmpty ? item.description.trim() : 'Service item';
      final qty = cleanNum(item.quantity, decimals: 3, fallback: '1.000');
      final rate = cleanNum(item.rate, decimals: 2, fallback: '0.00');
      return item.copyWith(description: desc, quantity: qty, rate: rate);
    }).toList();

    return q.copyWith(
      items: cleanItems.isEmpty ? [const LineItem(description: 'Service item', quantity: '1.000', rate: '0.00')] : cleanItems,
      discount: cleanNum(q.discount, decimals: 2, fallback: '0.00'),
      taxRate: cleanNum(q.taxRate, decimals: 2, fallback: '5.00'),
    );
  }

  @override
  Future<Quotation> updateStatus(String quotationId, String newStatus) async {
    final cached = await _sync.loadCachedRecords(_spreadsheetId, 'Quotations');
    final match = cached.where((x) => x['id']?.toString() == quotationId).firstOrNull;
    if (match == null) throw StateError('Quotation not found.');
    final current = Quotation.fromJson(match);
    final updated = current.copyWith(status: newStatus, version: current.version + 1);
    await _upsert(updated.id, updated.toJson());
    _scheduleBackgroundSync();
    return updated;
  }

  @override
  Future<void> delete(String quotationId) async {
    await _delete(quotationId);
    _scheduleBackgroundSync();
  }

  @override
  Future<String> archive(Quotation quotation, Uint8List bytes) async {
    if (!_hasCloudWorkspace) {
      throw StateError('Drive archive is available in connected mode.');
    }
    final token = await session.tryGetToken();
    if (token == null) return '';

    final fileName = '${quotation.number.isNotEmpty ? quotation.number : quotation.id}.pdf';
    final link = await _service.uploadPdfFile(
      token, _driveFolderId, fileName, bytes, subfolder: 'Quotations',
    );
    if (link.isNotEmpty) {
      final updated = quotation.copyWith(driveUrl: link);
      await _upsert(updated.id, updated.toJson());
    }
    return link;
  }
}
