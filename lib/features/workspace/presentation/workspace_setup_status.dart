import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/widgets/workspace_sync_icon.dart';

class WorkspaceSetupStatus extends StatelessWidget {
  const WorkspaceSetupStatus(
      {super.key,
      required this.stage,
      this.registering = false,
      this.registrationPending = false,
      this.error});
  final String? stage;
  final bool registering, registrationPending;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ready = !registering && !registrationPending && stage == 'READY';
    final attention = error != null || stage == 'RECOVERABLE_FAILURE';
    final connection =
        ['GOOGLE_CONNECTION_REQUIRED', 'RECONNECT_REQUIRED'].contains(stage);
    final deleting = stage == 'DELETING';
    final waiting = connection || (registrationPending && !registering);
    final active = !ready && !attention && !waiting && !deleting;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final color = attention
        ? colors.error
        : ready
            ? (dark ? Colors.green.shade200 : Colors.green.shade700)
            : waiting || deleting
                ? (dark ? Colors.amber.shade200 : Colors.orange.shade800)
                : (dark ? Colors.lightBlue.shade200 : Colors.blue.shade700);
    final title = registering
        ? 'Creating your workspace'
        : registrationPending
            ? 'Registration needs confirmation'
            : attention
                ? 'Setup needs attention'
                : ready
                    ? 'Workspace setup complete'
                    : connection
                        ? 'Connect Google to continue'
                        : deleting
                            ? 'Workspace deletion in progress'
                            : switch (stage) {
                                'CREATING_FOLDER' ||
                                'FOLDER_READY' =>
                                  'Preparing company folders',
                                'CREATING_SPREADSHEET' ||
                                'SPREADSHEET_READY' =>
                                  'Preparing your accounts database',
                                'CREATING_SCHEMA' =>
                                  'Setting up your accounting tables',
                                'VERIFYING_SCHEMA' => 'Checking your workspace',
                                _ => 'Preparing your workspace',
                              };
    final message = error ??
        (ready
            ? 'Everything is ready. You can open your company workspace.'
            : registering
                ? 'Saving your company registration. Please wait; keep this page open.'
                : registrationPending
                    ? 'Use Resume registration to confirm the saved request.'
                    : connection
                        ? 'Setup will continue after you connect your Google account.'
                        : attention
                            ? 'Your setup progress is saved. Use Retry setup to continue.'
                            : deleting
                                ? 'Removing workspace data. Check the status before retrying deletion.'
                                : 'Setup is running in the background. Status updates automatically; you can wait here or return later.');
    final step = registering || registrationPending
        ? 0
        : connection
            ? 1
            : ready
                ? 5
                : ['CREATING_SCHEMA', 'VERIFYING_SCHEMA'].contains(stage)
                    ? 3
                    : stage == 'SPREADSHEET_READY'
                        ? 3
                        : 2;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          border: Border.all(color: color.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            WorkspaceSyncIcon(
                syncing: active,
                color: color,
                icon: ready
                    ? Icons.check_circle_outline
                    : attention
                        ? Icons.error_outline
                        : Icons.hourglass_top),
            const SizedBox(width: 12),
            Expanded(
                child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              child: Align(
                  key: ValueKey(title),
                  alignment: Alignment.centerLeft,
                  child: Text(title,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 16))),
            )),
          ]),
          const SizedBox(height: 12),
          Text(message),
          if (!deleting) ...[
            const SizedBox(height: 16),
            for (final entry in const [
              'Register company',
              'Connect Google',
              'Prepare company storage',
              'Configure and verify accounts',
              'Ready to open',
            ].indexed)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(
                        entry.$1 < step
                            ? Icons.check_circle
                            : entry.$1 == step
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                        size: 18,
                        color:
                            entry.$1 <= step ? color : colors.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(entry.$2,
                            style: TextStyle(
                                fontWeight: entry.$1 == step
                                    ? FontWeight.w600
                                    : FontWeight.normal))),
                  ])),
          ],
        ]),
      ),
    );
  }
}
