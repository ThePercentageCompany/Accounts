import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _backgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final _nativePush = _NativePush();

class _NativePush extends ChangeNotifier {
  _NativePush() {
    unawaited(_initialize());
  }
  bool supported = false;
  String permission = 'unsupported', taskLink = '';
  String? token;
  int notificationVersion = 0, subscriptionVersion = 0;
  Future<void>? _initialization;
  Future<void> _initialize() => _initialization ??= _setup();
  Future<void> _setup() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      FirebaseMessaging.onBackgroundMessage(_backgroundMessage);
      supported = true;
      _settings(await FirebaseMessaging.instance.getNotificationSettings());
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
              alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((message) {
        notificationVersion++;
        notifyListeners();
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      FirebaseMessaging.instance.onTokenRefresh.listen((value) {
        token = value;
        subscriptionVersion++;
        notifyListeners();
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _open(initial);
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool('native_push_enabled') == true &&
          permission == 'granted') {
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
        // APNs must have registered before asking FCM for a token.
        if (defaultTargetPlatform != TargetPlatform.iOS ||
            await FirebaseMessaging.instance.getAPNSToken() != null) {
          token = await FirebaseMessaging.instance.getToken();
        }
      }
    } catch (_) {
      supported = false;
    }
    notifyListeners();
  }

  void _settings(NotificationSettings settings) {
    permission = switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        'granted',
      AuthorizationStatus.denied => 'denied',
      _ => 'default',
    };
  }

  void _open(RemoteMessage message) {
    final company = message.data['companyId'], task = message.data['taskId'];
    final valid = RegExp(r'^[A-Za-z0-9_-]{43}$');
    if (company is String &&
        task is String &&
        valid.hasMatch(company) &&
        valid.hasMatch(task)) {
      taskLink = '$company:$task';
      notificationVersion++;
      notifyListeners();
    }
  }

  Map<String, dynamic>? get subscription => token == null
      ? null
      : {
          'transport': 'fcm',
          'platform':
              defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          'token': token,
          'endpoint': 'fcm:$token',
        };
  Future<Map<String, dynamic>> subscribe() async {
    await _initialize();
    if (!supported) {
      throw StateError('Firebase is not configured for this app.');
    }
    _settings(await FirebaseMessaging.instance.requestPermission());
    notifyListeners();
    if (permission != 'granted') {
      throw StateError('Notification permission was not granted.');
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await FirebaseMessaging.instance.getAPNSToken() == null) {
      throw StateError('Apple push registration is not ready. Try again.');
    }
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    token = await FirebaseMessaging.instance.getToken();
    if (token == null) throw StateError('Device registration is unavailable.');
    await (await SharedPreferences.getInstance())
        .setBool('native_push_enabled', true);
    notifyListeners();
    return subscription!;
  }

  Future<void> unsubscribe() async {
    await _initialize();
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    await FirebaseMessaging.instance.deleteToken();
    token = null;
    await (await SharedPreferences.getInstance())
        .setBool('native_push_enabled', false);
    notifyListeners();
  }
}

class PwaRuntime extends ChangeNotifier {
  PwaRuntime() {
    _nativePush.addListener(notifyListeners);
  }
  Map<String, dynamic> get status => {
        'online': true,
        'installed': false,
        'installable': false,
        'updateAvailable': false,
        'pushSupported': _nativePush.supported,
        'pushTransport': 'fcm',
        'permission': _nativePush.permission,
        'pushSubscribed': _nativePush.token != null,
        'notificationVersion': _nativePush.notificationVersion,
        'subscriptionVersion': _nativePush.subscriptionVersion,
        'taskLink': _nativePush.taskLink,
      };
  Future<bool> install() async => false;
  Future<void> update() async {}
  Future<void> checkUpdate() async {}
  Future<bool> pendingWork() async => false;
  Future<Map<String, dynamic>> subscribe(String key) => _nativePush.subscribe();
  Future<Map<String, dynamic>?> subscription() async =>
      _nativePush.subscription;
  Future<void> unsubscribe() => _nativePush.unsubscribe();
  void clearTask() {
    _nativePush.taskLink = '';
  }

  @override
  void dispose() {
    _nativePush.removeListener(notifyListeners);
    super.dispose();
  }
}
