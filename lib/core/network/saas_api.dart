import 'dart:async';
import 'package:tpc_invoice/features/auth/domain/session_repository.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tpc_invoice/core/network/supabase_runtime.dart';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tpc_invoice/core/offline/offline_store.dart';
import 'package:tpc_invoice/core/offline/offline_outbox.dart';
import 'package:tpc_invoice/core/offline/task_projection.dart';
import 'package:tpc_invoice/core/offline/provisional_report.dart';
import 'package:tpc_invoice/core/offline/entity_projection.dart';
import 'package:http_parser/http_parser.dart' show parseHttpDate;
import 'package:tpc_invoice/core/cache/cache_store.dart';
import 'package:tpc_invoice/core/cache/read_cache.dart';

import 'package:tpc_invoice/core/network/api_transport_stub.dart'
    if (dart.library.js_interop) 'package:tpc_invoice/core/network/api_transport_web.dart';

const configuredSaasApiOrigin = configuredSupabaseUrl;

class TaskRealtimeUpdate {
  const TaskRealtimeUpdate(
      {required this.companyId, required this.connected, this.refresh = true});
  final String companyId;
  final bool connected, refresh;
}

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
/// Supabase Auth manages the bearer session used by the Edge API.
class SaasApi implements SessionRepository {
  SaasApi({
    String origin = configuredSaasApiOrigin,
    http.Client? client,
    SupabaseClient? auth,
    CacheStore? cacheStore,
    OfflineStore? offlineStore,
    this.offlineAutomatic = true,
  })  : origin = _origin(origin),
        _client = client ?? createSaasTransport(),
        _auth = auth,
        _cacheStore = cacheStore,
        _offlineStore = offlineStore;

  final OfflineStore? _offlineStore;
  final SupabaseClient? _auth;
  SupabaseClient? get _supabase => _auth ?? currentSupabaseClient;
  Future<Session?>? _authRefresh;
  Future<Session?> _refreshAuthSession(SupabaseClient client) {
    final pending = _authRefresh;
    if (pending != null) return pending;
    final future = (() async {
      try {
        return (await client.auth.refreshSession()).session;
      } on AuthRetryableFetchException {
        throw const SaasApiException(
            'NETWORK', 'Connection unavailable. Your login is preserved.');
      } on AuthException catch (error) {
        if (const {
          'refresh_token_not_found',
          'refresh_token_already_used',
          'session_not_found',
          'user_banned',
          'user_not_found'
        }.contains(error.code)) {
          throw const SaasApiException(
              'UNAUTHORIZED', 'Your session is no longer valid. Sign in again.',
              status: 401);
        }
        throw const SaasApiException(
            'NETWORK', 'Could not refresh your login. Retry when connected.');
      }
    })();
    _authRefresh = future;
    future.then((_) {
      if (identical(_authRefresh, future)) _authRefresh = null;
    }, onError: (Object _, StackTrace __) {
      if (identical(_authRefresh, future)) _authRefresh = null;
    });
    return future;
  }

  RealtimeChannel? _realtime;
  final _taskUpdates = StreamController<TaskRealtimeUpdate>.broadcast();
  Stream<TaskRealtimeUpdate> get taskUpdates => _taskUpdates.stream;
  bool _taskRealtimeConnected = false;
  bool get taskRealtimeConnected => _taskRealtimeConnected;
  int _realtimeGeneration = 0;
  final bool offlineAutomatic;
  bool get offlineEnabled => kIsWeb || _offlineStore != null;
  String get _sessionSnapshotScope => 'session-profile:${origin.origin}';
  Future<void> saveSessionProfile(Map<String, dynamic> profile) async {
    if (!offlineEnabled) return;
    await offlineStore.change(
        _sessionSnapshotScope,
        (p) => p['profile'] = {
              ...profile,
              'authUserId': _supabase?.auth.currentUser?.id,
            });
  }

  Future<Map<String, dynamic>?> offlineSessionProfile() async {
    if (!offlineEnabled) return null;
    final profile = (await offlineStore.read(_sessionSnapshotScope))['profile'];
    if (profile is! Map ||
        (profile['expiresAt'] as int? ?? 0) <=
            DateTime.now().millisecondsSinceEpoch) {
      return null;
    }
    final auth = _supabase;
    if (auth != null &&
        (auth.auth.currentSession == null ||
            profile['authUserId'] != auth.auth.currentUser?.id)) {
      return null;
    }
    return Map<String, dynamic>.from(profile);
  }

