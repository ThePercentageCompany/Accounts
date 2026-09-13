// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation that completely wipes browser cache, local storage,
/// session storage, IndexedDB, CacheStorage, and Google Sign-In selection state.
Future<void> clearBrowserDataPlatform() async {
  // 1. Clear HTML5 LocalStorage
  try {
    html.window.localStorage.clear();
  } catch (_) {}

  // 2. Clear HTML5 SessionStorage
  try {
    html.window.sessionStorage.clear();
  } catch (_) {}

  // 3. Clear CacheStorage (Service Worker & Network Caches)
  try {
    if (html.window.caches != null) {
      final cacheKeys = await html.window.caches!.keys();
      for (final key in cacheKeys) {
        if (key != null) {
          await html.window.caches!.delete(key.toString());
        }
      }
    }
  } catch (_) {}

  // 4. Clear IndexedDB Databases
  try {
    final dynamic win = html.window;
    final idb = win.indexedDB;
    if (idb != null) {
      final dynamic dbs = await idb.databases();
      if (dbs is Iterable) {
        for (final db in dbs) {
          final dbName = db?.name?.toString() ?? (db is Map ? db['name']?.toString() : null);
          if (dbName != null && dbName.isNotEmpty) {
            idb.deleteDatabase(dbName);
          }
        }
      }
    }
  } catch (_) {}

  // 5. Disable Google Identity Services (GSI) Auto-Select
  try {
    final dynamic win = html.window;
    final google = win.google;
    if (google != null && google.accounts != null && google.accounts.id != null) {
      google.accounts.id.disableAutoSelect();
    }
  } catch (_) {}
}
