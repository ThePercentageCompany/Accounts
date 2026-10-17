import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../cache/cache_store.dart';
import 'offline_store.dart';

/// Native device persistence. A single serialized write commits an overlay and
/// its operation together; failures propagate before the UI reports a save.
class PreferencesOfflineStore implements OfflineStore {
  static Future<void> _tail = Future.value();
  static Future<T> transaction<T>(
      Future<T> Function(SharedPreferences) action) {
    final future = _tail.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      return action(preferences);
    });
    _tail = future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return future;
  }

  String _key(String scope) =>
      'tpc_offline_v2_${base64Url.encode(utf8.encode(scope))}';
  Map<String, dynamic> _decode(String? raw) {
    final value =
        raw == null ? emptyPartition() : copyJson(jsonDecode(raw) as Map);
    if (value['schema'] != 2) {
      throw StateError('Unsupported local storage version.');
    }
    return value;
  }

  @override
  Future<Map<String, dynamic>> read(String scope) => transaction(
      (preferences) async => _decode(preferences.getString(_key(scope))));
  @override
  Future<Map<String, dynamic>> change(
          String scope, void Function(Map<String, dynamic>) edit) =>
      transaction((preferences) async {
        final value = _decode(preferences.getString(_key(scope)));
        edit(value);
        final encoded = jsonEncode(value);
        if (utf8.encode(encoded).length > 8 * 1024 * 1024) {
          throw StateError('Pending changes exceed device storage capacity.');
        }
        if (!await preferences.setString(_key(scope), encoded)) {
          throw StateError('Could not save changes on this device.');
        }
        return copyJson(value);
      });
}

class PreferencesCacheStore implements CacheStore {
  static const _prefix = 'tpc_read_cache_v2_';
  String _key(String key) => '$_prefix${base64Url.encode(utf8.encode(key))}';
  @override
  Future<Map<String, dynamic>?> read(String key) =>
      PreferencesOfflineStore.transaction((preferences) async {
        final value = preferences.getString(_key(key));
        return value == null
            ? null
            : Map<String, dynamic>.from(jsonDecode(value) as Map);
      });
  @override
  Future<void> write(String key, Map<String, dynamic> value) =>
      PreferencesOfflineStore.transaction((preferences) async {
        final encoded = jsonEncode(value);
        if (utf8.encode(encoded).length > 4 * 1024 * 1024) return;
        if (!await preferences.setString(_key(key), encoded)) {
          throw StateError('Could not save snapshot.');
        }
        final entries = <String, Map>{};
        var bytes = 0;
        for (final entryKey
            in preferences.getKeys().where((key) => key.startsWith(_prefix))) {
          final raw = preferences.getString(entryKey)!;
          try {
            entries[entryKey] = jsonDecode(raw) as Map;
            bytes += utf8.encode(raw).length;
          } catch (_) {
            await preferences.remove(entryKey);
          }
        }
        final keys = entries.keys.toList()
          ..sort((a, b) => (entries[a]!['syncedAt'] as int)
              .compareTo(entries[b]!['syncedAt'] as int));
        var count = keys.length;
        final cutoff = DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch;
        for (final entryKey in keys) {
          if (entries[entryKey]!['syncedAt'] < cutoff ||
              count > 128 ||
              bytes > 20 * 1024 * 1024) {
            bytes -= utf8.encode(preferences.getString(entryKey)!).length;
            if (!await preferences.remove(entryKey)) {
              throw StateError('Could not prune snapshot.');
            }
            count--;
          }
        }
      });
  Future<void> _edit(bool Function(Map) affected, {bool invalidate = false}) =>
      PreferencesOfflineStore.transaction((preferences) async {
        for (final key in preferences
            .getKeys()
            .where((key) => key.startsWith(_prefix))
            .toList()) {
          Map row;
          try {
            row = jsonDecode(preferences.getString(key)!) as Map;
          } catch (_) {
            await preferences.remove(key);
            continue;
          }
          if (!affected(row)) continue;
          final success = invalidate
              ? await preferences.setString(
                  key, jsonEncode({...row, 'invalidated': true}))
              : await preferences.remove(key);
          if (!success) throw StateError('Could not update saved snapshot.');
        }
      });
  @override
  Future<void> removeEntry(String key) => _edit((row) => row['key'] == key);
  @override
  Future<void> removeAccount(String account) =>
      _edit((row) => row['account'] == account);
  @override
  Future<void> removeScope(String scope) =>
      _edit((row) => row['scope'] == scope);
  @override
  Future<void> invalidateScope(String scope, bool Function(String) affected) =>
      _edit(
          (row) =>
              row['scope'] == scope &&
              affected((jsonDecode(row['resource'] as String) as List).first
                  as String),
          invalidate: true);
}
