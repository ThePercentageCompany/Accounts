import 'package:flutter/foundation.dart';

class PwaRuntime extends ChangeNotifier {
  Map<String, dynamic> get status => {
        'online': true,
        'installed': false,
        'installable': false,
        'updateAvailable': false,
        'pushSupported': false,
        'permission': 'unsupported',
        'taskLink': ''
      };
  Future<bool> install() async => false;
  Future<void> update() async {}
  Future<void> checkUpdate() async {}
  Future<bool> pendingWork() async => false;
  Future<Map<String, dynamic>> subscribe(String key) async =>
      throw UnsupportedError('Web push is unavailable.');
  Future<Map<String, dynamic>?> subscription() async => null;
  Future<void> unsubscribe() async {}
  void clearTask() {}
}
