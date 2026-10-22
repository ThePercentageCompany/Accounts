import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/utils/business_time.dart';
import 'workspace_dashboard.dart';

class DashboardFinancialOverview extends StatefulWidget {
  const DashboardFinancialOverview(
      {super.key,
      required this.api,
      required this.companyId,
      required this.onReportSelected,
      this.employee = false,
      this.active = true,
      this.timeZone = 'Asia/Dubai'});
  final SaasApi api;
  final String companyId, timeZone;
  final bool employee, active;
  final ValueChanged<String> onReportSelected;
  @override
  State<DashboardFinancialOverview> createState() =>
      _DashboardFinancialOverviewState();
}

class _DashboardFinancialOverviewState
    extends State<DashboardFinancialOverview> {
  Map<String, dynamic>? _data;
  String? _error, _watched;
  String _period = 'year';
  bool _loading = false, _scheduled = false;
  int _generation = 0;
  DateTime get _now => businessNow(widget.timeZone);
  String get _asOf => _now.toIso8601String().substring(0, 10);
  String get _from {
    final now = _now;
    return (_period == 'month'
            ? DateTime(now.year, now.month)
            : _period == 'quarter'
                ? DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1)
                : DateTime(now.year))
        .toIso8601String()
        .substring(0, 10);
  }

  String get _path =>
      widget.api.financialReportPath(widget.companyId, 'dashboard',
          asOf: _asOf, from: _from, employee: widget.employee);
  @override
  void initState() {
    super.initState();
    widget.api.cache.addListener(_changed);
    _load();
  }

  void _watch() {
    if (_watched != null) widget.api.cache.deactivate(_watched!);
    _watched = widget.active ? _path : null;
    if (_watched != null) widget.api.cache.activate(_watched!);
  }

  void _changed() {
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!mounted) return;
      final state = widget.api.cache.state(_path);
      final signature = (state?.data, state?.refreshing, state?.error,
          state?.offline, state?.stale, widget.api.cache.localRevisionFor(_path));
      if (_cacheSignature == signature) return;
      _cacheSignature = signature;
      final raw = state?.data;
      if (raw != null) {
        setState(() => _data = widget.api.localFinancialReport(
            widget.companyId, raw, 'dashboard',
            employee: widget.employee));
      }
    });
  }
  Object? _cacheSignature;

  Future<void> _load({bool force = false}) async {
    _watch();
    if (!widget.active) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.financialReport(
          widget.companyId, 'dashboard',
          asOf: _asOf, from: _from, employee: widget.employee, force: force);
      if (mounted && generation == _generation) setState(() => _data = data);
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error is SaasApiException
            ? error.message
            : 'Financial overview unavailable. Please retry.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void didUpdateWidget(covariant DashboardFinancialOverview old) {
    super.didUpdateWidget(old);
    if (old.api != widget.api) {
      old.api.cache.removeListener(_changed);
      if (_watched != null) old.api.cache.deactivate(_watched!);
      _watched = null;
      widget.api.cache.addListener(_changed);
    }
    if (old.api != widget.api ||
        old.companyId != widget.companyId ||
        old.employee != widget.employee ||
        old.timeZone != widget.timeZone) {
      _data = null;
      _generation++;
      _load();
    } else if (old.active != widget.active) {
      _generation++;
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.api.cache.removeListener(_changed);
    if (_watched != null) widget.api.cache.deactivate(_watched!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Wrap(spacing: 8, children: [
            for (final entry in const {
              'month': 'This month',
              'quarter': 'This quarter',
              'year': 'This year'
            }.entries)
              ChoiceChip(
                  label: Text(entry.value),
                  selected: _period == entry.key,
                  onSelected: (_) {
                    if (_period == entry.key) return;
                    setState(() {
                      _period = entry.key;
                      _data = null;
                    });
                    _load();
                  })
          ])),
          IconButton(
              tooltip: 'Refresh financial overview',
              onPressed: _loading ? null : () => _load(force: true),
              icon: const Icon(Icons.refresh, size: 20))
        ]),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!)),
        if (_data != null)
          WorkspaceDashboard(
              data: _data!, onReportSelected: widget.onReportSelected),
      ]);
}
