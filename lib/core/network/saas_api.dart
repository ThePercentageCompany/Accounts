import 'dart:async';
import 'package:tpc_invoice/features/auth/domain/session_repository.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show parseHttpDate;
import 'package:tpc_invoice/core/cache/cache_store.dart';
import 'package:tpc_invoice/core/cache/read_cache.dart';

import 'package:tpc_invoice/core/network/api_transport_stub.dart'
    if (dart.library.js_interop) 'package:tpc_invoice/core/network/api_transport_web.dart';

const configuredSaasApiOrigin = String.fromEnvironment('SAAS_API_ORIGIN');

class SaasApiException implements Exception {
  const SaasApiException(
    this.code,
    this.message, {
    this.status = 0,
    this.retryAfter,
  });
  final String code;
  final String message;
  final int status;
  final Duration? retryAfter;
  bool get requiresSignIn =>
      status == 401 &&
      const {
        'UNAUTHORIZED',
        'EMPLOYEE_ACCESS_DENIED',
        'EMPLOYEE_SESSION_INVALID',
        'EMPLOYEE_SESSION_EXPIRED',
        'OAUTH_STATE_INVALID',
      }.contains(code);
  @override
  String toString() => message;
}

/// Trusted operator origin only. QR codes identify invitations, never servers.
/// Authentication lives in secure HttpOnly cookies, not local preferences.
class SaasApi implements SessionRepository {
  SaasApi({
    String origin = configuredSaasApiOrigin,
    http.Client? client,
    CacheStore? cacheStore,
  }) : origin = _origin(origin),
       _client = client ?? createSaasTransport(),
       _cacheStore = cacheStore;

  final Uri origin;
  final http.Client _client;
  final Set<Completer<void>> _readAborts = {};
  void _cancelReads() {
    for (final abort in _readAborts.toList()) {
      if (!abort.isCompleted) abort.complete();
    }
    _readAborts.clear();
  }

  final CacheStore? _cacheStore;
  @override
  void Function()? onAccessRevoked;
  @override
  void Function(Map<String, dynamic>)? onEmployeeChanged;
  Future<void>? _employeeRenewal;
  int _employeeRenewalVersion = 0;
  DateTime? _employeeExpiresAt;
  String? _cacheCompany, _cacheUser, _permissionKey;
  bool _cacheEmployee = false;
  DateTime _verifiedAt = DateTime.now();
  late final ReadCache cache = ReadCache(
    store: _cacheStore,
    isAuthorizationError: (e) => e is SaasApiException && e.requiresSignIn,
    isOfflineError: (e) => e is SaasApiException && e.code == 'NETWORK',
    isPermissionError: (e) => e is SaasApiException && e.status == 403,
    retryDelay: (e) => e is SaasApiException ? e.retryAfter : null,
    onAuthorizationFailure: (_) {
      _cancelReads();
      onAccessRevoked?.call();
    },
    validateContext: _revalidateContext,
  );

  String _permissions(Map<String, dynamic> employee) => dataFingerprint({
    'role': employee['role'],
    'allowedSections': (List<String>.from(
      employee['allowedSections'] as List? ?? [],
    )..sort()),
    'writableSections': (List<String>.from(
      employee['writableSections'] as List? ?? [],
    )..sort()),
  });

  /// Called only after the existing online identity/company checks succeed.
  @override
  void useVerifiedWorkspace(
    String companyId, {
    String? ownerId,
    Map<String, dynamic>? employee,
  }) {
    final user = ownerId ?? employee?['employeeId'] as String?;
    if (user == null) return;
    final permission = employee == null ? 'owner' : _permissions(employee);
    final account = jsonEncode([
      origin.toString(),
      employee == null ? 'owner' : 'employee',
      user,
    ]);
    final scope = jsonEncode([account, companyId, permission]);
    if (cache.scope == scope) return;
    _cancelReads();
    _cacheCompany = companyId;
    _cacheUser = user;
    _cacheEmployee = employee != null;
    _permissionKey = permission;
    _verifiedAt = DateTime.now();
    cache.configure(scope: scope, account: account);
  }

