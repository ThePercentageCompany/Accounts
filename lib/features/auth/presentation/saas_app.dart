import 'package:tpc_invoice/core/widgets/tpc_logo.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'admin_login_dialog.dart';
import 'package:tpc_invoice/core/network/supabase_runtime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'password_reset_dialog.dart';
import 'package:tpc_invoice/features/auth/domain/password_recovery.dart';

import 'package:tpc_invoice/features/workspace/presentation/business_group_view.dart';
import 'package:tpc_invoice/core/widgets/appearance_selector.dart';
import 'package:tpc_invoice/features/auth/presentation/employee_access_view.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/network/workspace_api.dart';
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
  bool _recoveryPending = false;
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
      final api = widget.api ?? createWorkspaceApi();
      _authSubscription =
          currentSupabaseClient?.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.passwordRecovery &&
            state.session != null) {
          _recoveryPending = true;
          unawaited(SharedPreferences.getInstance().then((prefs) =>
              prefs.setString(
                  'tpc_password_recovery_user', state.session!.user.id)));
          if (!_initializing) unawaited(_recoverPassword());
        }
      }, onError: (Object error, StackTrace stack) {
        if (mounted && isPasswordRecoveryLink(Uri.base)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'The password reset link could not be verified. Request a new link from Forgot password.'),
              duration: Duration(seconds: 12),
            ));
          });
        }
      });
      _api = api;
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      final session = SaasSession(api, preferences);
      _session = session;
      _sessionSubscription = session.stream.listen((_) => _sessionChanged());
      final recoveryUser = preferences.getString('tpc_password_recovery_user');
      if (recoveryUser != null &&
          recoveryUser == currentSupabaseClient?.auth.currentUser?.id) {
        _recoveryPending = true;
      }
      if (_recoveryPending) {
        _initializing = false;
        setState(() {});
        unawaited(_recoverPassword());
        return;
      }
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
      if (_recoveryPending) {
        unawaited(_recoverPassword());
      }
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
    _recoveryPending = false;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PasswordResetDialog());
    _passwordRecoveryOpen = false;
    if (saved == true && mounted) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('tpc_password_recovery_user');
      await preferences.setString('tpc_saas_session_mode', 'owner');
      if (!mounted) return;
      setState(() => _employee = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully.')));
      await _session?.restore();
    }
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
        countryCode: session.company!['countryCode'] as String?,
        currency: session.company!['currency'] as String?,
        timeZone: session.company!['timeZone'] as String?,
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        surfaceTintColor: session.owner == null && session.employee == null
            ? Colors.transparent
            : null,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const TpcLogo(),
          const SizedBox(width: 10),
          const Flexible(child: Text('TPC Business Suite'))
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
            IconButton(
                tooltip: 'Sign out',
                onPressed: session.busy ? null : session.signOut,
                icon: const Icon(Icons.logout)),
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
                child: BusinessGroupView(
                  api: _api!,
                  onOpen: (companyId) async {
                    await session.restore();
                    await session.selectCompany(companyId);
                    if (!session.ready ||
                        session.company?['companyId'] != companyId) {
                      throw StateError(
                          session.error ?? 'Entity could not be opened.');
                    }
                    await session.rememberWorkspace(true);
                    if (mounted) setState(() => _workspace = true);
                  },
                ),
              ),
            ),
    );
  }
}
