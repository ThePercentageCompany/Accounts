import 'package:flutter/material.dart';
import 'pwa_runtime.dart';

class PwaControls extends StatefulWidget {
  const PwaControls({super.key, this.hasPendingWork});
  final Future<bool> Function()? hasPendingWork;
  @override
  State<PwaControls> createState() => _PwaControlsState();
}

class _PwaControlsState extends State<PwaControls> {
  final _runtime = PwaRuntime();
  String? _error;
  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final status = _runtime.status;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('App & updates',
                          style: Theme.of(context).textTheme.titleLarge),
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
                      Text(status['updateAvailable'] == true
                          ? 'New version available'
                          : 'Your app checks for updates automatically.'),
                      const SizedBox(height: 8),
                      const Text(
                          'Finish any open forms before updating. Saved changes must be synced first. Other open tabs will stay on their current screen.'),
                      if (_error != null)
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      FilledButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            try {
                              if (await widget.hasPendingWork?.call() == true ||
                                  await _runtime.pendingWork()) {
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(const SnackBar(
                                          content: Text(
                                              'Sync your saved changes before updating.')));
                                }
                                return;
                              }
                              if (status['updateAvailable'] == true) {
                                await _runtime.update();
                              } else {
                                await _runtime.checkUpdate();
                              }
                            } catch (_) {
                              if (mounted) {
                                setState(() => _error =
                                    'Unable to update. Reconnect and try again.');
                              }
                            }
                          },
                          icon: const Icon(Icons.system_update_alt),
                          label: Text(status['updateAvailable'] == true
                              ? 'Update now'
                              : 'Check for updates')),
                    ]))));
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
