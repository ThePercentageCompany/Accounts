import 'package:flutter/material.dart';
import 'overview_charts.dart';

class WorkspaceQuickLookCard extends StatelessWidget {
  const WorkspaceQuickLookCard(
      {super.key,
      required this.section,
      required this.tables,
      required this.rows,
      required this.errors,
      required this.busy,
      required this.onOpen,
      required this.onRefresh,
      required this.amounts});
  final String section;
  final List<String> tables;
  final Map<String, List<Map<String, dynamic>>> rows;
  final Map<String, String> errors;
  final Map<String, List<String>> amounts;
  final bool busy;
  final ValueChanged<String> onOpen;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text(section,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700))),
              if (busy)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                    tooltip: 'Refresh $section',
                    onPressed: onRefresh,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.refresh, size: 18)),
            ]),
            for (final table in tables) ...[
              const SizedBox(height: 10),
              InkWell(
                  onTap: () => onOpen(table),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(
                                      table.replaceAllMapped(
                                          RegExp(r'([a-z])([A-Z])'),
                                          (m) => '${m[1]} ${m[2]}'),
                                      style: theme.textTheme.bodySmall)),
                              Text(
                                  errors.containsKey(table)
                                      ? 'Unavailable'
                                      : rows.containsKey(table)
                                          ? '${rows[table]!.length}'
                                          : '—',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_outward, size: 14),
                            ]),
                            if (rows.containsKey(table))
                              _statusBar(context, rows[table]!),
                            for (final amount in amounts[table] ?? <String>[])
                              Text(amount,
                                  style: theme.textTheme.labelSmall,
                                  maxLines: 2),
                            if (errors.containsKey(table))
                              Text('Tap to review connection or access',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.error)),
                            if (rows[table]?.any(
                                    (r) => r['syncStatus'] == 'PENDING') ==
                                true)
                              Text('Includes unsynced changes',
                                  style: theme.textTheme.labelSmall),
                          ]))),
            ],
          ])),
    );
  }

  Widget _statusBar(BuildContext context, List<Map<String, dynamic>> records) {
    final counts = <String, int>{};
    for (final row in records) {
      final label =
          '${row['paymentStatus'] ?? row['status'] ?? row['employmentStatus'] ?? 'Recorded'}'
              .replaceAll('_', ' ');
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (entries.isEmpty)
            Text('No records yet',
                style: Theme.of(context).textTheme.labelSmall)
          else ...[
            Semantics(
                label: entries.map((e) => '${e.key}: ${e.value}').join(', '),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Row(children: [
                      for (var i = 0; i < entries.length; i++)
                        Expanded(
                            flex: entries[i].value,
                            child: Tooltip(
                                message:
                                    '${entries[i].key}: ${entries[i].value}',
                                child: Container(
                                    height: 7,
                                    color: overviewPalette[
                                        i % overviewPalette.length]))),
                    ]))),
            const SizedBox(height: 6),
            Wrap(spacing: 10, runSpacing: 4, children: [
              for (var i = 0; i < entries.length; i++)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: overviewPalette[i % overviewPalette.length],
                          shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Flexible(
                      child: Text(
                          '${entries[i].key.toLowerCase()} ${entries[i].value}',
                          style: Theme.of(context).textTheme.labelSmall)),
                ]),
            ]),
          ],
        ]));
  }
}
