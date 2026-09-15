import 'dart:convert';
import 'dart:typed_data';

/// Excel 2003 XML is opened by Excel as a native workbook while keeping the
/// export dependency-free for web builds. The .xls extension is intentional.
class AccountingXlsExport {
  const AccountingXlsExport._();

  static Uint8List buildWorkbook({
    required String companyName,
    required String periodLabel,
    required Map<String, dynamic> balanceSheet,
    required Map<String, dynamic> trialBalance,
    required List<Map<String, dynamic>> ledgerLines,
    String? singleStatement,
  }) {
    final sheets = <String>[];
    if (singleStatement == null || singleStatement == 'Balance Sheet') {
      sheets.add(_balanceSheet(companyName, periodLabel, balanceSheet));
    }
    if (singleStatement == null || singleStatement == 'General Ledger') {
      sheets.add(_generalLedger(companyName, periodLabel, ledgerLines));
    }
    if (singleStatement == null || singleStatement == 'Trial Balance') {
      sheets.add(_trialBalance(companyName, periodLabel, trialBalance));
    }

    final workbook = '''<?xml version="1.0"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
 <Styles>
  <Style ss:ID="Default" ss:Name="Normal"><Alignment ss:Vertical="Center"/><Font ss:FontName="Calibri" ss:Size="10"/></Style>
  <Style ss:ID="title"><Font ss:FontName="Calibri" ss:Size="16" ss:Bold="1" ss:Color="#17365D"/><Alignment ss:Vertical="Center"/></Style>
  <Style ss:ID="subtitle"><Font ss:FontName="Calibri" ss:Size="10" ss:Color="#5B6573"/></Style>
  <Style ss:ID="header"><Font ss:FontName="Calibri" ss:Size="10" ss:Bold="1" ss:Color="#FFFFFF"/><Interior ss:Color="#1F4E78" ss:Pattern="Solid"/><Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/><Borders><Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#17365D"/></Borders></Style>
  <Style ss:ID="section"><Font ss:FontName="Calibri" ss:Size="10" ss:Bold="1" ss:Color="#17365D"/><Interior ss:Color="#D9EAF7" ss:Pattern="Solid"/></Style>
  <Style ss:ID="text"><Alignment ss:Vertical="Center"/><Borders><Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D9E2F3"/></Borders></Style>
  <Style ss:ID="money"><NumberFormat ss:Format="#,##0.00;[Red]-#,##0.00"/><Alignment ss:Horizontal="Right" ss:Vertical="Center"/><Borders><Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1" ss:Color="#D9E2F3"/></Borders></Style>
  <Style ss:ID="total"><Font ss:Bold="1" ss:Color="#17365D"/><Interior ss:Color="#EAF2F8" ss:Pattern="Solid"/><NumberFormat ss:Format="#,##0.00;[Red]-#,##0.00"/><Alignment ss:Horizontal="Right" ss:Vertical="Center"/><Borders><Border ss:Position="Top" ss:LineStyle="Double" ss:Weight="3" ss:Color="#1F4E78"/></Borders></Style>
  <Style ss:ID="totalLabel"><Font ss:Bold="1" ss:Color="#17365D"/><Interior ss:Color="#EAF2F8" ss:Pattern="Solid"/><Borders><Border ss:Position="Top" ss:LineStyle="Double" ss:Weight="3" ss:Color="#1F4E78"/></Borders></Style>
 </Styles>
 ${sheets.join('\n')}
</Workbook>''';
    return Uint8List.fromList(utf8.encode(workbook));
  }