  Future<void> clearSessionProfile() async {
    if (offlineEnabled) {
      await offlineStore.change(
          _sessionSnapshotScope, (p) => p.remove('profile'));
    }
  }

  late final OfflineStore offlineStore = _offlineStore ?? createOfflineStore();
  final _outboxes = <String, OfflineOutbox>{};
  OfflineOutbox outbox(String user, String company, {bool employee = false}) {
    final identity = employee ? user.replaceFirst('employee_', '') : user;
    final scope = jsonEncode([
      origin.toString(),
      employee ? 'employee' : 'owner',
      identity,
      company,
    ]);
    return _outboxes.putIfAbsent(
      scope,
      () => OfflineOutbox(
        store: offlineStore,
        automatic: offlineAutomatic,
        scope: scope,
        isCurrent: () =>
            cache.scope != null &&
            _cacheUser == identity &&
            _cacheCompany == company &&
            _cacheEmployee == employee,
        verifyIdentity: () =>
            verifySyncIdentity(identity, company, employee: employee),
        send: (op) async {
          if (!employee && op['table'] == 'ReportSettings') {
            final settings = Map<String, dynamic>.from(op['values'] as Map);
            final current = await _json(
                'GET', '/v1/companies/${_id(company)}/reports/settings',
                force: true);
            final comparable = {...current}..remove('version');
            final result = current['version'] ==
                        (op['expectedVersion'] as int) + 1 &&
                    dataFingerprint(comparable) == dataFingerprint(settings)
                ? current
                : await _saveReportSettingsOnline(
                    company, {...settings, 'version': op['expectedVersion']});
            return {
              'results': [
                {
                  'operationId': op['operationId'],
                  'status': 'APPLIED',
                  'recordId': 'report-settings',
                  'version': result['version']
                }
              ]
            };
          }
          if (!employee && op['table'] == 'Employees') {
            final result = await saveEmployee(
                company,
                op['recordId'] as String?,
                {
                  ...Map<String, Object?>.from(op['values'] as Map),
                  'expectedVersion': op['expectedVersion']
                },
                op['operationId'] as String);
            return {
              'results': [
                {
                  'operationId': op['operationId'],
                  'status': 'APPLIED',
                  'recordId': result['employeeId'],
                  if (result['employeeCode'] is String)
                    'employeeCode': result['employeeCode'],
                  'version': result['version']
                }
              ]
            };
          }
          if (op['table'] == 'Documents' && op['action'] == 'upload') {
            final values = op['values'] as Map;
            final result = await upload(company,
                employee: employee,
                operationId: op['operationId'] as String,
                name: values['name'],
                mimeType: values['mimeType'],
                relatedSection: values['section'],
                relatedRecordId: values['relatedRecordId'],
                bytes: base64Decode(values['data']));
            return {
              'results': [
                {
                  'operationId': op['operationId'],
                  'status': 'APPLIED',
                  'recordId': result['documentId'],
                  'version': 1
                }
              ]
            };
          }
          return sync(
            company,
            [op],
            employee: employee,
            expectedEmployeeId: employee ? identity : null,
            expectedOwnerId: employee ? null : identity,
          );
        },
        changed: (table) =>
            cache.localChanged(recordsPath(company, table, employee: employee)),
      ),
    );
  }

