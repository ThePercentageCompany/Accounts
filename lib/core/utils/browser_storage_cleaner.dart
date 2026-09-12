import 'browser_storage_cleaner_stub.dart'
    if (dart.library.html) 'browser_storage_cleaner_web.dart';

/// Clears browser cache, local storage, and session storage on web platforms.
Future<void> clearBrowserStorage() async {
  await clearBrowserDataPlatform();
}
