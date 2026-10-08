part of 'task_workspace.dart';

class TaskEditor extends StatefulWidget {
  const TaskEditor(
      {super.key,
      required this.api,
      required this.companyId,
      required this.employee,
      required this.assignees,
      required this.onSave,
      this.task});
  final SaasApi api;
  final String companyId;
  final bool employee;
  final Map<String, dynamic>? task;
  final List<Map<String, dynamic>> assignees;
  final Future<void> Function(Map<String, Object?> values, String operationId)
      onSave;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields = {
    for (final key in [
      'title',
      'description',
      'startDate',
      'dueDate',
      'startTime',
      'endTime',
      'project',
      'tags'
    ])
      key: TextEditingController(
          text: widget.task?[key]?.toString() ??
              (key == 'dueDate' ? taskDate(taskToday()) : ''))
  };
  late String _employeeId = widget.task?['employeeId']?.toString() ?? '';
  late String _priority = widget.task?['priority']?.toString() ?? 'MEDIUM';
  late String _status = widget.task?['status']?.toString() ?? 'TODO';
  late String _reminder = widget.task?['reminder']?.toString() ?? 'NONE';
  late List<Map<String, dynamic>> _assignees = widget.assignees;
  bool _busy = false, _loading = false;
  String? _error;
  String _operationId = const Uuid().v4();
  Map<String, Object?>? _attempt;
  @override
  void initState() {
    super.initState();
    if (_assignees.isEmpty) _reloadAssignees();
  }

  Future<void> _reloadAssignees() async {
    setState(() => _loading = true);
    try {
      final result = await widget.api
          .taskAssignees(widget.companyId, employee: widget.employee);
      if (mounted) {
        setState(() {
          _assignees =
              List<Map<String, dynamic>>.from(result['employees'] as List);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !AppFormValidation.validate(_form.currentState!)) return;
    final values = <String, Object?>{
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
      'employeeId': _employeeId,
      'priority': _priority,
      'status': _status,
      'reminder': _reminder
    };
    if (_attempt != null && values.toString() != _attempt.toString()) {
      _operationId = const Uuid().v4();
    }
    _attempt = values;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(values, _operationId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget field(String key, String label,
            {int lines = 1, int? maxLength, bool required = false}) =>
        ValidatedTextField(
            controller: _fields[key],
            required: required,
            kind: AppValidators.kindForKey(key),
            enabled: !_busy,
            maxLines: lines,
            maxLength: maxLength,
            textInputAction:
                lines == 1 ? TextInputAction.next : TextInputAction.newline,
            decoration: InputDecoration(
                labelText: label, alignLabelWithHint: lines > 1),
            validator: (v) => required && (v == null || v.trim().isEmpty)
                ? 'Enter $label'
                : null);
    Widget select(String title, String value, List<String> options,
            ValueChanged<String> onChange) =>
        DropdownButtonFormField<String>(
            initialValue: options.contains(value) ? value : options.first,
            isExpanded: true,
            decoration: InputDecoration(labelText: title),
            items: [
              for (final s in options)
                DropdownMenuItem(value: s, child: Text(taskLabel(s)))
            ],
            onChanged: _busy ? null : (s) => setState(() => onChange(s!)));
    Widget dateField(String key, String label,
            {bool time = false, bool required = false}) =>
        CalendarFormField(
            controller: _fields[key]!,
            decoration: InputDecoration(labelText: label),
            mode: time ? CalendarFieldMode.time : CalendarFieldMode.date,
            enabled: !_busy,
            optional: !required,
            validator: (v) {
              if (required && (v == null || v.isEmpty)) return 'Select $label';
              if (key == 'dueDate' &&
                  _fields['startDate']!.text.isNotEmpty &&
                  _fields['startDate']!.text.compareTo(v ?? '') > 0) {
                return 'Due date must follow start date';
              }
              if (key == 'endTime' &&
                  _fields['startDate']!.text == _fields['dueDate']!.text &&
                  _fields['startTime']!.text.isNotEmpty &&
                  (v ?? '').isNotEmpty &&
                  _fields['startTime']!.text.compareTo(v!) > 0) {
                return 'End time must follow start time';
              }
              return null;
            });
    Widget pair(Widget a, Widget b) => LayoutBuilder(
        builder: (context, c) => c.maxWidth < 600
            ? Column(children: [a, const SizedBox(height: 16), b])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: a),
                const SizedBox(width: 16),
                Expanded(child: b)
              ]));
    final available = [..._assignees];
    if (_employeeId.isNotEmpty &&
        !available.any((e) => e['recordId'] == _employeeId)) {
      available.add({
        'recordId': _employeeId,
        'fullName': widget.task?['assigneeName'] ?? 'Current employee'
      });
    }
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).bottom <
                  200
              ? null
              : AppBar(
                  title:
                      Text(widget.task == null ? 'Create Task' : 'Edit Task'),
                  automaticallyImplyLeading: false,
                  leading: IconButton(
                      tooltip: 'Close',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close))),
          body: SafeArea(
              child: Form(
                  key: _form,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    field('title', 'Task title',
                        maxLength: 200, required: true),
                    const SizedBox(height: 16),
                    field('description', 'Description',
                        lines: 5, maxLength: 10000),
                    const SizedBox(height: 16),
                    if (_loading) const LinearProgressIndicator(),
                    TaskAssigneeField(
                        api: widget.api,
                        companyId: widget.companyId,
                        employee: widget.employee,
                        value: _employeeId,
                        name: available
                                .where((e) => e['recordId'] == _employeeId)
                                .firstOrNull?['fullName']
                                ?.toString() ??
                            '',
                        enabled: !_busy,
                        required: true,
                        onChanged: (e) => setState(() {
                              _employeeId = e['recordId'].toString();
                              _assignees = [
                                ..._assignees
                                    .where((r) => r['recordId'] != _employeeId),
                                e
                              ];
                            })),
                    if (available.isEmpty && !_loading)
                      TextButton.icon(
                          onPressed: _reloadAssignees,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Load employees / retry')),
                    const SizedBox(height: 16),
                    pair(
                        select('Priority', _priority, taskPriorities,
                            (v) => _priority = v),
                        select('Status', _status, taskStatuses,
                            (v) => _status = v)),
                    const SizedBox(height: 16),
                    pair(dateField('startDate', 'Start date'),
                        dateField('dueDate', 'Due date', required: true)),
                    const SizedBox(height: 16),
                    pair(dateField('startTime', 'Start time', time: true),
                        dateField('endTime', 'End time', time: true)),
                    const SizedBox(height: 8),
                    const Text('Schedule times use UAE time (UTC+4).'),
                    const SizedBox(height: 16),
                    field('project', 'Project', maxLength: 300),
                    const SizedBox(height: 16),
                    field('tags', 'Tags (comma separated)', maxLength: 300),
                    const SizedBox(height: 16),
                    select(
                        'Reminder',
                        _reminder,
                        [
                          'NONE',
                          'AT_DUE',
                          '15_MIN',
                          '30_MIN',
                          '1_HOUR',
                          '2_HOURS',
                          '1_DAY'
                        ],
                        (v) => _reminder = v),
                    const SizedBox(height: 8),
                    const Text(
                        'Enable notifications for deadline alerts where supported. Reminders also appear while Tasks is open.'),
                    const SizedBox(height: 16),
                  ]))),
          bottomNavigationBar: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                          height: 48,
                          child: FilledButton(
                              onPressed: _busy || _loading ? null : _save,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : Text(widget.task == null
                                      ? 'Create Task'
                                      : 'Save Task')))))),
        ));
  }
}
