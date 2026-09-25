import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_transport_stub.dart'
    if (dart.library.js_interop) 'api_transport_web.dart';

const configuredSaasApiOrigin = String.fromEnvironment('SAAS_API_ORIGIN');

class SaasApiException implements Exception {
  const SaasApiException(this.code, this.message, {this.status = 0});
  final String code;
  final String message;
  final int status;
  bool get requiresSignIn => status == 401;
  @override
  String toString() => message;
}

/// Trusted operator origin only. QR codes identify invitations, never servers.
/// Authentication lives in secure HttpOnly cookies, not local preferences.
class SaasApi {
  SaasApi({String origin = configuredSaasApiOrigin, http.Client? client})
    : origin = _origin(origin),
      _client = client ?? createSaasTransport();

  final Uri origin;
  final http.Client _client;

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
    final request = http.Request(method, origin.resolve(path))
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
    late http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const SaasApiException(
        'NETWORK',
        'Connection timed out. Keep this change pending and retry.',
      );
    } on http.ClientException {
      throw const SaasApiException(
        'NETWORK',
        'Cannot reach the company service. Your pending changes must be retained.',
      );
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
      throw SaasApiException(code, message, status: response.statusCode);
    }
    return response;
  }

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, Object?>? data,
    String? operationId,
  }) async {
    final response = await _send(
      method,
      path,
      data: data,
      operationId: operationId,
    );
    if (response.statusCode == 204) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw const SaasApiException(
        'INVALID_RESPONSE',
        'The company service returned an invalid response.',
      );
    }
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

  Future<Uri> startSignIn() => _authorization('/v1/auth/google/start');
  Future<Map<String, dynamic>> me() => _json('GET', '/v1/me');
  Future<Map<String, dynamic>> companies() => _json('GET', '/v1/companies');
  Future<Map<String, dynamic>> createCompany(String name, String operationId) =>
      _json(
        'POST',
        '/v1/companies',
        data: {'name': name},
        operationId: operationId,
      );
  Future<Uri> connectGoogle(String companyId) =>
      _authorization('/v1/companies/${_id(companyId)}/google/connect');
  Future<Map<String, dynamic>> setup(String companyId) =>
      _json('GET', '/v1/companies/${_id(companyId)}/setup');
  Future<Map<String, dynamic>> retrySetup(String companyId) =>
      _json('POST', '/v1/companies/${_id(companyId)}/setup/retry');
  Future<Map<String, dynamic>> logout() => _json('POST', '/v1/auth/logout');
  Future<Map<String, dynamic>> employeeLogin(
    String inviteId,
    String privateCode,
  ) => _json(
    'POST',
    '/v1/employee/login',
    data: {'inviteId': _id(inviteId), 'privateCode': privateCode},
  );
  Future<Map<String, dynamic>> employeeMe() => _json('GET', '/v1/employee/me');
  Future<Map<String, dynamic>> employeeLogout() =>
      _json('POST', '/v1/employee/logout');
  Future<Map<String, dynamic>> employees(String companyId) =>
      _json('GET', '/v1/companies/${_id(companyId)}/employees');
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
  }) {
    if (!RegExp(r'^[A-Za-z]+$').hasMatch(table)) {
      throw const SaasApiException('INVALID_TABLE', 'Invalid record section.');
    }
    return _json(
      'GET',
      employee
          ? '/v1/employee/records/$table'
          : '/v1/companies/${_id(companyId)}/records/$table',
    );
  }

  Future<Map<String, dynamic>> sync(
    String companyId,
    List<Map<String, Object?>> operations,
  ) => _json(
    'POST',
    '/v1/companies/${_id(companyId)}/sync',
    data: {'operations': operations},
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

  void close() => _client.close();
}
