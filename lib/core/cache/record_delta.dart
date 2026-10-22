import 'package:tpc_invoice/core/network/saas_api.dart';

/// Merge into a private candidate snapshot. The caller publishes/persists the
/// records and cursor together only after every page in the window succeeds.
Future<Map<String, dynamic>?> fetchRecordDelta(
  Map<String, dynamic> snapshot,
  Future<Map<String, dynamic>> Function(String after, String? through, String scope) fetch,
) async {
  var cursor = snapshot['syncCursor'];
  final scope = snapshot['syncScope'];
  if (cursor is! String || !RegExp(r'^\d+$').hasMatch(cursor) ||
      scope is! String || snapshot['records'] is! List) { return null; }
  final rows = <String, Map<String, dynamic>>{
    for (final raw in snapshot['records'] as List)
      '${raw['recordId']}': Map<String, dynamic>.from(raw as Map),
  };
  final initialCursor = cursor;
  final changedIds = <String>{};
  final versions = {for (final entry in rows.entries)
    entry.key: (entry.value['recordVersion'] as num? ?? 0).toInt()};
  String? through;
  for (var pageNumber = 0; pageNumber < 100; pageNumber++) {
    final page = await fetch(cursor, through, scope);
    if (page['reset'] == true) return null;
    final next = page['cursor'], end = page['through'];
    if (page['reset'] != false || page['syncScope'] != scope ||
        next is! String || end is! String ||
        !RegExp(r'^\d+$').hasMatch(next) || !RegExp(r'^\d+$').hasMatch(end) ||
        BigInt.parse(next) < BigInt.parse(cursor) || BigInt.parse(next) > BigInt.parse(end) ||
        (through != null && end != through) ||
        page['records'] is! List || page['removed'] is! List || page['hasMore'] is! bool ||
        (page['hasMore'] == true && next == cursor)) {
      throw const SaasApiException('INVALID_RESPONSE', 'Record sync could not be verified. Saved data is retained.');
    }
    through = end;
    for (final raw in page['records'] as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['recordId'];
      if (id is! String || row['recordVersion'] is! int) {
        throw const SaasApiException('INVALID_RESPONSE', 'Record sync returned an invalid revision.');
      }
      if ((row['recordVersion'] as int) >= (versions[id] ?? 0)) {
        rows[id] = row; versions[id] = row['recordVersion'] as int; changedIds.add(id);
      }
    }
    for (final raw in page['removed'] as List) {
      final id = raw['recordId'], version = raw['recordVersion'];
      if (id is! String || version is! int) {
        throw const SaasApiException('INVALID_RESPONSE', 'Record deletion could not be verified.');
      }
      if (version >= (versions[id] ?? 0)) { rows.remove(id); versions[id] = version; changedIds.add(id); }
    }
    cursor = next;
    if (page['hasMore'] == false) {
      if (cursor != through) {
        throw const SaasApiException('INVALID_RESPONSE', 'Record sync window is incomplete.');
      }
      return {...snapshot, 'records': rows.values.toList(), 'syncCursor': cursor,
        '_recordDelta': {'fromCursor': initialCursor, 'ids': changedIds.toList()}};
    }
  }
  // A very old/busy workspace bootstraps rather than retrying an unbounded log.
  return null;
}
