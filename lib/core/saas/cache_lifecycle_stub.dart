class CacheLifecycle {
  CacheLifecycle(void Function() resume, void Function(String, String) message);
  bool get visible => true;
  void broadcast(String kind, String scope) {}
  void dispose() {}
}
