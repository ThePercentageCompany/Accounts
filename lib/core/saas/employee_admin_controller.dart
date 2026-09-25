import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'saas_api.dart';

const employeeSections = [
  'Dashboard',
  'Invoices',
  'Quotations',
  'Income & Expenses',
  'Capital & Equity',
  'Fixed Assets',
  'Balance Sheet',
  'Customers',
  'Employees',
  'Payroll',
  'Reports',
  'Settings',
  'Office & Attendance',
];

class EmployeeAdminController extends ChangeNotifier {
  EmployeeAdminController(
    this.api,
    this.preferences,
    this.ownerId,
    this.companyId,
  );
  final SaasApi api;
  final SharedPreferences preferences;
  final String ownerId;
  final String companyId;
  List<Map<String, dynamic>> employees = [];
  bool busy = false;
  bool _disposed = false;
  String? error;
  String get _key => 'saas_employee_write_${ownerId}_$companyId';
  bool get hasPending => preferences.containsKey(_key);
  bool get canDiscardRejected {
    final raw = preferences.getString(_key);
    return raw != null && (jsonDecode(raw) as Map)['rejected'] == true;
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    if (busy || _disposed) return null;
    busy = true;
    error = null;
    notifyListeners();
    try {
      return await action();
    } on SaasApiException catch (e) {
      error = e.message;
      if (e.status == 401 || e.status == 403) employees = [];
    } catch (_) {
      error = 'Unable to complete the request. Retry when connected.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
    return null;
  }

  Future<void> _load() async {
    final result = await api.employees(companyId);
    employees = (result['employees'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<void> refresh() async {
    await _run(_load);
  }

  Future<void> _submitPending() async {
    final raw = preferences.getString(_key);
    if (raw == null) return;
    final op = jsonDecode(raw) as Map;
    try {
      await api.saveEmployee(
        companyId,
        op['employeeId'] as String?,
        Map<String, Object?>.from(op['values'] as Map),
        op['operationId'] as String,
      );
    } on SaasApiException catch (e) {
      // These responses are produced before any employee write. An uncertain
      // network failure must never make a pending operation discardable.
      if (e.code == 'INVALID_EMPLOYEE' || e.code == 'VERSION_CONFLICT') {
        op['rejected'] = true;
        await preferences.setString(_key, jsonEncode(op));
      }
      rethrow;
    }
    if (!await preferences.remove(_key)) {
      throw const SaasApiException(
        'LOCAL_STORAGE',
        'Saved online. Retry to confirm local progress.',
      );
    }
    await _load();
  }

  Future<bool> save(String? id, Map<String, Object?> values) async =>
      await _run(() async {
        if (hasPending) {
          throw const SaasApiException(
            'PENDING',
            'Retry the pending employee change first.',
          );
        }
        final op = {
          'employeeId': id,
          'values': values,
          'operationId': const Uuid().v4(),
        };
        if (!await preferences.setString(_key, jsonEncode(op))) {
          throw const SaasApiException(
            'LOCAL_STORAGE',
            'Cannot save pending change on this device.',
          );
        }
        await _submitPending();
        return true;
      }) ??
      false;
  Future<void> retry() async {
    await _run(_submitPending);
  }

  Future<void> discardRejected() async {
    await _run(() async {
      if (!canDiscardRejected) {
        throw const SaasApiException(
          'PENDING',
          'Retry this change to confirm its result first.',
        );
      }
      if (!await preferences.remove(_key)) {
        throw const SaasApiException(
          'LOCAL_STORAGE',
          'Could not discard the rejected change.',
        );
      }
      await _load();
    });
  }

  Future<Map<String, dynamic>?> access(String id, String action) => _run(
    () async {
      if (hasPending) {
        throw const SaasApiException(
          'PENDING',
          'Confirm the pending employee change first.',
        );
      }
      // Codes are returned once and never persisted. Lost issue/reset responses
      // require an explicit reset; automatic retries cannot recover the secret.
      return api.employeeAccess(
        companyId,
        id,
        action,
        operationId: action == 'revoke' ? null : const Uuid().v4(),
      );
    },
  );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
