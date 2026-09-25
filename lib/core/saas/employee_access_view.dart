import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'employee_qr_scanner.dart';
import 'saas_api.dart';
import 'saas_session.dart';
import 'shared_workspace.dart';

/// Shared-backend employee authentication. Never opens legacy Sheets caches.
class EmployeeAccessView extends StatefulWidget {
  const EmployeeAccessView({
    super.key,
    required this.onBack,
    this.api,
    this.appUri,
    this.restoreSession = false,
  });
  final VoidCallback onBack;
  final SaasApi? api;
  final Uri? appUri;
  final bool restoreSession;

  @override
  State<EmployeeAccessView> createState() => _EmployeeAccessViewState();
}

class _EmployeeAccessViewState extends State<EmployeeAccessView> {
  final _link = TextEditingController();
  final _code = TextEditingController();
  SaasSession? _session;
  SaasApi? _api;
  String? _error;
  bool _showCode = false;
  bool _workspace = false;

  Uri get _appUri => widget.appUri ?? Uri.base;

  @override
  void initState() {
    super.initState();
    if (SaasApi.invitation(_appUri, _appUri) != null) {
      _link.text = _appUri.toString();
    }
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      _api = widget.api ?? SaasApi();
      _session = SaasSession(_api!, preferences)..addListener(_changed);
      if (widget.restoreSession && _link.text.isEmpty) {
        await _session!.restore(employeeOnly: true);
        if (!mounted) return;
      }
      // A new invite always asks for its private code, even if another employee
      // has a session cookie on this device.
      setState(() {});
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Employee access could not start. Contact the app administrator.',
        );
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _scan() async {
    try {
      final value = await scanEmployeeQr(context);
      if (!mounted || value == null) return;
      _link.text = value;
      _code.clear();
      setState(() => _error = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Camera unavailable. Paste your employee login link instead.',
        );
      }
    }
  }

  Future<void> _login() async {
    final uri = Uri.tryParse(_link.text.trim());
    final invite = uri == null ? null : SaasApi.invitation(uri, _appUri);
    if (invite == null || _code.text.trim().isEmpty) {
      setState(
        () => _error = invite == null
            ? 'Use a new employee link from this app. Older Apps Script QR codes must be reissued.'
            : 'Enter the private login code from your manager.',
      );
      return;
    }
    setState(() => _error = null);
    await _session!.employeeLogin(invite, _code.text.trim());
    // Do not retain a private code after either successful or failed login.
    if (mounted) _code.clear();
  }

  @override
  void dispose() {
    _session?.removeListener(_changed);
    _session?.dispose();
    if (widget.api == null) _api?.close();
    _link.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final employee = session?.employee;
    if (_workspace && employee != null) {
      return SharedWorkspace(
        key: ValueKey((employee['companyId'], employee['employeeId'])),
        api: _api!,
        companyId: employee['companyId'] as String,
        employee: employee,
        title: 'Your company workspace',
        onBack: () => setState(() => _workspace = false),
      );
    }
    final busy = session == null || session.busy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee access'),
        leading: IconButton(
          onPressed: busy || employee != null ? null : widget.onBack,
          tooltip: 'Back to sign-in',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) const LinearProgressIndicator(),
                if (employee == null) ...[
                  Text(
                    'Join your company',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scan your manager’s QR or paste your invitation link, then enter your private login code.',
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _link,
                    enabled: !busy,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Employee login link',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _code,
                    enabled: !busy,
                    obscureText: !_showCode,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Private login code',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _showCode = !_showCode),
                        tooltip: _showCode ? 'Hide code' : 'Show code',
                        icon: Icon(
                          _showCode ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (!busy) _login();
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : _login,
                    child: const Text('Sign in'),
                  ),
                ] else ...[
                  Text(
                    'Welcome, ${employee['name']}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text('Role: ${employee['role']}'),
                  const SizedBox(height: 16),
                  const Text('Your assigned sections'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final section in employee['allowedSections'] as List)
                        Chip(label: Text(section as String)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your access is verified. Open your workspace to view records allowed by your company.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => _workspace = true),
                    child: const Text('Open workspace'),
                  ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            await session.signOut();
                            if (mounted && session.employee == null) {
                              widget.onBack();
                            }
                          },
                    child: const Text('Sign out'),
                  ),
                ],
                if (_error != null || session?.error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error ?? session!.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
