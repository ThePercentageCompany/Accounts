import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:tpc_invoice/features/auth/presentation/cubit/saas_session.dart';

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

  Future<void> _deleteWorkspace() async {
    final company = widget.session.company;
    if (company == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently delete workspace?'),
        content: Text(
          'Delete ${company['name']} and all its invoices, quotations, accounting records, employees, uploaded documents and Google Drive workspace files? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all workspace data'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await widget.session.deleteCompany();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<SaasSession, SessionState>(
    bloc: widget.session,
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
            if (session.busy)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Semantics(
                  label: 'Loading company setup',
                  liveRegion: true,
                  child: const CupertinoActivityIndicator(),
                ),
              ),
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
                TextButton.icon(
                  onPressed: session.busy ? null : _deleteWorkspace,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Delete workspace'),
                ),
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
