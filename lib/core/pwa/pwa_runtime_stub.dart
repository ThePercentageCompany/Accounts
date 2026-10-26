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
  Future<void> enableSound() async {}
  Future<void> playSound(String sound, double volume, String id) async {}
  Future<Map<String, dynamic>?> registerTaskPush(Map<String, dynamic> config, String vapid,
      {bool requestPermission = false}) async => null;
  Future<void> disableTaskPush() async {}
}
