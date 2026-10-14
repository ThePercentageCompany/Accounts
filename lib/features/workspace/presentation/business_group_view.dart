import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

class BusinessGroupView extends StatefulWidget {
  const BusinessGroupView({super.key, required this.api, required this.onOpen});
  final SaasApi api;
  final Future<void> Function(String companyId) onOpen;
  @override
  State<BusinessGroupView> createState() => _BusinessGroupViewState();
}

class _BusinessGroupViewState extends State<BusinessGroupView> {
  Map<String, dynamic>? data;
  String? error, selectedGroup;
  bool loading = true, opening = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.api.businessGroups();
      if (mounted) setState(() => data = result);
    } catch (failure) {
      if (mounted) {
        setState(() => error = failure is SaasApiException
            ? failure.message
            : 'Could not load your businesses. Retry when connected.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create({String? groupId}) async {
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _BusinessCreateDialog(api: widget.api, groupId: groupId));
    if (saved == true && mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final groups = (data?['groups'] as List? ?? []).cast<Map>();
    final entities = (data?['entities'] as List? ?? [])
        .cast<Map>()
        .where((e) => selectedGroup == null || e['groupId'] == selectedGroup)
        .toList();
    final currencies = <String, num>{};
    for (final entity in entities) {
      final amounts = entity['metrics']['outstandingByCurrency'] as Map;
      for (final entry in amounts.entries) {
        currencies.update('${entry.key}', (v) => v + (entry.value as num),
            ifAbsent: () => entry.value as num);
      }
    }
    return RefreshIndicator(
        onRefresh: load,
        child: ListView(
            padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width > 700 ? 32 : 16),
            children: [
              Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                      color: const Color(0xff142c45),
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BUSINESS GROUP',
                            style: TextStyle(
                                color: Color(0xff83c8d7),
                                letterSpacing: 2,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        const Text('One group. Every business.',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        const Text(
                            'Accounts, people, work and sales — with independent books for each country entity.',
                            style: TextStyle(
                                color: Color(0xffd0deeb), height: 1.6)),
                        const SizedBox(height: 24),
                        Wrap(spacing: 12, runSpacing: 12, children: [
                          FilledButton.icon(
                              onPressed: loading ? null : () => create(),
                              icon: const Icon(Icons.add_business_outlined),
                              label: const Text('Create business group')),
                          if (selectedGroup != null)
                            OutlinedButton.icon(
                                onPressed: loading
                                    ? null
                                    : () => create(groupId: selectedGroup),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white),
                                icon: const Icon(Icons.add),
                                label: const Text('Add country entity')),
                        ]),
                      ])),
              const SizedBox(height: 24),
              if (loading) const LinearProgressIndicator(),
              if (error != null)
                Card(
                    child: ListTile(
                        title: Text(error!),
                        trailing: IconButton(
                            onPressed: load, icon: const Icon(Icons.refresh)))),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(
                    label: const Text('All businesses'),
                    selected: selectedGroup == null,
                    onSelected: (_) => setState(() => selectedGroup = null)),
                for (final group in groups)
                  ChoiceChip(
                      label: Text('${group['name']}'),
                      selected: selectedGroup == group['id'],
                      onSelected: (_) =>
                          setState(() => selectedGroup = '${group['id']}')),
              ]),
              const SizedBox(height: 24),
              Wrap(spacing: 16, runSpacing: 16, children: [
                _Summary('Legal entities', entities.length,
                    Icons.apartment_outlined),
                _Summary(
                    'Countries',
                    entities
                        .map((e) => e['countryCode'])
                        .where((c) => c != null)
                        .toSet()
                        .length,
                    Icons.public),
                _Summary(
                    'Active employees',
                    entities.fold<int>(
                        0,
                        (n, e) =>
                            n + ((e['metrics']['employees'] as num).toInt())),
                    Icons.badge_outlined),
                _Summary(
                    'Open tasks',
                    entities.fold<int>(
                        0,
                        (n, e) =>
                            n + ((e['metrics']['openTasks'] as num).toInt())),
                    Icons.task_alt),
              ]),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                    child: Text('Country entities',
                        style: Theme.of(context).textTheme.headlineSmall)),
                IconButton(
                    tooltip: 'Refresh overview',
                    onPressed: loading ? null : load,
                    icon: const Icon(Icons.refresh))
              ]),
              const Text(
                  'Choose an entity to work in its accounts, employee directory, schedule and sales.'),
              const SizedBox(height: 16),
              if (!loading && entities.isEmpty)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(children: [
                          const Icon(Icons.apartment_outlined, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                              'Start with a business group, then add its first country entity.'),
                          const SizedBox(height: 16),
                          FilledButton(
                              onPressed: () => create(groupId: selectedGroup),
                              child: Text(selectedGroup == null
                                  ? 'Create group'
                                  : 'Add entity')),
                        ]))),
              LayoutBuilder(
                  builder: (context, constraints) =>
                      Wrap(spacing: 16, runSpacing: 16, children: [
                        for (final entity in entities)
                          SizedBox(
                              width: constraints.maxWidth >= 760
                                  ? (constraints.maxWidth - 16) / 2
                                  : constraints.maxWidth,
                              child: Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(22),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              const Icon(
                                                  Icons.business_outlined),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: Text(
                                                      '${entity['name']}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleLarge)),
                                              Chip(
                                                  label: Text(
                                                      '${entity['countryCode'] ?? 'Entity'}'))
                                            ]),
                                            const SizedBox(height: 12),
                                            Text(
                                                '${entity['currency']} accounting currency · ${entity['timeZone']}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall),
                                            if ('${entity['taxRegistration'] ?? ''}'
                                                .isNotEmpty)
                                              Text(
                                                  'Tax registration: ${entity['taxRegistration']}'),
                                            const SizedBox(height: 16),
                                            Wrap(
                                                spacing: 16,
                                                runSpacing: 8,
                                                children: [
                                                  Text(
                                                      '${entity['metrics']['employees']} employees'),
                                                  Text(
                                                      '${entity['metrics']['openTasks']} open tasks'),
                                                  Text(
                                                      '${entity['metrics']['invoices']} invoices')
                                                ]),
                                            const SizedBox(height: 18),
                                            Row(children: [
                                              Expanded(
                                                  child: Text(
                                                      entity['groupId'] == null
                                                          ? 'Independent entity'
                                                          : '${groups.where((g) => g['id'] == entity['groupId']).firstOrNull?['name'] ?? 'Business group'}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall)),
                                              FilledButton.icon(
                                                  onPressed: opening
                                                      ? null
                                                      : () async {
                                                          setState(() =>
                                                              opening = true);
                                                          try {
                                                            await widget.onOpen(
                                                                '${entity['companyId']}');
                                                          } catch (failure) {
                                                            if (mounted) {
                                                              setState(() =>
                                                                  error =
                                                                      '$failure');
                                                            }
                                                          } finally {
                                                            if (mounted) {
                                                              setState(() =>
                                                                  opening =
                                                                      false);
                                                            }
                                                          }
                                                        },
                                                  icon: const Icon(
                                                      Icons.arrow_forward,
                                                      size: 18),
                                                  label:
                                                      const Text('Open entity'))
                                            ]),
                                          ])))),
                      ])),
              if (currencies.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text('Customer balances by currency',
                    style: Theme.of(context).textTheme.titleLarge),
                const Text(
                    'Native invoice currencies shown separately. These are not consolidated financial statements.'),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  for (final e in currencies.entries)
                    Chip(label: Text('${e.key} ${e.value.toStringAsFixed(2)}'))
                ]),
              ],
              const SizedBox(height: 32),
            ]));
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.label, this.value, this.icon);
  final String label;
  final int value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 210,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('$value',
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text(label),
                  ]))));
}

