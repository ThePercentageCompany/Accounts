import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/features/reports/data/report_exports.dart';
import 'package:tpc_invoice/features/reports/data/report_snapshot.dart';
import 'package:tpc_invoice/features/reports/data/report_format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('format preserves cents above JavaScript integer precision', () {
    const format = ReportFormat(parentheses: true);
    expect(format.money('-90071992547409.93'), '(90,071,992,547,409.93)');
    expect(
      const ReportFormat(locale: 'en_IN').money('1234567.89'),
      '12,34,567.89',
    );
    expect(const ReportFormat(locale: 'de_DE').money('1234.56'), '1.234,56');
    expect(format.money(null), '\u2014');
    expect(previousYearDate(DateTime(2024, 2, 29)), DateTime(2023, 2, 28));
    expect(
      financialYearStart(DateTime(2026, 2, 1), 4, 1),
      DateTime(2025, 4, 1),
    );
  });
  test(
    'frozen snapshot exports visible rows, movements and safe text in all formats',
    () async {
      final data = <String, dynamic>{
        'kind': 'trial-balance',
        'fullTrial': true,
        'asOf': '2026-09-30',
        'from': '2026-09-01',
        'metadata': {'companyName': 'Test <company>', 'currency': 'AED'},
        'accountSearch': 'cash',
        'accounts': [
          {
            'accountId': 'cash',
            'accountName': '=SUM(A1)',
            'accountGroup': 'Asset',
            'openingDebit': '1.00',
            'openingCredit': '0.00',
            'periodDebit': '0.30',
            'periodCredit': '0.10',
            'debit': '1.20',
            'credit': '0.00',
          },
        ],
      };
      final snapshot = ReportSnapshot('Trial balance', data);
      (data['accounts'] as List).clear();
      final csv = utf8.decode(snapshotCsv(snapshot));
      expect(csv, contains('Opening debit'));
      expect(csv, contains("'=SUM(A1)"));
      expect(csv, contains('1.20'));
      final zip = ZipDecoder().decodeBytes(snapshotXlsx(snapshot));
      final xml = zip.files
          .where((f) => f.name.startsWith('xl/worksheets/'))
          .map((f) => utf8.decode(f.content as List<int>))
          .join();
      expect(xml, contains('=SUM(A1)'));
      expect(xml, contains('<v>1.20</v>'));
      expect(xml, isNot(contains('<f>')));
      expect(snapshotHtml(snapshot), contains('Test &lt;company&gt;'));
      expect(snapshotHtml(snapshot), contains('Opening debit'));
      final pdf = await snapshotPdf(snapshot);
      expect(ascii.decode(pdf.take(4).toList()), '%PDF');
    },
  );
}
