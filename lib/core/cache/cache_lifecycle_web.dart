import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class CacheLifecycle {
  CacheLifecycle(
    void Function() resume,
    void Function(String, String) message,
  ) {
    _resume = ((web.Event _) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (visible) resume();
      });
    }).toJS;
    web.window.addEventListener('online', _resume);
    web.window.addEventListener('focus', _resume);
    web.document.addEventListener('visibilitychange', _resume);
    try {
      _channel = web.BroadcastChannel('tpc-cache-control-v2');
      _message = ((web.MessageEvent event) {
        try {
          final data = jsonDecode((event.data as JSString).toDart) as Map;
          message(data['kind'] as String, data['scope'] as String);
        } catch (_) {}
      }).toJS;
      _channel!.addEventListener('message', _message);
    } catch (_) {
      /* Cache still works when cross-tab messaging is unavailable. */
    }
  }
  Timer? _debounce;
  late final JSFunction _resume;
  late final JSFunction _message;
  web.BroadcastChannel? _channel;
  bool get visible => web.document.visibilityState != 'hidden';
  void broadcast(String kind, String scope) {
    if (kind == 'outbox') web.window.dispatchEvent(web.Event('tpc-outbox-pending'));
    try {
      _channel?.postMessage(jsonEncode({'kind': kind, 'scope': scope}).toJS);
    } catch (_) {}
  }

  void dispose() {
    _debounce?.cancel();
    web.window.removeEventListener('online', _resume);
    web.window.removeEventListener('focus', _resume);
    web.document.removeEventListener('visibilitychange', _resume);
    _channel?.close();
  }
}