const _countries = <String, (String, String, String)>{
  'AE': ('United Arab Emirates', 'AED', 'Asia/Dubai'),
  'IN': ('India', 'INR', 'Asia/Kolkata'),
  'SA': ('Saudi Arabia', 'SAR', 'Asia/Riyadh'),
  'QA': ('Qatar', 'QAR', 'Asia/Qatar'),
  'OM': ('Oman', 'OMR', 'Asia/Muscat'),
  'BH': ('Bahrain', 'BHD', 'Asia/Bahrain'),
  'KW': ('Kuwait', 'KWD', 'Asia/Kuwait'),
  'GB': ('United Kingdom', 'GBP', 'Europe/London'),
  'US': ('United States', 'USD', 'America/New_York'),
  'CA': ('Canada', 'CAD', 'America/Toronto'),
  'AU': ('Australia', 'AUD', 'Australia/Sydney'),
  'SG': ('Singapore', 'SGD', 'Asia/Singapore'),
  'DE': ('Germany', 'EUR', 'Europe/Berlin'),
  'FR': ('France', 'EUR', 'Europe/Paris'),
  'OTHER': ('Other country', '', ''),
};

class _BusinessCreateDialog extends StatefulWidget {
  const _BusinessCreateDialog({required this.api, this.groupId});
  final SaasApi api;
  final String? groupId;
  @override
  State<_BusinessCreateDialog> createState() => _BusinessCreateDialogState();
}

