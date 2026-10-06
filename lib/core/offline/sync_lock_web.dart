import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('navigator.locks')
external JSObject? get _locks;

Future<void> withSyncLock(String scope, Future<void> Function() work) async {
  final locks = _locks;
  if (locks == null) {
    throw StateError(
      'Safe multi-tab syncing requires Web Locks (HTTPS). Changes remain saved on this device.',
    );
  }
  await (locks as web.LockManager)
      .request(
        'tpc-outbox:$scope',
        web.LockOptions(ifAvailable: true),
        ((web.Lock? lock) {
          return (lock == null
                  ? Future<JSAny?>.value(null)
                  : work().then<JSAny?>((_) => null))
              .toJS;
        }).toJS,
      )
      .toDart;
}
