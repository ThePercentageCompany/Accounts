part of 'task_workspace.dart';

class TaskAssigneePicker extends StatefulWidget {
  const TaskAssigneePicker(
      {super.key,
      required this.api,
      required this.companyId,
      required this.employee,
      this.allowAll = false});
  final bool allowAll;
  final SaasApi api;
  final String companyId;
  final bool employee;
  @override
  State<TaskAssigneePicker> createState() => _TaskAssigneePickerState();
}

class _TaskAssigneePickerState extends State<TaskAssigneePicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _rows = [];
  int? _next;
  int _generation = 0;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.api.taskAssignees(widget.companyId,
          employee: widget.employee,
          search: _search.text.trim(),
          offset: more ? _next ?? 0 : 0);
      if (!mounted || generation != _generation) return;
      setState(() {
        final rows =
            List<Map<String, dynamic>>.from(response['employees'] as List);
        _rows = more ? [..._rows, ...rows] : rows;
        _next = response['nextOffset'] as int?;
        _busy = false;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('Select employee'),
          actions: [
            if (widget.allowAll)
              TextButton(
                  onPressed: () => Navigator.pop(context,
                      <String, dynamic>{'recordId': '', 'fullName': ''}),
                  child: const Text('All'))
          ],
          leading: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close))),
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                    labelText: 'Search name or department',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), _load);
                })),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Retry'))
              ])),
        Expanded(
            child: ListView(children: [
          for (final e in _rows)
            ListTile(
                minVerticalPadding: 16,
                title: Text('${e['fullName']}'),
                subtitle: '${e['department'] ?? ''}'.isEmpty
                    ? null
                    : Text('${e['department']}'),
                onTap: () => Navigator.pop(context, e)),
          if (!_busy && _rows.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No active employees found.')),
          if (_next != null)
            TextButton(
                onPressed: _busy ? null : () => _load(more: true),
                child: const Text('Load more employees'))
        ])),
      ])));
}

class TaskAssigneeField extends StatelessWidget {
  const TaskAssigneeField(
      {super.key,
      required this.api,
      required this.companyId,
      required this.employee,
      required this.value,
      required this.name,
      required this.onChanged,
      this.enabled = true,
      this.required = false});
  final SaasApi api;
  final String companyId, value, name;
  final bool employee, enabled, required;
  final ValueChanged<Map<String, dynamic>> onChanged;
  @override
  Widget build(BuildContext context) => FormField<String>(
      key: ValueKey(value),
      initialValue: value,
      validator: required
          ? (v) => v == null || v.isEmpty ? 'Select an employee' : null
          : null,
      builder: (field) => InkWell(
          onTap: enabled
              ? () async {
                  final selected = await _taskSurface<Map<String, dynamic>>(
                      context,
                      TaskAssigneePicker(
                          api: api,
                          companyId: companyId,
                          employee: employee,
                          allowAll: !required));
                  if (selected != null && context.mounted) onChanged(selected);
                }
              : null,
          child: InputDecorator(
              decoration: InputDecoration(
                  labelText: required ? 'Assign employee' : 'Employee',
                  errorText: field.errorText,
                  enabled: enabled,
                  suffixIcon: const Icon(Icons.search)),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 24),
                  child: Text(
                      value.isEmpty
                          ? (required ? 'Select employee' : 'All employees')
                          : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)))));
}