class _BusinessCreateDialogState extends State<_BusinessCreateDialog> {
  final form = GlobalKey<FormState>(),
      name = TextEditingController(),
      currency = TextEditingController(text: 'AED'),
      zone = TextEditingController(text: 'Asia/Dubai'),
      tax = TextEditingController(),
      customCountry = TextEditingController();
  final key = const Uuid().v4();
  String country = 'AE';
  bool busy = false, submitted = false;
  String? error;
  @override
  void dispose() {
    for (final c in [name, currency, zone, tax, customCountry]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.groupId == null
            ? 'Create business group'
            : 'Add country entity'),
        content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
                child: Form(
                    key: form,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextFormField(
                          controller: name,
                          readOnly: submitted,
                          maxLength: 160,
                          decoration: InputDecoration(
                              labelText: widget.groupId == null
                                  ? 'Group name'
                                  : 'Legal entity name'),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter a name.'
                              : null),
                      if (widget.groupId != null) ...[
                        DropdownButtonFormField<String>(
                            initialValue: country,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Country'),
                            items: [
                              for (final e in _countries.entries)
                                DropdownMenuItem(
                                    value: e.key, child: Text(e.value.$1))
                            ],
                            onChanged: submitted
                                ? null
                                : (v) {
                                    if (v != null) {
                                      setState(() {
                                        country = v;
                                        currency.text = _countries[v]!.$2;
                                        zone.text = _countries[v]!.$3;
                                      });
                                    }
                                  }),
                        if (country == 'OTHER')
                          TextFormField(
                              controller: customCountry,
                              readOnly: submitted,
                              decoration: const InputDecoration(
                                  labelText: 'Country code',
                                  helperText:
                                      'Two-letter ISO code, for example MY'),
                              validator: (v) => RegExp(r'^[A-Z]{2}$')
                                      .hasMatch(v?.trim().toUpperCase() ?? '')
                                  ? null
                                  : 'Use a two-letter country code.'),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: currency,
                            readOnly: submitted,
                            decoration: const InputDecoration(
                                labelText: 'Accounting currency',
                                helperText:
                                    'Currency for this entity’s accounting books'),
                            validator: (v) => RegExp(r'^[A-Z]{3}$')
                                    .hasMatch(v?.trim().toUpperCase() ?? '')
                                ? null
                                : 'Use a three-letter currency code.'),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: zone,
                            readOnly: submitted,
                            decoration: const InputDecoration(
                                labelText: 'Business time zone',
                                helperText:
                                    'Scheduling uses this IANA zone, e.g. Europe/London'),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Enter a time zone.'
                                : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: tax,
                            readOnly: submitted,
                            maxLength: 100,
                            decoration: const InputDecoration(
                                labelText: 'Tax registration (optional)')),
                      ],
                      if (error != null)
                        Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      if (busy) const LinearProgressIndicator(),
                    ])))),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() {
                        busy = true;
                        submitted = true;
                        error = null;
                      });
                      try {
                        if (widget.groupId == null) {
                          await widget.api
                              .createBusinessGroup(name.text.trim(), key);
                        } else {
                          await widget.api.createCountryEntity(
                              widget.groupId!,
                              {
                                'name': name.text.trim(),
                                'countryCode': country == 'OTHER'
                                    ? customCountry.text.trim().toUpperCase()
                                    : country,
                                'currency': currency.text.trim().toUpperCase(),
                                'timeZone': zone.text.trim(),
                                'taxRegistration': tax.text.trim()
                              },
                              key);
                        }
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (failure) {
                        if (mounted) {
                          setState(() {
                            error = failure is SaasApiException
                                ? failure.message
                                : 'Could not save. Retry to confirm the same request.';
                            if (failure is SaasApiException &&
                                failure.status == 400) {
                              submitted = false;
                            }
                          });
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: Text(submitted ? 'Retry / confirm' : 'Create'))
        ],
      );
}
