import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/cache/read_cache.dart';
import 'package:tpc_invoice/features/accounting/data/record_write_queue.dart';
import 'package:tpc_invoice/core/widgets/forms/date_time_field.dart';
import 'package:tpc_invoice/features/documents/data/document_upload_queue.dart';
import 'package:tpc_invoice/features/documents/presentation/record_documents_view.dart';

part 'task_day_agenda.dart';
part 'task_widgets.dart';
part 'task_editor.dart';
part 'task_details.dart';
part 'task_filters.dart';
part 'task_assignee_picker.dart';

const taskStatuses = ['TODO', 'IN_PROGRESS', 'IN_REVIEW', 'COMPLETED'];
const taskPriorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];
String taskLabel(String value) => value
    .toLowerCase()
    .split('_')
    .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
    .join(' ');
DateTime taskToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 4));
  return DateTime(now.year, now.month, now.day);
}

String taskDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
Color taskColor(String value) => switch (value) {
      'URGENT' => Colors.red,
      'HIGH' => Colors.deepOrange,
      'COMPLETED' => Colors.green,
      'IN_PROGRESS' => Colors.blue,
      'IN_REVIEW' => Colors.purple,
      _ => Colors.blueGrey
    };

class TaskWorkspace extends StatefulWidget {
  const TaskWorkspace(
      {super.key,
      required this.api,
      required this.companyId,
      this.employee,
      this.calendar = false,
      this.active = true,
      this.uploads,
      this.writes});
  final SaasApi api;
  final String companyId;
  final Map<String, dynamic>? employee;
  final bool calendar, active;
  final DocumentUploadQueue? uploads;
  final RecordWriteQueue? writes;
  @override
  State<TaskWorkspace> createState() => _TaskWorkspaceState();
}

