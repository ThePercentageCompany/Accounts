import 'dart:convert';

import 'package:http/http.dart' as http;

/// The gateway is configured by the app owner, never trusted from a scanned QR.
const configuredEmployeeGatewayUrl = String.fromEnvironment('EMPLOYEE_GATEWAY_URL');

class EmployeeGatewayException implements Exception {
  final String message;
  final String code;
  const EmployeeGatewayException(this.message, [this.code = 'NETWORK']);
  bool get sessionExpired => code == 'UNAUTHORIZED';
  @override
  String toString() => message;
}

class EmployeeGateway {
  final String endpoint;
  final http.Client _client;

  EmployeeGateway({String? endpoint, http.Client? client})
      : endpoint = endpoint ?? configuredEmployeeGatewayUrl,
        _client = client ?? http.Client();

  bool get isConfigured {
    final uri = Uri.tryParse(endpoint);
    return uri != null && uri.scheme == 'https' && uri.host == 'script.google.com' &&
        uri.path.startsWith('/macros/s/') && uri.path.endsWith('/exec') &&
        !uri.hasQuery && !uri.hasFragment && uri.userInfo.isEmpty;
  }

  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> data = const {},
    String? sessionToken,
    String? ownerAccessToken,
  }) async {
    if (!isConfigured) {
      throw const EmployeeGatewayException(
        'Employee login is not configured. Ask the owner to set up the employee gateway.',
        'CONFIGURATION',
      );
    }
    // text/plain is a CORS simple request for the Apps Script ContentService.
    // Google bearer credentials stay in the POST body; they never enter a URL.
    var response = await _client.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'text/plain;charset=utf-8'},
      body: jsonEncode({
        'action': action,
        'data': data,
        if (sessionToken != null) 'sessionToken': sessionToken,
        if (ownerAccessToken != null) 'ownerAccessToken': ownerAccessToken,
      }),
    ).timeout(const Duration(seconds: 60));

    // Native HTTP clients do not follow POST 302 responses automatically.
    // Read the generated response only from Google's ContentService host.
    if (response.statusCode == 302 || response.statusCode == 303) {
      final location = Uri.tryParse(response.headers['location'] ?? '');
      if (location == null || location.scheme != 'https' ||
          location.host != 'script.googleusercontent.com') {
        throw const EmployeeGatewayException('Employee gateway deployment is not accessible.', 'CONFIGURATION');
      }
      response = await _client.get(location).timeout(const Duration(seconds: 60));
    }
    if (response.statusCode != 200) {
      throw EmployeeGatewayException('Could not connect to the employee service (${response.statusCode}).');
    }
    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw const EmployeeGatewayException('Employee gateway returned an invalid response. Check its deployment settings.', 'CONFIGURATION');
    }
    if (body['ok'] != true) {
      throw EmployeeGatewayException(
        body['error']?.toString() ?? 'Employee request failed.',
        body['code']?.toString() ?? 'INVALID_REQUEST',
      );
    }
    return Map<String, dynamic>.from(body['result'] as Map? ?? const {});
  }
}
