import '../../../core/auth/google_session.dart';
import '../../../core/auth/google_workspace_service.dart';
import '../../../core/sync/sync_manager.dart';
import '../domain/quotation.dart';
import '../domain/quotation_repository.dart';

class GoogleDirectQuotationRepository implements QuotationRepository {
  final GoogleSession session;
  final GoogleWorkspaceService _service = GoogleWorkspaceService();
  final SyncManager _sync = SyncManager.instance;

  GoogleDirectQuotationRepository(this.session);

  @override
  bool get isDemo => false;

  String get _spreadsheetId {
    final id = session.workspace?.spreadsheetId;
    if (id == null || id.isEmpty) {
      throw StateError('No Google Spreadsheet linked. Complete onboarding first.');
    }
    return id;
  }

  @override
  Future<List<Quotation>> load() async {
    final cached = await _sync.loadCachedRecords(_spreadsheetId, 'Quotations');
    List<Quotation> list = cached.map((x) => Quotation.fromJson(x)).toList();

    final token = await session.tryGetToken();
    if (token != null) {
      try {
        final raw = await _service.readTabRecords(token, _spreadsheetId, 'Quotations');
        if (raw.isNotEmpty || cached.isEmpty) {
          await _sync.saveCachedRecords(_spreadsheetId, 'Quotations', raw);
          list = raw.map((x) => Quotation.fromJson(x)).toList();
        }
        await _sync.syncPendingChanges(token: token, spreadsheetId: _spreadsheetId);
        _sync.markSynced();
      } catch (_) {
        _sync.markOffline();
      }
    } else {
      _sync.markOffline();
    }

    return list;
  }

  @override
  Future<Quotation> save(Quotation quotation) async {
    QuotationTotals.of(quotation);
    final updated = quotation.copyWith(version: quotation.version + 1);
    await _sync.upsertCachedRecord(_spreadsheetId, 'Quotations', updated.id, updated.toJson());

    final token = await session.tryGetToken();
    if (token != null) {
      try {
        await _service.upsertTabRecord(token, _spreadsheetId, 'Quotations', updated.id, updated.toJson());
        _sync.markSynced();
        return updated;
      } catch (_) {}
    }

    await _sync.enqueueOperation(
      spreadsheetId: _spreadsheetId,
      tabName: 'Quotations',
      recordId: updated.id,
      action: 'upsert',
      data: updated.toJson(),
    );
    return updated;
  }

  @override
  Future<Quotation> issue(Quotation quotation) async {
    final all = await load();
    final current = all.where((x) => x.id == quotation.id).firstOrNull ?? quotation;
    if (current.number.isNotEmpty) return current;

    final prefix = quotation.company.prefix.isNotEmpty ? quotation.company.prefix : 'TPC';
    final year = DateTime.now().year;
    final seq = all.where((x) => x.number.isNotEmpty).length + 1;
    final generatedNumber = 'QT-$prefix-$year-${seq.toString().padLeft(6, '0')}';

    final issued = current.copyWith(
      number: generatedNumber,
      status: current.status == 'draft' ? 'sent' : current.status,
      issuedAt: DateTime.now().toUtc().toIso8601String(),
      version: current.version + 1,
    );

    QuotationTotals.of(issued);
    await _sync.upsertCachedRecord(_spreadsheetId, 'Quotations', issued.id, issued.toJson());

    final token = await session.tryGetToken();
    if (token != null) {
      try {
        await _service.upsertTabRecord(token, _spreadsheetId, 'Quotations', issued.id, issued.toJson());
        _sync.markSynced();
        return issued;
      } catch (_) {}
    }

    await _sync.enqueueOperation(
      spreadsheetId: _spreadsheetId,
      tabName: 'Quotations',
      recordId: issued.id,
      action: 'upsert',
      data: issued.toJson(),
    );
    return issued;
  }

  @override
  Future<Quotation> updateStatus(String quotationId, String newStatus) async {
    final all = await load();
    final current = all.where((x) => x.id == quotationId).firstOrNull;
    if (current == null) throw StateError('Quotation not found.');

    final updated = current.copyWith(
      status: newStatus,
      version: current.version + 1,
    );
    await _sync.upsertCachedRecord(_spreadsheetId, 'Quotations', updated.id, updated.toJson());

    final token = await session.tryGetToken();
    if (token != null) {
      try {
        await _service.upsertTabRecord(token, _spreadsheetId, 'Quotations', updated.id, updated.toJson());
        _sync.markSynced();
        return updated;
      } catch (_) {}
    }

    await _sync.enqueueOperation(
      spreadsheetId: _spreadsheetId,
      tabName: 'Quotations',
      recordId: updated.id,
      action: 'upsert',
      data: updated.toJson(),
    );
    return updated;
  }

  @override
  Future<void> delete(String quotationId) async {
    await _sync.deleteCachedRecord(_spreadsheetId, 'Quotations', quotationId);

    final token = await session.tryGetToken();
    if (token != null) {
      try {
        await _service.deleteTabRecord(token, _spreadsheetId, 'Quotations', quotationId);
        _sync.markSynced();
        return;
      } catch (_) {}
    }

    await _sync.enqueueOperation(
      spreadsheetId: _spreadsheetId,
      tabName: 'Quotations',
      recordId: quotationId,
      action: 'delete',
    );
  }
}
