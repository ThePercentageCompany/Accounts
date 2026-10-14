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
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, bounds) {
      final wide = bounds.maxWidth >= 900;
      final intro = Container(
          padding: EdgeInsets.all(wide ? 48 : 28),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF142C45), Color(0xFF087F8C)])),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business_center_outlined,
                    color: Color(0xFF90E4DE), size: 36),
                const SizedBox(height: 32),
                Text('Your business,\nin one place.',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: wide ? 46 : 34,
                        height: 1.12,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                const Text(
                    'A clear view of your accounts, your team and the work ahead.',
                    style: TextStyle(
                        color: Color(0xFFD7E9EE), fontSize: 17, height: 1.6)),
                const SizedBox(height: 36),
                for (final item in const [
                  (Icons.account_balance_outlined, 'Accounts & reporting'),
                  (Icons.groups_outlined, 'Employees & task scheduling'),
                  (Icons.receipt_long_outlined, 'Invoices & quotations'),
                  (Icons.public, 'Country entities & group overview'),
                ])
                  Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Row(children: [
                        Icon(item.$1, color: const Color(0xFF90E4DE), size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Text(item.$2,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15)))
                      ])),
              ]));
      final login = Padding(
          padding: EdgeInsets.all(wide ? 40 : 24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 32, color: colors.primary),
                const SizedBox(height: 24),
                Text('Welcome back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text('Sign in to continue to your workspace.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: colors.onSurfaceVariant, height: 1.5)),
                const SizedBox(height: 32),
                LoadingButton.icon(
                    busy: busy,
                    onPressed: busy ? null : onSignIn,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    icon: const Icon(Icons.login),
                    label:
                        Text(busy ? 'Opening workspace...' : 'Admin sign in')),
                const SizedBox(height: 14),
                LoadingButton.outlinedIcon(
                    onPressed: busy ? null : onEmployeeLogin,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Employee sign in')),
                const SizedBox(height: 20),
                Text(
                    'Employees: use the invitation link and private code provided by your company.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.5)),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Semantics(
                          liveRegion: true,
                          child: Text(error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.error)))),
                const SizedBox(height: 24),
                TextButton.icon(
                    onPressed: busy ? null : onFaq,
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('Help & getting started')),
              ]));
      return SingleChildScrollView(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: wide ? 32 : 16, vertical: wide ? 64 : 24),
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: colors.outlineVariant)),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                      Expanded(flex: 6, child: intro),
                                      Expanded(flex: 5, child: login)
                                    ])
                              : Column(children: [login, intro]))))));
    });
  }
}
