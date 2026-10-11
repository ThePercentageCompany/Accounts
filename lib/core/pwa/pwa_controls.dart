import 'package:flutter/material.dart';
import 'pwa_runtime.dart';
import '../widgets/loading.dart';

class PwaControls extends StatefulWidget {
  const PwaControls(
      {super.key, this.hasActiveSave, this.syncChanges, this.syncStatus});
  final Future<bool> Function()? hasActiveSave;
  final Listenable? syncChanges;
  final String Function()? syncStatus;
  @override
  State<PwaControls> createState() => _PwaControlsState();
}

class _PwaControlsState extends State<PwaControls> {
  final _runtime = PwaRuntime();
  String? _error;
  final _panelChanges = ValueNotifier<int>(0);
  @override
  void dispose() {
    _runtime.dispose();
    _panelChanges.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    _error = null;
    if ((_runtime.status['updateState'] ?? 'idle') == 'idle') {
      _runtime.checkUpdate().ignore();
    }
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => ListenableBuilder(
              listenable: Listenable.merge(
                  [_runtime, _panelChanges, widget.syncChanges]),
              builder: (context, _) {
                final status = _runtime.status;
                final state = status['updateState'] as String? ?? 'idle';
                final busy =
                    ['checking', 'downloading', 'applying'].contains(state);
                final message = switch (state) {
                  'checking' => 'Checking for a new version…',
                  'downloading' =>
                    'Downloading the new version… You can keep working.',
                  'ready' => 'New version downloaded and ready to install.',
                  'applying' =>
                    'Installing update… The app will restart shortly.',
                  'updated' =>
                    'Updated successfully. You are using the latest downloaded version.',
                  'current' =>
                    'You are up to date. No new version is available.',
                  'offline' => 'You are offline. Connect to check for updates.',
                  'unavailable' =>
                    'App updates are unavailable in this browser.',
                  'error' =>
                    'Update could not finish. Reconnect and try again.',
                  _ =>
                    'Update status has not been checked. Select Check for updates.',
                };
                return SafeArea(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('App & updates',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 16),
                              Text(status['installed'] == true
                                  ? 'You are using the installed app.'
                                  : 'Install TPC Accounts for a dedicated app window and quick access from your home screen.'),
                              if (status['installable'] == true)
                                FilledButton.icon(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await _runtime.install();
                                    },
                                    icon: const Icon(Icons.install_mobile),
                                    label: const Text('Install app'))
                              else if (status['installed'] != true)
                                const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                        'iPhone/iPad: open in Safari, tap Share, then Add to Home Screen. On other browsers, use Install app or Add to Home Screen in the browser menu when available.')),
                              const Divider(height: 32),
                              Row(children: [
                                if (busy) ...[
                                  const AppActivityIndicator(),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                    child: Text(message,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium)),
                              ]),
                              const SizedBox(height: 8),
                              if (widget.syncStatus != null) ...[
                                Text(widget.syncStatus!()),
                                const SizedBox(height: 12),
                              ],
                              const Text(
                                  'Finish any open forms before updating. Changes already saved on this device stay safe and resume syncing after restart. Other open tabs will stay on their current screen.'),
                              if (_error != null)
                                Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                              FilledButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          _error = null;
                                          _panelChanges.value++;
                                          try {
                                            if (_runtime.status[
                                                    'updateAvailable'] ==
                                                true) {
                                              if (await widget.hasActiveSave
                                                      ?.call() ==
                                                  true) {
                                                if (!mounted) return;
                                                _error =
                                                    'A change is being saved on this device. Please try updating again in a moment.';
                                                _panelChanges.value++;
                                                return;
                                              }
                                              await _runtime.update();
                                            } else {
                                              await _runtime.checkUpdate();
                                            }
                                          } catch (_) {
                                            if (mounted) {
                                              _error =
                                                  'Unable to update. Reconnect and try again.';
                                              _panelChanges.value++;
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.system_update_alt),
                                  label: Text(status['updateAvailable'] == true
                                      ? 'Update now'
                                      : 'Check for updates')),
                            ])));
              },
            ));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: _runtime,
      builder: (context, _) => IconButton(
          tooltip: 'Install app & updates',
          onPressed: _open,
          icon: Badge(
              isLabelVisible: _runtime.status['updateAvailable'] == true,
              child: const Icon(Icons.install_mobile))));
}
