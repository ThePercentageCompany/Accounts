import 'dart:convert';
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:tpc_invoice/core/offline/durable_value.dart';

import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/auth/domain/session_repository.dart';
part 'saas_session.freezed.dart';

@freezed
abstract class SessionState with _$SessionState {
  const factory SessionState({
    Map<String, dynamic>? owner,
    Map<String, dynamic>? employee,
    Map<String, dynamic>? company,
    @Default([]) List<Map<String, dynamic>> companies,
    @Default(false) bool busy,
    String? error,
    String? pendingCompanyName,
  }) = _SessionState;
}

/// Session and provisioning state for the shared backend. Legacy workspace
/// preferences and offline queues are deliberately never read or cleared here.
class SaasSession extends Cubit<SessionState> {
  SaasSession(this.api, this.preferences) : super(const SessionState()) {
    api.onAccessRevoked = _accessRevoked;
    api.onEmployeeChanged = _employeeChanged;
  }

  void _employeeChanged(Map<String, dynamic> current) {
    if (_disposed || employee == null) return;
    employee = Map.of(current);
    _notify();
  }

  void _accessRevoked() {
    if (_disposed) return;
    _clearIdentity();
    final client = api;
    if (client is SaasApi) client.clearSessionProfile().ignore();
    error = "Your access changed or expired. Sign in again.";
    _notify();
  }

  final SessionRepository api;
  final SharedPreferences preferences;
  Map<String, dynamic>? owner;
  Map<String, dynamic>? employee;
  List<Map<String, dynamic>> companies = [];
  Map<String, dynamic>? company;
  String? error;
  String? pendingCompanyName;
  bool busy = false;
  bool _disposed = false;
  bool offlineRestored = false;
  Future<void> _saveOfflineProfile() async {
    final client = api;
    if (client is! SaasApi || offlineRestored) return;
    if (owner == null && employee == null) {
      await client.clearSessionProfile();
      return;
    }
    Map<String, dynamic>? select(
            Map<String, dynamic>? data, List<String> keys) =>
        data == null
            ? null
            : {
                for (final key in keys)
                  if (data.containsKey(key)) key: data[key]
              };
    final expiry =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
    await client.saveSessionProfile({
      'expiresAt': expiry,
      'owner': select(owner, ['ownerId', 'name', 'email', 'picture']),
      'employee': select(employee, [
        'employeeId',
        'companyId',
        'name',
        'role',
        'permissions',
        'allowedSections',
        'writableSections'
      ]),
      'company': select(company, ['companyId', 'name', 'stage']),
      'companies': [
        for (final c in companies) select(c, ['companyId', 'name', 'stage'])
      ],
    });
  }

  Future<bool> _restoreOfflineProfile() async {
    final client = api;
    if (client is! SaasApi) return false;
    final profile = await client.offlineSessionProfile();
    if (profile == null) return false;
    owner = profile['owner'] == null
        ? null
        : Map<String, dynamic>.from(profile['owner'] as Map);
    employee = profile['employee'] == null
        ? null
        : Map<String, dynamic>.from(profile['employee'] as Map);
    company = profile['company'] == null
        ? null
        : Map<String, dynamic>.from(profile['company'] as Map);
    companies = (profile['companies'] as List)
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    offlineRestored = true;
    error = null;
    return owner != null || employee != null;
  }

  Future<bool> restoreCachedSession() async {
    try {
      final restored = await _restoreOfflineProfile();
      if (restored) _notify();
      return restored;
    } catch (_) {
      return false;
    }
  }

  String get _registrationKey => 'tpc_saas_registration_${owner!['ownerId']}';
  DurableValue? _registration;
  Future<String?> _readRegistration() async {
    final client = api;
    if (client is SaasApi && client.offlineEnabled) {
      _registration = DurableValue(
          client.offlineStore,
          jsonEncode(
              [client.origin.toString(), 'owner', owner!['ownerId'], 'setup']),
          _registrationKey,
          preferences);
      await _registration!.load();
      return _registration!.value;
    }
    return preferences.getString(_registrationKey);
  }

  Future<bool> _saveRegistration(String value) =>
      _registration?.put(value) ??
      preferences.setString(_registrationKey, value);
  Future<bool> _removeRegistration() =>
      _registration?.remove() ?? preferences.remove(_registrationKey);
  String get _selectedKey => 'tpc_saas_selected_company_${owner!['ownerId']}';
  String get _openKey => 'tpc_saas_open_workspace_${owner!['ownerId']}';
  bool get restoreWorkspace =>
      owner != null && ready && preferences.getBool(_openKey) == true;
  Future<void> rememberWorkspace(bool open) async {
    if (owner != null) await preferences.setBool(_openKey, open);
  }