  static String _balanceSheet(
      String company, String period, Map<String, dynamic> bs) {
    final rows = <String>[
      _sheetOpen('Balance Sheet', [270, 120]),
      _title(company, 'Statement of Financial Position', period, 2),
      _header(['Account', 'Amount (AED)']),
      _section('ASSETS', 2),
      _section('Current Assets', 2),
      ..._statementRows(
          (bs['currentAssets'] as List?)?.cast<Map<String, dynamic>>() ?? []),
      _total('Total Current Assets', bs['totalCurrentAssetsCents']),
      _section('Fixed Assets', 2),
      ..._statementRows((bs['fixedAssetsByCategory'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          []),
      _total('Total Fixed Assets', bs['totalFixedAssetsCents']),
      _total('TOTAL ASSETS', bs['totalAssetsCents']),
      _section('LIABILITIES', 2),
      ..._statementRows(
          (bs['liabilities'] as List?)?.cast<Map<String, dynamic>>() ?? []),
      _total('TOTAL LIABILITIES', bs['totalLiabilitiesCents']),
      _section('EQUITY', 2),
      _row(['Shareholder Capital', _money(bs['totalShareholderEquityCents'])]),
      _row([
        'Current Period Net Profit',
        _money(bs['currentYearNetProfitCents'])
      ]),
      _total('TOTAL EQUITY', bs['totalEquityCents']),
      _total(
          'TOTAL LIABILITIES & EQUITY', bs['totalLiabilitiesAndEquityCents']),
      '</Table></Worksheet>',
    ];
    return rows.join('\n');
  }

  static String _generalLedger(
      String company, String period, List<Map<String, dynamic>> lines) {
    final rows = <String>[
      _sheetOpen('General Ledger', [90, 100, 100, 170, 110, 105, 105, 250]),
      _title(company, 'General Ledger', period, 8),
      _header([
        'Date',
        'Journal No.',
        'Source',
        'Account',
        'Group',
        'Debit (AED)',
        'Credit (AED)',
        'Description'
      ]),
      ...lines.map((line) => _row([
            _text(line['date']),
            _text(line['journalNumber']),
            _text(line['sourceType']),
            _text(line['accountName']),
            _text(line['accountGroup']),
            _money(line['debitCents']),
            _money(line['creditCents']),
            _text(line['description']),
          ])),
      '</Table></Worksheet>',
    ];
    return rows.join('\n');
  }

  static String _trialBalance(
      String company, String period, Map<String, dynamic> tb) {
    final entries = (tb['rows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final rows = <String>[
      _sheetOpen('Trial Balance', [250, 120, 130, 130]),
      _title(company, 'Trial Balance', period, 4),
      _header(['Account', 'Group', 'Debit (AED)', 'Credit (AED)']),
      ...entries.map((entry) => _row([
            _text(entry['accountName']),
            _text(entry['accountGroup']),
            _money(entry['displayDebitCents']),
            _money(entry['displayCreditCents']),
          ])),
      _totalRow('TOTALS', [tb['totalDebitCents'], tb['totalCreditCents']], 4),
      '</Table></Worksheet>',
    ];
    return rows.join('\n');
  }

  static List<String> _statementRows(List<Map<String, dynamic>> items) => items
      .map((item) => _row([
            _text(item['name'] ?? item['category']),
            _money(item['amountCents'])
          ]))
      .toList();

  static String _sheetOpen(String name, List<int> widths) =>
      '<Worksheet ss:Name="${_escape(name)}"><Table>${widths.map((w) => '<Column ss:Width="$w"/>').join()}';
  static String _title(
          String company, String statement, String period, int columns) =>
      '<Row ss:Height="25"><Cell ss:StyleID="title" ss:MergeAcross="${columns - 1}"><Data ss:Type="String">${_escape(company)}</Data></Cell></Row>'
      '<Row><Cell ss:StyleID="subtitle" ss:MergeAcross="${columns - 1}"><Data ss:Type="String">${_escape(statement)} - ${_escape(period)}</Data></Cell></Row><Row ss:Height="8"/>';
  static String _header(List<String> values) =>
      '<Row ss:Height="28">${values.map((v) => '<Cell ss:StyleID="header"><Data ss:Type="String">${_escape(v)}</Data></Cell>').join()}</Row>';
  static String _section(String text, int columns) =>
      '<Row><Cell ss:StyleID="section" ss:MergeAcross="${columns - 1}"><Data ss:Type="String">${_escape(text)}</Data></Cell></Row>';
  static String _row(List<String> cells) => '<Row>${cells.join()}</Row>';
  static String _text(Object? value) =>
      '<Cell ss:StyleID="text"><Data ss:Type="String">${_escape(value?.toString() ?? '')}</Data></Cell>';
  static String _money(Object? cents) {
    final value = (cents as num?)?.toDouble() ?? 0;
    return '<Cell ss:StyleID="money"><Data ss:Type="Number">${value / 100}</Data></Cell>';
  }

  static String _total(String label, Object? cents) =>
      '<Row><Cell ss:StyleID="totalLabel"><Data ss:Type="String">${_escape(label)}</Data></Cell><Cell ss:StyleID="total"><Data ss:Type="Number">${((cents as num?)?.toDouble() ?? 0) / 100}</Data></Cell></Row>';
  static String _totalRow(String label, List<Object?> amounts, int columns) =>
      '<Row><Cell ss:StyleID="totalLabel" ss:MergeAcross="${columns - amounts.length - 1}"><Data ss:Type="String">${_escape(label)}</Data></Cell>${amounts.map((amount) => '<Cell ss:StyleID="total"><Data ss:Type="Number">${((amount as num?)?.toDouble() ?? 0) / 100}</Data></Cell>').join()}</Row>';
  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