  @override
  void detachWorkspace() {
    _cancelReads();
    cache.detach();
    _cacheCompany = null;
    _cacheUser = null;
  }

  @override
  Future<void> clearWorkspace() async {
    _cancelReads();
    _cacheCompany = null;
    _cacheUser = null;
    await cache.logout();
  }

  Future<void> _revalidateContext() async {
    if (_cacheCompany == null ||
        DateTime.now().difference(_verifiedAt) < const Duration(minutes: 1)) {
      return;
    }
    final companyId = _cacheCompany, user = _cacheUser, scope = cache.scope;
    if (_cacheEmployee) {
      final result = await _networkJson('GET', '/v1/employee/me');
      if (scope != cache.scope) return;
      final employee = Map<String, dynamic>.from(result['employee'] as Map);
      if (employee['employeeId'] != user ||
          employee['companyId'] != companyId) {
        throw const SaasApiException(
          'PERMISSIONS_CHANGED',
          'Your access changed. Sign in again to load current permissions.',
          status: 401,
        );
      }
      if (_permissions(employee) != _permissionKey) {
        useVerifiedWorkspace(companyId!, employee: employee);
        onEmployeeChanged?.call(employee);
      }
    } else {
      final identity = await _networkJson('GET', '/v1/me');
      if (scope != cache.scope) return;
      if ((identity['owner'] as Map)['ownerId'] != user) {
        throw const SaasApiException(
          'UNAUTHORIZED',
          'Sign in again.',
          status: 401,
        );
      }
      await _networkJson('GET', '/v1/companies/$companyId/setup');
    }
    if (scope == cache.scope) _verifiedAt = DateTime.now();
  }

  bool _cacheable(String path) {
    if (cache.scope == null) return false;
    final uri = Uri.parse(path);
    if (_cacheEmployee) {
      return uri.path.startsWith('/v1/employee/records/') ||
          uri.path.startsWith('/v1/employee/reports/');
    }
    final prefix = '/v1/companies/$_cacheCompany/';
    return uri.path.startsWith('${prefix}records/') ||
        uri.path.startsWith('${prefix}reports/') ||
        uri.path == '${prefix}employees';
  }

  String recordsPath(String companyId, String table, {bool employee = false}) =>
      employee
      ? '/v1/employee/records/$table'
      : '/v1/companies/$companyId/records/$table';

  void _invalidateMutation(
    String path,
    Map<String, Object?>? input,
    Map<String, dynamic> result,
  ) {
    if (cache.scope == null) return;
    final tables = <String>{};
    if (path.endsWith('/sync')) {
      final applied = (result['results'] as List? ?? [])
          .whereType<Map>()
          .where((r) => r['status'] == 'APPLIED')
          .map((r) => r['operationId'])
          .toSet();
      for (final op in (input?['operations'] as List? ?? []).whereType<Map>()) {
        if (applied.contains(op['operationId'])) {
          tables.add(op['table'] as String);
        }
      }
    } else if (path.contains('/employees')) {
      tables.add('Employees');
    }
    if (tables.isEmpty) return;
    final affected = {...tables};
    final financial = tables.any(
      (t) => !['Customers', 'Employees', 'CompanyProfile'].contains(t),
    );
    if (financial) affected.addAll(['Journals', 'JournalLines']);
    if (tables.any(
      (t) => ['Invoices', 'InvoiceItems', 'Receipts'].contains(t),
    )) {
      affected.addAll([
        'Invoices',
        'InvoiceItems',
        'Receipts',
        'ReceiptAllocations',
        'CreditNotes',
        'CreditNoteItems',
      ]);
    }
    if (tables.any((t) => ['Quotations', 'QuotationItems'].contains(t))) {
      affected.addAll([
        'Quotations',
        'QuotationItems',
        'Invoices',
        'InvoiceItems',
      ]);
    }
    if (tables.contains('Payroll')) {
      affected.addAll(['PayrollItems', 'Payslips']);
    }
    if (tables.contains('CapitalTransactions')) {
      affected.addAll(['CapitalAccounts', 'ShareholderEquity', 'Shareholders']);
    }
    cache.invalidate(
      (p) =>
          affected.contains(Uri.parse(p).path.split('/').last) ||
          (financial && p.contains('/reports/')) ||
          (tables.contains('Employees') && p.endsWith('/employees')),
      broadcastPaths: [
        for (final table in affected)
          recordsPath(_cacheCompany!, table, employee: _cacheEmployee),
        if (financial)
          _cacheEmployee
              ? '/v1/employee/reports/'
              : '/v1/companies/$_cacheCompany/reports/',
        if (tables.contains('Employees'))
          '/v1/companies/$_cacheCompany/employees',
      ],
    );
  }

