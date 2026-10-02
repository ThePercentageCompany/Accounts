import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'saas_api.dart';

/// Uses saved server totals, never the legacy local accounting repositories.
Future<Uint8List> sharedRecordPdf(
    SaasApi api, String companyId, String section, String recordId) async {
  const titles = {
    'Invoices': 'Invoice',
    'Quotations': 'Quotation',
    'Receipts': 'Payment receipt',
    'Payroll': 'Payslip',
    'Assets': 'Asset record'
  };
  if (!titles.containsKey(section)) {
    throw const SaasApiException(
        'DOCUMENT_TYPE', 'This record has no PDF template.');
  }
  Future<List<Map<String, dynamic>>> rows(String table) async =>
      ((await api.records(companyId, table))['records'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  Map<String, dynamic> find(List<Map<String, dynamic>> rows, String id) =>
      rows.firstWhere((row) => row['recordId'] == id,
          orElse: () => throw const SaasApiException('RECORD_UNAVAILABLE',
              'A document record is unavailable. Refresh and retry.'));
  final record = find(await rows(section), recordId);
  final profile = find(await rows('CompanyProfile'), 'company');
  Map<String, dynamic>? party;
  if (record['customerId'] != null) {
    party = find(await rows('Customers'), record['customerId']);
  }
  if (section == 'Payroll') {
    final employees = ((await api.employees(companyId))['employees'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    party = find(employees, record['employeeId']);
  }
  final itemTable = section == 'Invoices'
      ? 'InvoiceItems'
      : section == 'Quotations'
          ? 'QuotationItems'
          : null;
  final items = itemTable == null
      ? <Map<String, dynamic>>[]
      : (await rows(itemTable))
          .where((r) =>
              r[section == 'Invoices' ? 'invoiceId' : 'quotationId'] ==
              recordId)
          .toList()
    ..sort(
        (a, b) => (a['lineNumber'] as num).compareTo(b['lineNumber'] as num));
  Uint8List? logo;
  if ('${profile['logoDocumentId'] ?? ''}'.isNotEmpty) {
    logo = await api.document(companyId, profile['logoDocumentId']);
  }
  final latest = find(await rows(section), recordId);
  final latestProfile = find(await rows('CompanyProfile'), 'company');
  if (latest['recordVersion'] != record['recordVersion'] ||
      latestProfile['recordVersion'] != profile['recordVersion']) {
    throw const SaasApiException('VERSION_CONFLICT',
        'The record or company profile changed. Generate the document again.');
  }
  final doc = pw.Document();
  String text(Object? value) {
    final result = '${value ?? ''}';
    // The built-in PDF fonts cannot safely render every script. Fail visibly
    // instead of publishing a document with silently missing glyphs.
    if (result.runes.any((r) => r > 126)) {
      throw const SaasApiException('PDF_FONT_UNSUPPORTED',
          'Automatic PDFs currently support English text. Upload a prepared PDF for other scripts.');
    }
    return result;
  }

  String money(Object? value) =>
      value is num ? value.toStringAsFixed(2) : text(value);
  const labels = {
    'issueDate': 'Issue date',
    'dueDate': 'Due date',
    'validUntil': 'Valid until',
    'paymentDate': 'Payment date',
    'paymentAccount': 'Payment account',
    'reference': 'Reference',
    'month': 'Salary month',
    'paidDate': 'Paid date',
    'assetCode': 'Asset code',
    'name': 'Name',
    'purchaseDate': 'Purchase date',
    'category': 'Category',
    'serialNumber': 'Serial number',
    'location': 'Location',
    'depreciationMethod': 'Depreciation method',
    'usefulLife': 'Useful life (years)',
    'disposalDate': 'Disposal date',
    'voidDate': 'Void date',
    'voidReason': 'Void reason',
    'reversalDate': 'Reversal date',
    'reversalReason': 'Reversal reason'
  };
  const amounts = {
    'subtotal': 'Subtotal',
    'discount': 'Discount',
    'taxAmount': 'Tax',
    'total': 'Total',
    'paidAmount': 'Paid',
    'balance': 'Balance due',
    'amount': 'Received amount',
    'basicSalary': 'Basic salary',
    'allowances': 'Allowances',
    'overtimeAmount': 'Overtime',
    'bonus': 'Bonus',
    'grossSalary': 'Gross salary',
    'deductions': 'Deductions',
    'netSalary': 'Net salary',
    'cost': 'Acquisition cost',
    'residualValue': 'Residual value',
    'accumulatedDepreciation': 'Accumulated depreciation',
    'netBookValue': 'Net book value',
    'disposalProceeds': 'Disposal proceeds'
  };
  doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (context) => pw.Text(
          '${text(profile['name'])} | ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8)),
      build: (context) => [
            if (logo != null)
              pw.Image(pw.MemoryImage(logo),
                  width: 120, height: 60, fit: pw.BoxFit.contain),
            pw.Text(text(profile['name']),
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            for (final key in ['address', 'email', 'phone', 'taxNumber'])
              if (text(profile[key]).isNotEmpty)
                pw.Text(
                    '${key == 'taxNumber' ? 'Tax number: ' : ''}${text(profile[key])}'),
            pw.SizedBox(height: 20),
            pw.Text('${titles[section]} - ${text(record['status'])}',
                style: const pw.TextStyle(fontSize: 18)),
            pw.Text(text(record['number']).isEmpty
                ? 'Record: $recordId'
                : text(record['number'])),
            pw.Text(
                'Currency: ${text(record['currency'] ?? profile['currency'])}'),
            if (party != null) ...[
              pw.SizedBox(height: 12),
              pw.Text(text(party['name'] ?? party['fullName']),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (section != 'Payroll') ...[
                pw.Text(text(party['address'])),
                pw.Text('Tax number: ${text(party['taxNumber'])}'),
              ],
            ],
            pw.SizedBox(height: 12),
            for (final entry in labels.entries)
              if (text(record[entry.key]).isNotEmpty)
                pw.Text('${entry.value}: ${text(record[entry.key])}'),
            if (items.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                  headers: [
                    'Description',
                    'Qty',
                    'Unit price',
                    'Discount',
                    'Tax',
                    'Total'
                  ],
                  data: [
                    for (final item in items)
                      [
                        text(item['description']),
                        text(item['quantity']),
                        money(item['unitPrice']),
                        money(item['discount']),
                        money(item['taxAmount']),
                        money(item['lineTotal'])
                      ]
                  ],
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerStyle: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ],
            pw.SizedBox(height: 16),
            for (final entry in amounts.entries)
              if (record[entry.key] != null &&
                  text(record[entry.key]).isNotEmpty)
                pw.Text('${entry.value}: ${money(record[entry.key])}'),
            for (final key in ['notes', 'paymentTerms'])
              if (text(record[key]).isNotEmpty)
                pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 12),
                    child: pw.Text(text(record[key]))),
            if (['Invoices', 'Quotations'].contains(section)) ...[
              pw.SizedBox(height: 16),
              for (final key in [
                'bankName',
                'accountHolder',
                'accountNumber',
                'iban',
                'swift'
              ])
                if (text(profile[key]).isNotEmpty)
                  pw.Text('$key: ${text(profile[key])}'),
            ],
            pw.SizedBox(height: 16),
            pw.Text(
                'Saved record version ${record['recordVersion']}. Generated ${DateTime.now().toUtc().toIso8601String()}.',
                style: const pw.TextStyle(fontSize: 8)),
          ]));
  return doc.save();
}