class _TaskWorkspaceState extends State<TaskWorkspace>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  Timer? _debounce, _poll;
  final Set<String> _reminded = {};
  final Map<String, String> _pendingIds = {};
  List<Map<String, dynamic>> _tasks = [], _assignees = [];
  Map<String, dynamic> _summary = {}, _dateCounts = {};
  String _view = '',
      _scope = 'All',
      _sort = 'due',
      _boardStatus = 'TODO',
      _calendarView = '';
  Map<String, String> _filters = {};
  DateTime _date = taskToday();
  bool _busy = false, _loaded = false, _saving = false;
  String? _error;
  int _generation = 0,
      _total = 0,
      _lastRevision = 0,
      _surfaceDepth = 0,
      _mutationDepth = 0;
  String? _resource;
  bool _fetching = false, _appVisible = true;
  double _contentWidth = 0;
  int? _next;
  bool get _employee => widget.employee != null;
  bool get _manage =>
      !_employee ||
      (widget.employee!['writableSections'] as List? ?? []).contains('Tasks');
  bool get _calendar => widget.calendar || _view == 'Calendar';
  String get _employeeId => widget.employee?['employeeId']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.api.cache.addListener(_cacheChanged);
    _scope = _employee && !_manage ? 'My Tasks' : 'All';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recoverTasks();
    });
    if (_manage) _loadAssignees();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.active &&
          _appVisible &&
          !_fetching &&
          !_saving &&
          _surfaceDepth == 0 &&
          _mutationDepth == 0) {
        _load(quiet: true);
      }
    });
  }

  void _cacheChanged() {
    final resource = _resource;
    if (resource == null) return;
    final state = widget.api.cache.state(resource);
    if (state == null || state.revision == _lastRevision) return;
    _lastRevision = state.revision;
    if (widget.active &&
        _appVisible &&
        !_fetching &&
        _mutationDepth == 0 &&
        _surfaceDepth == 0) {
      scheduleMicrotask(() {
        if (mounted) _load(quiet: true);
      });
    }
  }

  bool get _pendingTask =>
      widget.writes?.pending
          .any((op) => ['Tasks', 'TaskComments'].contains(op['table'])) ??
      false;
  Future<void> _recoverTasks() async {
    if (!widget.active) return;
    if (_pendingTask && widget.writes?.canDiscardRejected == false) {
      try {
        await widget.writes!.flush();
      } catch (e) {
        _failure(e);
      }
    }
    if (mounted) await _load();
  }

  Future<void> _loadAssignees() async {
    try {
      final data =
          await widget.api.taskAssignees(widget.companyId, employee: _employee);
      if (mounted) {
        setState(() => _assignees =
            List<Map<String, dynamic>>.from(data['employees'] as List));
      }
    } catch (_) {/* The editor reports assignment loading errors with retry. */}
  }

  @override
  void didUpdateWidget(covariant TaskWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.active && widget.active) ||
        oldWidget.calendar != widget.calendar) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
    if (_appVisible && widget.active) _load(quiet: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.api.cache.removeListener(_cacheChanged);
    _search.dispose();
    _debounce?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Map<String, String> _query() {
    final today = taskToday();
    final filters = <String, String>{
      ..._filters,
      'sort': _sort,
      'limit': '40',
      if (_search.text.trim().isNotEmpty) 'search': _search.text.trim()
    };
    if (_scope == 'My Tasks' && _employeeId.isNotEmpty) {
      filters['employeeId'] = _employeeId;
    }
    if (_scope == 'Due Today') {
      filters['from'] = taskDate(today);
      filters['to'] = taskDate(today);
    }
    if (_scope == 'This Week') {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      filters['from'] = taskDate(monday);
      filters['to'] = taskDate(monday.add(const Duration(days: 6)));
    }
    if (_scope == 'Overdue') filters['overdue'] = 'true';
    if (_scope == 'Overdue') {
      filters['to'] = taskDate(today.subtract(const Duration(days: 1)));
    }
    if (_calendar) {
      final mode = _calendarView.isEmpty
          ? (_contentWidth < 768 ? 'Day' : 'Month')
          : _calendarView;
      final first = mode == 'Month'
          ? DateTime(_date.year, _date.month, 1)
          : mode == 'Week'
              ? _date.subtract(Duration(days: _date.weekday - 1))
              : _date;
      final last = mode == 'Month'
          ? DateTime(_date.year, _date.month + 1, 0)
          : mode == 'Week'
              ? first.add(const Duration(days: 6))
              : first;
      filters['from'] = taskDate(first);
      filters['to'] = taskDate(last);
    }
    return filters;
  }

  Future<void> _load({bool more = false, bool quiet = false}) async {
    if (!widget.active || (quiet && _fetching)) return;
    _fetching = true;
    final generation = ++_generation;
    if (!quiet && mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final filters = _query();
      final target = quiet ? _tasks.length : 40;
      if (target > 40) filters['limit'] = '100';
      if (more && _next != null) filters['offset'] = '$_next';
      _resource =
          '${widget.api.tasksPath(widget.companyId, employee: _employee)}?${Uri(queryParameters: filters).query}';
      // Display the query's saved page immediately, before its refresh. Keep
      // aggregate pages intact when loading more or doing background polling.
      final saved = widget.api.cache.state(_resource!)?.data;
      if (!_loaded && !more && saved != null && mounted) {
        setState(() {
          _tasks = (saved['records'] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          _summary = Map<String, dynamic>.from(saved['summary'] as Map? ?? {});
          _dateCounts =
              Map<String, dynamic>.from(saved['dateCounts'] as Map? ?? {});
          _loaded = true;
        });
      }
      _lastRevision = widget.api.cache.state(_resource!)?.revision ?? 0;
      final data = Map<String, dynamic>.from(await widget.api.tasks(
          widget.companyId,
          employee: _employee,
          force: quiet || more,
          filters: filters));
      if (quiet && !more) {
        final rows = List<Map<String, dynamic>>.from(data['records'] as List);
        while (rows.length < target &&
            data['nextOffset'] != null &&
            mounted &&
            generation == _generation) {
          filters['offset'] = data['nextOffset'].toString();
          final page = await widget.api.tasks(widget.companyId,
              employee: _employee, force: true, filters: filters);
          rows.addAll(List<Map<String, dynamic>>.from(page['records'] as List));
          data['nextOffset'] = page['nextOffset'];
        }
        data['records'] = rows;
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        final rows = List<Map<String, dynamic>>.from(data['records'] as List);
        _tasks = more ? [..._tasks, ...rows] : rows;
        _dateCounts =
            Map<String, dynamic>.from(data['dateCounts'] as Map? ?? {});
        _summary = Map<String, dynamic>.from(data['summary'] as Map? ?? {});
        for (final reminder
            in (data['reminders'] as List? ?? []).whereType<Map>()) {
          final key = reminder.toString();
          if (_reminded.add(key) && widget.active) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Task reminder: ${reminder['title']}')));
          }
        }
        _total = data['total'] as int;
        _next = data['nextOffset'] as int?;
        _loaded = true;
        _busy = false;
        _error = null;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.toString();
          if (e is SaasApiException && (e.status == 401 || e.status == 403)) {
            _tasks = [];
            _summary = {};
            _dateCounts = {};
          }
          _busy = false;
        });
      }
    } finally {
      if (generation == _generation) _fetching = false;
    }
  }

  Future<void> _write(
      String table, Map<String, dynamic>? row, Map<String, Object?> values,
      {String? operationId}) async {
    _mutationDepth++;
    try {
      final signature = dataFingerprint({
        'table': table,
        'recordId': row?['recordId'],
        'version': row == null ? 0 : int.parse(row['recordVersion'].toString()),
        'values': values
      });
      final queue = widget.writes;
      if (queue != null) {
        if (queue.pending.isNotEmpty) {
          final pending = queue.pending.single;
          final previous = dataFingerprint({
            'table': pending['table'],
            'recordId': pending['recordId'],
            'version': pending['expectedVersion'],
            'values': pending['values']
          });
          if (previous != signature) {
            throw const SaasApiException('PENDING',
                'Confirm or discard the rejected pending change before saving another change.');
          }
        } else {
          await queue.enqueue(table, row == null ? 'create' : 'update', values,
              recordId: row?['recordId'] as String?,
              expectedVersion:
                  row == null ? 0 : int.parse(row['recordVersion'].toString()));
        }
        await queue.flush();
        await _load();
        return;
      }
      final stableId = operationId ??
          _pendingIds.putIfAbsent(signature, () => const Uuid().v4());
      final response = await widget.api.sync(
          widget.companyId,
          [
            {
              'operationId': stableId,
              'table': table,
              'action': row == null ? 'create' : 'update',
              if (row != null) 'recordId': row['recordId'],
              'expectedVersion':
                  row == null ? 0 : int.parse('${row['recordVersion']}'),
              'values': values,
            }
          ],
          employee: _employee,
          expectedEmployeeId: _employeeId.isEmpty ? null : _employeeId);
      final result = (response['results'] as List).single as Map;
      if (result['status'] != 'APPLIED') {
        throw SaasApiException(
            '${result['error']?['code'] ?? 'TASK_SAVE_FAILED'}',
            '${result['error']?['message'] ?? 'Task was not saved. Retry.'}');
      }
      _pendingIds.remove(signature);
      await _load();
    } finally {
      _mutationDepth--;
    }
  }

  void _failure(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _status(Map<String, dynamic> task, String status) async {
    if (_saving || task['status'] == status) return;
    setState(() => _saving = true);
    try {
      await _write('Tasks', task, {'status': status});
    } catch (e) {
      _failure(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? task]) async {
    if (!_manage) return;
    _surfaceDepth++;
    await _taskSurface(
        context,
        TaskEditor(
            api: widget.api,
            companyId: widget.companyId,
            employee: _employee,
            task: task,
            assignees: _assignees,
            onSave: (values, operationId) =>
                _write('Tasks', task, values, operationId: operationId)));
    _surfaceDepth--;
    if (mounted) {
      _loadAssignees();
      _load(quiet: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> task) async {
    _mutationDepth++;
    try {
      final queue = widget.writes;
      if (queue != null) {
        if (queue.pending.isEmpty) {
          await queue.enqueue('Tasks', 'delete', {},
              recordId: task['recordId'].toString(),
              expectedVersion: int.parse(task['recordVersion'].toString()));
        } else if (queue.pending.length != 1 ||
            queue.pending.single['table'] != 'Tasks' ||
            queue.pending.single['action'] != 'delete' ||
            queue.pending.single['recordId'] != task['recordId']) {
          throw const SaasApiException(
              'PENDING', 'Confirm the pending change first.');
        }
        await queue.flush();
      } else {
        final key = 'delete:${task['recordId']}:${task['recordVersion']}';
        final response = await widget.api.sync(
            widget.companyId,
            [
              {
                'operationId':
                    _pendingIds.putIfAbsent(key, () => const Uuid().v4()),
                'table': 'Tasks',
                'action': 'delete',
                'recordId': task['recordId'],
                'expectedVersion': int.parse(task['recordVersion'].toString())
              }
            ],
            employee: _employee,
            expectedEmployeeId: _employeeId.isEmpty ? null : _employeeId);
        final result = (response['results'] as List).single as Map;
        if (result['status'] != 'APPLIED') {
          throw SaasApiException(result['error']['code'].toString(),
              result['error']['message'].toString());
        }
        _pendingIds.remove(key);
      }
      if (mounted) await _load();
    } finally {
      _mutationDepth--;
    }
  }

  Future<void> _detail(Map<String, dynamic> task) async {
    _surfaceDepth++;
    await _taskSurface(
        context,
        TaskDetails(
            api: widget.api,
            companyId: widget.companyId,
            employee: _employee,
            employeeId: _employeeId,
            manage: _manage,
            task: task,
            uploads: widget.uploads,
            onWrite: _write,
            onDelete: _delete,
            onEdit: _edit),
        drawer: true);
    _surfaceDepth--;
    if (mounted) _load(quiet: true);
  }

  void _change(VoidCallback change) {
    setState(change);
    _load();
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        _contentWidth = constraints.maxWidth;
        final mobile = constraints.maxWidth < 768;
        final view = _view.isEmpty ? (mobile ? 'List' : 'Board') : _view;
        return RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding:
                  EdgeInsets.fromLTRB(mobile ? 0 : 8, 8, mobile ? 0 : 8, 32),
              children: [
                Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            widget.calendar
                                ? 'Calendar'
                                : _employee && !_manage
                                    ? 'My Tasks'
                                    : 'Tasks',
                            style: Theme.of(context).textTheme.headlineSmall),
                        Text(
                            widget.calendar
                                ? 'Your team schedule · UAE time'
                                : 'Assign, track and complete your work',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ])),
                  if (_manage)
                    mobile
                        ? IconButton.filled(
                            tooltip: 'Create task',
                            onPressed: () => _edit(),
                            icon: const Icon(Icons.add))
                        : FilledButton.icon(
                            onPressed: () => _edit(),
                            icon: const Icon(Icons.add),
                            label: const Text('New Task'))
                ]),
                const SizedBox(height: 16),
                if (_pendingTask)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                    'A task change is awaiting confirmation.'),
                                TextButton(
                                    onPressed: _recoverTasks,
                                    child: const Text('Retry pending change')),
                                if (widget.writes!.canDiscardRejected)
                                  TextButton(
                                      onPressed: () async {
                                        await widget.writes!.discardRejected();
                                        if (mounted) _load();
                                      },
                                      child: const Text(
                                          'Discard rejected change')),
                              ]))),
                if (_employee && !_manage && !_calendar) ...[
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final item in [
                      ('To do', 'todo'),
                      ('In progress', 'inProgress'),
                      ('Due today', 'today'),
                      ('Overdue', 'overdue')
                    ])
                      ActionChip(
                          label: Text('${_summary[item.$2] ?? 0}  ${item.$1}'),
                          onPressed: () => _change(() {
                                _scope = item.$2 == 'today'
                                    ? 'Due Today'
                                    : item.$2 == 'overdue'
                                        ? 'Overdue'
                                        : 'My Tasks';
                                _filters = item.$2 == 'todo'
                                    ? {'status': 'TODO'}
                                    : item.$2 == 'inProgress'
                                        ? {'status': 'IN_PROGRESS'}
                                        : {};
                              })),
                  ]),
                  const SizedBox(height: 12),
                ],
                TextField(
                    controller: _search,
                    decoration: InputDecoration(
                        hintText: 'Search tasks',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _search.clear();
                                  _load();
                                },
                                icon: const Icon(Icons.close))),
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(
                          const Duration(milliseconds: 350), () => _load());
                    }),
                const SizedBox(height: 12),
                if (!widget.calendar)
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final scope in [
                          'All',
                          if (_employee) 'My Tasks',
                          'Due Today',
                          'This Week',
                          'Overdue'
                        ])
                          Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                  label: Text(scope),
                                  selected: _scope == scope,
                                  onSelected: (_) =>
                                      _change(() => _scope = scope))),
                      ])),
                const SizedBox(height: 8),
                if (mobile)
                  Row(children: [
                    OutlinedButton.icon(
                        onPressed: _filterSheet,
                        icon: const Icon(Icons.tune),
                        label: Text(
                            'Filters${_filters.isEmpty ? '' : ' (${_filters.length})'}')),
                    const Spacer(),
                    _sortMenu()
                  ])
                else
                  Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_manage)
                          SizedBox(
                              width: 220,
                              child: _filterField('employeeId', 'Employee', {
                                for (final e in _assignees)
                                  '${e['recordId']}': '${e['fullName']}'
                              })),
                        SizedBox(
                            width: 180,
                            child: _filterField('status', 'Status', {
                              for (final s in taskStatuses) s: taskLabel(s)
                            })),
                        SizedBox(
                            width: 160,
                            child: _filterField('priority', 'Priority', {
                              for (final s in taskPriorities) s: taskLabel(s)
                            })),
                        SizedBox(
                            width: 180,
                            child: TextFormField(
                                initialValue: _filters['project'],
                                decoration:
                                    const InputDecoration(labelText: 'Project'),
                                onFieldSubmitted: (v) => _change(() {
                                      if (v.trim().isEmpty) {
                                        _filters.remove('project');
                                      } else {
                                        _filters['project'] = v.trim();
                                      }
                                    }))),
                        _sortMenu(),
                        if (_filters.isNotEmpty)
                          TextButton(
                              onPressed: () => _change(() => _filters.clear()),
                              child: const Text('Clear filters')),
                      ]),
                if (!widget.calendar) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, children: [
                    for (final v in ['Board', 'List', 'Calendar'])
                      ChoiceChip(
                          label: Text(v),
                          selected: view == v,
                          onSelected: (_) => _change(() => _view = v))
                  ])
                ],
                const SizedBox(height: 16),
                if (_error != null)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(children: [
                            Text(_error!),
                            TextButton.icon(
                                onPressed: () => _load(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'))
                          ]))),
                if (_busy && !_loaded) ...[
                  for (var i = 0; i < 4; i++) const _TaskSkeleton()
                ] else if (_calendar)
                  _calendarBody(mobile)
                else if (view == 'Board')
                  _board(mobile, constraints.maxWidth)
                else
                  _taskList(mobile),
                if (_employee &&
                    !_manage &&
                    !_calendar &&
                    (_summary['upcoming'] as List? ?? []).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Upcoming',
                      style: Theme.of(context).textTheme.titleMedium),
                  for (final day
                      in (_summary['upcoming'] as List).whereType<Map>())
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(day['date'].toString()),
                        subtitle: Text('${day['count']} tasks'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _change(() {
                              _date = DateTime.parse(day['date'].toString());
                              _view = 'Calendar';
                              _calendarView = 'Day';
                            })),
                ],
                if (_busy && _loaded)
                  const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator()),
                if (_next != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: OutlinedButton(
                          onPressed: _busy ? null : () => _load(more: true),
                          child:
                              Text('Load more (${_tasks.length} of $_total)'))),
                if (_loaded && !_busy && _tasks.isEmpty && !_calendar)
                  Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(children: [
                        const Icon(Icons.task_alt, size: 48),
                        const SizedBox(height: 12),
                        const Text('No tasks match this view.'),
                        if (_manage)
                          TextButton(
                              onPressed: () => _edit(),
                              child: const Text('Create a task'))
                      ])),
              ],
            ));
      });
  Widget _sortMenu() => PopupMenuButton<String>(
      tooltip: 'Sort tasks',
      initialValue: _sort,
      onSelected: (s) => _change(() => _sort = s),
      itemBuilder: (_) => [
            for (final pair in [
              ('due', 'Due date'),
              ('priority', 'Priority'),
              ('updated', 'Recently updated')
            ])
              PopupMenuItem(value: pair.$1, child: Text(pair.$2))
          ],
      child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('Sort'), Icon(Icons.arrow_drop_down)])));
  Widget _filterField(String key, String title, Map<String, String> options) =>
      key == 'employeeId'
          ? TaskAssigneeField(
              api: widget.api,
              companyId: widget.companyId,
              employee: _employee,
              value: _filters[key] ?? '',
              name: options[_filters[key]] ?? 'Selected employee',
              onChanged: (e) => _change(() {
                    if (e['recordId'] == '') {
                      _filters.remove(key);
                    } else {
                      _filters[key] = e['recordId'].toString();
                      _assignees = [
                        ..._assignees
                            .where((r) => r['recordId'] != e['recordId']),
                        e
                      ];
                    }
                  }))
          : DropdownButtonFormField<String>(
              key: ValueKey((key, _filters[key], options.length)),
              initialValue:
                  options.containsKey(_filters[key]) ? _filters[key] : '',
              isExpanded: true,
              decoration: InputDecoration(labelText: title),
              items: [
                DropdownMenuItem(
                    value: '', child: Text('All ${title.toLowerCase()}')),
                for (final e in options.entries)
                  DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis))
              ],
              onChanged: (v) => _change(() {
                    if (v == null || v.isEmpty) {
                      _filters.remove(key);
                    } else {
                      _filters[key] = v;
                    }
                  }));
  Future<void> _filterSheet() async {
    final filters = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => TaskFilters(
            api: widget.api,
            companyId: widget.companyId,
            employee: _employee,
            filters: _filters,
            manage: _manage,
            assignees: _assignees));
    if (filters != null && mounted) _change(() => _filters = filters);
  }

  List<Map<String, dynamic>> get _visible => _scope == 'Overdue'
      ? _tasks.where((t) => t['status'] != 'COMPLETED').toList()
      : _tasks;
  Widget _card(Map<String, dynamic> task) => TaskCard(
      task: task,
      onTap: () => _detail(task),
      onEdit: _manage ? () => _edit(task) : null);
  Widget _taskList(bool mobile) {
    if (mobile) return Column(children: [for (final t in _visible) _card(t)]);
    return Column(children: [
      const Padding(
          padding: EdgeInsets.all(12),
          child: Row(children: [
            Expanded(flex: 3, child: Text('Task')),
            Expanded(flex: 2, child: Text('Employee')),
            Expanded(child: Text('Priority')),
            Expanded(flex: 2, child: Text('Status')),
            Expanded(flex: 2, child: Text('Due'))
          ])),
      for (final t in _visible)
        Card(
            child: InkWell(
                onTap: () => _detail(t),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                          flex: 3,
                          child: Text('${t['title']}',
                              maxLines: 2, overflow: TextOverflow.ellipsis)),
                      Expanded(
                          flex: 2,
                          child: Text('${t['assigneeName']}',
                              maxLines: 2, overflow: TextOverflow.ellipsis)),
                      Expanded(child: Text(taskLabel('${t['priority']}'))),
                      Expanded(
                          flex: 2, child: Text(taskLabel('${t['status']}'))),
                      Expanded(
                          flex: 2,
                          child: Text('${t['dueDate']} ${t['endTime'] ?? ''}'))
                    ])))),
    ]);
  }

  Widget _board(bool mobile, double width) {
    Widget column(String status, double columnWidth) => SizedBox(
        width: columnWidth,
        child: DragTarget<Map<String, dynamic>>(
          onWillAcceptWithDetails: (d) =>
              !_saving && (_manage || d.data['employeeId'] == _employeeId),
          onAcceptWithDetails: (d) => _status(d.data, status),
          builder: (context, candidates, rejected) => Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: candidates.isNotEmpty
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                            '${taskLabel(status)} · ${_visible.where((t) => t['status'] == status).length}',
                            style: Theme.of(context).textTheme.titleSmall)),
                    for (final t
                        in _visible.where((t) => t['status'] == status))
                      _manage || t['employeeId'] == _employeeId
                          ? LongPressDraggable<Map<String, dynamic>>(
                              data: t,
                              feedback: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                      width: columnWidth - 16,
                                      child: _card(t))),
                              childWhenDragging:
                                  Opacity(opacity: .4, child: _card(t)),
                              child: _card(t))
                          : _card(t),
                    if (!_visible.any((t) => t['status'] == status))
                      const Padding(
                          padding: EdgeInsets.all(20), child: Text('No tasks')),
                  ])),
        ));
    if (mobile) {
      return Column(children: [
        DropdownButtonFormField<String>(
            initialValue: _boardStatus,
            isExpanded: true,
            items: [
              for (final s in taskStatuses)
                DropdownMenuItem(value: s, child: Text(taskLabel(s)))
            ],
            onChanged: (s) => setState(() => _boardStatus = s!),
            decoration: const InputDecoration(labelText: 'Board column')),
        const SizedBox(height: 12),
        column(_boardStatus, width)
      ]);
    }
    final columnWidth = width >= 1024 ? (width - 52) / 4 : 280.0;
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final s in taskStatuses)
            Padding(
                padding: const EdgeInsets.only(right: 12),
                child: column(s, columnWidth))
        ]));
  }

  Widget _calendarBody(bool mobile) {
    final mode =
        _calendarView.isEmpty ? (mobile ? 'Day' : 'Month') : _calendarView;
    final first = DateTime(_date.year, _date.month, 1);
    final count = DateTime(_date.year, _date.month + 1, 0).day;
    final selectedTasks =
        _tasks.where((t) => t['dueDate'] == taskDate(_date)).toList();
    void move(int direction) => _change(() {
          _date = mode == 'Month'
              ? DateTime(_date.year, _date.month + direction, 1)
              : _date.add(Duration(days: direction * (mode == 'Week' ? 7 : 1)));
        });
    Widget dayCell(DateTime date, {bool dense = false}) {
      final events =
          _tasks.where((t) => t['dueDate'] == taskDate(date)).toList();
      final selected = taskDate(date) == taskDate(_date);
      return Semantics(
          label:
              '${DateFormat.yMMMMd().format(date)}, ${_dateCounts[taskDate(date)] ?? events.length} tasks',
          button: true,
          selected: selected,
          child: InkWell(
              onTap: () => _change(() => _date = date),
              child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${date.day}',
                            textAlign:
                                dense ? TextAlign.center : TextAlign.left,
                            style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        if (dense)
                          Expanded(
                              child: Center(
                                  child: Wrap(spacing: 2, children: [
                            for (var i = 0;
                                i <
                                    ((_dateCounts[taskDate(date)] ??
                                            events.length) as int)
                                        .clamp(0, 3);
                                i++)
                              Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                      color: i < events.length
                                          ? taskColor(
                                              events[i]['priority'].toString())
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
                                      shape: BoxShape.circle))
                          ])))
                        else ...[
                          for (final t in events.take(2))
                            InkWell(
                                onTap: () => _detail(t),
                                child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                        '${t['endTime'] ?? ''} ${t['title']}\n${t['assigneeName']}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                taskColor('${t['status']}'))))),
                          if ((_dateCounts[taskDate(date)] ?? events.length) >
                              2)
                            Text(
                                '+${(_dateCounts[taskDate(date)] ?? events.length) - events.take(2).length} more',
                                style: const TextStyle(fontSize: 11))
                        ],
                      ]))));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          spacing: 4,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
                onPressed: () => _change(() => _date = taskToday()),
                child: const Text('Today')),
            IconButton(
                tooltip: 'Previous $mode',
                onPressed: () => move(-1),
                icon: const Icon(Icons.chevron_left)),
            Text(
                DateFormat(mode == 'Month' ? 'MMMM yyyy' : 'd MMM yyyy')
                    .format(_date),
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
                tooltip: 'Next $mode',
                onPressed: () => move(1),
                icon: const Icon(Icons.chevron_right)),
          ]),
      Wrap(spacing: 8, children: [
        for (final v in ['Month', 'Week', 'Day'])
          ChoiceChip(
              label: Text(v),
              selected: mode == v,
              onSelected: (_) => _change(() => _calendarView = v))
      ]),
      const SizedBox(height: 12),
      if (mode == 'Month') ...[
        Row(children: [
          for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
            Expanded(child: Center(child: Text(d)))
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(
            builder: (context, c) => GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: mobile ? (c.maxWidth / 7 / 48) : .95,
                    children: [
                      for (var i = 0;
                          i < ((first.weekday - 1 + count + 6) ~/ 7) * 7;
                          i++)
                        i < first.weekday - 1 || i >= first.weekday - 1 + count
                            ? const SizedBox.shrink()
                            : dayCell(
                                DateTime(_date.year, _date.month,
                                    i - first.weekday + 2),
                                dense: mobile),
                    ])),
        const SizedBox(height: 16),
      ],
      if (mode == 'Week') ...[
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var i = 0; i < 7; i++)
                Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                        label: Text(DateFormat('EEE d').format(_date
                            .subtract(Duration(days: _date.weekday - 1))
                            .add(Duration(days: i)))),
                        selected: i == _date.weekday - 1,
                        onSelected: (_) => _change(() => _date = _date
                            .subtract(Duration(days: _date.weekday - 1))
                            .add(Duration(days: i)))))
            ])),
        if (!mobile)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                  child: Column(children: [
                for (final t in _tasks.where((t) =>
                    t['dueDate'] ==
                    taskDate(_date
                        .subtract(Duration(days: _date.weekday - 1))
                        .add(Duration(days: i)))))
                  _card(t)
              ]))
          ]),
      ],
      Text(DateFormat('EEEE, d MMMM').format(_date),
          style: Theme.of(context).textTheme.titleMedium),
      Text(
          '${_dateCounts[taskDate(_date)] ?? selectedTasks.length} tasks${_next != null ? ' · more tasks available below' : ''}'),
      const SizedBox(height: 8),
      if (mode == 'Day') ...[
        if (selectedTasks.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No scheduled tasks for this date.')),
        for (final t in selectedTasks) _card(t),
      ] else
        _TaskDayAgenda(
            key: ValueKey((taskDate(_date), dataFingerprint(_filters))),
            api: widget.api,
            companyId: widget.companyId,
            employee: _employee,
            filters: {
              ..._query(),
              'from': taskDate(_date),
              'to': taskDate(_date)
            },
            initial: selectedTasks,
            expectedCount:
                (_dateCounts[taskDate(_date)] ?? selectedTasks.length) as int,
            revision: _generation,
            onOpen: _detail),
    ]);
  }
}
