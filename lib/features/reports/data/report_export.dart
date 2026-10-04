import 'dart:convert';
import 'dart:typed_data';

/// Quote CSV fields and neutralize spreadsheet formulas in user-supplied text.
Uint8List reportCsv(String title, Map<String, dynamic> report) {
  String cell(Object? value, {bool money = false}) {
    var text = '${value ?? ''}';
    if (!money && RegExp(r'^\s*[=+@\-\t\r\n]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final lines = <String>[];
  void row(List<Object?> values, [Set<int> amounts = const {}]) => lines.add(
    [
      for (var i = 0; i < values.length; i++)
        cell(values[i], money: amounts.contains(i)),
    ].join(','),
  );
  row([title]);
  row(['From', report['from'] ?? 'Inception', 'As of', report['asOf']]);
  row(['Posted journals', report['journalCount']]);
  for (final field in report.entries) {
    if (!['from', 'asOf', 'journalCount', 'accounts'].contains(field.key)) {
      row([field.key, field.value], {1});
    }
  }
  final accounts = report['accounts'] as List? ?? [];
  final ledger =
      accounts.isNotEmpty && (accounts.first as Map).containsKey('entries');
  if (ledger) {
    row([
      'Account ID',
      'Account',
      'Group',
      'Date',
      'Journal',
      'Description',
      'Debit',
      'Credit',
      'Balance',
    ]);
    for (final a in accounts) {
      row(
        [
          a['accountId'],
          a['accountName'],
          a['accountGroup'],
          '',
          '',
          'Opening',
          '',
          '',
          a['opening'],
        ],
        {8},
      );
      for (final e in a['entries']) {
        row(
          [
            a['accountId'],
            a['accountName'],
            a['accountGroup'],
            e['date'],
            e['number'],
            e['description'],
            e['debit'],
            e['credit'],
            e['balance'],
          ],
          {6, 7, 8},
        );
      }
      row(
        [
          a['accountId'],
          a['accountName'],
          a['accountGroup'],
          '',
          '',
          'Closing / period totals',
          a['debit'],
          a['credit'],
          a['closing'],
        ],
        {6, 7, 8},
      );
    }
  } else {
    row(['Account ID', 'Account', 'Group', 'Debit', 'Credit', 'Amount']);
    for (final a in accounts) {
      row(
        [
          a['accountId'],
          a['accountName'],
          a['accountGroup'],
          a['debit'],
          a['credit'],
          a['amount'],
        ],
        {3, 4, 5},
      );
    }
  }
  return Uint8List.fromList(utf8.encode('\uFEFF${lines.join('\r\n')}\r\n'));
}
