import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner-only snapshots. Sessions, employee data and document bytes are excluded.
class WorkspaceRecordCache {
  WorkspaceRecordCache(this.preferences, this.scope);
  final SharedPreferences preferences;
  final String scope;
  String _key(String table) => 'tpc_workspace_cache_v1_${scope}_$table';

  List<Map<String, dynamic>>? read(String table) {
    try {
      final raw = preferences.getString(_key(table));
      if (raw == null) return null;
      final snapshot = jsonDecode(raw) as Map;
      final saved = DateTime.parse(snapshot['savedAt'] as String);
      if (DateTime.now().difference(saved) > const Duration(hours: 24)) {
        return null;
      }
      return (snapshot['records'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String table, List<Map<String, dynamic>> rows) async {
    final value = jsonEncode(
        {'savedAt': DateTime.now().toUtc().toIso8601String(), 'records': rows});
    // Bound browser storage per table; caching must never block a server read.
    if (utf8.encode(value).length > 512 * 1024) {
      await clear(table);
      return;
    }
    await preferences.setString(_key(table), value);
  }

  Future<void> clear(String table) => preferences.remove(_key(table));
}
