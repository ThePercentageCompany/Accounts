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
    final theme = Theme.of(context), colors = theme.colorScheme;
    return LayoutBuilder(builder: (context, bounds) {
      final wide = bounds.maxWidth >= 900;
      final hero =
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: Color(0xffef5a00), shape: BoxShape.circle)),
          const SizedBox(width: 9),
          Expanded(
              child: Text('THE PERCENTAGE COMPANY',
                  style:
                      theme.textTheme.labelSmall?.copyWith(letterSpacing: 2)))
        ]),
        const SizedBox(height: 28),
        Text('Less admin.\nMore business.',
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: wide ? 76 : 46,
                height: 1.02,
                letterSpacing: wide ? -4 : -2,
                fontWeight: FontWeight.w500,
                color: colors.onSurface)),
        const SizedBox(height: 24),
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
                'Your accounts, your people and your next move.\nOne considered workspace for everything ahead.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: colors.onSurfaceVariant, height: 1.7))),
        const SizedBox(height: 30),
        Wrap(spacing: 12, runSpacing: 12, children: [
          LoadingButton.icon(
              busy: busy,
              onPressed: busy ? null : onSignIn,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(busy ? 'Opening workspace...' : 'Admin sign in'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20))),
          LoadingButton.outlinedIcon(
              onPressed: busy ? null : onEmployeeLogin,
              icon: const Icon(Icons.person_outline, size: 18),
              label: const Text('Employee sign in'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20))),
        ]),
        const SizedBox(height: 16),
        Text('Employees: enter with your company invitation and private code.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant)),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(
                  liveRegion: true,
                  child: Text(error!, style: TextStyle(color: colors.error)))),
        const SizedBox(height: 16),
        TextButton(
            onPressed: busy ? null : onFaq,
            child: const Text('Explore the workspace  ↗')),
      ]);
      final preview = _WorkspaceIllustration();
      return SingleChildScrollView(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          wide ? 64 : 24, wide ? 80 : 40, wide ? 64 : 24, 40),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (wide)
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(flex: 6, child: hero),
                                    const SizedBox(width: 48),
                                    Expanded(flex: 5, child: preview)
                                  ])
                            else ...[hero, const SizedBox(height: 36), preview],
                            const SizedBox(height: 64),
                            const Divider(),
                            const SizedBox(height: 28),
                            Text('Everything connected. Nothing in your way.',
                                style: theme.textTheme.headlineSmall),
                            const SizedBox(height: 24),
                            LayoutBuilder(builder: (context, size) {
                              final columns = size.maxWidth >= 850
                                  ? 4
                                  : size.maxWidth >= 500
                                      ? 2
                                      : 1;
                              return Wrap(
                                  spacing: 24,
                                  runSpacing: 28,
                                  children: [
                                    for (final feature in const [
                                      (
                                        Icons.receipt_long_outlined,
                                        '01',
                                        'Sales, simplified.',
                                        'Quotations, invoices and customer payments.'
                                      ),
                                      (
                                        Icons.insights_outlined,
                                        '02',
                                        'Clarity in the numbers.',
                                        'Reports, cash and a detailed financial overview.'
                                      ),
                                      (
                                        Icons.people_outline,
                                        '03',
                                        'A team in sync.',
                                        'People, payroll, projects and everyday tasks.'
                                      ),
                                      (
                                        Icons.public_outlined,
                                        '04',
                                        'Room to grow.',
                                        'Country entities with a connected group view.'
                                      ),
                                    ])
                                      SizedBox(
                                          width: (size.maxWidth -
                                                  24 * (columns - 1)) /
                                              columns,
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(children: [
                                                  Icon(feature.$1, size: 23),
                                                  const Spacer(),
                                                  Text(feature.$2,
                                                      style: theme
                                                          .textTheme.labelSmall)
                                                ]),
                                                const SizedBox(height: 22),
                                                Text(feature.$3,
                                                    style: theme
                                                        .textTheme.titleMedium),
                                                const SizedBox(height: 8),
                                                Text(feature.$4,
                                                    style: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                            color: colors
                                                                .onSurfaceVariant)),
                                              ])),
                                  ]);
                            }),
                            const SizedBox(height: 48),
                            const Divider(),
                            const SizedBox(height: 16),
                            Text(
                                'TPC Business Suite · Built for the work ahead.',
                                style: theme.textTheme.bodySmall),
                          ])))));
    });
  }
}

class _WorkspaceIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
                offset: Offset(0, 18 * (1 - value)), child: child)),
        child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outlineVariant)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.grid_view_outlined, size: 17),
                    const SizedBox(width: 9),
                    const Expanded(child: Text('Your workspace')),
                    Text('PREVIEW',
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.5,
                            color: colors.onSurfaceVariant))
                  ]),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('A clearer view.\nA better working day.',
                      style: TextStyle(
                          fontSize: 28, height: 1.15, letterSpacing: -1)),
                  const SizedBox(height: 26),
                  SizedBox(
                      height: 112,
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 0; i < 10; i++)
                              Expanded(
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      child: Container(
                                          height: [
                                            28.0,
                                            46.0,
                                            39.0,
                                            60.0,
                                            55.0,
                                            77.0,
                                            67.0,
                                            87.0,
                                            81.0,
                                            108.0
                                          ][i],
                                          decoration: BoxDecoration(
                                              color: i == 9
                                                  ? const Color(0xffef5a00)
                                                  : colors.onSurface.withValues(
                                                      alpha: .08 + i * .018),
                                              borderRadius: const BorderRadius
                                                  .vertical(
                                                  top: Radius.circular(3)))))),
                          ])),
                  const SizedBox(height: 12),
                  Text('ILLUSTRATIVE ACTIVITY',
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.2,
                          color: colors.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  for (final item in const [
                    (Icons.check_circle_outline, 'Accounts in focus'),
                    (Icons.view_kanban_outlined, 'Work moving forward'),
                    (Icons.groups_outlined, 'People connected')
                  ])
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          Icon(item.$1, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(item.$2)),
                          const Icon(Icons.arrow_outward, size: 14)
                        ])),
                ])));
  }
}
