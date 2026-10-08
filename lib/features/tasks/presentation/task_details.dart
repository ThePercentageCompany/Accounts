part of 'task_workspace.dart';

class TaskDetails extends StatefulWidget {
  const TaskDetails(
      {super.key,
      required this.api,
      required this.companyId,
      required this.employee,
      required this.employeeId,
      required this.manage,
      required this.task,
      required this.onWrite,
      required this.onEdit,
      this.onDelete,
      this.uploads,
      this.writes});
  final SaasApi api;
  final String companyId, employeeId;
  final bool employee, manage;
  final Map<String, dynamic> task;
  final DocumentUploadQueue? uploads;
  final RecordWriteQueue? writes;
  final Future<void> Function(
      String table, Map<String, dynamic>? row, Map<String, Object?> values,
      {String? operationId}) onWrite;
  final Future<void> Function(Map<String, dynamic>? task) onEdit;
  final Future<void> Function(Map<String, dynamic> task)? onDelete;
  @override
  State<TaskDetails> createState() => _TaskDetailsState();
}

class _TaskDetailsState extends State<TaskDetails> {
  late Map<String, dynamic> _task = widget.task;
  List<Map<String, dynamic>> _comments = [], _activity = [];
  final _comment = TextEditingController();
  final _commentForm = GlobalKey<FormState>();
  String? _error;
  bool _loading = true, _busy = false, _unavailable = false;
  String _commentId = const Uuid().v4(), _lastComment = '';
  bool get _canStatus =>
      widget.manage || _task['employeeId'] == widget.employeeId;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if ('${_task['recordId']}'.startsWith('local_')) {
      if (mounted) {
        setState(() {
          _comments = (widget.writes?.visibleRows('TaskComments', _comments) ??
                  _comments)
              .where((c) => c['taskId'] == _task['recordId'])
              .toList();
          _loading = false;
        });
      }
      return;
    }
    try {
      final data = await widget.api.taskDetail(
          widget.companyId, '${_task['recordId']}',
          employee: widget.employee);
      if (mounted) {
        setState(() {
          _unavailable = false;
          final serverTask = Map<String, dynamic>.from(data['task'] as Map);
          _task = (widget.writes?.visibleRows('Tasks', [serverTask]) ??
                  [serverTask])
              .firstWhere((t) => t['recordId'] == serverTask['recordId']);
          _comments = (widget.writes?.visibleRows(
                      'TaskComments',
                      List<Map<String, dynamic>>.from(
                          data['comments'] as List)) ??
                  List<Map<String, dynamic>>.from(data['comments'] as List))
              .where((c) => c['taskId'] == _task['recordId'])
              .toList();
          _activity = List<Map<String, dynamic>>.from(data['activity'] as List);
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _unavailable =
              e is SaasApiException && [401, 403, 404].contains(e.status);
          _loading = false;
        });
      }
    }
  }

  Future<void> _status(String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onWrite('Tasks', _task, {'status': status});
      if (mounted) setState(() => _task = {..._task, 'status': status});
      // The workspace overlay carries the pending version; a refresh must not
      // replace it with an older server snapshot.
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addComment() async {
    final body = _comment.text.trim();
    if (_busy || !AppFormValidation.validate(_commentForm.currentState!)) {
      return;
    }
    if (_lastComment != body) {
      _lastComment = body;
      _commentId = const Uuid().v4();
    }
    setState(() => _busy = true);
    try {
      await widget.onWrite(
          'TaskComments', null, {'taskId': _task['recordId'], 'body': body},
          operationId: _commentId);
      _comment.clear();
      _lastComment = '';
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteTask() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete task?'),
                content: const Text(
                    'The task will leave the board and calendar. Its history is retained.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'))
                ]));
    if (confirmed != true || !mounted || widget.onDelete == null) return;
    setState(() => _busy = true);
    try {
      await widget.onDelete!(_task);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _stamp(dynamic value) {
    final parsed = int.tryParse('$value');
    return parsed == null
        ? ''
        : DateFormat('d MMM, HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(parsed, isUtc: true)
                .add(const Duration(hours: 4)));
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) {
      return Scaffold(
          appBar: AppBar(title: const Text('Task unavailable')),
          body: Center(child: Text(_error ?? 'Task is unavailable.')));
    }
    Widget information() =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
              key: ValueKey(_task['status']),
              initialValue: '${_task['status']}',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final s in taskStatuses)
                  DropdownMenuItem(value: s, child: Text(taskLabel(s)))
              ],
              onChanged: _canStatus && !_busy ? (s) => _status(s!) : null),
          const SizedBox(height: 16),
          Text('${taskLabel('${_task['priority']}')} priority',
              style: TextStyle(color: taskColor('${_task['priority']}'))),
          const SizedBox(height: 16),
          Text('Assigned to', style: Theme.of(context).textTheme.labelMedium),
          Text('${_task['assigneeName'] ?? ''}'),
          const SizedBox(height: 16),
          Text('Due · UAE time',
              style: Theme.of(context).textTheme.labelMedium),
          Text('${_task['dueDate']} ${_task['endTime'] ?? ''}'),
          if ('${_task['startDate'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Starts ${_task['startDate']} ${_task['startTime'] ?? ''}')
          ],
          if ('${_task['project'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Project', style: Theme.of(context).textTheme.labelMedium),
            Text('${_task['project']}')
          ],
          if ('${_task['tags'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final tag in '${_task['tags']}'.split(','))
                Chip(label: Text(tag.trim()))
            ])
          ],
          const SizedBox(height: 16),
          if (widget.manage && widget.onDelete != null)
            TextButton.icon(
                onPressed: _busy ? null : _deleteTask,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete task')),
          OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => RecordDocumentsView(
                      api: widget.api,
                      companyId: widget.companyId,
                      section: 'Tasks',
                      record: _task,
                      employee: widget.employee,
                      uploads: widget.uploads)),
              icon: const Icon(Icons.attach_file),
              label: const Text('Attachments')),
        ]);
    Widget content() =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Description', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText('${_task['description'] ?? ''}'.isEmpty
              ? 'No description.'
              : '${_task['description']}'),
          const SizedBox(height: 24),
          Text('Comments', style: Theme.of(context).textTheme.titleMedium),
          if (_comments.isEmpty && !_loading)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No comments yet.')),
          for (final c in _comments)
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${c['createdBy'] == widget.employeeId ? 'You' : c['authorName'] ?? 'Team member'} · ${_stamp(c['createdAt'])}',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 6),
                          SelectableText('${c['body']}')
                        ]))),
          const SizedBox(height: 12),
          Form(
              key: _commentForm,
              child: ValidatedTextField(
                  inputFormatters: [AppInputFormatters.text],
                  controller: _comment,
                  required: true,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 5000,
                  decoration:
                      const InputDecoration(labelText: 'Add a comment'))),
          Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                  onPressed: _busy ? null : _addComment,
                  child: _busy
                      ? const SizedBox(
                          width: 20, height: 20, child: AppActivityIndicator())
                      : const Text('Post comment'))),
          const SizedBox(height: 24),
          Text('Activity', style: Theme.of(context).textTheme.titleMedium),
          for (final a in _activity.reversed)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    '${a['summary']}\n${a['authorName'] ?? 'Team member'} ? ${_stamp(a['createdAt'])}',
                    style: Theme.of(context).textTheme.bodyMedium)),
        ]);
    return Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
                tooltip: 'Close task',
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
            title: const Text('Task details'),
            actions: [
              if (widget.manage)
                IconButton(
                    tooltip: 'Edit / reassign',
                    onPressed: _busy
                        ? null
                        : () async {
                            await widget.onEdit(_task);
                            await _load();
                          },
                    icon: const Icon(Icons.edit_outlined))
            ]),
        bottomNavigationBar: _canStatus &&
                MediaQuery.viewInsetsOf(context).bottom == 0
            ? SafeArea(
                top: false,
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SizedBox(
                        height: 48,
                        child: FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _status(_task['status'] == 'TODO'
                                    ? 'IN_PROGRESS'
                                    : _task['status'] == 'COMPLETED'
                                        ? 'TODO'
                                        : 'COMPLETED'),
                            child: _busy
                                ? const AppActivityIndicator()
                                : Text(_task['status'] == 'TODO'
                                    ? 'Start task'
                                    : _task['status'] == 'COMPLETED'
                                        ? 'Reopen task'
                                        : 'Complete task')))))
            : null,
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('${_task['title']}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Column(children: [
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              TextButton(onPressed: _load, child: const Text('Retry'))
            ]),
          LayoutBuilder(
              builder: (context, c) => c.maxWidth < 700
                  ? Column(children: [
                      information(),
                      const SizedBox(height: 24),
                      content()
                    ])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Expanded(flex: 3, child: content()),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: information())
                        ])),
        ])));
  }
}
