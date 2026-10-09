import 'package:tpc_invoice/core/widgets/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'help_guides.dart';
import 'help_answers.dart';

const _mail = 'hello@thepercentagecompany.com';
const _topics = {
  'Getting started': Icons.rocket_launch_outlined,
  'Work & team': Icons.people_outline,
  'Sales & payments': Icons.receipt_long_outlined,
  'Accounting': Icons.account_balance_outlined,
  'Reports': Icons.insights_outlined,
  'Settings & data': Icons.settings_outlined
};

class WorkspaceHelp extends StatefulWidget {
  const WorkspaceHelp({super.key});
  @override
  State<WorkspaceHelp> createState() => _WorkspaceHelpState();
}

class _WorkspaceHelpState extends State<WorkspaceHelp> {
  final _search = TextEditingController();
  String _topic = 'All';
  bool _faq = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final query = _search.text.trim().toLowerCase();
    final guides = helpGuides
        .where((g) =>
            (_topic == 'All' || g.category == _topic) &&
            '${g.title} ${g.category} ${g.purpose} ${g.useCase} ${g.steps.join(' ')}'
                .toLowerCase()
                .contains(query))
        .toList();
    final answers = helpAnswers
        .where((a) =>
            '${a.title} ${a.body} ${a.topic}'.toLowerCase().contains(query))
        .toList();
    return Scaffold(
        appBar: AppBar(title: const Text('TPC Help Center')),
        body: ListView(children: [
          Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
                padding: AppSpacing.page(context),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                          padding: AppSpacing.page(context),
                          decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(24)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.help_outline,
                                    size: 36, color: colors.onPrimaryContainer),
                                const SizedBox(height: 16),
                                Text('What do you need help with?',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                            color: colors.onPrimaryContainer)),
                                const SizedBox(height: 8),
                                Text(
                                    'Learn every section, follow a workflow, or find a quick answer.',
                                    style: TextStyle(
                                        color: colors.onPrimaryContainer)),
                                const SizedBox(height: 20),
                                TextField(
                                    controller: _search,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                        labelText: 'Search help',
                                        hintText:
                                            'Try tasks, invoices or payroll',
                                        prefixIcon: const Icon(Icons.search),
                                        filled: true,
                                        fillColor: colors.surface,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                        suffixIcon: query.isEmpty
                                            ? null
                                            : IconButton(
                                                tooltip: 'Clear search',
                                                icon: const Icon(Icons.close),
                                                onPressed: () => setState(
                                                    () => _search.clear())))),
                              ])),
                      const SizedBox(height: 24),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ChoiceChip(
                            label: const Text('Section guides'),
                            selected: !_faq,
                            onSelected: (_) => setState(() => _faq = false)),
                        ChoiceChip(
                            label: const Text('Quick answers'),
                            selected: _faq,
                            onSelected: (_) => setState(() => _faq = true)),
                      ]),
                      const SizedBox(height: 24),
                      if (!_faq) ...[
                        if (query.isEmpty) ...[
                          Text('Browse by topic',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 12),
                          LayoutBuilder(builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 850
                                ? 3
                                : constraints.maxWidth >= 560
                                    ? 2
                                    : 1;
                            final width =
                                (constraints.maxWidth - (columns - 1) * 12) /
                                    columns;
                            return Wrap(spacing: 12, runSpacing: 12, children: [
                              for (final topic in _topics.entries)
                                SizedBox(
                                    width: width,
                                    child: Card(
                                        color: _topic == topic.key
                                            ? colors.secondaryContainer
                                            : null,
                                        child: ListTile(
                                            leading: Icon(topic.value),
                                            title: Text(topic.key),
                                            subtitle: Text(
                                                '${helpGuides.where((g) => g.category == topic.key).length} guides'),
                                            trailing:
                                                const Icon(Icons.chevron_right),
                                            onTap: () => setState(
                                                () => _topic = topic.key))))
                            ]);
                          }),
                          const SizedBox(height: 20),
                        ],
                        Row(children: [
                          Expanded(
                              child: Text(
                                  _topic == 'All'
                                      ? 'All section guides'
                                      : _topic,
                                  style: theme.textTheme.titleLarge)),
                          if (_topic != 'All')
                            TextButton(
                                onPressed: () => setState(() => _topic = 'All'),
                                child: const Text('Show all'))
                        ]),
                        Text(
                            '${guides.length} guides${query.isEmpty ? '' : ' found'}'),
                        const SizedBox(height: 12),
                        for (final guide in guides)
                          Card(
                              child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: Icon(_topics[guide.category]),
                                  title: Text(guide.title),
                                  subtitle: Text(guide.purpose),
                                  trailing: const Icon(Icons.arrow_forward),
                                  onTap: () => Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                          builder: (_) => _GuidePage(guide))))),
                      ] else ...[
                        Text('Frequently asked questions',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        for (final answer in answers)
                          Card(
                              child: ExpansionTile(
                                  key: PageStorageKey(answer.title),
                                  title: Text(answer.title),
                                  subtitle: Text(answer.topic),
                                  children: [
                                Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 20),
                                    child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: SelectableText(answer.body)))
                              ])),
                      ],
                      if ((!_faq && guides.isEmpty) ||
                          (_faq && answers.isEmpty))
                        Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(children: [
                              const Icon(Icons.search_off, size: 36),
                              const SizedBox(height: 8),
                              const Text(
                                  'No matching answers. Try another word or browse all topics.'),
                              TextButton(
                                  onPressed: () => setState(() {
                                        _search.clear();
                                        _topic = 'All';
                                      }),
                                  child: const Text('Reset search')),
                            ])),
                      const SizedBox(height: 24),
                      const _SupportCard(),
                      const SizedBox(height: 16),
                      const Text(
                          'Sections and actions depend on your role. Reading help does not change your records.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                    ])),
          ))
        ]));
  }
}

