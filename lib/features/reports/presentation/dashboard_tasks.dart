import 'package:tpc_invoice/core/widgets/loading.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

class DashboardTasks extends StatefulWidget {
  const DashboardTasks(
      {super.key,
      required this.api,
      required this.companyId,
      required this.employee,
      required this.onTask,
      this.active = true});
  final SaasApi api;
  final String companyId;
  final bool employee, active;
  final ValueChanged<String> onTask;
  @override
  State<DashboardTasks> createState() => _DashboardTasksState();
}

class _DashboardTasksState extends State<DashboardTasks> {
  static const _statuses = {
    'TODO': 'To do',
    'IN_PROGRESS': 'In progress',
    'IN_REVIEW': 'In review',
    'COMPLETED': 'Completed'
  };
  Map<String, int> _counts = {};
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _tasks = [];
  bool _busy = false;
  String? _error;
  int _generation = 0;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.active &&
          (WidgetsBinding.instance.lifecycleState == null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed)) {
        _load(force: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant DashboardTasks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api ||
        oldWidget.companyId != widget.companyId ||
        oldWidget.employee != widget.employee) {
      _generation++;
      _busy = false;
      _counts = {};
      _summary = {};
      _tasks = [];
      _load();
    } else if (!oldWidget.active && widget.active) {
      _load(force: true);
    }
  }

  Future<void> _load({bool force = false}) async {
    if (_busy || !widget.active) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait(_statuses.keys.map((status) =>
          widget.api.tasks(widget.companyId,
              employee: widget.employee,
              force: force,
              filters: {'status': status, 'sort': 'due', 'limit': '5'})));
      if (!mounted || generation != _generation) return;
      final tasks = <Map<String, dynamic>>[];
      final counts = <String, int>{};
      for (var i = 0; i < results.length; i++) {
        final status = _statuses.keys.elementAt(i);
        counts[status] = (results[i]['total'] as num?)?.toInt() ?? 0;
        if (status != 'COMPLETED') {
          tasks.addAll((results[i]['records'] as List? ?? [])
              .map((row) => Map<String, dynamic>.from(row as Map)));
        }
      }
      tasks.sort((a, b) => '${a['dueDate']}${a['endTime'] ?? '23:59'}'
          .compareTo('${b['dueDate']}${b['endTime'] ?? '23:59'}'));
      setState(() {
        _counts = counts;
        _summary =
            Map<String, dynamic>.from(results.first['summary'] as Map? ?? {});
        _tasks = tasks.take(5).toList();
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = error is SaasApiException
          ? error.message
          : 'Could not load tasks. Please retry.');
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 4))
        .toIso8601String()
        .substring(0, 10);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('Tasks overview',
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                    tooltip: 'Refresh tasks',
                    onPressed: _busy ? null : () => _load(force: true),
                    icon: const Icon(Icons.refresh))
              ]),
              const Text('Current tasks · deadlines use Dubai time'),
              if (_busy) const Center(child: AppActivityIndicator()),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              if (_counts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(
                      label: Text(
                          'Total: ${_counts.values.fold<int>(0, (a, b) => a + b)}')),
                  for (final status in _statuses.entries)
                    Chip(
                        label: Text(
                            '${status.value}: ${_counts[status.key] ?? 0}')),
                  Chip(label: Text('Due today: ${_summary['today'] ?? 0}')),
                  Chip(label: Text('Overdue: ${_summary['overdue'] ?? 0}')),
                ]),
                const SizedBox(height: 16),
                Text('Open tasks by deadline',
                    style: Theme.of(context).textTheme.titleMedium),
                if (_tasks.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No open tasks.')),
                for (final task in _tasks)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        '${task['dueDate']}'.compareTo(today) < 0
                            ? Icons.warning_amber
                            : Icons.task_alt,
                        color: '${task['dueDate']}'.compareTo(today) < 0
                            ? Theme.of(context).colorScheme.error
                            : null),
                    title: Text('${task['title'] ?? 'Task'}'),
                    subtitle: Text([
                      '${_statuses[task['status']] ?? task['status']} · ${task['priority'] ?? 'MEDIUM'} priority',
                      if ('${task['assigneeName'] ?? ''}'.isNotEmpty)
                        'Assigned to ${task['assigneeName']}',
                      if ('${task['project'] ?? ''}'.isNotEmpty)
                        'Project: ${task['project']}',
                      'Due ${task['dueDate']} at ${task['endTime'] == null || task['endTime'] == '' ? '23:59' : task['endTime']}',
                    ].join('\n')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onTask('${task['recordId']}'),
                  ),
              ],
            ])));
  }
}
