import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'saas_api.dart';

/// Session and provisioning state for the shared backend. Legacy workspace
/// preferences and offline queues are deliberately never read or cleared here.
class SaasSession extends ChangeNotifier {
  SaasSession(this.api, this.preferences);

  final SaasApi api;
  final SharedPreferences preferences;
  Map<String, dynamic>? owner;
  Map<String, dynamic>? employee;
  List<Map<String, dynamic>> companies = [];
  Map<String, dynamic>? company;
  String? error;
  String? pendingCompanyName;
  bool busy = false;
  bool _disposed = false;

  String get _registrationKey => 'tpc_saas_registration_${owner!['ownerId']}';
  bool get ready => company?['stage'] == 'READY';

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
    } on SaasApiException catch (failure) {
      error = failure.message;
      if (failure.requiresSignIn) _clearIdentity();
    } catch (_) {
      error =
          'Unable to complete the request. Retry without discarding your changes.';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _clearIdentity() {
    owner = null;
    employee = null;
    company = null;
    companies = [];
    pendingCompanyName = null;
  }

  Future<void> restore({bool employeeOnly = false}) => _run(() async {
    _clearIdentity();
    if (!employeeOnly) {
      try {
        owner = Map<String, dynamic>.from((await api.me())['owner'] as Map);
      } on SaasApiException catch (failure) {
        if (!failure.requiresSignIn) rethrow;
      }
    }
    if (owner != null) {
      final pending = preferences.getString(_registrationKey);
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
    } on SaasApiException catch (failure) {
      if (!failure.requiresSignIn) rethrow;
    }
  });

  Future<void> _loadCompanies() async {
    final previousId = company?['companyId'];
    final result = await api.companies();
    companies = (result['companies'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    company =
        companies.where((row) => row['companyId'] == previousId).firstOrNull ??
        companies.firstOrNull;
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
    final saved = preferences.getString(_registrationKey);
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
    if (!await preferences.setString(_registrationKey, jsonEncode(operation))) {
      throw const SaasApiException(
        'LOCAL_STORAGE',
        'Cannot save setup progress on this device.',
      );
    }
    pendingCompanyName = cleaned;
    final result = await api.createCompany(cleaned, operation['key'] as String);
    company = Map<String, dynamic>.from(result['company'] as Map);
    if (!await preferences.remove(_registrationKey)) {
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
      (await api.retrySetup(company!['companyId'] as String))['company'] as Map,
    );
  });

  Future<void> signIn(Future<void> Function(Uri) navigate) => _run(() async {
    await navigate(await api.startSignIn());
  });

  Future<void> connectGoogle(Future<void> Function(Uri) navigate) => _run(
    () async {
      if (company == null) return;
      await navigate(await api.connectGoogle(company!['companyId'] as String));
    },
  );

  Future<void> employeeLogin(String invite, String code) => _run(() async {
    final result = await api.employeeLogin(invite, code);
    _clearIdentity();
    employee = Map<String, dynamic>.from(result['employee'] as Map);
  });

  Future<void> signOut() => _run(() async {
    if (employee != null) await api.employeeLogout();
    if (owner != null) await api.logout();
    _clearIdentity();
  });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
