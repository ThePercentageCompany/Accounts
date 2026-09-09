import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../billing/domain/totals.dart';
import '../domain/quotation.dart';
import '../domain/quotation_document_service.dart';

class PdfQuotationDocumentService implements QuotationDocumentService {
  @override
  Future<Uint8List> render(Quotation q) async {
    final doc = pw.Document();
    final t = QuotationTotals.of(q);
    final c = q.company;

    pw.Widget text(String v, {bool bold = false, double size = 10, PdfColor? color}) =>
        pw.Text(v,
            style: pw.TextStyle(
              fontSize: size,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ));

    pw.Widget summary(String label, int value, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              text(label, bold: bold, size: 9.5),
              text(money(value), bold: bold, size: 9.5),
            ],
          ),
        );

    final logo = c.logo.isEmpty ? null : pw.MemoryImage(base64Decode(c.logo));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(38),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                text(c.name, size: 8, color: PdfColors.grey700),
                text('${context.pageNumber} / ${context.pagesCount}', size: 8, color: PdfColors.grey700),
              ],
            ),
          ],
        ),
        build: (context) => [
          // Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logo != null)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 12),
                        child: pw.Image(logo, width: 110, height: 52, fit: pw.BoxFit.contain),
                      ),
                    text(c.name, bold: true, size: 12),
                    pw.SizedBox(height: 4),
                    text(c.address, size: 9),
                    text(c.phone, size: 9),
                    text(c.email, size: 9),
                    if (c.trn.isNotEmpty) text('TRN: ${c.trn}', size: 9, bold: true),
                  ],
                ),
              ),
              pw.SizedBox(width: 25),
              pw.SizedBox(
                width: 215,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: const pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF007AFF),
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        q.status == 'draft'
                            ? 'DRAFT QUOTATION'
                            : q.status == 'converted'
                                ? 'QUOTATION (INVOICED)'
                                : 'PRICE QUOTATION',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    text(q.number.isEmpty ? 'Draft - Unassigned' : q.number, size: 12, bold: true),
                    pw.SizedBox(height: 8),
                    text('Quotation Total', bold: true, size: 10, color: PdfColors.grey700),
                    text(money(t.total), bold: true, size: 15, color: const PdfColor.fromInt(0xFF007AFF)),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // Quotation Details & Client info
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      text('QUOTATION PREPARED FOR', bold: true, size: 8.5, color: PdfColors.grey700),
                      pw.SizedBox(height: 6),
                      text(q.customer.name, bold: true, size: 11),
                      if (q.customer.address.isNotEmpty) text(q.customer.address, size: 9),
                      if (q.customer.email.isNotEmpty) text(q.customer.email, size: 9),
                      if (q.customer.phone.isNotEmpty) text(q.customer.phone, size: 9),
                      if (q.customer.trn.isNotEmpty) text('TRN: ${q.customer.trn}', size: 9, bold: true),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.SizedBox(
                width: 215,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    text('Date of Issue: ${q.date}', size: 9),
                    pw.SizedBox(height: 4),
                    if (q.validUntil.isNotEmpty)
                      text('Valid Until: ${q.validUntil}', bold: true, size: 9, color: const PdfColor.fromInt(0xFFFF2D55)),
                    pw.SizedBox(height: 4),
                    text('Payment Terms: ${q.terms}', size: 9),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // Line Items Table
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Item & Description', 'Qty', 'Rate', 'Amount'],
            data: [
              for (var n = 0; n < q.items.length; n++)
                [
                  '${n + 1}',
                  q.items[n].description,
                  q.items[n].quantity,
                  (scaled(q.items[n].rate, 2) / 100).toStringAsFixed(2),
                  (lineTotal(q.items[n]) / 100).toStringAsFixed(2),
                ]
            ],
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1C1C1E),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.all(8),
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.4),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(0.7),
              3: const pw.FlexColumnWidth(1.1),
              4: const pw.FlexColumnWidth(1.2),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),

          pw.SizedBox(height: 16),

          // Totals calculation box
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 260,
              child: pw.Column(
                children: [
                  summary('Item Total (AED)', t.subtotal),
                  if (t.discount > 0) summary('Special Discount', t.discount),
                  summary('Subtotal (Net)', t.subtotal - t.discount),
                  if (t.tax > 0) summary('VAT (${q.taxRate}%)', t.tax),
                  pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFEBF5FF),
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        text('QUOTATION TOTAL', bold: true, size: 10, color: const PdfColor.fromInt(0xFF007AFF)),
                        text(money(t.total), bold: true, size: 11, color: const PdfColor.fromInt(0xFF007AFF)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 28),

          // Terms & Notes
          if (q.notes.isNotEmpty) ...[
            text('Notes & Conditions', bold: true, size: 9.5),
            pw.SizedBox(height: 4),
            text(q.notes, size: 8.5, color: PdfColors.grey800),
            pw.SizedBox(height: 14),
          ],

          if (q.terms.isNotEmpty) ...[
            text('Commercial Terms', bold: true, size: 9.5),
            pw.SizedBox(height: 4),
            text(q.terms, size: 8.5, color: PdfColors.grey800),
            pw.SizedBox(height: 14),
          ],

          // Bank Details
          text('Remittance Bank Details', bold: true, size: 9.5),
          pw.SizedBox(height: 4),
          text('Account Holder: ${c.accountHolder}', size: 8.5),
          text('Bank Name: ${c.bank}', size: 8.5),
          text('Account Number: ${c.accountNumber}', size: 8.5),
          if (c.iban.isNotEmpty) text('IBAN: ${c.iban}', size: 8.5),

          pw.SizedBox(height: 36),

          // Signature / Acceptance block
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 170, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 4),
                  text('Authorized Signature', bold: true, size: 8.5),
                  text(c.name, size: 8, color: PdfColors.grey600),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 170, height: 1, color: PdfColors.grey400),
                  pw.SizedBox(height: 4),
                  text('Client Acceptance Signature', bold: true, size: 8.5),
                  text('Date: ____ / ____ / ________', size: 8, color: PdfColors.grey600),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }
}
