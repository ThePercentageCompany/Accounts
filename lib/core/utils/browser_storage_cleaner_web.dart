// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation that clears HTML5 LocalStorage and SessionStorage.
Future<void> clearBrowserDataPlatform() async {
  try {
    html.window.localStorage.clear();
  } catch (_) {}
  try {
    html.window.sessionStorage.clear();
  } catch (_) {}
}