  static Uri _origin(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.hasPort && uri.port != 443)) {
      throw const SaasApiException(
        'CONFIGURATION',
        'The company service is not configured.',
      );
    }
    return uri.replace(path: '');
  }

  static String _id(String value) {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value)) {
      throw const SaasApiException(
        'INVALID_ID',
        'Invalid company or record identifier.',
      );
    }
    return value;
  }

  static String? invitation(Uri link, Uri appOrigin) {
    if (link.scheme != 'https' ||
        !link.hasAuthority ||
        appOrigin.scheme != 'https' ||
        !appOrigin.hasAuthority ||
        link.userInfo.isNotEmpty ||
        link.origin != appOrigin.origin ||
        link.path != '/' ||
        link.hasQuery) {
      return null;
    }
    final match = RegExp(
      r'^employee-invite=([A-Za-z0-9_-]{43})$',
    ).firstMatch(link.fragment);
    return match?.group(1);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? data,
    String? operationId,
  }) async {
    if (!path.startsWith('/v1/') ||
        path.startsWith('//') ||
        path.contains('#')) {
      throw const SaasApiException('INVALID_PATH', 'Invalid service request.');
    }
    final abort = method == 'GET' && _cacheable(path)
        ? Completer<void>()
        : null;
    if (abort != null) _readAborts.add(abort);
    final request =
        (abort == null
              ? http.Request(method, origin.resolve(path))
              : http.AbortableRequest(
                  method,
                  origin.resolve(path),
                  abortTrigger: abort.future,
                ))
          ..followRedirects = false
          ..headers['Accept'] = 'application/json';
    if (method != 'GET') {
      request.headers.addAll({
        'Content-Type': 'application/json',
        'X-TPC-CSRF': '1',
      });
      request.body = jsonEncode(data ?? const <String, Object?>{});
    }
    if (operationId != null) {
      if (!RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(operationId)) {
        throw const SaasApiException(
          'INVALID_OPERATION',
          'Invalid change identifier.',
        );
      }
      request.headers['Idempotency-Key'] = operationId;
    }
    if (_cacheEmployee &&
        _cacheCompany != null &&
        (path.startsWith('/v1/employee/records/') ||
            path.startsWith('/v1/employee/reports/'))) {
      request.headers['X-TPC-Company'] = _cacheCompany!;
      request.headers['X-TPC-Employee'] = _cacheUser!;
    }
    late http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      if (abort != null && !abort.isCompleted) abort.complete();
      throw const SaasApiException(
        'NETWORK',
        'Connection timed out. Keep this change pending and retry.',
      );
    } on http.ClientException {
      throw const SaasApiException(
        'NETWORK',
        'Cannot reach the company service. Your pending changes must be retained.',
      );
    } finally {
      if (abort != null) _readAborts.remove(abort);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String code = 'SERVICE_UNAVAILABLE';
      String message = 'Company service unavailable. Retry later.';
      try {
        final error = (jsonDecode(response.body) as Map)['error'] as Map;
        if (error['code'] is String && error['message'] is String) {
          code = error['code'] as String;
          message = error['message'] as String;
        }
      } catch (_) {
        /* A proxy error is not a valid API response. */
      }
      final retryHeader = response.headers['retry-after'] ?? '';
      final retrySeconds = int.tryParse(retryHeader);
      Duration? retryAfter;
      if (response.statusCode == 429) {
        retryAfter = const Duration(seconds: 60);
        if (retrySeconds != null && retrySeconds >= 0) {
          retryAfter = Duration(seconds: retrySeconds);
        } else {
          try {
            final wait = parseHttpDate(
              retryHeader,
            ).difference(DateTime.now().toUtc());
            retryAfter = wait.isNegative ? Duration.zero : wait;
          } catch (_) {}
        }
      }
      throw SaasApiException(
        code,
        message,
        status: response.statusCode,
        retryAfter: retryAfter,
      );
    }
    return response;
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, Object?>? data,
    String? operationId,
    bool force = false,
  }) async {
    if (method == 'GET' && _cacheable(path)) {
      return cache.read(path, () => _networkJson(method, path), force: force);
    }
    final mutationScope = cache.scope;
    final result = await _networkJson(
      method,
      path,
      data: data,
      operationId: operationId,
    );
    if (method != 'GET' && mutationScope == cache.scope) {
      _invalidateMutation(path, data, result);
    }
    return result;
  }

  Future<Map<String, dynamic>> _networkJson(
    String method,
    String path, {
    Map<String, Object?>? data,
    String? operationId,
  }) async {
    final employeeRequest =
        path.startsWith('/v1/employee/') &&
        ![
          '/v1/employee/login',
          '/v1/employee/logout',
          '/v1/employee/refresh',
        ].contains(path);
    final requestedScope = cache.scope;
    if (employeeRequest &&
        _employeeExpiresAt != null &&
        DateTime.now().isAfter(
          _employeeExpiresAt!.subtract(const Duration(minutes: 5)),
        )) {
      await _renewEmployee();
      if (requestedScope != cache.scope) {
        throw const SaasApiException(
          'CONTEXT_CHANGED',
          'Workspace access changed. Review your pending change before retrying.',
        );
      }
    }
    final renewalVersion = _employeeRenewalVersion;
    late http.Response response;
    try {
      response = await _send(
        method,
        path,
        data: data,
        operationId: operationId,
      );
    } on SaasApiException catch (error) {
      // Only the explicit renewable-session error permits a single replay.
      // Sync carries stable per-operation identifiers; other mutations are not replayed.
      if (!employeeRequest ||
          error.code != 'EMPLOYEE_SESSION_EXPIRED' ||
          !(method == 'GET' || path == '/v1/employee/sync')) {
        rethrow;
      }
      if (renewalVersion == _employeeRenewalVersion) {
        await _renewEmployee();
      }
      if (requestedScope != cache.scope) {
        throw const SaasApiException(
          'CONTEXT_CHANGED',
          'Workspace access changed. Review your pending change before retrying.',
        );
      }
      response = await _send(
        method,
        path,
        data: data,
        operationId: operationId,
      );
    }
    if (response.statusCode == 204) return {};
    try {
      final result = Map<String, dynamic>.from(
        jsonDecode(response.body) as Map,
      );
      if ((path == '/v1/employee/login' || path == '/v1/employee/refresh') &&
          result['expiresAt'] is num) {
        _employeeExpiresAt = DateTime.fromMillisecondsSinceEpoch(
          (result['expiresAt'] as num).toInt(),
        );
      }
      final uri = Uri.parse(path);
      final listKey = uri.path.contains('/records/')
          ? 'records'
          : uri.path.endsWith('/employees')
          ? 'employees'
          : null;
      if (method == 'GET' &&
          listKey != null &&
          (result[listKey] is! List ||
              !(result[listKey] as List).every((r) => r is Map))) {
        throw const FormatException('Invalid record list');
      }
      return result;
    } catch (_) {
      throw const SaasApiException(
        'INVALID_RESPONSE',
        'The company service returned an invalid response.',
      );
    }
  }

  Future<void> _renewEmployee() {
    final pending = _employeeRenewal;
    if (pending != null) return pending;
    final scope = cache.scope;
    final future = (() async {
      final result = await _networkJson('POST', '/v1/employee/refresh');
      if (cache.scope != scope) return;
      final employee = Map<String, dynamic>.from(result['employee'] as Map);
      if (_cacheUser != null &&
          (employee['employeeId'] != _cacheUser ||
              employee['companyId'] != _cacheCompany)) {
        throw const SaasApiException(
          'EMPLOYEE_SESSION_INVALID',
          'Employee account changed. Sign in again.',
          status: 401,
        );
      }
      if (_cacheCompany != null && _permissions(employee) != _permissionKey) {
        useVerifiedWorkspace(_cacheCompany!, employee: employee);
        onEmployeeChanged?.call(employee);
      }
      _employeeRenewalVersion++;
    })();
    _employeeRenewal = future;
    future.then(
      (_) {
        if (identical(_employeeRenewal, future)) _employeeRenewal = null;
      },
      onError: (Object _, StackTrace __) {
        if (identical(_employeeRenewal, future)) _employeeRenewal = null;
      },
    );
    return future;
  }

  Future<Uri> _authorization(String path) async {
    final result = await _json('POST', path);
    final uri = Uri.tryParse(
      result['authorizationUrl'] is String
          ? result['authorizationUrl'] as String
          : '',
    );
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'accounts.google.com' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      throw const SaasApiException(
        'INVALID_RESPONSE',
        'Invalid Google sign-in destination.',
      );
    }
    return uri;
  }

  @override
  Future<Uri> startSignIn() async {
    await clearWorkspace();
    return _authorization('/v1/auth/google/start');
  }

  @override
  Future<Map<String, dynamic>> me() => _json('GET', '/v1/me');
  Future<Map<String, dynamic>> employeeReport(
    String kind,
    String from,
    String asOf, {
    bool force = false,
  }) {
    if (!const [
      'dashboard',
      'general-ledger',
      'trial-balance',
      'profit-and-loss',
      'balance-sheet',
    ].contains(kind)) {
      throw const SaasApiException('INVALID_REPORT', 'Invalid report.');
    }
    final period = const [
      'dashboard',
      'general-ledger',
      'profit-and-loss',
    ].contains(kind);
    return _json(
      'GET',
      '/v1/employee/reports/$kind?asOf=${Uri.encodeQueryComponent(asOf)}${period ? '&from=${Uri.encodeQueryComponent(from)}' : ''}',
      force: force,
    );
  }

  String financialReportPath(
    String companyId,
    String kind, {
    required String asOf,
    String? from,
    String? compareFrom,
    String? compareAsOf,
    bool employee = false,
  }) {
    if (!const [
      'dashboard',
      'general-ledger',
      'trial-balance',
      'profit-and-loss',
      'balance-sheet',
    ].contains(kind)) {
      throw const SaasApiException('INVALID_REPORT', 'Invalid report.');
    }
    final query = <String, String>{
      'asOf': asOf,
      if (from != null && kind != 'balance-sheet') 'from': from,
      if (compareAsOf != null) 'compareAsOf': compareAsOf,
      if (compareFrom != null && kind != 'balance-sheet')
        'compareFrom': compareFrom,
    };
    final base = employee
        ? '/v1/employee/reports'
        : '/v1/companies/${_id(companyId)}/reports';
    return '$base/$kind?${Uri(queryParameters: query).query}';
  }

  Future<Map<String, dynamic>> financialReport(
    String companyId,
    String kind, {
    required String asOf,
    String? from,
    String? compareFrom,
    String? compareAsOf,
    bool employee = false,
    bool force = false,
  }) => _json(
    'GET',
    financialReportPath(
      companyId,
      kind,
      asOf: asOf,
      from: from,
      compareFrom: compareFrom,
      compareAsOf: compareAsOf,
      employee: employee,
    ),
    force: force,
  );

  Future<Map<String, dynamic>> reportSettings(
    String companyId, {
    bool employee = false,
    bool force = false,
  }) => _json(
    'GET',
    employee
        ? '/v1/employee/reports/settings'
        : '/v1/companies/${_id(companyId)}/reports/settings',
    force: force,
  );

  Future<Map<String, dynamic>> saveReportSettings(
    String companyId,
    Map<String, dynamic> settings,
  ) async {
    final result = await _json(
      'PUT',
      '/v1/companies/${_id(companyId)}/reports/settings',
      data: {
        'expectedVersion': settings['version'],
        'settings': {...settings}..remove('version'),
      },
    );
    cache.invalidate((path) => path.contains('/reports/'));
    return result;
  }

  Future<Map<String, dynamic>> report(
    String companyId,
    String kind,
    String from,
    String asOf, {
    bool force = false,
  }) {
    if (!const ['dashboard', 'general-ledger'].contains(kind)) {
      throw const SaasApiException('INVALID_REPORT', 'Invalid report.');
    }
    return _json(
      'GET',
      '/v1/companies/${_id(companyId)}/reports/$kind?from=${Uri.encodeQueryComponent(from)}&asOf=${Uri.encodeQueryComponent(asOf)}',
      force: force,
    );
  }

  Future<Map<String, dynamic>> documents(
    String companyId,
    String section,
    String recordId, {
    bool employee = false,
  }) => _json(
    'GET',
    '/v1/${employee ? 'employee/' : ''}companies/${_id(companyId)}/documents?section=${Uri.encodeQueryComponent(section)}&recordId=${Uri.encodeQueryComponent(recordId)}',
  );
  Future<Map<String, dynamic>> balanceSheet(
    String companyId,
    String asOf, {
    bool force = false,
  }) => _json(
    'GET',
    '/v1/companies/$companyId/reports/balance-sheet?asOf=${Uri.encodeQueryComponent(asOf)}',
    force: force,
  );
  Future<Map<String, dynamic>> profitAndLoss(
    String companyId,
    String from,
    String asOf, {
    bool force = false,
  }) => _json(
    'GET',
    '/v1/companies/$companyId/reports/profit-and-loss?from=${Uri.encodeQueryComponent(from)}&asOf=${Uri.encodeQueryComponent(asOf)}',
    force: force,
  );
  Future<Map<String, dynamic>> trialBalance(
    String companyId,
    String asOf, {
    bool force = false,
  }) => _json(
    'GET',
    '/v1/companies/$companyId/reports/trial-balance?asOf=${Uri.encodeQueryComponent(asOf)}',
    force: force,
  );
  @override
  Future<Map<String, dynamic>> companies() => _json('GET', '/v1/companies');
  @override
  Future<Map<String, dynamic>> deleteCompany(String companyId) =>
      _json('DELETE', '/v1/companies/${_id(companyId)}');
  @override
  Future<Map<String, dynamic>> createCompany(String name, String operationId) =>
      _json(
        'POST',
        '/v1/companies',
        data: {'name': name},
        operationId: operationId,
      );
  @override
  Future<Uri> connectGoogle(String companyId) =>
      _authorization('/v1/companies/${_id(companyId)}/google/connect');
  @override
  Future<Map<String, dynamic>> setup(String companyId) =>
      _json('GET', '/v1/companies/${_id(companyId)}/setup');
  @override
  Future<Map<String, dynamic>> retrySetup(String companyId) =>
      _json('POST', '/v1/companies/${_id(companyId)}/setup/retry');
  @override
  Future<Map<String, dynamic>> logout() async {
    await clearWorkspace();
    return _json('POST', '/v1/auth/logout');
  }

  @override
  Future<Map<String, dynamic>> employeeLogin(
    String inviteId,
    String privateCode,
  ) async {
    await clearWorkspace();
    _employeeExpiresAt = null;
    return _json(
      'POST',
      '/v1/employee/login',
      data: {'inviteId': _id(inviteId), 'privateCode': privateCode},
    );
  }

  @override
  Future<Map<String, dynamic>> employeeMe() => _json('GET', '/v1/employee/me');
  @override
  Future<Map<String, dynamic>> employeeLogout() async {
    try {
      await _employeeRenewal;
    } catch (_) {}
    _employeeExpiresAt = null;
    await clearWorkspace();
    return _json('POST', '/v1/employee/logout');
  }

  Future<Map<String, dynamic>> employees(
    String companyId, {
    bool force = false,
  }) => _json('GET', '/v1/companies/${_id(companyId)}/employees', force: force);
  Future<Map<String, dynamic>> saveEmployee(
    String companyId,
    String? employeeId,
    Map<String, Object?> values,
    String operationId,
  ) => _json(
    employeeId == null ? 'POST' : 'PATCH',
    '/v1/companies/${_id(companyId)}/employees${employeeId == null ? '' : '/${_id(employeeId)}'}',
    data: values,
    operationId: operationId,
  );
  Future<Map<String, dynamic>> employeeAccess(
    String companyId,
    String employeeId,
    String action, {
    String? operationId,
  }) {
    if (!const ['issue', 'reset', 'revoke'].contains(action)) {
      throw const SaasApiException('INVALID_ACTION', 'Invalid access action.');
    }
    return _json(
      'POST',
      '/v1/companies/${_id(companyId)}/employees/${_id(employeeId)}/access/$action',
      operationId: operationId,
    );
  }

  Future<Map<String, dynamic>> records(
    String companyId,
    String table, {
    bool employee = false,
    bool force = false,
  }) {
    if (!RegExp(r'^[A-Za-z]+$').hasMatch(table)) {
      throw const SaasApiException('INVALID_TABLE', 'Invalid record section.');
    }
    return _json(
      'GET',
      employee
          ? '/v1/employee/records/$table'
          : '/v1/companies/${_id(companyId)}/records/$table',
      force: force,
    );
  }

  Future<Map<String, dynamic>> sync(
    String companyId,
    List<Map<String, Object?>> operations, {
    bool employee = false,
    String? expectedEmployeeId,
  }) => _json(
    'POST',
    employee ? '/v1/employee/sync' : '/v1/companies/${_id(companyId)}/sync',
    data: {
      'operations': operations,
      if (employee) 'companyId': _id(companyId),
      if (employee && (expectedEmployeeId ?? _cacheUser) != null)
        'employeeId': _id(expectedEmployeeId ?? _cacheUser!),
    },
  );

  Future<Map<String, dynamic>> upload(
    String companyId, {
    required String operationId,
    required String name,
    required String mimeType,
    required String relatedSection,
    required String relatedRecordId,
    required Uint8List bytes,
  }) => _json(
    'POST',
    '/v1/companies/${_id(companyId)}/documents',
    operationId: operationId,
    data: {
      'name': name,
      'mimeType': mimeType,
      'relatedSection': relatedSection,
      'relatedRecordId': relatedRecordId,
      'data': base64Encode(bytes),
    },
  );

  Future<Uint8List> document(
    String companyId,
    String documentId, {
    bool employee = false,
  }) async => (await _send(
    'GET',
    '/v1/${employee ? 'employee/' : ''}companies/${_id(companyId)}/documents/${_id(documentId)}',
  )).bodyBytes;

  void close() {
    _cancelReads();
    cache.dispose();
    _client.close();
  }
}