  Future<void> verifySyncIdentity(
    String user,
    String company, {
    bool employee = false,
  }) async {
    final identity = await _networkJson(
      'GET',
      employee ? '/v1/employee/me' : '/v1/me',
    );
    final principal = identity[employee ? 'employee' : 'owner'] as Map;
    if (principal[employee ? 'employeeId' : 'ownerId'] != user ||
        (employee && principal['companyId'] != company)) {
      throw const SaasApiException(
        'SYNC_ACCOUNT_MISMATCH',
        'Sign in to the original account and workspace to sync these changes.',
        status: 401,
      );
    }
  }

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
    _watchRealtime(companyId);
    for (final outbox in _outboxes.values) {
      outbox.resumeAuthentication();
    }
  }

  @override
  void detachWorkspace() {
    _stopRealtime();
    for (final outbox in _outboxes.values) {
      outbox.pause();
    }
    _cancelReads();
    cache.detach();
    _cacheCompany = null;
    _cacheUser = null;
  }

  @override
  Future<void> clearWorkspace() async {
    _stopRealtime();
    for (final outbox in _outboxes.values) {
      outbox.pause();
    }
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
          uri.path.startsWith('/v1/employee/references/') ||
          uri.path.startsWith('/v1/employee/reports/') ||
          uri.path == '/v1/employee/companies/$_cacheCompany/documents' ||
          uri.path.startsWith('/v1/employee/companies/$_cacheCompany/tasks') ||
          uri.path == '/v1/employee/companies/$_cacheCompany/notifications';
    }
    final prefix = '/v1/companies/$_cacheCompany/';
    return uri.path.startsWith('${prefix}records/') ||
        uri.path == '${prefix}overview' ||
        uri.path.startsWith('${prefix}reports/') ||
        uri.path == '${prefix}employees' ||
        uri.path == '${prefix}documents' ||
        uri.path.startsWith('${prefix}tasks') ||
        uri.path == '${prefix}notifications';
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
    if (path.endsWith('/documents')) {
      cache.invalidate((p) => Uri.parse(p).path == path);
    }
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
      (t) => ![
        'Customers',
        'Projects',
        'Employees',
        'CompanyProfile',
        'Tasks',
        'TaskComments',
        'TaskActivity',
      ].contains(t),
    );
    if (tables.contains('Tasks')) affected.add('TaskActivity');
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
          p.endsWith('/overview') ||
          affected.contains(Uri.parse(p).path.split('/').last) ||
          (financial && p.contains('/reports/')) ||
          (tables.contains('Employees') &&
              (p.endsWith('/employees') ||
                  Uri.parse(p).path.endsWith('/tasks/assignees'))) ||
          (tables.any(
                (t) => ['Tasks', 'TaskComments', 'TaskActivity'].contains(t),
              ) &&
              p.contains('/tasks') &&
              !Uri.parse(p).path.endsWith('/assignees')),
      broadcastPaths: [
        if (tables.any(
          (t) => ['Tasks', 'TaskComments', 'TaskActivity'].contains(t),
        ))
          '/v1/${_cacheEmployee ? 'employee/' : ''}companies/$_cacheCompany/tasks',
        for (final table in affected)
          recordsPath(_cacheCompany!, table, employee: _cacheEmployee),
        if (financial)
          _cacheEmployee
              ? '/v1/employee/reports/'
              : '/v1/companies/$_cacheCompany/reports/',
        if (tables.contains('Employees')) ...[
          '/v1/companies/$_cacheCompany/employees',
          '/v1/${_cacheEmployee ? 'employee/' : ''}companies/$_cacheCompany/tasks/assignees',
        ],
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
    bool retryAuth = true,
  }) async {
    if (!path.startsWith('/v1/') ||
        path.startsWith('//') ||
        path.contains('#')) {
      throw const SaasApiException('INVALID_PATH', 'Invalid service request.');
    }
    final abort =
        method == 'GET' && _cacheable(path) ? Completer<void>() : null;
    if (abort != null) _readAborts.add(abort);
    final target = origin.resolve(
        origin.host.endsWith('.supabase.co') ? '/functions/v1/api$path' : path);
    final request = (abort == null
        ? http.Request(method, target)
        : http.AbortableRequest(
            method,
            target,
            abortTrigger: abort.future,
          ))
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    final supabase = _supabase;
    if (supabase != null) {
      var session = supabase.auth.currentSession;
      if (session?.expiresAt != null &&
          DateTime.now().millisecondsSinceEpoch ~/ 1000 >=
              session!.expiresAt! - 60) {
        session = await _refreshAuthSession(supabase);
      }
      if (session != null) {
        request.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
      request.headers['apikey'] = configuredSupabaseKey;
    }
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
            path.startsWith('/v1/employee/references/') ||
            path.startsWith('/v1/employee/reports/') ||
            path.startsWith('/v1/employee/companies/'))) {
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
      // A background refresh can race an in-flight read using the old token.
      // Renew and replay a read once before treating it as a lost login.
      if (retryAuth &&
          method == 'GET' &&
          response.statusCode == 401 &&
          code == 'UNAUTHORIZED' &&
          supabase?.auth.currentSession != null) {
        final refreshed = await _refreshAuthSession(supabase!);
        if (refreshed != null) {
          return _send(method, path,
              data: data, operationId: operationId, retryAuth: false);
        }
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
      final result = await cache.read(path, () => _networkJson(method, path),
          force: force);
      final kind = Uri.parse(path).path.split('/').last;
      if (_cacheCompany != null &&
          path.contains('/reports/') &&
          const [
            'dashboard',
            'general-ledger',
            'trial-balance',
            'profit-and-loss',
            'balance-sheet'
          ].contains(kind)) {
        return localFinancialReport(_cacheCompany!, result, kind,
            employee: _cacheEmployee);
      }
      if (_cacheCompany != null && Uri.parse(path).path.endsWith('/overview')) {
        return localEntityOverview(_cacheCompany!, result);
      }
      return result;
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
    final employeeRequest = path.startsWith('/v1/employee/') &&
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
  }) async {
    final result = await _json(
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
    return result;
  }

  Map<String, dynamic> localFinancialReport(
      String companyId, Map<String, dynamic> snapshot, String kind,
      {bool employee = false}) {
    final box = workspaceOutbox(companyId, employee: employee);
    if (box == null) return snapshot;
    return projectFinancialReport(box, snapshot, kind, (table) {
      final rows = cache
              .state(recordsPath(companyId, table, employee: employee))
              ?.data?['records'] as List? ??
          [];
      return box.overlay(table,
          rows.map((row) => Map<String, dynamic>.from(row as Map)).toList());
    });
  }

  Future<Map<String, dynamic>> reportSettings(
    String companyId, {
    bool employee = false,
    bool force = false,
  }) async {
    final box = _ownerOutbox(companyId);
    if (box != null && !employee) await box.reload();
    final future = _json(
      'GET',
      employee
          ? '/v1/employee/reports/settings'
          : '/v1/companies/${_id(companyId)}/reports/settings',
      force: force,
    );
    final local =
        box?.data['records']['ReportSettings:report-settings'] as Map?;
    Map<String, dynamic> savedSettings(Map saved) => {
          ...Map<String, dynamic>.from(saved)
            ..removeWhere((k, _) =>
                k.startsWith('_') ||
                const ['recordId', 'recordVersion', 'syncStatus', 'isDeleted']
                    .contains(k)),
          'version': saved['recordVersion']
        };
    if (!employee && local != null && local['syncStatus'] != 'SYNCED') {
      future.ignore();
      return savedSettings(local);
    }
    final result = await future;
    if (!employee &&
        local != null &&
        (local['recordVersion'] as num) > (result['version'] as num)) {
      return savedSettings(local);
    }
    return result;
  }

  OfflineOutbox? _ownerOutbox(String company) => offlineEnabled &&
          !_cacheEmployee &&
          _cacheCompany == company &&
          _cacheUser != null &&
          cache.scope != null
      ? outbox(_cacheUser!, company)
      : null;

  Future<Map<String, dynamic>> saveReportSettings(
    String companyId,
    Map<String, dynamic> settings,
  ) async {
    final box = _ownerOutbox(companyId);
    if (box != null) {
      await box.reload();
      await box.enqueue(
          'ReportSettings', 'update', {...settings}..remove('version'),
          recordId: 'report-settings',
          expectedVersion: settings['version'] as int,
          base: settings,
          local: true);
      return settings;
    }
    return _saveReportSettingsOnline(companyId, settings);
  }

  Future<Map<String, dynamic>> _saveReportSettingsOnline(
      String companyId, Map<String, dynamic> settings) async {
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
  }) =>
      _json(
        'GET',
        '/v1/${employee ? 'employee/' : ''}companies/${_id(companyId)}/documents?section=${Uri.encodeQueryComponent(section)}&recordId=${Uri.encodeQueryComponent(recordId)}',
      );
  Future<Map<String, dynamic>> balanceSheet(
    String companyId,
    String asOf, {
    bool force = false,
  }) =>
      _json(
        'GET',
        '/v1/companies/$companyId/reports/balance-sheet?asOf=${Uri.encodeQueryComponent(asOf)}',
        force: force,
      );
  Future<Map<String, dynamic>> profitAndLoss(
    String companyId,
    String from,
    String asOf, {
    bool force = false,
  }) =>
      _json(
        'GET',
        '/v1/companies/$companyId/reports/profit-and-loss?from=${Uri.encodeQueryComponent(from)}&asOf=${Uri.encodeQueryComponent(asOf)}',
        force: force,
      );
  Future<Map<String, dynamic>> trialBalance(
    String companyId,
    String asOf, {
    bool force = false,
  }) =>
      _json(
        'GET',
        '/v1/companies/$companyId/reports/trial-balance?asOf=${Uri.encodeQueryComponent(asOf)}',
        force: force,
      );
  @override
  Future<Map<String, dynamic>> companies() => _json('GET', '/v1/companies');
  Future<Map<String, dynamic>> businessGroups() => _json('GET', '/v1/groups');
  Future<Map<String, dynamic>> entityOverview(String companyId,
          {bool force = false}) =>
      _json('GET', '/v1/companies/${_id(companyId)}/overview', force: force);
  Map<String, dynamic> localEntityOverview(
      String companyId, Map<String, dynamic> snapshot) {
    final box = workspaceOutbox(companyId);
    return box == null
        ? snapshot
        : projectEntity(box, snapshot,
            syncedAt:
                cache.state('/v1/companies/$companyId/overview')?.syncedAt);
  }

  Future<Map<String, dynamic>> createBusinessGroup(String name, String key) =>
      _json('POST', '/v1/groups', data: {'name': name}, operationId: key);
  Future<Map<String, dynamic>> createCountryEntity(
          String groupId, Map<String, dynamic> values, String key) =>
      _json('POST', '/v1/groups/${_id(groupId)}/entities',
          data: values, operationId: key);
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
  Future<Map<String, dynamic>> setup(String companyId) =>
      _json('GET', '/v1/companies/${_id(companyId)}/setup');
  @override
  Future<Map<String, dynamic>> retrySetup(String companyId) =>
      _json('POST', '/v1/companies/${_id(companyId)}/setup/retry');
  @override
  Future<Map<String, dynamic>> logout() async {
    await clearWorkspace();
    await _supabase?.auth.signOut();
    return {};
  }

  @override
  Future<Map<String, dynamic>> employeeLogin(
    String inviteId,
    String privateCode,
  ) async {
    await clearWorkspace();
    _employeeExpiresAt = null;
    final result = await _json(
      'POST',
      '/v1/employee/login',
      data: {'inviteId': _id(inviteId), 'privateCode': privateCode},
    );
    if (_supabase != null) {
      await _supabase!.auth
          .setSession((result['session'] as Map)['refresh_token'] as String);
    }
    result.remove('session');
    return result;
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
    await _supabase?.auth.signOut();
    return {};
  }

  Future<Map<String, dynamic>> employees(
    String companyId, {
    bool force = false,
  }) async {
    final box = _ownerOutbox(companyId);
    if (box != null) await box.reload();
    final future =
        _json('GET', '/v1/companies/${_id(companyId)}/employees', force: force);
    if (box != null &&
        cache.state('/v1/companies/$companyId/employees')?.data == null &&
        box.overlay('Employees', []).isNotEmpty) {
      future.ignore();
      return {'employees': box.overlay('Employees', [])};
    }
    final result = await future;
    if (box == null) return result;
    final rows = (result['employees'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    box.reconcile('Employees', rows).ignore();
    return {...result, 'employees': box.overlay('Employees', rows)};
  }

  Future<Map<String, dynamic>> saveEmployee(
    String companyId,
    String? employeeId,
    Map<String, Object?> values,
    String operationId,
  ) =>
      _json(
        employeeId == null ? 'POST' : 'PATCH',
        '/v1/companies/${_id(companyId)}/employees${employeeId == null ? '' : '/${_id(employeeId)}'}',
        data: values,
        operationId: operationId,
      );
  Future<Map<String, dynamic>> payrollPreview(
    String companyId,
    Map<String, Object?> values, {
    bool employee = false,
  }) =>
      _json(
        'POST',
        employee
            ? '/v1/employee/payroll/preview'
            : '/v1/companies/${_id(companyId)}/payroll/preview',
        data: values,
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

  String tasksPath(String companyId, {bool employee = false}) =>
      '/v1/${employee ? 'employee/' : ''}companies/${_id(companyId)}/tasks';

  Future<Map<String, dynamic>> tasks(
    String companyId, {
    bool employee = false,
    bool force = false,
    Map<String, String> filters = const {},
  }) async {
    final box = workspaceOutbox(companyId, employee: employee);
    if (box != null) await box.reload();
    final path =
        '${tasksPath(companyId, employee: employee)}?${Uri(queryParameters: filters).query}';
    final pending = _json(
      'GET',
      path,
      force: force,
    );
    if (box != null &&
        cache.state(path)?.data == null &&
        box.localRecords('Tasks').isNotEmpty) {
      pending.ignore();
      return projectTaskPage(
          box,
          {
            'records': [],
            'total': 0,
            'summary': {},
            'dateCounts': {},
            'nextOffset': null
          },
          filters,
          hasSnapshot: false);
    }
    final result = await pending;
    return localTaskPage(companyId, result,
        employee: employee, filters: filters);
  }

  Map<String, dynamic> localTaskPage(
      String companyId, Map<String, dynamic> page,
      {bool employee = false, Map<String, String> filters = const {}}) {
    final box = workspaceOutbox(companyId, employee: employee);
    final path =
        '${tasksPath(companyId, employee: employee)}?${Uri(queryParameters: filters).query}';
    return box == null
        ? page
        : projectTaskPage(box, page, filters,
            syncedAt: cache.state(path)?.syncedAt);
  }

  OfflineOutbox? workspaceOutbox(String companyId, {bool employee = false}) =>
      offlineEnabled &&
              _cacheUser != null &&
              _cacheCompany == companyId &&
              _cacheEmployee == employee
          ? outbox(employee ? 'employee_$_cacheUser' : _cacheUser!, companyId,
              employee: employee)
          : null;

  Future<Map<String, dynamic>> taskDetail(
    String companyId,
    String taskId, {
    bool employee = false,
  }) =>
      _json(
        'GET',
        '${tasksPath(companyId, employee: employee)}/${_id(taskId)}',
        force: false,
      );

  Future<Map<String, dynamic>> taskAssignees(
    String companyId, {
    bool employee = false,
    String search = '',
    int offset = 0,
  }) =>
      _json(
        'GET',
        '${tasksPath(companyId, employee: employee)}/assignees?${Uri(queryParameters: {
              'search': search,
              'offset': '$offset',
              'limit': '40'
            }).query}',
      );
  Future<Map<String, dynamic>> editorReferences(
    String companyId,
    String table,
    String section, {
    bool employee = false,
  }) async {
    if (!employee) return records(companyId, table);
    if (!RegExp(r'^[A-Za-z]+$').hasMatch(table)) {
      throw const SaasApiException('INVALID_TABLE', 'Invalid reference table.');
    }
    final box = offlineEnabled &&
            _cacheUser != null &&
            _cacheEmployee &&
            _cacheCompany == companyId
        ? outbox('employee_$_cacheUser', companyId, employee: true)
        : null;
    if (box != null) await box.reload();
    final result = await _json(
      'GET',
      '/v1/employee/references/$table?section=${Uri.encodeQueryComponent(section)}',
    );
    return box == null
        ? result
        : {
            ...result,
            'records': box.overlay(
                table,
                (result['records'] as List)
                    .map((r) => Map<String, dynamic>.from(r as Map))
                    .toList())
          };
  }

  Future<Map<String, dynamic>> exchangeRate(
          String companyId, String currency, String date,
          {bool employee = false}) =>
      _json('GET',
          '/v1/${employee ? 'employee/companies' : 'companies'}/${_id(companyId)}/exchange-rate?currency=${Uri.encodeComponent(currency)}&date=${Uri.encodeComponent(date)}',
          force: true);

  Future<Map<String, dynamic>> records(
    String companyId,
    String table, {
    bool employee = false,
    bool force = false,
  }) async {
    if (!RegExp(r'^[A-Za-z]+$').hasMatch(table)) {
      throw const SaasApiException('INVALID_TABLE', 'Invalid record section.');
    }
    final box = offlineEnabled &&
            _cacheUser != null &&
            _cacheCompany == companyId &&
            _cacheEmployee == employee
        ? outbox(
            employee ? 'employee_$_cacheUser' : _cacheUser!,
            companyId,
            employee: employee,
          )
        : null;
    if (box != null) {
      try {
        await box.reload();
      } catch (_) {
        /* Storage status is visible; online reads remain available. */
      }
    }
    final future = _json(
      'GET',
      employee
          ? '/v1/employee/records/$table'
          : '/v1/companies/${_id(companyId)}/records/$table',
      force: force,
    );
    if (box != null &&
        cache.state(recordsPath(companyId, table, employee: employee))?.data ==
            null &&
        box.overlay(table, []).isNotEmpty) {
      future
          .then(
            (r) => box.reconcile(
              table,
              (r['records'] as List)
                  .map((v) => Map<String, dynamic>.from(v as Map))
                  .toList(),
            ),
          )
          .ignore();
      return {'records': box.overlay(table, [])};
    }
    final result = await future;
    if (box != null) {
      final rows = (result['records'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      // Retire only acknowledged overlays that the server snapshot now covers.
      unawaited(box.reconcile(table, rows).catchError((Object _) {}));
      return {...result, 'records': box.overlay(table, rows)};
    }
    return result;
  }

  Future<Map<String, dynamic>> sync(
    String companyId,
    List<Map<String, Object?>> operations, {
    bool employee = false,
    String? expectedEmployeeId,
    String? expectedOwnerId,
  }) async {
    final path =
        employee ? '/v1/employee/sync' : '/v1/companies/${_id(companyId)}/sync';
    final data = <String, Object?>{
      'operations': operations,
      if (!employee && expectedOwnerId != null) 'ownerId': expectedOwnerId,
      if (employee) 'companyId': _id(companyId),
      if (employee && (expectedEmployeeId ?? _cacheUser) != null)
        'employeeId': _id(expectedEmployeeId ?? _cacheUser!),
    };
    try {
      return await _json('POST', path, data: data);
    } on SaasApiException catch (error) {
      // Older owner endpoints accept only `operations`. This validation error
      // occurs before writes; preserve operation IDs for the compatibility retry.
      if (employee ||
          expectedOwnerId == null ||
          operations.isEmpty ||
          operations.length > 20 ||
          error.status != 400 ||
          error.code != 'INVALID_BATCH' ||
          error.message != 'Supply between 1 and 20 operations.') {
        rethrow;
      }
      await verifySyncIdentity(expectedOwnerId, companyId);
      return _json('POST', path, data: {'operations': operations});
    }
  }

  String notificationsPath(String companyId, {bool employee = false}) =>
      '/v1/${employee ? 'employee/' : ''}companies/${_id(companyId)}/notifications';
  Future<Map<String, dynamic>> notifications(String companyId,
          {bool employee = false, bool force = false}) =>
      _json('GET', notificationsPath(companyId, employee: employee),
          force: force);
  Future<Map<String, dynamic>> notificationRead(String companyId, String id,
          {bool employee = false, bool read = true}) =>
      _json('POST', '${notificationsPath(companyId, employee: employee)}/read',
          data: {'id': id, 'read': read});
  Future<Map<String, dynamic>> subscribePush(
          String companyId, Map<String, dynamic> subscription,
          {bool employee = false}) =>
      _json('POST',
          '${notificationsPath(companyId, employee: employee)}/subscription',
          data: {'subscription': subscription});
  Future<Map<String, dynamic>> unsubscribePush(String companyId,
          {bool employee = false, String? endpoint}) =>
      _json('DELETE',
          '${notificationsPath(companyId, employee: employee)}/subscription',
          data: {if (endpoint != null) 'endpoint': endpoint});

  Future<Map<String, dynamic>> upload(
    String companyId, {
    required String operationId,
    required String name,
    required String mimeType,
    required String relatedSection,
    required String relatedRecordId,
    required Uint8List bytes,
    bool employee = false,
  }) =>
      _json(
        'POST',
        '/v1/${employee ? 'employee/' : ''}companies/${_id(companyId)}/documents',
        operationId: operationId,
        data: {
          'name': name,
          'mimeType': mimeType,
          'section': relatedSection,
          'relatedRecordId': relatedRecordId,
          'data': base64Encode(bytes),
        },
      );

  Future<Uint8List> document(
    String companyId,
    String documentId, {
    bool employee = false,
  }) async =>
      (await _send(
        'GET',
        '/v1/${employee ? 'employee/' : ''}companies/${_id(companyId)}/documents/${_id(documentId)}',
      ))
          .bodyBytes;

  Future<Map<String, dynamic>> documentDesign(String companyId, String section,
          {bool employee = false}) =>
      _json('GET',
          '/v1/${employee ? 'employee/' : ''}companies/${_id(companyId)}/document-designs/$section',
          force: true);

  Future<Map<String, dynamic>> saveDocumentDesign(String companyId,
          String section, String source, int expectedVersion) =>
      _json('PUT', '/v1/companies/${_id(companyId)}/document-designs/$section',
          data: {'source': source, 'expectedVersion': expectedVersion});

  void close() {
    _stopRealtime();
    _taskUpdates.close();
    for (final outbox in _outboxes.values) {
      outbox.dispose();
    }
    _cancelReads();
    cache.dispose();
    _client.close();
  }

  Future<void> signInWithPassword(String email, String password) async {
    final client = _supabase;
    if (client == null) {
      throw const SaasApiException('CONFIGURATION',
          'Configure SUPABASE_PUBLISHABLE_KEY and rebuild the app.');
    }
    await clearWorkspace();
    await client.auth
        .signInWithPassword(email: email.trim(), password: password);
  }

  Future<bool> signUp(String email, String password) async {
    final client = _supabase;
    if (client == null) {
      throw const SaasApiException(
          'CONFIGURATION', 'Supabase Auth is not configured.');
    }
    final result = await client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: Uri.base.origin);
    return result.session != null;
  }

  Future<void> resetPassword(String email) async {
    final client = _supabase;
    if (client == null) {
      throw const SaasApiException(
          'CONFIGURATION', 'Supabase Auth is not configured.');
    }
    await client.auth
        .resetPasswordForEmail(email.trim(), redirectTo: Uri.base.origin);
  }

  Future<String> recordHtml(String companyId, String section, String recordId,
          {bool employee = false, String? source}) async =>
      (await _send(source == null ? 'GET' : 'POST',
              '/v1/${employee ? 'employee/' : ''}companies/${_id(companyId)}/record-html/$section/${_id(recordId)}',
              data: source == null ? null : {'source': source}))
          .body;

  void _stopRealtime() {
    _realtimeGeneration++;
    _taskRealtimeConnected = false;
    final channel = _realtime;
    _realtime = null;
    if (channel != null) _supabase?.removeChannel(channel).ignore();
  }

  void _watchRealtime(String companyId) {
    _stopRealtime();
    final client = _supabase;
    if (client == null || client.auth.currentUser == null) return;
    final generation = _realtimeGeneration;
    bool current() =>
        generation == _realtimeGeneration && _cacheCompany == companyId;
    void taskUpdate({bool refresh = true}) {
      if (current() && !_taskUpdates.isClosed) {
        _taskUpdates.add(TaskRealtimeUpdate(
            companyId: companyId,
            connected: _taskRealtimeConnected,
            refresh: refresh));
      }
    }

    _realtime = client
        .channel('workspace:$companyId:${client.auth.currentUser!.id}')
      ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'company_changes',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'company_id',
              value: companyId),
          callback: (change) {
            if (!current()) return;
            final sections = change.newRecord['sections'] as List? ?? [];
            if (sections.isEmpty) {
              cache.invalidateAll();
            } else {
              _invalidateMutation('/v1/companies/$companyId/sync', {
                'operations': [
                  for (final section in sections)
                    {'operationId': section, 'table': section},
                ],
              }, {
                'results': [
                  for (final section in sections)
                    {'operationId': section, 'status': 'APPLIED'},
                ],
              });
            }
            if (sections.isEmpty ||
                sections.any((s) => const [
                      'Tasks',
                      'TaskComments',
                      'TaskActivity',
                      'Employees',
                      'Projects'
                    ].contains(s))) {
              taskUpdate();
            }
          })
      ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'company_memberships',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: client.auth.currentUser!.id),
          callback: (change) {
            if (!current() || change.newRecord['company_id'] != companyId) {
              return;
            }
            _verifiedAt = DateTime.fromMillisecondsSinceEpoch(0);
            _revalidateContext().catchError((Object error) {
              if (error is SaasApiException && error.requiresSignIn) {
                onAccessRevoked?.call();
              }
            }).ignore();
          })
      ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'company_id',
              value: companyId),
          callback: (_) {
            if (current()) {
              cache.invalidate(
                  (path) => Uri.parse(path).path.endsWith('/notifications'));
            }
          })
      ..subscribe((status, error) {
        if (!current()) return;
        _taskRealtimeConnected = status == RealtimeSubscribeStatus.subscribed;
        if (_taskRealtimeConnected) cache.invalidateAll();
        taskUpdate(refresh: _taskRealtimeConnected);
      });
  }
}
