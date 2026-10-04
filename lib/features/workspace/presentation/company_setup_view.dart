import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tpc_invoice/features/auth/presentation/cubit/saas_session.dart';

/// Workspace management reuses the session's provisioning and deletion flows.
class CompanySetupView extends StatefulWidget {
  const CompanySetupView({
    super.key,
    required this.session,
    required this.navigate,
    this.onOpen,
  });
  final SaasSession session;
  final Future<void> Function(Uri) navigate;
  final VoidCallback? onOpen;
  @override
  State<CompanySetupView> createState() => _CompanySetupViewState();
}

class _CompanySetupViewState extends State<CompanySetupView> {
  final _name = TextEditingController();
  String _search = '';
  bool _creating = false;

  Future<void> _deleteWorkspace() async {
    final company = widget.session.company;
    if (company == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined, size: 36),
        title: const Text('Permanently delete workspace?'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${company['name']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                'All invoices, quotations, accounting records, employees, uploaded documents and Google Drive workspace files will be permanently removed.',
              ),
              const SizedBox(height: 16),
              const Text(
                'This cannot be undone.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
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

  String _status(Map<String, dynamic> company) => switch (company['stage']) {
    'READY' => 'Ready',
    'DELETING' => 'Deletion in progress',
    'RECOVERABLE_FAILURE' => 'Needs attention',
    _ => 'Setup in progress',
  };

  Widget _card(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );

  @override
  Widget build(BuildContext context) => BlocBuilder<SaasSession, SessionState>(
    bloc: widget.session,
    builder: (context, state) {
      final session = widget.session;
      final company = state.company;
      final colors = Theme.of(context).colorScheme;
      final reduced = MediaQuery.disableAnimationsOf(context);
      final companies = state.companies
          .where((item) => '${item['name']}'.toLowerCase().contains(_search))
          .toList();
      final action = company?['nextAction'];
      final overview = _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.business_outlined, color: colors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    company == null
                        ? 'Your next workspace'
                        : '${company['name']}',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TweenAnimationBuilder<double>(
              key: ValueKey(company?['companyId']),
              tween: Tween(begin: 0, end: 1),
              duration: reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - value)),
                  child: child,
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(
                      session.ready
                          ? Icons.check_circle_outline
                          : Icons.build_circle_outlined,
                      size: 18,
                    ),
                    label: Text(
                      company == null ? 'Get started' : _status(company),
                    ),
                  ),
                  const Chip(
                    avatar: Icon(Icons.lock_outline, size: 18),
                    label: Text('Owner managed'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              company == null
                  ? 'Create a workspace to bring your customers, invoices and accounting together.'
                  : session.ready
                  ? 'Everything is ready. Open your workspace and get back to business.'
                  : action == 'CONNECT_GOOGLE' || action == 'RECONNECT_GOOGLE'
                  ? 'Connect your Google account to finish preparing company storage.'
                  : company['stage'] == 'DELETING'
                  ? 'Workspace deletion has started. If it was interrupted, use Delete workspace to retry removing the remaining data.'
                  : 'We are preparing your company workspace. You can refresh its status or return later.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.6),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (session.ready && widget.onOpen != null)
                  FilledButton.icon(
                    onPressed: state.busy ? null : widget.onOpen,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Open company workspace'),
                  ),
                if (action == 'CONNECT_GOOGLE' || action == 'RECONNECT_GOOGLE')
                  FilledButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => session.connectGoogle(widget.navigate),
                    icon: const Icon(Icons.link),
                    label: Text(
                      action == 'RECONNECT_GOOGLE'
                          ? 'Reconnect Google'
                          : 'Connect Google',
                    ),
                  ),
                if (company != null && !session.ready)
                  OutlinedButton.icon(
                    onPressed: state.busy ? null : session.refreshSetup,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh setup status'),
                  ),
                if (company?['stage'] == 'RECOVERABLE_FAILURE')
                  FilledButton(
                    onPressed: state.busy ? null : session.retrySetup,
                    child: const Text('Retry setup'),
                  ),
              ],
            ),
            if (company != null) ...[
              const Divider(height: 40),
              Text(
                'Workspace management',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Permanently remove this workspace and all its company data.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: state.busy ? null : _deleteWorkspace,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete workspace'),
              ),
            ],
          ],
        ),
      );
      return SingleChildScrollView(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 16 : 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your workspaces',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A clear home for every business you manage.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (state.owner != null || state.employee != null)
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: state.busy ? null : session.signOut,
                    icon: const Icon(Icons.logout),
                  ),
              ],
            ),
            SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.centerRight,
                child: state.busy
                    ? Semantics(
                        label: 'Loading company setup',
                        liveRegion: true,
                        child: const CupertinoActivityIndicator(),
                      )
                    : null,
              ),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _card(
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: colors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(state.error!),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (state.owner == null && state.employee == null)
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.business_outlined, size: 48),
                    const SizedBox(height: 20),
                    Text(
                      'Make room for your business',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sign in to create a workspace or continue managing an existing company.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: state.busy
                          ? null
                          : () => session.signIn(widget.navigate),
                      child: const Text('Sign in with Google'),
                    ),
                  ],
                ),
              ),
            if (state.employee != null)
              _card(
                const Text('Company setup is managed by your company owner.'),
              ),
            if (state.owner != null) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final list = _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Workspace directory',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Text(
                              '${state.companies.length}',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search workspaces',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => setState(
                            () => _search = value.trim().toLowerCase(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (companies.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              state.companies.isEmpty
                                  ? 'No workspaces yet. Create your first company below.'
                                  : 'No workspaces match your search.',
                            ),
                          ),
                        for (final item in companies)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: company?['companyId'] == item['companyId']
                                  ? colors.primaryContainer
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                leading: const Icon(Icons.business_outlined),
                                title: Text(
                                  '${item['name']}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(_status(item)),
                                trailing: Icon(
                                  company?['companyId'] == item['companyId']
                                      ? Icons.check_circle_outline
                                      : Icons.chevron_right,
                                ),
                                onTap: state.busy
                                    ? null
                                    : () => session.selectCompany(
                                        item['companyId'] as String,
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                  if (constraints.maxWidth < 820) {
                    return Column(
                      children: [list, const SizedBox(height: 20), overview],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: list),
                      const SizedBox(width: 24),
                      Expanded(flex: 6, child: overview),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.add_business_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Start another workspace',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (state.companies.isNotEmpty &&
                            state.pendingCompanyName == null)
                          IconButton(
                            tooltip: _creating
                                ? 'Collapse company form'
                                : 'Expand company form',
                            onPressed: () =>
                                setState(() => _creating = !_creating),
                            icon: Icon(
                              _creating || state.pendingCompanyName != null
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Keep each companyâ€™s records and team in its own workspace.',
                    ),
                    AnimatedSize(
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child:
                          _creating ||
                              state.pendingCompanyName != null ||
                              state.companies.isEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),
                                if (state.pendingCompanyName != null)
                                  Text(
                                    'Pending registration: ${state.pendingCompanyName}',
                                  ),
                                TextField(
                                  controller: _name,
                                  enabled:
                                      !state.busy &&
                                      state.pendingCompanyName == null,
                                  maxLength: 160,
                                  decoration: const InputDecoration(
                                    labelText: 'New company name',
                                    prefixIcon: Icon(Icons.business_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: state.busy
                                      ? null
                                      : () => session.createCompany(
                                          state.pendingCompanyName ??
                                              _name.text,
                                        ),
                                  icon: const Icon(Icons.add),
                                  label: Text(
                                    state.pendingCompanyName == null
                                        ? 'Create company'
                                        : 'Resume registration',
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
