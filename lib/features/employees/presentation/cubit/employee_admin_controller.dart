import 'dart:async';
import 'package:tpc_invoice/core/cache/read_cache.dart';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
part 'employee_admin_controller.freezed.dart';

@freezed
abstract class EmployeeAdminState with _$EmployeeAdminState {
  const factory EmployeeAdminState({
    @Default([]) List<Map<String, dynamic>> employees,
    @Default(false) bool busy,
    @Default(false) bool hasPending,
    @Default(false) bool canDiscardRejected,
    @Default(false) bool refreshing,
    @Default(false) bool offline,
    String? error,
    String? refreshError,
  }) = _EmployeeAdminState;
}

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

class EmployeeAdminController extends Cubit<EmployeeAdminState> {
  EmployeeAdminController(
    this.api,
    this.preferences,
    this.ownerId,
    this.companyId,
  ) : super(const EmployeeAdminState()) {
    api.cache.addListener(_cacheChanged);
  }
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
    _notify();
    try {
      return await action();
    } on SaasApiException catch (e) {
      error = e.message;
      if (e.status == 401 || e.status == 403) employees = [];
    } catch (_) {
      error = 'Unable to complete the request. Retry when connected.';
    } finally {
      busy = false;
      if (!_disposed) _notify();
    }
    return null;
  }

  String get resourcePath => '/v1/companies/$companyId/employees';
  void _cacheChanged() {
    scheduleMicrotask(() {
      if (_disposed) return;
      final data = api.cache.state(resourcePath)?.data;
      if (data != null) {
        final fresh = (data['employees'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        if (dataFingerprint({'employees': fresh}) !=
            dataFingerprint({'employees': employees})) {
          employees = fresh;
        }
      } else if (api.cache.scope == null) {
        employees = [];
      }
      _notify();
    });
  }

  Future<void> _load({bool force = false}) async {
    final result = await api.employees(companyId, force: force);
    employees = (result['employees'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<void> refresh({bool force = true}) async {
    await _run(() async {
      // Recover the exact persisted write before reading: the server can block
      // list requests until an uncertain employee write has been confirmed.
      if (hasPending && !canDiscardRejected) {
        await _submitPending();
      } else {
        await _load(force: force);
      }
    });
  }

  Future<void> _submitPending() async {
    final raw = preferences.getString(_key);
    if (raw == null) return;
    final op = jsonDecode(raw) as Map;
    // A retry may now be accepted (for example after an API upgrade). Persist
    // its uncertain state before sending so a lost response cannot leave a
    // submitted operation marked safe to discard.
    if (op.remove('rejected') == true &&
        !await preferences.setString(_key, jsonEncode(op))) {
      throw const SaasApiException(
        'LOCAL_STORAGE',
        'Could not prepare the saved edit for retry. Try again.',
      );
    }
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
    await _load(force: true);
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
      await _load(force: true);
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

  void _notify() {
    if (_disposed) return;
    final cached = api.cache.state(resourcePath);
    emit(
      EmployeeAdminState(
        employees: employees
            .map((employee) => Map<String, dynamic>.of(employee))
            .toList(),
        busy: busy,
        hasPending: hasPending,
        canDiscardRejected: canDiscardRejected,
        refreshing: cached?.refreshing ?? false,
        offline: cached?.offline ?? false,
        error: error,
        refreshError: cached?.error?.toString(),
      ),
    );
  }

  @override
  Future<void> close() {
    _disposed = true;
    api.cache.removeListener(_cacheChanged);
    return super.close();
  }

  void dispose() => unawaited(close());
}
