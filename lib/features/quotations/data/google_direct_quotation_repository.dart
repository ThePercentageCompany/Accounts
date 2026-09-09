import '../../../core/auth/google_session.dart';
import '../../../core/auth/google_workspace_service.dart';
import '../domain/quotation.dart';
import '../domain/quotation_repository.dart';

class GoogleDirectQuotationRepository implements QuotationRepository {
  final GoogleSession session;
  final GoogleWorkspaceService _service = GoogleWorkspaceService();

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
    final token = await session.token();
    final raw = await _service.readTabRecords(token, _spreadsheetId, 'Quotations');
    return raw.map((x) => Quotation.fromJson(x)).toList();
  }

  @override
  Future<Quotation> save(Quotation quotation) async {
    QuotationTotals.of(quotation);
    final updated = quotation.copyWith(version: quotation.version + 1);
    final token = await session.token();
    await _service.upsertTabRecord(token, _spreadsheetId, 'Quotations', updated.id, updated.toJson());
    return updated;
  }

  @override
  Future<Quotation> issue(Quotation quotation) async {
    final token = await session.token();
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
    await _service.upsertTabRecord(token, _spreadsheetId, 'Quotations', issued.id, issued.toJson());
    return issued;
  }

  @override
  Future<Quotation> updateStatus(String quotationId, String newStatus) async {
    final token = await session.token();
    final all = await load();
    final current = all.where((x) => x.id == quotationId).firstOrNull;
    if (current == null) throw StateError('Quotation not found.');

    final updated = current.copyWith(
      status: newStatus,
      version: current.version + 1,
    );
    await _service.upsertTabRecord(token, _spreadsheetId, 'Quotations', updated.id, updated.toJson());
    return updated;
  }

  @override
  Future<void> delete(String quotationId) async {
    final token = await session.token();
    await _service.deleteTabRecord(token, _spreadsheetId, 'Quotations', quotationId);
  }
}