  bool get ready => company?['stage'] == 'READY';

  Future<void> _run(Future<void> Function() action,
      {bool allowOfflineRestore = false}) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
      try {
        await _saveOfflineProfile();
      } catch (_) {
        /* Cache failure does not turn a confirmed API operation into a failure. */
      }
    } on SaasApiException catch (failure) {
      error = failure.message;
      if (allowOfflineRestore && failure.code == 'NETWORK') {
        try {
          await _restoreOfflineProfile();
        } catch (_) {}
      }
      if (failure.requiresSignIn) {
        _clearIdentity();
        final client = api;
        if (client is SaasApi) await client.clearSessionProfile();
      }
    } catch (_) {
      error =
          'Unable to complete the request. Retry without discarding your changes.';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _clearIdentity() {
    _registration = null;
    offlineRestored = false;
    api.detachWorkspace();
    owner = null;
    employee = null;
    company = null;
    companies = [];
    pendingCompanyName = null;
  }

  Future<void> restore({bool employeeOnly = false}) => _run(() async {
        if (!offlineRestored) _clearIdentity();
        final employeeMode = employeeOnly ||
            preferences.getString('tpc_saas_session_mode') == 'employee';
        if (employeeMode && owner != null) _clearIdentity();
        if (!employeeMode) {
          try {
            owner = Map<String, dynamic>.from((await api.me())['owner'] as Map);
            offlineRestored = false;
          } on SaasApiException catch (failure) {
            if (!failure.requiresSignIn) rethrow;
            _clearIdentity();
            final client = api;
            if (client is SaasApi) await client.clearSessionProfile();
          }
        }
        if (owner != null) {
          final pending = await _readRegistration();
          if (pending != null) {
            pendingCompanyName = (jsonDecode(pending) as Map)['name'] as String;
          }
          await _loadCompanies();
          return;
        }
        try {
          employee = Map<String, dynamic>.from(
            (await api.employeeMe())['employee'] as Map,
          );
          offlineRestored = false;
        } on SaasApiException catch (failure) {
          if (!failure.requiresSignIn) rethrow;
          _clearIdentity();
          final client = api;
          if (client is SaasApi) await client.clearSessionProfile();
        }
      }, allowOfflineRestore: true);

  Future<void> _loadCompanies() async {
    final previousId =
        company?['companyId'] ?? preferences.getString(_selectedKey);
    final result = await api.companies();
    companies = (result['companies'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    if (previousId != null &&
        !companies.any((row) => row['companyId'] == previousId)) {
      await preferences.remove(_openKey);
    }
    company =
        companies.where((row) => row['companyId'] == previousId).firstOrNull ??
            companies.firstOrNull;
    if (company != null) {
      await preferences.setString(
        _selectedKey,
        company!['companyId'] as String,
      );
    }
  }

  Future<void> selectCompany(String companyId) => _run(() async {
        if (!companies.any((row) => row['companyId'] == companyId)) {
          throw const SaasApiException(
            'COMPANY_NOT_FOUND',
            'Choose a company from your account.',
          );
        }
        company = Map<String, dynamic>.from(
          (await api.setup(companyId))['company'] as Map,
        );
        await preferences.setString(_selectedKey, companyId);
      });

  Future<void> createCompany(String name) => _run(() async {
        if (owner == null) {
          throw const SaasApiException(
            'UNAUTHORIZED',
            'Sign in first.',
            status: 401,
          );
        }
        final cleaned = name.trim();
        if (cleaned.isEmpty || cleaned.length > 160) {
          throw const SaasApiException(
            'INVALID_COMPANY',
            'Enter a company name between 1 and 160 characters.',
          );
        }
        final saved = await _readRegistration();
        final operation = saved == null
            ? {'name': cleaned, 'key': const Uuid().v4()}
            : Map<String, dynamic>.from(jsonDecode(saved) as Map);
        if (operation['name'] != cleaned) {
          throw const SaasApiException(
            'REGISTRATION_PENDING',
            'Retry the pending company name before registering another company.',
          );
        }
        // Persist before sending: a lost response must not create a second company.
        if (!await _saveRegistration(jsonEncode(operation))) {
          throw const SaasApiException(
            'LOCAL_STORAGE',
            'Cannot save setup progress on this device.',
          );
        }
        pendingCompanyName = cleaned;
        final result =
            await api.createCompany(cleaned, operation['key'] as String);
        company = Map<String, dynamic>.from(result['company'] as Map);
        if (!await _removeRegistration()) {
          throw const SaasApiException(
            'LOCAL_STORAGE',
            'Company created. Retry to confirm saved setup progress.',
          );
        }
        pendingCompanyName = null;
        await _loadCompanies();
      });

  Future<void> refreshSetup() => _run(() async {
        if (company == null) return;
        company = Map<String, dynamic>.from(
          (await api.setup(company!['companyId'] as String))['company'] as Map,
        );
      });

  Future<void> retrySetup() => _run(() async {
        if (company == null) return;
        company = Map<String, dynamic>.from(
          (await api.retrySetup(company!['companyId'] as String))['company']
              as Map,
        );
      });

  Future<void> deleteCompany() => _run(() async {
        if (company == null || owner == null) return;
        final id = company!['companyId'] as String;
        final client = api;
        if (client is SaasApi && client.offlineEnabled) {
          final box = client.outbox(owner!['ownerId'] as String, id);
          await box.reload();
          if (box.pending.isNotEmpty ||
              (box.data['aux'] as Map? ?? {}).isNotEmpty) {
            throw const SaasApiException('PENDING',
                'Sync or export pending changes before deleting this workspace.');
          }
        }
        try {
          await api.deleteCompany(id);
        } on SaasApiException catch (failure) {
          // A previous deletion may have succeeded with its response lost.
          if (failure.code != 'COMPANY_NOT_FOUND' || failure.status != 404) {
            rethrow;
          }
        }
        await api.clearWorkspace();
        for (final key in preferences
            .getKeys()
            .where(
              (key) =>
                  key.contains(id) &&
                  (key.startsWith('saas_') ||
                      key.startsWith('tpc_workspace_cache_')),
            )
            .toList()) {
          await preferences.remove(key);
        }
        companies.removeWhere((entry) => entry['companyId'] == id);
        company = companies.isEmpty ? null : companies.first;
      });

  Future<void> signIn(Future<void> Function(Uri) navigate) => _run(() async {
        await preferences.setString('tpc_saas_session_mode', 'owner');
        await navigate(await api.startSignIn());
      });

  Future<void> connectGoogle(Future<void> Function(Uri) navigate) => _run(
        () async {
          if (company == null) return;
          await navigate(
              await api.connectGoogle(company!['companyId'] as String));
        },
      );

  Future<void> employeeLogin(String invite, String code) => _run(() async {
        final result = await api.employeeLogin(invite, code);
        _clearIdentity();
        employee = Map<String, dynamic>.from(result['employee'] as Map);
        await preferences.setString('tpc_saas_session_mode', 'employee');
      });

  Future<void> signOut() => _run(() async {
        // Purge optional read snapshots before logout; preserve the existing
        // authenticated session/error behavior if remote logout fails.
        for (final key in preferences
            .getKeys()
            .where((k) => k.startsWith('tpc_workspace_cache_v1_'))
            .toList()) {
          await preferences.remove(key);
        }
        if (employee != null) await api.employeeLogout();
        if (owner != null) await api.logout();
        await preferences.remove('tpc_saas_session_mode');
        if (owner != null) {
          await preferences.remove(_openKey);
          await preferences.remove(_selectedKey);
        }
        _clearIdentity();
      });

  void _notify() {
    if (_disposed) return;
    // Owner and employee views can share the transport. Restore the callback
    // when this session becomes active again after the other view is disposed.
    api.onAccessRevoked = _accessRevoked;
    api.onEmployeeChanged = _employeeChanged;
    if (employee != null) {
      api.useVerifiedWorkspace(
        employee!['companyId'] as String,
        employee: employee,
      );
    } else if (owner != null && ready) {
      api.useVerifiedWorkspace(
        company!['companyId'] as String,
        ownerId: owner!['ownerId'] as String,
      );
    }
    emit(
      SessionState(
        owner: owner == null ? null : Map.of(owner!),
        employee: employee == null ? null : Map.of(employee!),
        company: company == null ? null : Map.of(company!),
        companies: companies
            .map((company) => Map<String, dynamic>.of(company))
            .toList(),
        busy: busy,
        error: error,
        pendingCompanyName: pendingCompanyName,
      ),
    );
  }

  @override
  Future<void> close() {
    _disposed = true;
    if (api.onAccessRevoked == _accessRevoked) api.onAccessRevoked = null;
    if (api.onEmployeeChanged == _employeeChanged) api.onEmployeeChanged = null;
    return super.close();
  }

  void dispose() => unawaited(close());
}
