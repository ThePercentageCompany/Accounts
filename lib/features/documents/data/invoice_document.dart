import 'dart:typed_data';
import 'package:invoice_kit/invoice_kit.dart' as kit;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum DocumentStyle { modern, classic }

/// Mirrors the service's minor-unit, per-line rounding. These are preview
/// estimates only; saved exports always use the service's saved totals.
Map<String, num> estimateDocument(List<Map<String, dynamic>> items) {
  BigInt minor(Object? value) {
    final amount = num.tryParse('$value') ?? 0;
    if (!amount.isFinite || amount.abs() > 1e12) return BigInt.zero;
    return BigInt.parse(amount.toStringAsFixed(2).replaceAll('.', ''));
  }

  final hundred = BigInt.from(100), half = BigInt.from(50);
  var gross = BigInt.zero, discount = BigInt.zero, tax = BigInt.zero;
  for (final item in items) {
    final lineGross =
        (minor(item['quantity']) * minor(item['unitPrice']) + half) ~/ hundred;
    final lineDiscount = minor(item['discount']);
    final net = lineGross - lineDiscount;
    gross += lineGross;
    discount += lineDiscount;
    tax +=
        (net * minor(item['taxRate']) + BigInt.from(5000)) ~/
        BigInt.from(10000);
  }
  num money(BigInt value) => value.toDouble() / 100;
  return {
    'subtotal': money(gross),
    'discount': money(discount),
    'taxAmount': money(tax),
    'total': money(gross - discount + tax),
  };
}

kit.InvoiceData documentData({
  required bool quotation,
  required Map<String, dynamic> record,
  required Map<String, dynamic> company,
  required Map<String, dynamic> customer,
  required List<Map<String, dynamic>> items,
  bool estimate = false,
  bool creditNote = false,
}) => kit.InvoiceData({
  'title': creditNote
      ? 'CREDIT NOTE'
      : quotation
      ? 'QUOTATION'
      : 'INVOICE',
  'record': record,
  'seller': company,
  'buyer': customer,
  'items': items,
  'totals': estimate ? estimateDocument(items) : record,
  'estimate': estimate,
});

/// invoice_kit custom template: company branding, UAE VAT labels, quotation
/// validity and authoritative totals without the package's GST assumptions.
class BusinessDocumentTemplate extends kit.InvoiceTemplate {
  BusinessDocumentTemplate({this.style = DocumentStyle.modern, this.logo});
  final DocumentStyle style;
  final Uint8List? logo;
  @override
  String get id => 'tpc_${style.name}';
  @override
  String get name => style == DocumentStyle.modern ? 'Modern' : 'Classic';
  @override
  String get description =>
      'Branded invoice or quotation with VAT and bank details';
  @override
  PdfPageFormat get pageFormat => PdfPageFormat.a4;

