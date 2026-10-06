final _held = <String>{};
Future<void> withSyncLock(String scope, Future<void> Function() work) async {
  if (!_held.add(scope)) return;
  try {
    await work();
  } finally {
    _held.remove(scope);
  }
}
