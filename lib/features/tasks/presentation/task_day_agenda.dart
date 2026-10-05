part of 'task_workspace.dart';

/// Loads only the selected day's events when the month/week page is partial.
class _TaskDayAgenda extends StatefulWidget {
  const _TaskDayAgenda(
      {super.key,
      required this.api,
      required this.companyId,
      required this.employee,
      required this.filters,
      required this.initial,
      required this.expectedCount,
      required this.revision,
      required this.onOpen});
  final SaasApi api;
  final String companyId;
  final bool employee;
  final Map<String, String> filters;
  final List<Map<String, dynamic>> initial;
  final int expectedCount, revision;
  final ValueChanged<Map<String, dynamic>> onOpen;
  @override
  State<_TaskDayAgenda> createState() => _TaskDayAgendaState();
}

class _TaskDayAgendaState extends State<_TaskDayAgenda> {
  late List<Map<String, dynamic>> _rows = widget.initial;
  int? _next;
  int _generation = 0;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (_rows.length < widget.expectedCount) _load();
  }

  @override
  void didUpdateWidget(covariant _TaskDayAgenda oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision != oldWidget.revision) {
      if (widget.initial.length == widget.expectedCount) {
        _rows = widget.initial;
        _next = null;
      } else {
        _load();
      }
    }
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    final target = more ? 40 : _rows.length.clamp(40, 10000);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final filters = {
        ...widget.filters,
        'limit': target > 40 ? '100' : '40',
        if (more && _next != null) 'offset': '$_next'
      };
      final page = Map<String, dynamic>.from(await widget.api.tasks(
          widget.companyId,
          employee: widget.employee,
          filters: filters,
          force: true));
      final rows = List<Map<String, dynamic>>.from(page['records'] as List);
      while (!more &&
          rows.length < target &&
          page['nextOffset'] != null &&
          mounted &&
          generation == _generation) {
        filters['offset'] = page['nextOffset'].toString();
        final nextPage = await widget.api.tasks(widget.companyId,
            employee: widget.employee, filters: filters, force: true);
        rows.addAll(
            List<Map<String, dynamic>>.from(nextPage['records'] as List));
        page['nextOffset'] = nextPage['nextOffset'];
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _rows = more ? [..._rows, ...rows] : rows;
        _next = page['nextOffset'] as int?;
        _busy = false;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = e.toString();
          _busy = false;
          if (e is SaasApiException && [401, 403].contains(e.status)) {
            _rows = [];
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_busy && _rows.isEmpty) const _TaskSkeleton(),
        if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry schedule'))
        ],
        if (!_busy && _rows.isEmpty && _error == null)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No scheduled tasks for this date.')),
        for (final task in _rows)
          TaskCard(task: task, onTap: () => widget.onOpen(task)),
        if (_next != null)
          OutlinedButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: const Text('Load more for this date')),
        if (_busy && _rows.isNotEmpty) const LinearProgressIndicator(),
      ]);
}
