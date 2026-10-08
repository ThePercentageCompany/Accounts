import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

class NotificationCenter extends StatefulWidget {
  const NotificationCenter(
      {super.key,
      required this.api,
      required this.companyId,
      required this.employee,
      required this.onTask,
      this.settingsEntry = false});
  final SaasApi api;
  final String companyId;
  final bool employee;
  final bool settingsEntry;
  final ValueChanged<String> onTask;
  @override
  State<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends State<NotificationCenter>
    with WidgetsBindingObserver {
  final _changes = ValueNotifier<int>(0);
  List<Map<String, dynamic>> _items = [];
  Timer? _timer;
  bool _busy = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.api.cache.addListener(_cacheChanged);
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
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
      widget.api.cache.addListener(_cacheChanged);
      _generation++;
      _items = [];
      _error = null;
      _busy = false;
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
      _items = (data['notifications'] as List? ?? [])
          .map((n) => Map<String, dynamic>.from(n as Map))
          .toList();
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
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                                'Task assignments and deadline reminders appear here while you use the app. Notifications refresh automatically.')),
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
    _changes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.settingsEntry
      ? ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Notifications'),
          subtitle: const Text('View task alerts and unread notifications'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open())
      : IconButton(
          tooltip: 'Notifications',
          onPressed: () => _open(),
          icon: Badge(
              isLabelVisible: _items.any((n) => n['readAt'] == null),
              label: Text('${_items.where((n) => n['readAt'] == null).length}'),
              child: const Icon(Icons.notifications_outlined)));
}
