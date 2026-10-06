import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_store.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

/// Online-only workflows also keep uncertain requests in IndexedDB on web.
/// Preferences are read only to migrate pre-existing pending operations.
class DurableValue {
  DurableValue(this.store, this.scope, this.key, this.preferences);
  final OfflineStore store;
  final String scope, key;
  final SharedPreferences preferences;
  String? value;
  Future<void> load({String Function(String)? migrateLegacy}) async {
    final data = await _storage(() => store.read(scope));
    final aux = data['aux'] as Map? ?? {};
    value = aux[key] as String?;
    final legacy = preferences.getString(key);
    if (legacy != null) {
      if (value == null) await put(migrateLegacy?.call(legacy) ?? legacy);
      if (!await preferences.remove(key)) {
        throw StateError('Pending-change migration could not finish.');
      }
    }
  }

  Future<bool> put(String next) async {
    // Validate before the transaction, including binary requests stored as JSON.
    jsonDecode(next);
    await _storage(() => store.change(scope, (p) {
          final aux = p.putIfAbsent('aux', () => <String, dynamic>{}) as Map;
          if (aux[key] != value && aux[key] != next) {
            throw StateError(
                'Pending changes were updated in another tab. Reload before saving.');
          }
          aux[key] = next;
        }));
    value = next;
    return true;
  }

  Future<bool> remove() async {
    await _storage(() => store.change(scope, (p) {
          if ((p['aux'] as Map?)?[key] != value) {
            throw StateError(
                'Pending changes were updated in another tab. Reload before clearing.');
          }
          (p['aux'] as Map?)?.remove(key);
        }));
    value = null;
    return true;
  }

  Future<T> _storage<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw SaasApiException('LOCAL_STORAGE',
          'Device storage could not confirm this change. Saved progress is retained; retry: $error');
    }
  }
}
