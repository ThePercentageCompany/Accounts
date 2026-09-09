import 'dart:typed_data';
import '../../../core/auth/google_session.dart';
import '../../../core/auth/google_workspace_service.dart';
import '../domain/billing_repository.dart';
import '../domain/models.dart';
import '../domain/totals.dart';

class GoogleDirectBillingRepository implements BillingRepository {
  final GoogleSession session;
  final GoogleWorkspaceService _service = GoogleWorkspaceService();

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

  @override
  Future<BillingData> load() async {
    final token = await session.token();
    final spreadsheetId = _spreadsheetId;

    // 1. Customers
    final rawCustomers = await _service.readTabRecords(token, spreadsheetId, 'Customers');
    final customers = rawCustomers.map((x) => Customer.fromJson(x)).toList();

    // 2. Invoices
    final rawInvoices = await _service.readTabRecords(token, spreadsheetId, 'Invoices');
    final invoices = rawInvoices.map((x) => Invoice.fromJson(x)).toList();

    // 3. Company Settings
    final rawSettings = await _service.readTabRecords(token, spreadsheetId, 'Settings');
    Company company = const Company();
    for (final s in rawSettings) {
      if (s['id'] == 'company') {
        final val = s['value'] ?? s;
        if (val is Map) {
          company = Company.fromJson(Map<String, dynamic>.from(val));
        }
      }
    }

    return BillingData(
      customers: customers,
      invoices: invoices,
      company: company,
    );
  }

  @override
  Future<void> saveCustomer(Customer customer) async {
    final token = await session.token();
    final updated = customer.copyWith(version: customer.version + 1);
    await _service.upsertTabRecord(token, _spreadsheetId, 'Customers', updated.id, updated.toJson());
  }

  @override
  Future<void> saveCompany(Company company) async {
    final token = await session.token();
    final updated = company.copyWith(version: company.version + 1);
    await _service.upsertTabRecord(
      token,
      _spreadsheetId,
      'Settings',
      'company',
      {'id': 'company', 'value': updated.toJson()},
    );
  }

  @override
  Future<Invoice> saveDraft(Invoice invoice) async {
    if (invoice.status != 'draft') throw StateError('Only drafts can be edited.');
    Totals.of(invoice);
    final updated = invoice.copyWith(version: invoice.version + 1);
    final token = await session.token();
    await _service.upsertTabRecord(token, _spreadsheetId, 'Invoices', updated.id, updated.toJson());
    return updated;
  }

  @override
  Future<Invoice> issue(Invoice invoice) async {
    final token = await session.token();
    final current = await _findInvoice(token, invoice.id) ?? invoice;
    if (current.number.isNotEmpty) return current;

    // Generate sequential invoice number
    final allInvoices = (await _service.readTabRecords(token, _spreadsheetId, 'Invoices'))
        .map((x) => Invoice.fromJson(x))
        .toList();

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
    await _service.upsertTabRecord(token, _spreadsheetId, 'Invoices', issued.id, issued.toJson());
    return issued;
  }

  @override
  Future<Invoice> pay(Invoice invoice, Payment payment) async {
    final token = await session.token();
    final current = await _findInvoice(token, invoice.id) ?? invoice;
    if (current.status != 'issued') throw StateError('Only issued invoices accept payments.');
    if (current.payments.any((x) => x.id == payment.id)) return current;

    final changed = current.copyWith(
      payments: [...current.payments, payment],
      version: current.version + 1,
    );
    Totals.of(changed);

    await _service.upsertTabRecord(token, _spreadsheetId, 'Invoices', changed.id, changed.toJson());
    return changed;
  }

  @override
  Future<Invoice> voidInvoice(Invoice invoice) async {
    final token = await session.token();
    final current = await _findInvoice(token, invoice.id) ?? invoice;
    if (current.payments.isNotEmpty) throw StateError('Invoices with payments cannot be voided.');

    final changed = current.copyWith(
      status: 'void',
      version: current.version + 1,
    );
    await _service.upsertTabRecord(token, _spreadsheetId, 'Invoices', changed.id, changed.toJson());
    return changed;
  }

  @override
  Future<String> archive(Invoice invoice, Uint8List bytes, {String? paymentId}) async {
    final token = await session.token();
    final fileName = '${invoice.number.isNotEmpty ? invoice.number : invoice.id}.pdf';
    final link = await _service.uploadPdfFile(token, _driveFolderId, fileName, bytes);

    if (link.isNotEmpty) {
      final updated = invoice.copyWith(
        driveUrl: link,
        archivedVersion: invoice.version,
      );
      await _service.upsertTabRecord(token, _spreadsheetId, 'Invoices', updated.id, updated.toJson());
    }
    return link;
  }

  Future<Invoice?> _findInvoice(String token, String id) async {
    final records = await _service.readTabRecords(token, _spreadsheetId, 'Invoices');
    final match = records.where((x) => x['id']?.toString() == id);
    if (match.isEmpty) return null;
    return Invoice.fromJson(match.first);
  }
}
