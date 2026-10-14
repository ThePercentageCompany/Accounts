import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

class EntityOverview extends StatefulWidget {
  const EntityOverview(
      {super.key,
      required this.api,
      required this.companyId,
      required this.name,
      this.active = true,
      required this.onNavigate});
  final SaasApi api;
  final String companyId, name;
  final bool active;
  final void Function(String section) onNavigate;
  @override
  State<EntityOverview> createState() => _EntityOverviewState();
}

class _EntityOverviewState extends State<EntityOverview> {
  Map<String, dynamic>? entity;
  String? error;
  bool loading = true;
  String get path => '/v1/companies/${widget.companyId}/overview';
  void cacheChanged() {
    final data = widget.api.cache.state(path)?.data;
    if (!mounted || data == null) return;
    final next = data['entity'];
    if (next is Map) {
      setState(() => entity = Map<String, dynamic>.from(next));
    }
  }

  void watch() {
    if (widget.active) widget.api.cache.activate(path);
  }

  @override
  void initState() {
    super.initState();
    widget.api.cache.addListener(cacheChanged);
    watch();
    load();
  }

  @override
  void didUpdateWidget(covariant EntityOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (oldWidget.active) widget.api.cache.deactivate(path);
      watch();
    }
    if (widget.active && !oldWidget.active) {
      load();
    }
  }

  @override
  void dispose() {
    widget.api.cache.removeListener(cacheChanged);
    if (widget.active) widget.api.cache.deactivate(path);
    super.dispose();
  }

  Future<void> load({bool force = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result =
          await widget.api.entityOverview(widget.companyId, force: force);
      if (mounted) {
        setState(
            () => entity = Map<String, dynamic>.from(result['entity'] as Map));
      }
    } catch (failure) {
      if (mounted) {
        setState(() => error = failure is SaasApiException
            ? failure.message
            : 'Could not load the overview.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = entity?['metrics'] as Map?;
    return RefreshIndicator(
        onRefresh: () => load(force: true),
        child: ListView(
            padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width > 700 ? 32 : 16),
            children: [
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('ENTITY OVERVIEW',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  letterSpacing: 2,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 8),
                      Text(widget.name,
                          style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 8),
                      Text(
                          '${entity?['countryCode'] ?? 'Independent business'} · ${entity?['currency'] ?? 'Accounting'} · ${entity?['timeZone'] ?? 'Business time'}'),
                    ])),
                IconButton(
                    tooltip: 'Refresh overview',
                    onPressed: loading ? null : () => load(force: true),
                    icon: const Icon(Icons.refresh))
              ]),
              const SizedBox(height: 24),
              if (loading) const LinearProgressIndicator(),
              if (error != null)
                Card(
                    child: ListTile(
                        title: Text(error!),
                        trailing: IconButton(
                            onPressed: load, icon: const Icon(Icons.refresh)))),
              Wrap(spacing: 16, runSpacing: 16, children: [
                for (final metric in [
                  ('Invoices', m?['invoices'], Icons.receipt_long_outlined),
                  ('Active employees', m?['employees'], Icons.badge_outlined),
                  ('Open tasks', m?['openTasks'], Icons.task_alt)
                ])
                  SizedBox(
                      width: 220,
                      child: Card(
                          child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(metric.$3,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                    const SizedBox(height: 18),
                                    Text('${metric.$2 ?? '—'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium),
                                    Text(metric.$1)
                                  ])))),
              ]),
              const SizedBox(height: 32),
              Text('Your business, connected',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                  'Move from the day’s work to its financial result in one workspace.'),
              const SizedBox(height: 20),
              LayoutBuilder(
                  builder: (context, c) =>
                      Wrap(spacing: 16, runSpacing: 16, children: [
                        for (final module in [
                          (
                            'Accounting',
                            'Cash, expenses, assets and financial reports.',
                            Icons.account_balance_outlined,
                            ['Reports', 'Cash & Bank', 'Income & Expenses']
                          ),
                          (
                            'Sales',
                            'From quotation to invoice and customer payment.',
                            Icons.receipt_long_outlined,
                            ['Quotations', 'Invoices', 'Customers']
                          ),
                          (
                            'People',
                            'Employee directory, access and payroll.',
                            Icons.groups_outlined,
                            ['Employees', 'Payroll']
                          ),
                          (
                            'Work',
                            'Plan projects, assign tasks and schedule delivery.',
                            Icons.calendar_month_outlined,
                            ['Tasks', 'Calendar', 'Projects']
                          ),
                        ])
                          SizedBox(
                              width: c.maxWidth >= 760
                                  ? (c.maxWidth - 16) / 2
                                  : c.maxWidth,
                              child: Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Icon(module.$3,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary),
                                              const SizedBox(width: 12),
                                              Text(module.$1,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge)
                                            ]),
                                            const SizedBox(height: 12),
                                            Text(module.$2),
                                            const SizedBox(height: 18),
                                            Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  for (final section
                                                      in module.$4)
                                                    ActionChip(
                                                        label: Text(section),
                                                        onPressed: () =>
                                                            widget.onNavigate(
                                                                section))
                                                ]),
                                          ])))),
                      ])),
              const SizedBox(height: 28),
              if (m != null &&
                  (m['outstandingByCurrency'] as Map).isNotEmpty) ...[
                Text('Outstanding customer balances',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 8, children: [
                  for (final e in (m['outstandingByCurrency'] as Map).entries)
                    Chip(
                        label: Text(
                            '${e.key} ${(e.value as num).toStringAsFixed(2)}'))
                ]),
              ],
              const SizedBox(height: 32),
            ]));
  }
}
