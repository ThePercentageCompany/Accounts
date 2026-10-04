import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tpc_invoice/features/workspace/presentation/company_setup_view.dart';
import 'package:tpc_invoice/core/widgets/appearance_selector.dart';
import 'package:tpc_invoice/features/auth/presentation/employee_access_view.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/auth/presentation/cubit/saas_session.dart';
import 'package:tpc_invoice/features/workspace/presentation/shared_workspace.dart';

class SaasApp extends StatefulWidget {
  const SaasApp({super.key, this.api});
  final SaasApi? api;

  @override
  State<SaasApp> createState() => _SaasAppState();
}

class _SaasAppState extends State<SaasApp> {
  SaasApi? _api;
  SaasSession? _session;
  StreamSubscription<SessionState>? _sessionSubscription;
  String? _initializationError;
  bool _employee = SaasApi.invitation(Uri.base, Uri.base) != null;
  bool _workspace = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final api = widget.api ?? SaasApi();
      _api = api;
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      final session = SaasSession(api, preferences);
      _session = session;
      _sessionSubscription = session.stream.listen((_) => _sessionChanged());
      // Invitation links must not silently adopt a cached owner/employee.
      if (!_employee) await session.restore();
      if (!mounted) return;
      if (session.employee != null) _employee = true;
      setState(() {});
    } catch (_) {
      if (mounted) {
        setState(
          () => _initializationError =
              'The shared company service is not configured. The app administrator must configure SAAS_API_ORIGIN and rebuild the app.',
        );
      }
    }
  }

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _navigate(Uri uri) async {
    if (!await launchUrl(uri, webOnlyWindowName: '_self')) {
      throw const SaasApiException(
        'NAVIGATION',
        'Could not open Google sign-in. Try again.',
      );
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _session?.dispose();
    if (widget.api == null) _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                _initializationError!,
                key: const Key('shared-service-unavailable'),
              ),
            ),
          ),
        ),
      );
    }
    final session = _session;
    if (session == null) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }
    if (_employee) {
      return EmployeeAccessView(
        api: _api,
        restoreSession: session.employee != null,
        onBack: () {
          setState(() => _employee = false);
          session.restore();
        },
      );
    }
    if (_workspace && session.ready && session.owner != null) {
      return SharedWorkspace(
        key: ValueKey((
          session.company!['companyId'],
          session.owner!['ownerId'],
        )),
        api: _api!,
        companyId: session.company!['companyId'] as String,
        title: session.company!['name'] as String,
        ownerId: session.owner!['ownerId'] as String,
        preferences: session.preferences,
        onBack: () => setState(() => _workspace = false),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('TPC Accounts'),
        actions: [
          const AppearanceSelector(),
          TextButton.icon(
            onPressed: () => setState(() => _employee = true),
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Employee login'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              BlocBuilder<SaasSession, SessionState>(
                bloc: session,
                builder: (context, _) => session.ready && session.owner != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: FilledButton(
                          onPressed: session.busy
                              ? null
                              : () => setState(() => _workspace = true),
                          child: const Text('Open company workspace'),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: CompanySetupView(session: session, navigate: _navigate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
