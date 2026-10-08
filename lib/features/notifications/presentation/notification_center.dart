import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/pwa/pwa_runtime.dart';

class NotificationCenter extends StatefulWidget {
  const NotificationCenter(
      {super.key,
      required this.api,
      required this.companyId,
      required this.employee,
      required this.onTask});
  final SaasApi api;
  final String companyId;
  final bool employee;
  final ValueChanged<String> onTask;
  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter>
    with WidgetsBindingObserver {
  final _runtime = PwaRuntime();
  final _changes = ValueNotifier<int>(0);
  List<Map<String, dynamic>> _items = [];
  Timer? _timer;
  bool _busy = false, _pushBusy = false;
  String? _error, _publicKey;
  int _notificationVersion = 0, _generation = 0;
  bool _deviceEnabled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runtime.addListener(_runtimeChanged);
    widget.api.cache.addListener(_cacheChanged);
    unawaited(_load());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_load(force: true));
      }
    });
  }

  void _runtimeChanged() {
    final version = _runtime.status['notificationVersion'] as int? ?? 0;
    if (version != _notificationVersion) {
      _notificationVersion = version;
      unawaited(_load(force: true));
    }
    _notify();
  }

  @override
  void didUpdateWidget(covariant NotificationCenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api ||
        oldWidget.companyId != widget.companyId ||
        oldWidget.employee != widget.employee) {
      oldWidget.api.cache.removeListener(_cacheChanged);
      widget.api.cache.addListener(_cacheChanged);
      _generation++;
      _items = [];
      _publicKey = null;
      _error = null;
      _busy = false;
      _pushBusy = false;
      _deviceEnabled = false;
      unawaited(_load(force: true));
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
    if (state == AppLifecycleState.resumed) unawaited(_load(force: true));
  }

  void _cacheChanged() {
    final data = widget.api.cache
        .state(widget.api
            .notificationsPath(widget.companyId, employee: widget.employee))
        ?.data;
    if (data == null) return;
    _items = (data['notifications'] as List? ?? [])
        .map((n) => Map<String, dynamic>.from(n as Map))
        .toList();
    _publicKey = data['publicKey'] as String?;
    _notify();
  }

  Future<void> _load({bool force = false}) async {
    if (_busy) return;
    _busy = true;
    final generation = _generation;
    _notify();
    try {
      final data = await widget.api.notifications(widget.companyId,
          employee: widget.employee, force: force);
      if (!mounted || generation != _generation) return;
      final subscription = await _runtime.subscription();
      if (!mounted || generation != _generation) return;
      _deviceEnabled = subscription != null &&
          (data['pushEndpoints'] as List? ?? [])
              .contains(subscription['endpoint']);
      _items = (data['notifications'] as List? ?? [])
          .map((n) => Map<String, dynamic>.from(n as Map))
          .toList();
      _publicKey = data['publicKey'] as String?;
      _error = null;
    } catch (error) {
      if (!mounted || generation != _generation) return;
      _error = error is SaasApiException
          ? error.message
          : 'Unable to load notifications. Reconnect and try again.';
    } finally {
      if (mounted && generation == _generation) {
        _busy = false;
        _notify();
      }
    }
  }

  Future<void> _read(String id, bool read) async {
    try {
      await widget.api.notificationRead(widget.companyId, id,
          employee: widget.employee, read: read);
      await _load(force: true);
    } catch (_) {
      _error = 'Could not update the read state. Please retry.';
      _notify();
    }
  }

  Future<void> _enable() async {
    if (_publicKey == null || _pushBusy) return;
    _pushBusy = true;
    final generation = _generation;
    final api = widget.api;
    final companyId = widget.companyId;
    final employee = widget.employee;
    _notify();
    try {
      final subscription = await _runtime.subscribe(_publicKey!);
      if (!mounted || generation != _generation) return;
      await api.subscribePush(companyId, subscription, employee: employee);
      if (!mounted || generation != _generation) return;
      _deviceEnabled = true;
      _error = null;
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _error = _runtime.status['permission'] == 'denied'
          ? 'Notifications are blocked. Enable them in browser settings if you want task alerts.'
          : 'Notifications could not be enabled. Reconnect and try again.';
    } finally {
      if (mounted && generation == _generation) {
        _pushBusy = false;
        _notify();
      }
    }
  }

  Future<void> _disable() async {
    if (_pushBusy) return;
    final generation = _generation;
    final api = widget.api;
    final companyId = widget.companyId;
    final employee = widget.employee;
    _pushBusy = true;
    _notify();
    try {
      final subscription = await _runtime.subscription();
      if (subscription != null) {
        if (!mounted || generation != _generation) return;
        await api.unsubscribePush(companyId,
            employee: employee, endpoint: subscription['endpoint'] as String);
        await _runtime.unsubscribe();
      }
      if (!mounted || generation != _generation) return;
      _deviceEnabled = false;
      _error = null;
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _error = 'Could not disable notifications. Please retry.';
    } finally {
      if (mounted && generation == _generation) {
        _pushBusy = false;
        _notify();
      }
    }
  }

  Future<void> _open() async {
    unawaited(_load(force: true));
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
                      ListView(padding: const EdgeInsets.all(16), children: [
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
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                          'Get task assignments and deadline reminders even when the app is closed, where your browser supports it.'),
                                      const SizedBox(height: 12),
                                      if (_runtime.status['pushSupported'] !=
                                          true)
                                        const Text(
                                            'Push is unavailable in this browser. On iPhone/iPad, install the app from Safari first. You can still read notification history here.')
                                      else if (_publicKey == null)
                                        const Text(
                                            'Push alerts are awaiting administrator configuration. Notification history is still available.')
                                      else if (_runtime.status['permission'] ==
                                          'denied')
                                        const Text(
                                            'Permission is blocked. You can change it in browser settings.')
                                      else
                                        Wrap(spacing: 8, children: [
                                          FilledButton(
                                              onPressed:
                                                  _pushBusy || _deviceEnabled
                                                      ? null
                                                      : _enable,
                                              child: Text(_pushBusy
                                                  ? 'Enabling…'
                                                  : _deviceEnabled
                                                      ? 'Notifications enabled'
                                                      : 'Enable notifications')),
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Not now')),
                                          TextButton(
                                              onPressed:
                                                  _pushBusy ? null : _disable,
                                              child: const Text(
                                                  'Disable notifications')),
                                        ]),
                                    ]))),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        if (_busy) const LinearProgressIndicator(),
                        if (_items.isEmpty && !_busy)
                          const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No notifications yet.')),
                        for (final item in _items)
                          Card(
                              child: ListTile(
                            leading: Icon(
                                item['type'] == 'task-due'
                                    ? Icons.alarm
                                    : Icons.task_alt,
                                color: item['readAt'] == null
                                    ? Theme.of(context).colorScheme.primary
                                    : null),
                            title: Text('${item['title']}',
                                style: TextStyle(
                                    fontWeight: item['readAt'] == null
                                        ? FontWeight.w700
                                        : FontWeight.normal)),
                            subtitle: Text(
                                '${item['body']}\n${DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch((item['createdAt'] as num).toInt()).toUtc().add(const Duration(hours: 4)))} · Dubai time'),
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
                              Navigator.pop(context);
                              widget.onTask('${item['taskId']}');
                            },
                          )),
                      ])),
            )));
  }

  @override
  void dispose() {
    widget.api.cache.removeListener(_cacheChanged);
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _runtime.removeListener(_runtimeChanged);
    _runtime.dispose();
    _changes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: 'Notifications',
      onPressed: _open,
      icon: Badge(
          isLabelVisible: _items.any((n) => n['readAt'] == null),
          label: Text('${_items.where((n) => n['readAt'] == null).length}'),
          child: const Icon(Icons.notifications_outlined)));
}
