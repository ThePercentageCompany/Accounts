part of 'task_workspace.dart';

class TaskFilters extends StatefulWidget {
  const TaskFilters(
      {super.key,
      required this.filters,
      required this.api,
      required this.companyId,
      required this.employee,
      required this.manage,
      required this.assignees});
  final Map<String, String> filters;
  final SaasApi api;
  final String companyId;
  final bool employee;
  final bool manage;
  final List<Map<String, dynamic>> assignees;
  @override
  State<TaskFilters> createState() => _TaskFiltersState();
}

class _TaskFiltersState extends State<TaskFilters> {
  late String _assigneeName = widget.assignees
          .where((e) => e['recordId'] == widget.filters['employeeId'])
          .firstOrNull?['fullName']
          ?.toString() ??
      'Selected employee';
  late final Map<String, String> _draft = {...widget.filters};
  late final _project = TextEditingController(text: _draft['project']);
  late final _from = TextEditingController(text: _draft['from']);
  late final _to = TextEditingController(text: _draft['to']);
  @override
  void dispose() {
    _project.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget dropdown(String key, String title, Map<String, String> options) =>
        DropdownButtonFormField<String>(
            initialValue: options.containsKey(_draft[key]) ? _draft[key] : '',
            isExpanded: true,
            decoration: InputDecoration(labelText: title),
            items: [
              const DropdownMenuItem(value: '', child: Text('All')),
              for (final item in options.entries)
                DropdownMenuItem(
                    value: item.key,
                    child: Text(item.value, overflow: TextOverflow.ellipsis))
            ],
            onChanged: (v) {
              if (v == null || v.isEmpty) {
                _draft.remove(key);
              } else {
                _draft[key] = v;
              }
            });
    return Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Filters',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      if (widget.manage) ...[
                        TaskAssigneeField(
                            api: widget.api,
                            companyId: widget.companyId,
                            employee: widget.employee,
                            value: _draft['employeeId'] ?? '',
                            name: _assigneeName,
                            onChanged: (e) => setState(() {
                                  _assigneeName = e['fullName'].toString();
                                  if (e['recordId'] == '') {
                                    _draft.remove('employeeId');
                                  } else {
                                    _draft['employeeId'] =
                                        e['recordId'].toString();
                                  }
                                })),
                        const SizedBox(height: 12)
                      ],
                      dropdown('status', 'Status',
                          {for (final s in taskStatuses) s: taskLabel(s)}),
                      const SizedBox(height: 12),
                      dropdown('priority', 'Priority',
                          {for (final s in taskPriorities) s: taskLabel(s)}),
                      const SizedBox(height: 12),
                      TextField(
                          inputFormatters: [
                            AppInputFormatters.text,
                            AppInputFormatters.search
                          ],
                          controller: _project,
                          decoration:
                              const InputDecoration(labelText: 'Project')),
                      const SizedBox(height: 12),
                      CalendarFormField(
                          controller: _from,
                          decoration:
                              const InputDecoration(labelText: 'Due from'),
                          optional: true),
                      const SizedBox(height: 12),
                      CalendarFormField(
                          controller: _to,
                          decoration:
                              const InputDecoration(labelText: 'Due until'),
                          optional: true),
                      const SizedBox(height: 20),
                      FilledButton(
                          onPressed: () {
                            for (final item in [
                              ('project', _project.text.trim()),
                              ('from', _from.text),
                              ('to', _to.text)
                            ]) {
                              if (item.$2.isEmpty) {
                                _draft.remove(item.$1);
                              } else {
                                _draft[item.$1] = item.$2;
                              }
                            }
                            Navigator.pop(context, _draft);
                          },
                          child: const Text('Apply filters')),
                      TextButton(
                          onPressed: () =>
                              Navigator.pop(context, <String, String>{}),
                          child: const Text('Clear all')),
                    ]))));
  }
}
