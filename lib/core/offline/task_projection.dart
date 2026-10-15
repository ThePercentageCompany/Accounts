import '../utils/business_time.dart';
import 'offline_outbox.dart';

/// Projects durable edits over a server page without changing that snapshot.
Map<String, dynamic> projectTaskPage(
    OfflineOutbox box, Map<String, dynamic> page, Map<String, String> query,
    {DateTime? syncedAt, bool hasSnapshot = true}) {
  final today = businessNow('Asia/Dubai').toIso8601String().substring(0, 10);
  bool matches(Map row) =>
      row.isNotEmpty &&
      row['isDeleted'] != true &&
      [
        'employeeId',
        'status',
        'priority',
        'project'
      ].every((key) => (query[key] ?? '').isEmpty || row[key] == query[key]) &&
      ((query['from'] ?? '').isEmpty ||
          '${row['dueDate']}'.compareTo(query['from']!) >= 0) &&
      ((query['to'] ?? '').isEmpty ||
          '${row['dueDate']}'.compareTo(query['to']!) <= 0) &&
      (query['overdue'] != 'true' || row['status'] != 'COMPLETED') &&
      ((query['search'] ?? '').isEmpty ||
          '${row['title']} ${row['description']} ${row['project']} ${row['tags']}'
              .toLowerCase()
              .contains(query['search']!.toLowerCase()));
  final rows = {
    for (final raw in page['records'] as List? ?? [])
      '${raw['recordId']}': Map<String, dynamic>.from(raw as Map),
  };
  final summary = Map<String, dynamic>.from(page['summary'] as Map? ?? {});
  final dates = Map<String, dynamic>.from(page['dateCounts'] as Map? ?? {});
  final upcoming = <String, int>{
    for (final row in summary['upcoming'] as List? ?? [])
      '${row['date']}': (row['count'] as num).toInt(),
  };
  var total = (page['total'] as num?)?.toInt() ?? rows.length;
  void count(Map target, String key, int amount) {
    final next = ((target[key] as num?)?.toInt() ?? 0) + amount;
    target[key] = next < 0 ? 0 : next;
  }

  void adjust(Map row, int sign) {
    if (row.isEmpty || row['isDeleted'] == true) return;
    if (matches(row)) {
      total += sign;
      count(dates, '${row['dueDate']}', sign);
    }
    if (row['status'] == 'TODO') count(summary, 'todo', sign);
    if (row['status'] == 'IN_PROGRESS') count(summary, 'inProgress', sign);
    if (row['status'] != 'COMPLETED') {
      final due = '${row['dueDate'] ?? ''}';
      if (due == today) count(summary, 'today', sign);
      if (due.isNotEmpty && due.compareTo(today) < 0) {
        count(summary, 'overdue', sign);
      }
      if (due.compareTo(today) > 0) count(upcoming, due, sign);
    }
  }

  for (final local in box.localRecords('Tasks')) {
    if (local['syncStatus'] == 'SYNCED' &&
        syncedAt != null &&
        local['_acknowledgedAt'] is int &&
        syncedAt.millisecondsSinceEpoch >= (local['_acknowledgedAt'] as int)) {
      continue;
    }
    final id = '${local['recordId']}';
    final present = rows[id];
    if (present != null &&
        local['syncStatus'] == 'SYNCED' &&
        (present['recordVersion'] as num? ?? 0) >=
            (local['recordVersion'] as num? ?? 0)) {
      continue;
    }
    final base =
        present ?? Map<String, dynamic>.from(local['_localBase'] as Map? ?? {});
    if (hasSnapshot) adjust(base, -1);
    adjust(local, 1);
    rows.remove(id);
    if (matches(local) &&
        (present != null || (query['offset'] ?? '0') == '0')) {
      rows[id] = local;
    }
  }
  final result = rows.values.where(matches).toList();
  const priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];
  result.sort((a, b) {
    final order = switch (query['sort']) {
      'priority' => priorities
          .indexOf('${b['priority']}')
          .compareTo(priorities.indexOf('${a['priority']}')),
      'updated' =>
        (b['updatedAt'] as num? ?? 0).compareTo(a['updatedAt'] as num? ?? 0),
      _ => '${a['dueDate']}${a['endTime'] ?? ''}'
          .compareTo('${b['dueDate']}${b['endTime'] ?? ''}'),
    };
    return order != 0
        ? order
        : '${a['recordId']}'.compareTo('${b['recordId']}');
  });
  summary['upcoming'] =
      (upcoming.keys.where((date) => upcoming[date]! > 0).toList()..sort())
          .take(7)
          .map((date) => {'date': date, 'count': upcoming[date]})
          .toList();
  return {
    ...page,
    'records': result,
    'total': total < 0 ? 0 : total,
    'summary': summary,
    'dateCounts': dates
  };
}
