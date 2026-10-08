import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

class ProjectDropdown extends StatefulWidget {
  const ProjectDropdown(
      {super.key,
      required this.api,
      required this.companyId,
      required this.employee,
      required this.value,
      required this.onChanged,
      this.filter = false});
  final SaasApi api;
  final String companyId;
  final bool employee, filter;
  final String value;
  final ValueChanged<String> onChanged;
  @override
  State<ProjectDropdown> createState() => _ProjectDropdownState();
}

class _ProjectDropdownState extends State<ProjectDropdown> {
  List<String> _names = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProjectDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId ||
        oldWidget.employee != widget.employee ||
        oldWidget.api != widget.api) {
      _load();
    }
  }

  Future<void> _load() async {
    final company = widget.companyId;
    setState(() {
      _loading = true;
      _error = null;
      _names = [];
    });
    try {
      final result = await widget.api.editorReferences(
          company, 'Projects', 'Tasks',
          employee: widget.employee);
      if (!mounted || company != widget.companyId) return;
      setState(() {
        _names = (result['records'] as List)
            .where((r) => widget.filter || r['status'] == 'ACTIVE')
            .map((r) => r['name'].toString())
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      });
    } catch (_) {
      if (mounted && company == widget.companyId) {
        setState(() => _error = 'Could not load projects');
      }
    } finally {
      if (mounted && company == widget.companyId) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final names =
        {..._names, if (widget.value.isNotEmpty) widget.value}.toList();
    return DropdownButtonFormField<String>(
        key: ValueKey((widget.companyId, widget.value, names.join('|'))),
        initialValue: widget.value,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: 'Project',
            helperText: _loading
                ? 'Loading projects?'
                : names.isEmpty && _error == null
                    ? 'Add projects in the Projects module'
                    : null,
            errorText: _error,
            suffixIcon: _error == null
                ? null
                : IconButton(
                    onPressed: _load,
                    tooltip: 'Retry projects',
                    icon: const Icon(Icons.refresh))),
        items: [
          DropdownMenuItem(
              value: '',
              child: Text(widget.filter ? 'All projects' : 'No project')),
          for (final name in names)
            DropdownMenuItem(
                value: name, child: Text(name, overflow: TextOverflow.ellipsis))
        ],
        onChanged: _loading || _error != null
            ? null
            : (value) {
                if (value != null) widget.onChanged(value);
              });
  }
}
