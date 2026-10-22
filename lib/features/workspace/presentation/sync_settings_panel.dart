import 'sync_change_editor.dart';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/offline/offline_outbox.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

class SyncSettingsPanel extends StatefulWidget {
  const SyncSettingsPanel({
    super.key,
    required this.outbox,
    required this.api,
    required this.companyId,
    this.employee = false,
    this.storageIssue,
  });
  final OfflineOutbox outbox;
  final SaasApi api;
  final String companyId;
  final bool employee;
  final String? storageIssue;
  @override
  State<SyncSettingsPanel> createState() => _SyncSettingsPanelState();
}

class _SyncSettingsPanelState extends State<SyncSettingsPanel> {
  String? _error;
  bool _saving = false;
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(Map<String, Object?> op) => _run(() async {
    var version = op['expectedVersion'] as int;
    Map<String, dynamic>? serverRecord;
    if (op['action'] != 'create' && op['recordId'] != null) {
      final response = await widget.api.syncBaseline(
        widget.companyId,
        op['table'] as String,
        employee: widget.employee,
      );
      final rows = op['table'] == 'ReportSettings'
          ? [
              {
                ...response,
                'recordId': 'report-settings',
                'recordVersion': response['version'],
              },
            ]
          : (response['records'] ?? response['employees']) as List;
      final current = rows
          .where((r) => r['recordId'] == op['recordId'])
          .firstOrNull;
      if (current == null) {
        throw StateError(
          'This record no longer exists online. Discard its rejected edit.',
        );
      }
      version = int.parse('${current['recordVersion']}');
      serverRecord = Map<String, dynamic>.from(current as Map);
    }
    if (!mounted) return;
    final references = <String, List<Map<String, dynamic>>>{};
    final values = Map<String, Object?>.from(op['values'] as Map? ?? {});
    for (final entry in const {
      'customerId': 'Customers',
      'employeeId': 'Employees',
      'shareholderId': 'Shareholders',
      'projectId': 'Projects',
      'invoiceId': 'Invoices',
    }.entries) {
      if (!values.containsKey(entry.key)) continue;
      try {
        final response = entry.value == 'Employees' && !widget.employee
            ? await widget.api.employees(widget.companyId)
            : await widget.api.records(
                widget.companyId,
                entry.value,
                employee: widget.employee,
              );
        references[entry.key] =
            ((response['records'] ?? response['employees']) as List)
                .map((r) => Map<String, dynamic>.from(r as Map))
                .toList();
      } catch (_) {
        /* Keep saved references if unavailable. */
      }
    }
    if (!mounted) return;
    final corrected = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => SyncChangeEditor(
        section: '${op['table']}',
        serverValues: serverRecord,
        references: references,
        values: Map<String, Object?>.from(op['values'] as Map? ?? {}),
      ),
    );
    if (corrected != null && mounted) {
      await widget.outbox.correctRejected(
        op['operationId'] as String,
        corrected,
        expectedVersion: version,
      );
    }
  });

  Future<void> _delete(Map<String, Object?> op) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard rejected local change?'),
        content: const Text(
          'This change was rejected by the server. Its local edit will be removed. Dependent changes that have not been submitted will also be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _run(
        () => widget.outbox.discardRejected(
          operationId: op['operationId'] as String,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.outbox,
    builder: (context, _) {
      final box = widget.outbox;
      final issues = box.pending
          .where((op) => op['error'] != null || op['state'] == 'failed')
          .toList();
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sync and device storage',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${box.status} · ${box.pending.length} saved change(s) awaiting confirmation',
              ),
              const SizedBox(height: 8),
              const Text(
                'Changes are saved on this device first. Keep using the app while they sync. Reports and document numbers are confirmed by the server.',
              ),
              if (box.storageError != null || widget.storageIssue != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('${box.storageError ?? widget.storageIssue}'),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: box.syncing || _saving
                      ? null
                      : () {
                          box.retry().ignore();
                        },
                  icon: box.syncing
                      ? const AppActivityIndicator(radius: 8)
                      : const Icon(Icons.sync),
                  label: const Text('Retry sync'),
                ),
              ),
              if (issues.isEmpty) const Text('No sync errors.'),
              for (final op in issues)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${op['table']} · ${op['action']} · ${box.operationStatus(op)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text('${op['error']}'),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (op['errorCode'] != 'VERSION_CONFLICT')
                            TextButton(
                              onPressed: _saving || box.syncing
                                  ? null
                                  : () {
                                      if (op['state'] == 'failed') {
                                        _run(
                                          () => box.correctRejected(
                                            op['operationId'] as String,
                                            Map<String, Object?>.from(
                                              op['values'] as Map? ?? {},
                                            ),
                                            expectedVersion:
                                                op['expectedVersion'] as int,
                                          ),
                                        );
                                      } else {
                                        box.retry().ignore();
                                      }
                                    },
                              child: const Text('Retry'),
                            ),
                          if (op['state'] == 'failed') ...[
                            TextButton(
                              onPressed: _saving ? null : () => _edit(op),
                              child: const Text('Edit'),
                            ),
                            TextButton(
                              onPressed: _saving ? null : () => _delete(op),
                              child: const Text('Discard'),
                            ),
                          ] else
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'Awaiting confirmation; retained for a safe retry.',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
