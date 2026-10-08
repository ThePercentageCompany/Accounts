import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

@JS('tpcPwa.status')
external JSString _status();
@JS('tpcPwa.install')
external JSPromise<JSBoolean> _install();
@JS('tpcPwa.update')
external JSPromise<JSAny?> _update();
@JS('tpcPwa.checkUpdate')
external JSPromise<JSAny?> _checkUpdate();
@JS('tpcPwa.pendingWork')
external JSPromise<JSBoolean> _pendingWork();
@JS('tpcPwa.subscribe')
external JSPromise<JSString> _subscribe(JSString key);
@JS('tpcPwa.subscription')
external JSPromise<JSString> _subscription();
@JS('tpcPwa.unsubscribe')
external JSPromise<JSAny?> _unsubscribe();
@JS('tpcPwa.clearTask')
external void _clearTask();

class PwaRuntime extends ChangeNotifier {
  PwaRuntime() {
    _listener = ((web.Event _) => notifyListeners()).toJS;
    web.window.addEventListener('tpc-pwa-change', _listener);
  }
  late final JSFunction _listener;
  Map<String, dynamic> get status {
    try {
      return Map<String, dynamic>.from(jsonDecode(_status().toDart) as Map);
    } catch (_) {
      return {
        'online': web.window.navigator.onLine,
        'pushSupported': false,
        'permission': 'unsupported'
      };
    }
  }

  Future<bool> install() async => (await _install().toDart).toDart;
  Future<void> update() async {
    await _update().toDart;
  }

  Future<void> checkUpdate() async {
    await _checkUpdate().toDart;
  }

  Future<bool> pendingWork() async => (await _pendingWork().toDart).toDart;

  Future<Map<String, dynamic>> subscribe(String key) async =>
      Map<String, dynamic>.from(
          jsonDecode((await _subscribe(key.toJS).toDart).toDart) as Map);
  Future<Map<String, dynamic>?> subscription() async {
    final value = jsonDecode((await _subscription().toDart).toDart);
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  Future<void> unsubscribe() async {
    await _unsubscribe().toDart;
  }

  void clearTask() => _clearTask();
  @override
  void dispose() {
    web.window.removeEventListener('tpc-pwa-change', _listener);
    super.dispose();
  }
}
