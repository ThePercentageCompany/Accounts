import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> printReportPlatform(String html) async {
  final frame = web.HTMLIFrameElement()..srcdoc = html.toJS;
  frame.style
    ..position = 'fixed'
    ..width = '1px'
    ..height = '1px'
    ..border = '0';
  final loaded = frame.onLoad.first;
  web.document.body!.appendChild(frame);
  try {
    await loaded.timeout(const Duration(seconds: 15));
    final window = frame.contentWindow;
    if (window == null) throw StateError('Print preview could not open.');
    window.print();
    Timer(const Duration(minutes: 1), () => frame.remove());
  } catch (_) {
    frame.remove();
    rethrow;
  }
}
