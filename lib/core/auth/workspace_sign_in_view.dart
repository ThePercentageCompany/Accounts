import 'package:flutter/material.dart';

import '../widgets/brand_logo.dart';
import 'employee_login_view.dart';
import 'google_session.dart';
import 'sign_in_button.dart';
import '../saas/saas_api.dart';

/// The entry screen keeps owner authorization separate from employee access.
class WorkspaceSignInView extends StatelessWidget {
  const WorkspaceSignInView({super.key, required this.session});

  final GoogleSession session;

  Future<void> _scan(BuildContext context) async {
    if (configuredSaasApiOrigin.isNotEmpty) {
      session.requestEmployeeLogin();
      return;
    }
    final value = await scanEmployeeQr(context);
    if (!context.mounted || value == null) return;
    if (!session.acceptEmployeeInvite(value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This QR is not supported. Ask your manager for a new employee QR.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final text = Theme.of(context).textTheme;
      return Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              final introduction = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      TpcBrandLogo(size: 40),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'TPC Accounts',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: wide ? 64 : 28),
                  Text(
                    'A clearer view of\nyour business.',
                    style: text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Manage invoices, people and finances from your company workspace.',
                    style: text.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  if (wide) ...[
                    const SizedBox(height: 40),
                    const _Feature(
                      icon: Icons.receipt_long_outlined,
                      title: 'Keep business moving',
                      detail: 'Invoices, quotations and customer records.',
                    ),
                    const _Feature(
                      icon: Icons.groups_outlined,
                      title: 'Bring your team together',
                      detail: 'Employee access, payroll and attendance.',
                    ),
                    const _Feature(
                      icon: Icons.insights_outlined,
                      title: 'Understand your numbers',
                      detail: 'Income, expenses, assets and reports.',
                    ),
                  ],
                ],
              );
              final access = Container(
                padding: EdgeInsets.all(wide ? 32 : 20),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome to your workspace',
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose how you want to sign in.',
                      style: text.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Company owner',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.user == null
                          ? 'Use your Google account to open or set up your company.'
                          : 'Continue with ${session.user!.email}.',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    if (session.user == null)
                      Center(
                        child: AbsorbPointer(
                          absorbing: session.isAuthorizing,
                          child: googleButton(() => session.signIn()),
                        ),
                      )
                    else ...[
                      FilledButton.icon(
                        onPressed: session.isAuthorizing
                            ? null
                            : () => session.authorize(),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Continue to workspace'),
                      ),
                      TextButton(
                        onPressed: session.isAuthorizing
                            ? null
                            : () => session.signOut(),
                        child: const Text('Use another Google account'),
                      ),
                    ],
                    if (session.isAuthorizing) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('Connecting your account…'),
                    ],
                    if (session.error != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            session.error!,
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(),
                    ),
                    Text(
                      'Joining your team?',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use the QR or login link from your manager and your private login code.',
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: session.isAuthorizing
                          ? null
                          : session.requestEmployeeLogin,
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Employee Login'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: session.isAuthorizing
                          ? null
                          : () => _scan(context),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR'),
                    ),
                  ],
                ),
              );
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 48 : 20,
                  vertical: wide ? 56 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: introduction),
                              const SizedBox(width: 72),
                              Expanded(child: access),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              introduction,
                              const SizedBox(height: 32),
                              access,
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                detail,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
