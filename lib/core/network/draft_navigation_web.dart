import 'dart:js_interop';
import 'package:web/web.dart' as web;

class DraftNavigationGuard {
  DraftNavigationGuard(bool Function() hasUnsavedWork) {
    _listener = ((web.BeforeUnloadEvent event) {
      if (hasUnsavedWork()) {
        event.preventDefault();
        event.returnValue = '';
      }
    }).toJS;
    web.window.addEventListener('beforeunload', _listener);
  }
  late final JSFunction _listener;
  void dispose() => web.window.removeEventListener('beforeunload', _listener);
}
