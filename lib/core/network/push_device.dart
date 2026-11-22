import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

String? get nativePushPlatform => kIsWeb
    ? null
    : switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => null,
      };

const _installationKey = 'workspace.push.installation';
const _enabledKey = 'workspace.push.enabled';

Future<String?> nativePushInstallation() async {
  if (nativePushPlatform == null) return null;
  return (await SharedPreferences.getInstance()).getString(_installationKey);
}

Future<Map<String, dynamic>?> nativePushRegistration({
  required bool requestPermission,
}) async {
  final platform = nativePushPlatform;
  if (platform == null) return null;
  final prefs = await SharedPreferences.getInstance();
  if (!requestPermission && prefs.getBool(_enabledKey) != true) return null;
  final messaging = FirebaseMessaging.instance;
  final settings = requestPermission
      ? await messaging.requestPermission()
      : await messaging.getNotificationSettings();
  if (settings.authorizationStatus != AuthorizationStatus.authorized &&
      settings.authorizationStatus != AuthorizationStatus.provisional) {
    if (!requestPermission) return null;
    throw StateError(
        'Allow notifications in your device settings and try again.');
  }
  await messaging.setAutoInitEnabled(true);
  if (platform == 'ios') {
    await messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);
    for (var i = 0; i < 10 && await messaging.getAPNSToken() == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (await messaging.getAPNSToken() == null) {
      throw StateError(
          'Apple Push Notifications are unavailable for this build.');
    }
  }
  // Keep legacy registration tokens until the push pipeline migrates to FIDs.
  // ignore: deprecated_member_use
  final token = await messaging.getToken();
  if (token == null) {
    throw StateError('The device did not receive a push token.');
  }
  final installation = prefs.getString(_installationKey) ?? const Uuid().v4();
  await prefs.setString(_installationKey, installation);
  await prefs.setBool(_enabledKey, true);
  return {'token': token, 'installationId': installation, 'platform': platform};
}

Future<void> disableNativePush() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_enabledKey, false);
  final messaging = FirebaseMessaging.instance;
  await messaging.setAutoInitEnabled(false);
  // Revoke the legacy registration token created by nativePushRegistration.
  // ignore: deprecated_member_use
  await messaging.deleteToken();
}
