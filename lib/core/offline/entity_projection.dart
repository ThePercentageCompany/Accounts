import 'offline_outbox.dart';
import 'offline_store.dart';

Map<String, dynamic> projectEntity(
    OfflineOutbox box, Map<String, dynamic> snapshot,
    {DateTime? syncedAt}) {
  final result = copyJson(snapshot);
  final entity = result['entity'];
  if (entity is! Map || entity['metrics'] is! Map) return result;
  final metrics = entity['metrics'] as Map;
  for (final table in ['Employees', 'Tasks', 'Invoices']) {
    final key = table == 'Employees'
        ? 'employees'
        : table == 'Tasks'
            ? 'openTasks'
            : 'invoices';
    bool counted(Map row) =>
        row.isNotEmpty &&
        row['isDeleted'] != true &&
        (table == 'Employees'
            ? row['employmentStatus'] == 'ACTIVE'
            : table == 'Tasks'
                ? !['COMPLETED', 'CANCELLED'].contains(row['status'])
                : true);
    var count = (metrics[key] as num?)?.toInt() ?? 0;
    for (final row in box.localRecords(table)) {
      if (row['syncStatus'] == 'SYNCED' &&
          syncedAt != null &&
          row['_acknowledgedAt'] is int &&
          syncedAt.millisecondsSinceEpoch >= (row['_acknowledgedAt'] as int)) {
        continue;
      }
      final base = row['_localBase'] as Map? ?? {};
      if (counted(base)) count--;
      if (counted(row)) count++;
    }
    metrics[key] = count < 0 ? 0 : count;
  }
  final profile = box.localRecords('CompanyProfile').firstOrNull;
  if (profile != null) {
    for (final key in ['name', 'currency']) {
      if (profile[key] != null) entity[key] = profile[key];
    }
  }
  return result;
}
