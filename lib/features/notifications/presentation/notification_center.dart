import 'package:tpc_invoice/core/widgets/app_spacing.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:tpc_invoice/core/network/push_device.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/pwa/pwa_runtime.dart';
import 'package:tpc_invoice/core/utils/business_time.dart';

class NotificationCenter extends StatefulWidget {
  const NotificationCenter(
      {super.key,
      required this.api,
      required this.companyId,
      required this.employee,
      required this.onTask,
      this.timeZone = 'Asia/Dubai',
      this.settingsEntry = false});
  final SaasApi api;
  final String companyId;
  final bool employee;
  final bool settingsEntry;
  final String timeZone;
  final ValueChanged<String> onTask;
  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter>
    with WidgetsBindingObserver {
  final _changes = ValueNotifier<int>(0);
  final _pwa = PwaRuntime();
  static const _android = MethodChannel('tpc/workspace_notifications');
  final _pushListeners = <StreamSubscription<dynamic>>[];
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _configuration = {};
  int _unread = 0;
  String? _nextCursor;
  String? _registeredToken;
  int? _webPushVersion;
  bool _webPushSupported = false;
  bool _pushBusy = false, _sheetOpen = false, _refreshQueued = false;
  Timer? _timer;
  bool _busy = false;
  String? _error;
  int _generation = 0;
  Map<String, dynamic>? _snapshot;
  String get _path =>
      widget.api.notificationsPath(widget.companyId, employee: widget.employee);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.api.cache.addListener(_cacheChanged);
    widget.api.cache.activate(_path);
    final webStatus = _pwa.status;
    _webPushVersion = webStatus['notificationVersion'] as int?;
    _webPushSupported = webStatus['pushSupported'] == true;
    _pwa.addListener(_webPushChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openWebNotification());
    if (nativePushPlatform != null && Firebase.apps.isNotEmpty) {
      _listenForNativePush();
    }
    unawaited(_load());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!widget.api.workspaceRealtimeConnected &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        unawaited(_load(force: true));
      }
    });
  }

  @override
  void didUpdateWidget(covariant NotificationCenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api ||
        oldWidget.companyId != widget.companyId ||
        oldWidget.employee != widget.employee) {
      oldWidget.api.cache.removeListener(_cacheChanged);
      oldWidget.api.cache.deactivate(oldWidget.api.notificationsPath(
          oldWidget.companyId,
          employee: oldWidget.employee));
      widget.api.cache.addListener(_cacheChanged);
      widget.api.cache.activate(_path);
      _generation++;
      _items = [];
      _configuration = {};
      _registeredToken = null;
      _unread = 0;
      _nextCursor = null;
      _refreshQueued = false;
      _pushBusy = false;
      _snapshot = null;
      _error = null;
      _busy = false;
      unawaited(_load(force: true));
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openWebNotification());
    }
  }

  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
      return;
    }
    if (mounted) {
      setState(() {});
      _changes.value++;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_load(force: true));
    }
  }

  void _webPushChanged() {
    final status = _pwa.status;
    final supported = status['pushSupported'] == true;
    if (supported != _webPushSupported) {
      _webPushSupported = supported;
      _notify();
      if (supported) unawaited(_registerPush());
    }
    final version = status['notificationVersion'] as int?;
    if (version == _webPushVersion) return;
    _webPushVersion = version;
    unawaited(_load(force: true));
    _openWebNotification();
  }

  void _openWebNotification() {
    if (!mounted || _pwa.status['notificationLink'] != widget.companyId) return;
    _pwa.clearNotification();
    unawaited(_open(refresh: false));
  }

  void _listenForNativePush() {
    _pushListeners.addAll([
      FirebaseMessaging.onMessage.listen((message) {
        if (message.data['companyId'] != widget.companyId) return;
        unawaited(_load(force: true));
        if (nativePushPlatform == 'android') {
          _android.invokeMethod<void>('show', message.data).ignore();
        }
      }),
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _openPush(m.data)),
      // Match the legacy token registration in nativePushRegistration.
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        unawaited(_registerPush());
      }, onError: (Object _) {}),
    ]);
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _openPush(message.data);
    }).ignore();
    if (nativePushPlatform == 'android') {
      _android.setMethodCallHandler((call) async {
        if (call.method == 'opened') _openPush(call.arguments as Map);
      });
      _android.invokeMapMethod<String, dynamic>('initial').then((data) {
        if (data != null) _openPush(data);
      }).ignore();
    }
  }

  void _openPush(Map data) {
    if (!mounted || data['companyId'] != widget.companyId) return;
    final task = data['taskId'];
    final id = data['notificationId'];
    if (task is String && task.isNotEmpty) {
      if (id is String) unawaited(_read(id, true));
      widget.onTask(task);
    } else {
      unawaited(_open());
    }
  }

  bool get _pushAvailable => nativePushPlatform != null
      ? Firebase.apps.isNotEmpty &&
          _configuration['nativePushAvailable'] == true
      : _configuration['pushAvailable'] == true &&
          _configuration['firebaseConfig'] is Map &&
          _webPushSupported;

  Future<void> _registerPush({bool requestPermission = false}) async {
    if (!_pushAvailable || _pushBusy) return;
    final generation = _generation;
    _pushBusy = true;
    if (requestPermission) _notify();
    try {
      final registration = nativePushPlatform != null
          ? await nativePushRegistration(requestPermission: requestPermission)
          : await _pwa.registerTaskPush(
              Map<String, dynamic>.from(
                  _configuration['firebaseConfig'] as Map),
              _configuration['vapidKey'] as String,
              requestPermission: requestPermission);
      if (!mounted || generation != _generation) return;
      if (registration == null) {
        _registeredToken = null;
        return;
      }
      final token = registration['token'] as String;
      if (token == _registeredToken) return;
      await widget.api.subscribePush(widget.companyId, registration,
          employee: widget.employee);
      if (mounted && generation == _generation) _registeredToken = token;
    } catch (error) {
      if (mounted && generation == _generation && requestPermission) {
        _error = error is SaasApiException
            ? error.message
            : error is StateError
                ? error.message
                : 'Unable to enable push notifications on this device.';
      }
    } finally {
      if (mounted && generation == _generation) {
        _pushBusy = false;
        _notify();
      }
    }
  }

  void _applyPage(Map<String, dynamic> data, {bool append = false}) {
    final page = (data['notifications'] as List? ?? [])
        .map((n) => Map<String, dynamic>.from(n as Map));
    _items = {
      if (append)
        for (final item in _items) item['id']: item,
      for (final item in page) item['id']: item,
    }.values.toList();
    _unread = (data['unread'] as num?)?.toInt() ??
        _items.where((n) => n['readAt'] == null).length;
    _nextCursor = data['nextCursor'] as String?;
    _configuration = data;
  }

  void _cacheChanged() {
    final data = widget.api.cache
        .state(widget.api
            .notificationsPath(widget.companyId, employee: widget.employee))
        ?.data;
    if (data == null || identical(data, _snapshot)) return;
    _snapshot = data;
    _applyPage(data);
    _notify();
  }

  Future<void> _load({bool force = false, bool more = false}) async {
    if (_busy) {
      if (force) _refreshQueued = true;
      return;
    }
    final cursor = more ? _nextCursor : null;
    _busy = true;
    final generation = _generation;
    _notify();
    try {
      final data = cursor == null
          ? await widget.api.notifications(widget.companyId,
              employee: widget.employee, force: force)
          : await widget.api.notificationPage(widget.companyId, cursor,
              employee: widget.employee);
      if (!mounted || generation != _generation) return;
      if (cursor == null) {
        // A forced read can return its saved page while the network refresh
        // finishes. Prefer the cache's latest page over that earlier snapshot.
        _applyPage(widget.api.cache.state(_path)?.data ?? data);
      } else {
        _applyPage(data, append: true);
      }
      _error = null;
      unawaited(_registerPush());
    } catch (error) {
      if (!mounted || generation != _generation) return;
      _error = error is SaasApiException
          ? error.message
          : 'Unable to load notifications. Reconnect and try again.';
    } finally {
      if (mounted && generation == _generation) {
        _busy = false;
        _notify();
        if (_refreshQueued) {
          _refreshQueued = false;
          unawaited(_load(force: true));
        }
      }
    }
  }

  Future<void> _read(String id, bool read) async {
    final generation = _generation;
    try {
      await widget.api.notificationRead(widget.companyId, id,
          employee: widget.employee, read: read);
      if (!mounted || generation != _generation) return;
      await _load(force: true);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _error = 'Could not update the read state. Please retry.';
      _notify();
    }
  }

  Future<void> _open({bool refresh = true}) async {
    if (_sheetOpen || !mounted) return;
    _sheetOpen = true;
    if (refresh) unawaited(_load(force: true));
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
                child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .8,
              child: ValueListenableBuilder<int>(
                  valueListenable: _changes,
                  builder: (context, _, _) =>
                      ListView(padding: AppSpacing.page(context), children: [
                        Text('Notifications',
                            style: Theme.of(context).textTheme.titleLarge),
                        Wrap(spacing: 8, children: [
                          TextButton.icon(
                              onPressed: () => _load(force: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh')),
                          TextButton(
                              onPressed: () => _read('all', true),
                              child: const Text('Mark all read')),
                        ]),
                        if (_pushAvailable)
                          ListTile(
                            leading:
                                const Icon(Icons.notifications_active_outlined),
                            title: Text(_registeredToken == null
                                ? 'Enable push notifications'
                                : 'Push notifications enabled'),
                            onTap: _pushBusy || _registeredToken != null
                                ? null
                                : () => _registerPush(requestPermission: true),
                            trailing:
                                _pushBusy ? const AppActivityIndicator() : null,
                          ),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        if (_busy) const Center(child: AppActivityIndicator()),
                        if (_items.isEmpty && !_busy && _error == null)
                          const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No notifications yet.')),
                        for (final item in _items)
                          Card(
                              child: ListTile(
                            leading: Icon(
                                switch (item['type']) {
                                  'task-due' || 'task-overdue' => Icons.alarm,
                                  'payroll-paid' ||
                                  'payroll-due' =>
                                    Icons.payments_outlined,
                                  _ => Icons.task_alt,
                                },
                                color: item['readAt'] == null
                                    ? Theme.of(context).colorScheme.primary
                                    : null),
                            title: Text('${item['title']}',
                                style: TextStyle(
                                    fontWeight: item['readAt'] == null
                                        ? FontWeight.w700
                                        : FontWeight.normal)),
                            subtitle: Text(
                                '${item['body']}\n${DateFormat.yMMMd().add_jm().format(businessTimestamp((item['createdAt'] as num).toInt(), widget.timeZone))} · ${widget.timeZone}'),
                            isThreeLine: true,
                            trailing: IconButton(
                                tooltip: item['readAt'] == null
                                    ? 'Mark read'
                                    : 'Mark unread',
                                onPressed: () => _read(
                                    '${item['id']}', item['readAt'] == null),
                                icon: Icon(item['readAt'] == null
                                    ? Icons.mark_email_read_outlined
                                    : Icons.mark_email_unread_outlined)),
                            onTap: () {
                              unawaited(_read('${item['id']}', true));
                              final task = item['taskId'];
                              final metadata = item['metadata'] as Map?;
                              if (task is String &&
                                  task.isNotEmpty &&
                                  metadata?['canOpenTask'] != false) {
                                Navigator.pop(context);
                                widget.onTask(task);
                              }
                            },
                          )),
                        if (_nextCursor != null)
                          TextButton(
                              onPressed: _busy ? null : () => _load(more: true),
                              child: const Text('Load more')),
                      ])),
            )));
    _sheetOpen = false;
  }

  @override
  void dispose() {
    widget.api.cache.deactivate(_path);
    widget.api.cache.removeListener(_cacheChanged);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pwa.dispose();
    for (final listener in _pushListeners) {
      unawaited(listener.cancel());
    }
    if (nativePushPlatform == 'android' && _pushListeners.isNotEmpty) {
      _android.setMethodCallHandler(null);
    }
    _changes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.settingsEntry
      ? ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Notifications'),
          subtitle: const Text('View task and payroll alerts'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open())
      : IconButton(
          tooltip: 'Notifications',
          onPressed: () => _open(),
          icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              child: const Icon(Icons.notifications_outlined)));
}
