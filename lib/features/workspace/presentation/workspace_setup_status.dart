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
    final ready = stage == 'READY' && !registering && !registrationPending;
    final colors = Theme.of(context).colorScheme;
    final title = error != null
        ? 'Workspace needs attention'
        : ready
            ? 'Workspace ready'
            : 'Creating your workspace';
    return Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            WorkspaceSyncIcon(
                syncing: registering,
                color: error != null ? colors.error : colors.primary,
                icon: ready ? Icons.check_circle_outline : Icons.hourglass_top),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(error ??
                      (ready
                          ? 'Your company data, documents and employee access are ready.'
                          : registrationPending
                              ? 'Confirm the previous request before creating another workspace.'
                              : 'Preparing secure company storage.')),
                ])),
          ]),
        ));
  }
}