class _GuidePage extends StatelessWidget {
  const _GuidePage(this.guide);
  final HelpGuide guide;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(guide.title)),
      body: ListView(children: [
        Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(guide.category,
                              style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 12),
                          Text(guide.title,
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 24),
                          _section(context, 'What it’s for', guide.purpose),
                          _section(context, 'When to use it', guide.useCase),
                          Text('How to use it',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          for (var i = 0; i < guide.steps.length; i++)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                          radius: 16, child: Text('${i + 1}')),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: SelectableText(guide.steps[i],
                                              style: const TextStyle(
                                                  height: 1.6))),
                                    ])),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text('Related guides',
                              style: Theme.of(context).textTheme.titleLarge),
                          for (final related in helpGuides
                              .where((g) =>
                                  g.category == guide.category &&
                                  g.title != guide.title)
                              .take(3))
                            ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                title: Text(related.title),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context)
                                    .pushReplacement<void, void>(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                _GuidePage(related)))),
                          const SizedBox(height: 24),
                          const _SupportCard(),
                        ]))))
      ]));
  Widget _section(BuildContext context, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SelectableText(body, style: const TextStyle(height: 1.6))
      ]));
}

class _SupportCard extends StatelessWidget {
  const _SupportCard();
  @override
  Widget build(BuildContext context) => Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Still need help?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'Tell us the section, what you tried, and the error message. Leave out passwords, private login codes and sensitive documents.'),
            const SizedBox(height: 12),
            const SelectableText(_mail),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 8, children: [
              FilledButton.icon(
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Email support'),
                  onPressed: () async {
                    try {
                      if (await launchUrl(Uri(
                          scheme: 'mailto',
                          path: _mail,
                          query: 'subject=TPC%20Accounts%20support'))) {
                        return;
                      }
                    } catch (_) {}
                    await Clipboard.setData(const ClipboardData(text: _mail));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Support email copied. Paste it into your email app.')));
                    }
                  }),
              OutlinedButton.icon(
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy email'),
                  onPressed: () async {
                    await Clipboard.setData(const ClipboardData(text: _mail));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Support email copied.')));
                    }
                  }),
            ]),
          ])));
}
