import 'package:flutter/widgets.dart';

class CacheLifecycle with WidgetsBindingObserver {
  CacheLifecycle(this._resume, void Function(String, String) message) {
    try {
      _binding = WidgetsBinding.instance;
      _binding!.addObserver(this);
    } on StateError {
      // Pure Dart unit tests need not create a Flutter binding.
    } on FlutterError {
      // The debug binding getter also reports an uninitialized binding.
    }
  }
  final void Function() _resume;
  WidgetsBinding? _binding;
  bool get visible =>
      _binding?.lifecycleState != AppLifecycleState.paused &&
      _binding?.lifecycleState != AppLifecycleState.detached;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _resume();
  }

  void broadcast(String kind, String scope) {}
  void dispose() {
    _binding?.removeObserver(this);
  }
}
