// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation that clears HTML5 SessionStorage without wiping persistent LocalStorage.
Future<void> clearBrowserDataPlatform() async {
  try {
    html.window.sessionStorage.clear();
  } catch (_) {}
}
