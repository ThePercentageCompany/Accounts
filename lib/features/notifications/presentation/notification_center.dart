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
      this.timeZone = 'Asia/Dubai'});
  final SaasApi api;
  final String companyId;
  final bool employee;
  final String timeZone;
  final ValueChanged<String> onTask;
  @override
  NotificationCenterState createState() => NotificationCenterState();
}

class NotificationCenterState extends State<NotificationCenter>
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
  String? _installationId, _pushFeedback;
  bool _testing = false;
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
      _installationId = null;
      _pushFeedback = null;
      _testing = false;
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
    if (requestPermission) {
      _pushFeedback = null;
      _notify();
    }
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
      if (mounted && generation == _generation) {
        _registeredToken = token;
        _installationId = registration['installationId'] as String;
      }
    } catch (error) {
      if (mounted && generation == _generation && requestPermission) {
        _pushFeedback = error is SaasApiException
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

  Future<void> _testPush() async {
    final installation = _installationId;
    if (_testing || _registeredToken == null || installation == null) return;
    final generation = _generation;
    _testing = true;
    _pushFeedback = null;
    _notify();
    try {
      await widget.api
          .testPush(widget.companyId, installation, employee: widget.employee);
      if (!mounted || generation != _generation) return;
      _pushFeedback =
          'Test queued. Switch away from the app to check for a device alert. Quiet hours can delay delivery.';
      unawaited(_load(force: true));
    } catch (error) {
      if (!mounted || generation != _generation) return;
      _pushFeedback = error is SaasApiException
          ? error.message
          : 'Could not queue the test. Check your connection and retry.';
    } finally {
      if (mounted && generation == _generation) {
        _testing = false;
        _notify();
      }
    }
  }

  Future<void> openSettings() async {
    unawaited(_load(force: true));
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) => SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: _changes,
          builder: (context, _, _) {
            final enabled = _registeredToken != null;
            final status = enabled
                ? 'Enabled on this device'
                : _pushAvailable
                    ? 'Off on this device'
                    : _busy && _configuration.isEmpty
                        ? 'Checking availability...'
                        : _error ??
                            (_configuration.isEmpty
                                ? 'Refresh to check push availability.'
                                : !_webPushSupported &&
                                        nativePushPlatform == null
                                    ? 'Push is unavailable here. On iPhone or iPad, add the website to your Home Screen and open it from there.'
                                    : 'Push is unavailable. Check the workspace push configuration.');
            return SingleChildScrollView(
              padding: AppSpacing.page(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Notification settings',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  Text('Device push',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(status),
                  const SizedBox(height: 12),
                  if (enabled)
                    FilledButton.tonalIcon(
                      onPressed: _testing || _pushBusy ? null : _testPush,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(_testing
                          ? 'Queuing test...'
                          : 'Send test notification'),
                    )
                  else if (_pushAvailable)
                    FilledButton.icon(
                      onPressed: _pushBusy
                          ? null
                          : () => _registerPush(requestPermission: true),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: Text(_pushBusy
                          ? 'Checking device...'
                          : 'Enable push notifications'),
                    )
                  else
                    TextButton.icon(
                      onPressed: _busy ? null : () => _load(force: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh availability'),
                    ),
                  if (_pushFeedback != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                          liveRegion: true, child: Text(_pushFeedback!)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
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
    try {
      final settings = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 680),
        builder: (context) {
          final theme = Theme.of(context);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .8,
              child: ValueListenableBuilder<int>(
                valueListenable: _changes,
                builder: (context, _, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Notifications',
                                  style: theme.textTheme.headlineSmall),
                              Text('$_unread unread'),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Notification settings',
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.settings_outlined),
                        ),
                        IconButton(
                          tooltip: 'Close notifications',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(children: [
                        TextButton.icon(
                          onPressed: _busy ? null : () => _load(force: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                        TextButton.icon(
                          onPressed: _unread == 0 || _busy
                              ? null
                              : () => _read('all', true),
                          icon: const Icon(Icons.done_all),
                          label: const Text('Mark all read'),
                        ),
                      ]),
                    ),
                    if (_busy && _items.isNotEmpty)
                      const LinearProgressIndicator(),
                    const Divider(height: 1),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_error!,
                            style: TextStyle(color: theme.colorScheme.error)),
                      ),
                    Expanded(
                      child: _items.isEmpty
                          ? Center(
                              child: _busy
                                  ? const AppActivityIndicator()
                                  : _error != null
                                      ? const SizedBox.shrink()
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.notifications_none,
                                                size: 40,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant),
                                            const SizedBox(height: 12),
                                            Text('No notifications yet',
                                                style: theme
                                                    .textTheme.titleMedium),
                                            const Text(
                                                'Task and payroll alerts will appear here.'),
                                          ],
                                        ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              itemCount:
                                  _items.length + (_nextCursor == null ? 0 : 1),
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                if (index == _items.length) {
                                  return TextButton(
                                    onPressed:
                                        _busy ? null : () => _load(more: true),
                                    child: const Text('Load more'),
                                  );
                                }
                                return _notificationTile(
                                    context, _items[index]);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (settings == true && mounted) await openSettings();
    } finally {
      _sheetOpen = false;
    }
  }

  Widget _notificationTile(BuildContext context, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final unread = item['readAt'] == null;
    final id = item['id'] as String;
    final task = item['taskId'];
    final canOpenTask = task is String &&
        task.isNotEmpty &&
        (item['metadata'] as Map?)?['canOpenTask'] != false;
    final timestamp = DateFormat.yMMMd().add_jm().format(
          businessTimestamp(
              (item['createdAt'] as num).toInt(), widget.timeZone),
        );
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: unread ? theme.colorScheme.primary.withAlpha(18) : null,
      leading: Icon(
        switch (item['type']) {
          'task-due' || 'task-overdue' => Icons.alarm,
          'payroll-paid' || 'payroll-due' => Icons.payments_outlined,
          'push-test' => Icons.notifications_active_outlined,
          _ => Icons.task_alt,
        },
        color: unread
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text('${item['title']}',
          style: unread ? const TextStyle(fontWeight: FontWeight.w700) : null),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item['body']}'),
            const SizedBox(height: 4),
            Text(timestamp,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
      trailing: IconButton(
        tooltip: unread ? 'Mark as read' : 'Mark as unread',
        onPressed: () => _read(id, unread),
        icon: Icon(unread
            ? Icons.mark_email_read_outlined
            : Icons.mark_email_unread_outlined),
      ),
      onTap: unread || canOpenTask
          ? () {
              if (unread) unawaited(_read(id, true));
              if (canOpenTask) {
                Navigator.pop(context);
                widget.onTask(task);
              }
            }
          : null,
    );
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
  Widget build(BuildContext context) => IconButton(
      tooltip: 'Notifications',
      onPressed: () => _open(),
      icon: Badge(
          isLabelVisible: _unread > 0,
          label: Text('$_unread'),
          child: const Icon(Icons.notifications_outlined)));
}
