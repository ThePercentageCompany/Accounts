import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';

class LandingView extends StatelessWidget {
  const LandingView(
      {super.key,
      required this.busy,
      required this.onSignIn,
      required this.onFaq,
      required this.onEmployeeLogin,
      this.error});
  final bool busy;
  final VoidCallback onSignIn, onFaq, onEmployeeLogin;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width < 600 ? 16 : 32),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                        MediaQuery.sizeOf(context).width < 600 ? 24 : 40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.primaryContainer,
                            colors.surfaceContainerLow
                          ]),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.auto_graph_rounded,
                              size: 40, color: colors.primary),
                          const SizedBox(height: 20),
                          Text('YOUR BUSINESS, TOGETHER',
                              style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  letterSpacing: 1.4)),
                          const SizedBox(height: 12),
                          Text(
                              'Less scattered work.\nA clearer picture of your business.',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800, height: 1.15)),
                          const SizedBox(height: 20),
                          const Text(
                              'TPC Accounts brings invoices, customers, payments, accounting and team tasks into one company workspace.',
                              style: TextStyle(fontSize: 16, height: 1.6)),
                          const SizedBox(height: 24),
                          Wrap(spacing: 12, runSpacing: 12, children: [
                            LoadingButton.icon(
                                onPressed: busy ? null : onSignIn,
                                icon: const Icon(Icons.login),
                                label: Text(busy
                                    ? 'Opening sign-in…'
                                    : 'Get started with Google')),
                            OutlinedButton.icon(
                                onPressed: onFaq,
                                icon: const Icon(Icons.help_outline),
                                label: const Text('FAQ & getting started')),
                          ]),
                          const SizedBox(height: 16),
                          const Text(
                              'Already have a workspace? Sign in to continue where you left off.'),
                          if (busy)
                            Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Semantics(
                                    liveRegion: true,
                                    child: const Text(
                                        'Please wait while we connect you to Google.'))),
                        ]),
                  ),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(error!,
                                style: TextStyle(color: colors.error)))),
                  const SizedBox(height: 28),
                  Text('One place for the everyday work',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 760 ? 3 : 1;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 16) / columns;
                    return Wrap(spacing: 16, runSpacing: 16, children: [
                      for (final feature in const [
                        (
                          Icons.receipt_long_outlined,
                          'Sales & payments',
                          'Create quotations and invoices, manage customers and record receipts.'
                        ),
                        (
                          Icons.account_balance_outlined,
                          'Understand your accounts',
                          'Track income, expenses, assets and capital. Review posted activity in financial reports.'
                        ),
                        (
                          Icons.groups_outlined,
                          'Keep your team connected',
                          'Organize tasks and calendars, manage employees and choose their workspace access.'
                        ),
                      ])
                        SizedBox(
                            width: width,
                            child: Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(feature.$1,
                                              color: colors.primary),
                                          const SizedBox(height: 12),
                                          Text(feature.$2,
                                              style:
                                                  theme.textTheme.titleMedium),
                                          const SizedBox(height: 8),
                                          Text(feature.$3,
                                              style: TextStyle(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                  height: 1.5)),
                                        ])))),
                    ]);
                  }),
                  const SizedBox(height: 28),
                  Text('Start in three steps',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (final step in const [
                    ('Sign in', 'Use Google to access your owner account.'),
                    (
                      'Create your workspace',
                      'Name your company and connect Google to prepare its storage. Setup shows you the progress.'
                    ),
                    (
                      'Make it yours',
                      'Check your company settings, add a customer and create your first invoice draft.'
                    ),
                  ].indexed)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                  radius: 16,
                                  backgroundColor: colors.primaryContainer,
                                  foregroundColor: colors.onPrimaryContainer,
                                  child: Text('${step.$1 + 1}')),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(step.$2.$1,
                                        style: theme.textTheme.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(step.$2.$2),
                                  ])),
                            ])),
                  const SizedBox(height: 20),
                  Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Joining your company as an employee?',
                                    style: theme.textTheme.titleMedium),
                                const SizedBox(height: 8),
                                const Text(
                                    'Use the invitation and private login code provided by your company administrator.'),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                    onPressed: busy ? null : onEmployeeLogin,
                                    icon: const Icon(Icons.badge_outlined),
                                    label: const Text('Employee login')),
                              ]))),
                  const SizedBox(height: 24),
                ]),
          ),
        ),
      ),
    );
  }
}
