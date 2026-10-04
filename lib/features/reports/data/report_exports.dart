import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'report_snapshot.dart';
import 'report_format.dart';

String _xml(Object? value) => const HtmlEscape(
  HtmlEscapeMode.element,
).convert('${value ?? ''}').replaceAll('"', '&quot;').replaceAll("'", '&apos;');

Uint8List snapshotCsv(ReportSnapshot snapshot) {
  String cell(Object? value, bool numeric) {
    var text = '${value ?? ''}';
    if ((!numeric || reportMinor(value) == null) &&
        RegExp(r'^\s*[=+@\-\t\r\n]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  final lines = <String>[];
  void row(List<Object?> values, [Set<int> numeric = const {}]) => lines.add(
    [
      for (var i = 0; i < values.length; i++)
        cell(values[i], numeric.contains(i)),
    ].join(','),
  );
  row([snapshot.title]);
  for (final r in snapshot.context) {
    row(r);
  }
  for (final table in snapshot.tables) {
    row([]);
    row([table.title]);
    row(table.headers);
    for (final r in table.rows) {
      row(r, table.numericColumns);
    }
  }
  return Uint8List.fromList(utf8.encode('\uFEFF${lines.join('\r\n')}\r\n'));
}

Uint8List snapshotXlsx(ReportSnapshot snapshot) {
  final archive = Archive();
  void add(String path, String text) {
    final bytes = utf8.encode(text);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  final sheets = <(String, List<List<Object?>>, Set<int>)>[
    (
      'Report context',
      [
        [snapshot.title],
        ...snapshot.context,
      ],
      {},
    ),
    for (final t in snapshot.tables)
      (t.title, [t.headers, ...t.rows], t.numericColumns),
  ];
  String column(int n) {
    var text = '';
    n++;
    while (n > 0) {
      n--;
      text = String.fromCharCode(65 + n % 26) + text;
      n ~/= 26;
    }
    return text;
  }

  add(
    '[Content_Types].xml',
    '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>${[for (var i = 0; i < sheets.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}</Types>',
  );
  add(
    '_rels/.rels',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
  );
  String sheetName(int i) {
    final name = '${i + 1} ${sheets[i].$1}'.replaceAll(
      RegExp(r'[\[\]:*?/\\]'),
      ' ',
    );
    return _xml(name.substring(0, name.length.clamp(0, 31)));
  }

  add(
    'xl/workbook.xml',
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${[for (var i = 0; i < sheets.length; i++) '<sheet name="${sheetName(i)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${[for (var i = 0; i < sheets.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}<Relationship Id="styles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
  );
  add(
    'xl/styles.xml',
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/><xf numFmtId="4" fontId="0" fillId="0" borderId="0" applyNumberFormat="1"/></cellXfs></styleSheet>',
  );
  for (var i = 0; i < sheets.length; i++) {
    final table = sheets[i];
    final rows = <String>[];
    for (var r = 0; r < table.$2.length; r++) {
      final cells = <String>[];
      for (var c = 0; c < table.$2[r].length; c++) {
        final value = table.$2[r][c], ref = '${column(c)}${r + 1}';
        final numeric =
            r > 0 && table.$3.contains(c) && reportMinor(value) != null;
        cells.add(
          numeric
              ? '<c r="$ref" s="1"><v>${_xml(value)}</v></c>'
              : '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_xml(value)}</t></is></c>',
        );
      }
      rows.add('<row r="${r + 1}">${cells.join()}</row>');
    }
    add(
      'xl/worksheets/sheet${i + 1}.xml',
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><cols><col min="1" max="30" width="24" customWidth="1"/></cols><sheetData>${rows.join()}</sheetData></worksheet>',
    );
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

Future<Uint8List> snapshotPdf(ReportSnapshot snapshot) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter.ttf'));
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a3.landscape,
      maxPages: 1000,
      header: (_) => pw.Text(
        snapshot.title,
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
      ),
      footer: (context) => pw.Text(
        'Page ${context.pageNumber} / ${context.pagesCount} · ${snapshot.data['metadata']?['currency'] ?? 'Workspace currency'}',
      ),
      build: (_) => [
        for (final r in snapshot.context)
          pw.Text(
            r.map((c) => '${c ?? ''}').join('  '),
            style: const pw.TextStyle(fontSize: 9),
          ),
        for (final t in snapshot.tables) ...[
          pw.SizedBox(height: 16),
          pw.Text(t.title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: t.headers,
            data: [
              for (final r in t.rows)
                [
                  for (var i = 0; i < r.length; i++)
                    t.numericColumns.contains(i) && reportMinor(r[i]) != null
                        ? snapshot.format.money(r[i])
                        : '${r[i] ?? ''}',
                ],
            ],
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignments: {
              for (final i in t.numericColumns) i: pw.Alignment.centerRight,
            },
          ),
        ],
      ],
    ),
  );
  return doc.save();
}

String snapshotHtml(ReportSnapshot snapshot) =>
    '''<!doctype html><html><head><meta charset="utf-8"><title>${_xml(snapshot.title)}</title><style>
@page{size:A3 landscape;margin:14mm}body{font:12px Arial;color:#172033}h1{font-size:24px}table{border-collapse:collapse;width:100%;margin-bottom:24px}thead{display:table-header-group}th{background:#eef1f5}th,td{border-bottom:1px solid #d7dce3;padding:8px;text-align:left}td.amount{text-align:right;font-variant-numeric:tabular-nums}tr{break-inside:avoid}
</style></head><body><h1>${_xml(snapshot.title)}</h1>${[for (final r in snapshot.context) '<p>${r.map(_xml).join(' &nbsp; ')}</p>'].join()}
${[
      for (final t in snapshot.tables) '<h2>${_xml(t.title)}</h2><table><thead><tr>${t.headers.map((h) => '<th>${_xml(h)}</th>').join()}</tr></thead><tbody>${[
          for (final r in t.rows) '<tr>${[for (var i = 0; i < r.length; i++) '<td class="${t.numericColumns.contains(i) ? 'amount' : ''}">${_xml(t.numericColumns.contains(i) && reportMinor(r[i]) != null ? snapshot.format.money(r[i]) : r[i])}</td>'].join()}</tr>',
        ].join()}</tbody></table>',
    ].join()}</body></html>''';
