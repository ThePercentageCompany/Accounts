import 'package:flutter/material.dart';

import 'saas_session.dart';

/// Shared-backend setup controls. The host owns the session and navigation.
/// Accounting routes must only be attached after repository migration.
class CompanySetupView extends StatefulWidget {
  const CompanySetupView({
    super.key,
    required this.session,
    required this.navigate,
  });

  final SaasSession session;
  final Future<void> Function(Uri) navigate;

  @override
  State<CompanySetupView> createState() => _CompanySetupViewState();
}

class _CompanySetupViewState extends State<CompanySetupView> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final session = widget.session;
      final company = session.company;
      final action = company?['nextAction'];
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Company setup',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (session.busy) const LinearProgressIndicator(),
            if (session.error != null)
              Semantics(liveRegion: true, child: Text(session.error!)),
            if (session.owner == null && session.employee == null)
              FilledButton(
                onPressed: session.busy
                    ? null
                    : () => session.signIn(widget.navigate),
                child: const Text('Sign in with Google'),
              ),
            if (session.employee != null)
              const Text('Company setup is managed by your company owner.'),
            if (session.owner != null) ...[
              if (session.ready)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Company setup is complete. Open your workspace to manage employee access and view company records.',
                  ),
                ),
              if (session.companies.isNotEmpty)
                DropdownButton<String>(
                  isExpanded: true,
                  value: company?['companyId'] as String?,
                  items: session.companies
                      .map(
                        (item) => DropdownMenuItem(
                          value: item['companyId'] as String,
                          child: Text(item['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: session.busy
                      ? null
                      : (id) {
                          if (id != null) session.selectCompany(id);
                        },
                ),
              if (company != null) ...[
                Text(
                  session.ready
                      ? 'Company workspace is ready.'
                      : 'Setup: ${company['stage']}',
                ),
                if (action == 'CONNECT_GOOGLE' || action == 'RECONNECT_GOOGLE')
                  FilledButton(
                    onPressed: session.busy
                        ? null
                        : () => session.connectGoogle(widget.navigate),
                    child: Text(
                      action == 'RECONNECT_GOOGLE'
                          ? 'Reconnect Google'
                          : 'Connect Google',
                    ),
                  ),
                if (!session.ready) ...[
                  TextButton(
                    onPressed: session.busy ? null : session.refreshSetup,
                    child: const Text('Refresh setup status'),
                  ),
                  if (company['stage'] == 'RECOVERABLE_FAILURE')
                    FilledButton(
                      onPressed: session.busy ? null : session.retrySetup,
                      child: const Text('Retry setup'),
                    ),
                ],
              ],
              if (session.pendingCompanyName != null)
                Text('Pending registration: ${session.pendingCompanyName}'),
              TextField(
                controller: _name,
                enabled: !session.busy && session.pendingCompanyName == null,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'New company name',
                ),
              ),
              FilledButton(
                onPressed: session.busy
                    ? null
                    : () => session.createCompany(
                        session.pendingCompanyName ?? _name.text,
                      ),
                child: Text(
                  session.pendingCompanyName == null
                      ? 'Create company'
                      : 'Resume registration',
                ),
              ),
            ],
            if (session.owner != null || session.employee != null)
              TextButton(
                onPressed: session.busy ? null : session.signOut,
                child: const Text('Sign out'),
              ),
          ],
        ),
      );
    },
  );
}
