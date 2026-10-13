import 'package:tpc_invoice/core/widgets/tpc_logo.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'admin_login_dialog.dart';
import 'package:tpc_invoice/core/network/supabase_runtime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'password_reset_dialog.dart';

import 'package:tpc_invoice/features/workspace/presentation/company_setup_view.dart';
import 'package:tpc_invoice/core/widgets/appearance_selector.dart';
import 'package:tpc_invoice/features/auth/presentation/employee_access_view.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/auth/presentation/cubit/saas_session.dart';
import 'package:tpc_invoice/features/workspace/presentation/shared_workspace.dart';
import 'package:tpc_invoice/features/workspace/presentation/workspace_help.dart';
import 'landing_view.dart';
import 'package:tpc_invoice/core/pwa/pwa_controls.dart';
import 'package:tpc_invoice/core/pwa/pwa_runtime.dart';

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
  StreamSubscription<AuthState>? _authSubscription;
  bool _passwordRecoveryOpen = false;
  String? _initializationError;
  bool _employee = SaasApi.invitation(Uri.base, Uri.base) != null;
  bool _workspace = false;
  bool _initializing = true;
  final _pwa = PwaRuntime();
  bool _routingTask = false;
  Future<void> _routeTask() async {
    if (_routingTask || !mounted || _session == null || _initializing) return;
    final parts = '${_pwa.status['taskLink'] ?? ''}'.split(':');
    if (parts.length != 2 ||
        !parts.every((p) => RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(p))) {
      return;
    }
    final session = _session!;
    if (session.owner == null) {
      return; // Employee workspace validates its own company.
    }
    if (!session.companies.any((c) => c['companyId'] == parts[0])) {
      _pwa.clearTask();
      return;
    }
    _routingTask = true;
    try {
      if (session.company?['companyId'] != parts[0]) {
        await session.selectCompany(parts[0]);
      }
      if (mounted &&
          session.ready &&
          session.company?['companyId'] == parts[0]) {
        await session.rememberWorkspace(true);
        if (mounted) setState(() => _workspace = true);
      }
    } finally {
      _routingTask = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _pwa.addListener(_routeTask);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (widget.api == null && currentSupabaseClient == null) {
        throw const SaasApiException(
            'CONFIGURATION', 'Supabase Auth is not configured.');
      }
      final api = widget.api ?? SaasApi();
      _authSubscription = currentSupabaseClient?.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.passwordRecovery) _recoverPassword();
      });
      _api = api;
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      final session = SaasSession(api, preferences);
      _session = session;
      _sessionSubscription = session.stream.listen((_) => _sessionChanged());
      // Invitation links must not silently adopt a cached owner/employee.
      if (!_employee) {
        if (await session.restoreCachedSession()) {
          if (!mounted) return;
          _workspace = session.restoreWorkspace;
          _employee = session.employee != null;
          _initializing = false;
          setState(() {});
        }
        await session.restore();
      }
      if (!mounted) return;
      if (session.employee != null) _employee = true;
      _workspace = session.restoreWorkspace;
      _initializing = false;
      setState(() {});
      unawaited(_routeTask());
    } catch (_) {
      if (mounted) {
        setState(
          () => _initializationError =
              'Supabase is not configured. Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY and rebuild the app.',
        );
      }
    }
  }

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _adminSignIn() async {
    final result = await showDialog<bool>(
        context: context, builder: (_) => AdminLoginDialog(api: _api!));
    if (result != true || !mounted) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('tpc_saas_session_mode', 'owner');
    await _session!.restore();
  }

  Future<void> _recoverPassword() async {
    if (!mounted || _passwordRecoveryOpen) return;
    _passwordRecoveryOpen = true;
    final saved = await showDialog<bool>(context: context, barrierDismissible: false,
        builder: (_) => const PasswordResetDialog());
    _passwordRecoveryOpen = false;
    if (saved == true && mounted) await _session?.restore();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _pwa.removeListener(_routeTask);
    _pwa.dispose();
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
    if (session == null || _initializing) {
      return const Scaffold(body: CenteredLoading());
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
        onBack: () {
          unawaited(session.rememberWorkspace(false));
          setState(() => _workspace = false);
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: session.owner == null && session.employee == null
            ? const Color(0xff0a0a0c)
            : null,
        foregroundColor: session.owner == null && session.employee == null
            ? Colors.white
            : null,
        surfaceTintColor: session.owner == null && session.employee == null
            ? Colors.transparent
            : null,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          TpcLogo(
              brightness: session.owner == null && session.employee == null
                  ? Brightness.dark
                  : null),
          const SizedBox(width: 10),
          const Flexible(child: Text('TPC Accounts'))
        ]),
        actions: [
          IconButton(
            tooltip: 'FAQ & getting started',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const WorkspaceHelp()),
            ),
          ),
          if (session.owner != null || session.employee != null) ...[
            const AppearanceSelector(),
            const PwaControls(),
            if (MediaQuery.sizeOf(context).width < 600)
              IconButton(
                tooltip: 'Employee login',
                onPressed: session.busy
                    ? null
                    : () => setState(() => _employee = true),
                icon: const Icon(Icons.badge_outlined),
              )
            else
              LoadingButton.textIcon(
                onPressed: () => setState(() => _employee = true),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Employee login'),
              ),
          ],
        ],
      ),
      body: session.owner == null && session.employee == null
          ? LandingView(
              busy: session.busy,
              error: session.error,
              onSignIn: _adminSignIn,
              onFaq: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const WorkspaceHelp()),
              ),
              onEmployeeLogin: () => setState(() => _employee = true),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: CompanySetupView(
                  session: session,
                  onSignIn: _adminSignIn,
                  onOpen: () {
                    unawaited(session.rememberWorkspace(true));
                    setState(() => _workspace = true);
                  },
                ),
              ),
            ),
    );
  }
}