  @override
  Future<pw.Document> build(
    kit.InvoiceData data, {
    kit.TemplateConfig? config,
  }) async {
    final seller = Map<String, dynamic>.from(data.get('seller') as Map);
    final buyer = Map<String, dynamic>.from(data.get('buyer') as Map);
    final record = Map<String, dynamic>.from(data.get('record') as Map);
    final totals = Map<String, dynamic>.from(data.get('totals') as Map);
    final items = (data.get('items') as List).cast<Map<String, dynamic>>();
    String text(Object? value) => '${value ?? ''}';
    String money(Object? value) =>
        (num.tryParse('$value') ?? 0).toStringAsFixed(2);
    final currency = text(record['currency']).isEmpty
        ? 'AED'
        : text(record['currency']);
    final unicode = data.toMap().toString().runes.any((rune) => rune > 126);
    final fonts = unicode ? await kit.FontLoader.autoLoad(data) : null;
    final regular = config?.baseFont ?? fonts?.regular ?? pw.Font.helvetica();
    final bold = config?.boldFont ?? fonts?.bold ?? pw.Font.helveticaBold();
    final color = style == DocumentStyle.modern
        ? PdfColor.fromHex('#155E75')
        : PdfColors.black;
    final doc = pw.Document(
      compress: config?.extras['compress'] != false,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    pw.Widget detail(String label, Object? value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        '$label: ${text(value)}',
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
    pw.Widget party(Map<String, dynamic> values, String label) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          text(values['name']),
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        for (final key in ['address', 'email', 'phone'])
          if (text(values[key]).isNotEmpty)
            pw.Text(text(values[key]), style: const pw.TextStyle(fontSize: 9)),
        if (text(values['taxNumber']).isNotEmpty)
          detail('Tax number / TRN', values['taxNumber']),
      ],
    );
    final draft =
        data.get('estimate') == true || text(record['status']) == 'DRAFT';
    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              draft
                  ? 'DRAFT - ${data.get('estimate') == true ? 'Unsaved estimate' : 'Not issued'}'
                  : 'Saved record version ${record['recordVersion']}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.Image(
                  pw.MemoryImage(logo!),
                  width: 110,
                  height: 54,
                  fit: pw.BoxFit.contain,
                )
              else
                pw.Expanded(
                  child: pw.Text(
                    text(seller['name']),
                    style: pw.TextStyle(
                      fontSize: 20,
                      color: color,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    text(data.get('title')),
                    style: pw.TextStyle(
                      fontSize: 24,
                      color: color,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    text(record['number']).isEmpty
                        ? 'DRAFT'
                        : text(record['number']),
                  ),
                  if (text(record['status']).isNotEmpty)
                    pw.Text(
                      text(record['status']),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Divider(color: color),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: party(seller, 'FROM')),
              pw.SizedBox(width: 28),
              pw.Expanded(child: party(buyer, 'BILL TO')),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Wrap(
            spacing: 24,
            children: [
              detail('Issue date', record['issueDate']),
              if (text(record['dueDate']).isNotEmpty)
                detail('Due date', record['dueDate']),
              if (text(record['validUntil']).isNotEmpty)
                detail('Valid until', record['validUntil']),
              detail('Currency', currency),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: [
              '#',
              'Description',
              'Qty',
              'Rate',
              'Discount',
              'VAT %',
              'Amount',
            ],
            headerDecoration: pw.BoxDecoration(color: color),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.all(6),
            columnWidths: {
              0: const pw.FixedColumnWidth(18),
              1: const pw.FlexColumnWidth(3),
            },
            data: [
              for (var i = 0; i < items.length; i++)
                [
                  '${i + 1}',
                  text(items[i]['description']),
                  text(items[i]['quantity']),
                  money(items[i]['unitPrice']),
                  money(items[i]['discount']),
                  text(items[i]['taxRate']),
                  money(
                    items[i]['lineTotal'] ??
                        estimateDocument([items[i]])['total'],
                  ),
                ],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  for (final entry in {
                    'subtotal': 'Subtotal',
                    'discount': 'Discount',
                    'taxAmount': 'VAT',
                    'total': 'Total',
                    if (data.get('title') == 'INVOICE' && !draft)
                      'paidAmount': 'Paid',
                    if (data.get('title') == 'INVOICE' && !draft)
                      'balance': 'Balance due',
                  }.entries)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            entry.value,
                            style: pw.TextStyle(
                              fontWeight: entry.key == 'total'
                                  ? pw.FontWeight.bold
                                  : pw.FontWeight.normal,
                            ),
                          ),
                          pw.Text(
                            '$currency ${money(totals[entry.key])}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          for (final entry in {
            'notes': 'Notes',
            'paymentTerms': 'Terms & conditions',
          }.entries)
            if (text(record[entry.key]).isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                entry.value,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                text(record[entry.key]),
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          pw.SizedBox(height: 18),
          for (final entry in {
            'bankName': 'Bank',
            'accountHolder': 'Account holder',
            'accountNumber': 'Account number',
            'iban': 'IBAN',
            'swift': 'SWIFT',
          }.entries)
            if (text(seller[entry.key]).isNotEmpty)
              detail(entry.value, seller[entry.key]),
        ],
      ),
    );
    return doc;
  }
}
