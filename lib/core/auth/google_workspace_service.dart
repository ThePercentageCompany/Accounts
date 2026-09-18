import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/billing/domain/models.dart';
import '../sync/sheet_schema.dart';
import '../sync/sync_manager.dart';

const String defaultMasterAdminEmail = String.fromEnvironment(
  'MASTER_ADMIN_EMAIL',
  defaultValue: 'thepercentagecompany1@gmail.com',
);

class WorkspaceConfig {
  final String spreadsheetId;
  final String driveFolderId;
  final String companyName;
  final String? spreadsheetUrl;
  final String? folderUrl;
  final String? employeeId;
  final String? employeeCode;
  final String? employeeName;
  final String? employeeEmail;
  final String? employeeRole;
  final List<String>? allowedSections;
  final bool isEmployee;
  final String? employeeGatewayUrl;

  const WorkspaceConfig({
    required this.spreadsheetId,
    required this.driveFolderId,
    required this.companyName,
    this.spreadsheetUrl,
    this.folderUrl,
    this.employeeId,
    this.employeeCode,
    this.employeeName,
    this.employeeEmail,
    this.employeeRole,
    this.allowedSections,
    this.isEmployee = false,
    this.employeeGatewayUrl,
  });

  Map<String, dynamic> toJson() => {
        'spreadsheetId': spreadsheetId,
        'driveFolderId': driveFolderId,
        'companyName': companyName,
        'spreadsheetUrl': spreadsheetUrl,
        'folderUrl': folderUrl,
        if (employeeId != null) 'employeeId': employeeId,
        if (employeeCode != null) 'employeeCode': employeeCode,
        if (employeeName != null) 'employeeName': employeeName,
        if (employeeEmail != null) 'employeeEmail': employeeEmail,
        if (employeeRole != null) 'employeeRole': employeeRole,
        if (allowedSections != null) 'allowedSections': allowedSections,
        'isEmployee': isEmployee,
        if (employeeGatewayUrl != null) 'employeeGatewayUrl': employeeGatewayUrl,
      };

  factory WorkspaceConfig.fromJson(Map<String, dynamic> json) => WorkspaceConfig(
        spreadsheetId: json['spreadsheetId'] as String? ?? '',
        driveFolderId: json['driveFolderId'] as String? ?? '',
        companyName: json['companyName'] as String? ?? 'The Percentage Company',
        spreadsheetUrl: json['spreadsheetUrl'] as String?,
        folderUrl: json['folderUrl'] as String?,
        employeeId: json['employeeId'] as String?,
        employeeCode: json['employeeCode'] as String?,
        employeeName: json['employeeName'] as String?,
        employeeEmail: json['employeeEmail'] as String?,
        employeeRole: json['employeeRole'] as String?,
        allowedSections: (json['allowedSections'] as List?)?.map((e) => e.toString()).toList(),
        isEmployee: json['isEmployee'] == true,
        employeeGatewayUrl: json['employeeGatewayUrl'] as String?,
      );

  WorkspaceConfig copyWith({
    String? employeeName,
    String? employeeEmail,
    String? employeeRole,
    List<String>? allowedSections,
  }) => WorkspaceConfig(
        spreadsheetId: spreadsheetId,
        driveFolderId: driveFolderId,
        companyName: companyName,
        spreadsheetUrl: spreadsheetUrl,
        folderUrl: folderUrl,
        employeeId: employeeId,
        employeeCode: employeeCode,
        employeeName: employeeName ?? this.employeeName,
        employeeEmail: employeeEmail ?? this.employeeEmail,
        employeeRole: employeeRole ?? this.employeeRole,
        allowedSections: allowedSections ?? this.allowedSections,
        isEmployee: isEmployee,
        employeeGatewayUrl: employeeGatewayUrl,
      );

  String toInvitePayload() {
    if (employeeGatewayUrl != null) {
      return jsonEncode({
        'type': 'tpc_employee_access_v2',
        'companyName': companyName,
        'employeeId': employeeId,
        'employeeGatewayUrl': employeeGatewayUrl,
      });
    }
    return jsonEncode({
      'type': 'tpc_employee_invite',
      'companyName': companyName,
      'spreadsheetId': spreadsheetId,
      'driveFolderId': driveFolderId,
      'employeeId': employeeId ?? '',
      'employeeCode': employeeCode ?? '',
      'employeeName': employeeName ?? '',
      'employeeEmail': employeeEmail ?? '',
      'employeeRole': employeeRole ?? 'Staff',
      'allowedSections': allowedSections ?? const ['Dashboard', 'Office & Attendance'],
    });
  }

  /// A public invitation identifies the employee, never their login secret.
  String toInviteLink({Uri? appBaseUri}) {
    if (employeeGatewayUrl != null) {
      final payload = toInvitePayload();
      const configuredLoginUrl = String.fromEnvironment('EMPLOYEE_LOGIN_URL');
      final current = appBaseUri ?? Uri.base;
      final base = configuredLoginUrl.isNotEmpty
          ? Uri.parse(configuredLoginUrl)
          : current.scheme == 'https' ||
                  (current.scheme == 'http' &&
                      const ['localhost', '127.0.0.1', '[::1]'].contains(current.host))
              ? current
              : Uri.parse('tpc://employee-login');
      if (base.scheme != 'https' && base.scheme != 'http' && base.scheme != 'tpc') {
        throw StateError('Set a valid employee login website URL.');
      }
      return base.replace(queryParameters: {'invite': payload}, fragment: '').toString();
    }
    final accessPayload = jsonEncode({
      'type': 'tpc_employee_access',
      'companyName': companyName,
      'spreadsheetId': spreadsheetId,
      'driveFolderId': driveFolderId,
      'employeeId': employeeId ?? '',
    });
    return 'tpc://employee-login?invite=${Uri.encodeComponent(accessPayload)}';
  }

  static WorkspaceConfig? fromInvitePayload(String raw) {
    try {
      var cleaned = raw.trim();
      if (cleaned.startsWith('TPC_INVITE:')) {
        cleaned = cleaned.substring('TPC_INVITE:'.length).trim();
      }
      // Flutter web can place its route in the fragment. Native deep links and
      // normal website links carry the invite in the outer query instead.
      if (!cleaned.startsWith('{')) {
        final uri = Uri.tryParse(cleaned);
        final route = uri?.hasFragment == true ? Uri.tryParse(uri!.fragment) : null;
        final linkInvite = uri?.queryParameters['invite'] ?? route?.queryParameters['invite'];
        if (linkInvite != null && linkInvite.isNotEmpty) cleaned = linkInvite;
      }
      if (cleaned.startsWith('TPC_INVITE:')) {
        cleaned = cleaned.substring('TPC_INVITE:'.length).trim();
      }
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic> && decoded['type'] == 'tpc_employee_access_v2') {
        final employeeId = decoded['employeeId'];
        final gateway = decoded['employeeGatewayUrl'];
        if (employeeId is! String ||
            !RegExp(r'^[a-zA-Z0-9_-]{1,160}$').hasMatch(employeeId) ||
            gateway is! String || gateway.trim().isEmpty) {
          return null;
        }
        return WorkspaceConfig(
          spreadsheetId: '', driveFolderId: '',
          companyName: decoded['companyName'] as String? ?? 'Company',
          employeeId: employeeId, employeeGatewayUrl: gateway, isEmployee: true,
        );
      }
      if (decoded is Map<String, dynamic> && decoded['spreadsheetId'] != null) {
        return WorkspaceConfig(
          spreadsheetId: decoded['spreadsheetId'] as String? ?? '',
          driveFolderId: decoded['driveFolderId'] as String? ?? '',
          companyName: decoded['companyName'] as String? ?? 'The Percentage Company',
          employeeId: decoded['employeeId'] as String?,
          employeeCode: decoded['employeeCode'] as String?,
          employeeName: decoded['employeeName'] as String?,
          employeeEmail: decoded['employeeEmail'] as String?,
          employeeRole: decoded['employeeRole'] as String? ?? 'Staff',
          allowedSections: (decoded['allowedSections'] as List?)?.map((e) => e.toString()).toList(),
          isEmployee: true,
        );
      }
    } catch (_) {}
    return null;
  }
}

class GoogleWorkspaceService {
  GoogleWorkspaceService({http.Client? client}) : _httpClient = client;

  http.Client? _httpClient;
  http.Client get _client => _httpClient ??= http.Client();
  final Set<String> _verifiedSchemas = {};

  void _requireSuccess(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var detail = '';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is Map) {
        detail = body['error']['message']?.toString() ?? '';
      }
    } catch (_) {}
    throw StateError('$action (${response.statusCode})${detail.isEmpty ? '.' : ': $detail'}');
  }

  String _tabRange(String tabName, {int startRow = 2, String? endColumn}) {
    final title = "'${tabName.replaceAll("'", "''")}'";
    return '$title!A$startRow:${endColumn ?? SheetSchema.getColLetter(SheetSchema.getHeaders(tabName).length)}';
  }

  static const _prefsKeyPrefix = 'tpc_workspace_';

  static const List<String> standardSubfolders = [
    'Invoices',
    'Quotations',
    'Payroll',
    'Assets',
    'Reports',
  ];

  static final Map<String, Map<String, String>> _subfolderCache = {};

  static Future<WorkspaceConfig?> loadSavedWorkspace(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefsKeyPrefix$email');
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return WorkspaceConfig.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveWorkspace(String email, WorkspaceConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefsKeyPrefix$email', jsonEncode(config.toJson()));
  }

  static Future<void> clearSavedWorkspace(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefsKeyPrefix$email');
  }

  /// Searches the user's Google Drive for an existing TPC Business spreadsheet.
  Future<WorkspaceConfig?> findExistingWorkspace(String accessToken) async {
    try {
      final query = Uri.encodeComponent(
        "name contains 'TPC Business' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false",
      );
      final url = Uri.parse(
        'https://www.googleapis.com/drive/v3/files?q=$query&fields=files(id,name,webViewLink,parents)&pageSize=5',
      );

      final response = await _client.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      final files = (body['files'] as List?) ?? [];
      if (files.isEmpty) return null;

      final file = Map<String, dynamic>.from(files.first as Map);
      final spreadsheetId = file['id'] as String;
      final name = file['name'] as String;
      final webViewLink = file['webViewLink'] as String?;

      // Find or locate folder
      String folderId = '';
      String? folderLink;
      try {
        final folderQuery = Uri.encodeComponent(
          "name contains 'TPC Business Documents' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        );
        final folderRes = await _client.get(
          Uri.parse('https://www.googleapis.com/drive/v3/files?q=$folderQuery&fields=files(id,name,webViewLink)&pageSize=1'),
          headers: {'Authorization': 'Bearer $accessToken'},
        ).timeout(const Duration(seconds: 10));

        if (folderRes.statusCode == 200) {
          final folderBody = Map<String, dynamic>.from(jsonDecode(folderRes.body) as Map);
          final folderFiles = (folderBody['files'] as List?) ?? [];
          if (folderFiles.isNotEmpty) {
            final f = Map<String, dynamic>.from(folderFiles.first as Map);
            folderId = f['id'] as String;
            folderLink = f['webViewLink'] as String?;
          }
        }
      } catch (_) {}

      final companyName = name.replaceFirst('TPC Business - ', '').replaceFirst('TPC Business', 'TPC Business').trim();

      return WorkspaceConfig(
        spreadsheetId: spreadsheetId,
        driveFolderId: folderId,
        companyName: companyName.isNotEmpty ? companyName : 'TPC Business',
        spreadsheetUrl: webViewLink,
        folderUrl: folderLink,
      );
    } catch (_) {
      return null;
    }
  }

  /// Provision a brand new private Google Workspace (Drive folder + Sheets + Auto Share permissions).
  Future<WorkspaceConfig> provisionWorkspace({
    required String accessToken,
    required Company company,
    required String masterEmail,
    void Function(String stepMessage)? onProgress,
  }) async {
    final companyName = company.name.trim().isNotEmpty ? company.name.trim() : 'Business';

    // STEP 1: Create Documents Folder in user's Drive
    onProgress?.call('Creating Google Drive documents folder...');
    final folderRes = await _client.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': 'TPC Business Documents - $companyName',
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    ).timeout(const Duration(seconds: 20));

    if (folderRes.statusCode != 200 && folderRes.statusCode != 201) {
      throw StateError('Failed to create Drive folder (${folderRes.statusCode}): ${folderRes.body}');
    }
    final folderData = Map<String, dynamic>.from(jsonDecode(folderRes.body) as Map);
    final folderId = folderData['id'] as String;

    // STEP 1.5: Create Standard Structured Subfolders in Drive
    onProgress?.call('Creating structured Drive folders (Invoices, Quotations, Payroll, Assets, Reports)...');
    await ensureFolderStructure(accessToken, folderId);

    // STEP 2: Create Spreadsheet with all tabs defined in SheetSchema
    onProgress?.call('Creating private Google Spreadsheet database...');
    final sheetTitles = SheetSchema.allTabs;

    final sheetRes = await _client.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'properties': {'title': 'TPC Business - $companyName'},
        'sheets': sheetTitles.map((t) => {'properties': {
          'title': t,
          'gridProperties': {'columnCount': SheetSchema.getHeaders(t).length},
        }}).toList(),
      }),
    ).timeout(const Duration(seconds: 25));

    if (sheetRes.statusCode != 200 && sheetRes.statusCode != 201) {
      throw StateError('Failed to create Spreadsheet (${sheetRes.statusCode}): ${sheetRes.body}');
    }
    final sheetData = Map<String, dynamic>.from(jsonDecode(sheetRes.body) as Map);
    final spreadsheetId = sheetData['spreadsheetId'] as String;
    final spreadsheetUrl = sheetData['spreadsheetUrl'] as String?;

    // STEP 3: Initialize Headers and initial Company Settings
    onProgress?.call('Writing initial schema & company settings...');
    final valueData = <Map<String, dynamic>>[];
    for (final title in sheetTitles) {
      final headers = SheetSchema.getHeaders(title);
      final endCol = SheetSchema.getColLetter(headers.length);
      valueData.add({
        'range': '$title!A1:${endCol}1',
        'values': [headers],
      });
    }

    // Add company profile to Settings sheet
    final companyRow = SheetSchema.recordToRow('Settings', {'id': 'company', 'value': company.toJson()});
    final settingsEndCol = SheetSchema.getColLetter(companyRow.length);
    valueData.add({
      'range': 'Settings!A2:${settingsEndCol}2',
      'values': [companyRow],
    });

    await _client.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values:batchUpdate'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'valueInputOption': 'USER_ENTERED',
        'data': valueData,
      }),
    ).timeout(const Duration(seconds: 25));

    // Seed local cache with initial company settings
    try {
      await SyncManager.instance.saveCachedRecords(spreadsheetId, 'Settings', [
        {'id': 'company', 'value': company.toJson()}
      ]);
    } catch (_) {}

    // STEP 3.5: Migrate and sync all existing offline/local data to the new cloud spreadsheet
    onProgress?.call('Migrating and synchronizing offline local data to Google Sheets...');
    try {
      await SyncManager.instance.migrateAndSyncLocalDataToCloud(
        spreadsheetId: spreadsheetId,
        token: accessToken,
      );
    } catch (_) {}

    // STEP 4: Share View Access with Master Admin Account
    if (masterEmail.isNotEmpty && masterEmail.contains('@')) {
      onProgress?.call('Sharing view-only access with master admin ($masterEmail)...');
      try {
        // Share Spreadsheet
        await _client.post(
          Uri.parse('https://www.googleapis.com/drive/v3/files/$spreadsheetId/permissions?sendNotificationEmail=false'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'role': 'reader',
            'type': 'user',
            'emailAddress': masterEmail.trim(),
          }),
        ).timeout(const Duration(seconds: 15));

        // Share Documents Folder
        await _client.post(
          Uri.parse('https://www.googleapis.com/drive/v3/files/$folderId/permissions?sendNotificationEmail=false'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'role': 'reader',
            'type': 'user',
            'emailAddress': masterEmail.trim(),
          }),
        ).timeout(const Duration(seconds: 15));
      } catch (e) {
        // Non-fatal if domain restrictions block sharing outside workspace
      }
    }

    return WorkspaceConfig(
      spreadsheetId: spreadsheetId,
      driveFolderId: folderId,
      companyName: companyName,
      spreadsheetUrl: spreadsheetUrl,
      folderUrl: 'https://drive.google.com/drive/folders/$folderId',
    );
  }

  /// Creates missing tabs and adds new trailing headers without relabelling
  /// existing columns or converting a failed read into an empty sheet.
  Future<void> ensureAllTabsExist(String accessToken, String spreadsheetId) async {
    final auth = {'Authorization': 'Bearer $accessToken'};
    final res = await _client.get(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId?fields=sheets.properties'),
      headers: auth,
    ).timeout(const Duration(seconds: 15));
    _requireSuccess(res, 'Could not inspect Google Sheets');
    final body = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    final existing = ((body['sheets'] as List?) ?? [])
        .whereType<Map>()
        .map((sheet) => (sheet['properties'] as Map?)?['title'])
        .whereType<String>().toSet();
    final missing = SheetSchema.allTabs.where((tab) => !existing.contains(tab)).toList();
    final present = SheetSchema.allTabs.where(existing.contains).toList();
    final needsHeaders = <String>[...missing];
    final resizeRequests = <Map<String, dynamic>>[];
    for (final sheet in ((body['sheets'] as List?) ?? []).whereType<Map>()) {
      final properties = sheet['properties'] as Map? ?? {};
      final title = properties['title'];
      final columns = (properties['gridProperties'] as Map?)?['columnCount'];
      if (title is String && SheetSchema.allTabs.contains(title) &&
          columns is num && columns < SheetSchema.getHeaders(title).length) {
        resizeRequests.add({'updateSheetProperties': {
          'properties': {'sheetId': properties['sheetId'],
            'gridProperties': {'columnCount': SheetSchema.getHeaders(title).length}},
          'fields': 'gridProperties.columnCount',
        }});
      }
    }

    if (present.isNotEmpty) {
      final ranges = present.map((tab) =>
          'ranges=${Uri.encodeComponent("'${tab.replaceAll("'", "''")}'!1:1")}').join('&');
      final headersRes = await _client.get(
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values:batchGet?$ranges'),
        headers: auth,
      ).timeout(const Duration(seconds: 15));
      _requireSuccess(headersRes, 'Could not read spreadsheet headers');
      final headerBody = jsonDecode(headersRes.body) as Map;
      final valueRanges = headerBody['valueRanges'] as List?;
      if (valueRanges == null || valueRanges.length != present.length) {
        throw StateError('Google Sheets returned incomplete headers. Please retry syncing.');
      }
      for (var i = 0; i < present.length; i++) {
        final values = (valueRanges[i] as Map)['values'] as List? ?? [];
        final actual = values.isEmpty ? <dynamic>[] : values.first as List;
        final expected = SheetSchema.getHeaders(present[i]);
        for (var c = 0; c < actual.length && c < expected.length; c++) {
          if (actual[c].toString() != expected[c]) {
            throw StateError('The ${present[i]} columns do not match the app schema. Restore their original order before syncing.');
          }
        }
        if (actual.length < expected.length) needsHeaders.add(present[i]);
      }
    }
    if (missing.isNotEmpty || resizeRequests.isNotEmpty) {
      final added = await _client.post(
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId:batchUpdate'),
        headers: {...auth, 'Content-Type': 'application/json'},
        body: jsonEncode({'requests': [
          for (final tab in missing) {'addSheet': {'properties': {
            'title': tab, 'gridProperties': {'columnCount': SheetSchema.getHeaders(tab).length},
          }}},
          ...resizeRequests,
        ]}),
      ).timeout(const Duration(seconds: 20));
      _requireSuccess(added, 'Could not create missing spreadsheet tabs');
    }
    if (needsHeaders.isNotEmpty) {
      final updated = await _client.post(
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values:batchUpdate'),
        headers: {...auth, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'valueInputOption': 'RAW',
          'data': [
            for (final tab in needsHeaders) {
              'range': '${_tabRange(tab, startRow: 1)}1',
              'values': [SheetSchema.getHeaders(tab)],
            },
          ],
        }),
      ).timeout(const Duration(seconds: 20));
      _requireSuccess(updated, 'Could not initialize spreadsheet headers');
    }
    _verifiedSchemas.add(spreadsheetId);
  }

  Future<void> ensureTabExists(String accessToken, String spreadsheetId, String tabName) async {
    if (!SheetSchema.allTabs.contains(tabName)) throw StateError('Unknown spreadsheet tab: $tabName');
    await ensureAllTabsExist(accessToken, spreadsheetId);
  }

  Future<Map<String, List<Map<String, dynamic>>>> readAllTabsBatch(
    String accessToken, String spreadsheetId, List<String> tabNames,
  ) async {
    if (tabNames.isEmpty) return {};
    await ensureAllTabsExist(accessToken, spreadsheetId);
    final ranges = tabNames.map((tab) => 'ranges=${Uri.encodeComponent(_tabRange(tab))}').join('&');
    final res = await _client.get(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values:batchGet?$ranges'),
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 20));
    _requireSuccess(res, 'Could not read Google Sheets');
    final body = jsonDecode(res.body) as Map;
    final valueRanges = body['valueRanges'] as List?;
    if (valueRanges == null || valueRanges.length != tabNames.length) {
      throw StateError('Google Sheets returned an incomplete snapshot. Please retry syncing.');
    }
    return {
      for (var i = 0; i < tabNames.length; i++)
        tabNames[i]: _decodeRows(tabNames[i], valueRanges[i] as Map),
    };
  }

  List<Map<String, dynamic>> _decodeRows(String tabName, Map response) {
    final values = response['values'] as List? ?? [];
    return [
      for (final row in values.whereType<List>())
        if (row.isNotEmpty && row.first.toString().isNotEmpty)
          SheetSchema.rowToRecord(tabName, row),
    ].where((row) => row.isNotEmpty).toList();
  }

  Future<http.Response> _readRange(
    String accessToken, String spreadsheetId, String sheetName, String range,
  ) async {
    final url = Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/${Uri.encodeComponent(range)}');
    final headers = {'Authorization': 'Bearer $accessToken'};
    var response = await _client.get(url, headers: headers).timeout(const Duration(seconds: 15));
    if (response.statusCode == 400) {
      await ensureTabExists(accessToken, spreadsheetId, sheetName);
      response = await _client.get(url, headers: headers).timeout(const Duration(seconds: 15));
    }
    _requireSuccess(response, 'Could not read $sheetName');
    return response;
  }

  Future<List<Map<String, dynamic>>> readTabRecords(
    String accessToken, String spreadsheetId, String sheetName,
  ) async {
    final res = await _readRange(accessToken, spreadsheetId, sheetName, _tabRange(sheetName));
    return _decodeRows(sheetName, jsonDecode(res.body) as Map);
  }

  Future<void> upsertTabRecord(
    String accessToken, String spreadsheetId, String sheetName,
    String id, Map<String, dynamic> record,
  ) async {
    final res = await _readRange(accessToken, spreadsheetId, sheetName, _tabRange(sheetName, endColumn: 'A'));
    if (!_verifiedSchemas.contains(spreadsheetId)) {
      await ensureAllTabsExist(accessToken, spreadsheetId);
    }
    final values = (jsonDecode(res.body) as Map)['values'] as List? ?? [];
    final index = values.indexWhere((row) => row is List && row.isNotEmpty && row[0].toString() == id);
    final rowValues = SheetSchema.recordToRow(sheetName, record);
    final title = "'${sheetName.replaceAll("'", "''")}'";
    final endCol = SheetSchema.getColLetter(rowValues.length);
    final headers = {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'};
    final body = jsonEncode({'values': [rowValues]});
    late http.Response written;
    if (index < 0) {
      // Sheets allocates the new row atomically so concurrent inserts cannot
      // both overwrite the same last row.
      written = await _client.post(
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/${Uri.encodeComponent('$title!A:$endCol')}:append?valueInputOption=RAW&insertDataOption=INSERT_ROWS'),
        headers: headers, body: body,
      ).timeout(const Duration(seconds: 20));
    } else {
      final row = index + 2;
      written = await _client.put(
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/${Uri.encodeComponent('$title!A$row:$endCol$row')}?valueInputOption=RAW'),
        headers: headers, body: body,
      ).timeout(const Duration(seconds: 20));
    }
    _requireSuccess(written, 'Could not save $sheetName');
  }

  /// Deletes just the matching row; never clears and rewrites unrelated data.
  Future<void> deleteTabRecord(
    String accessToken, String spreadsheetId, String sheetName, String id,
  ) async {
    final res = await _readRange(accessToken, spreadsheetId, sheetName, _tabRange(sheetName, endColumn: 'A'));
    final values = (jsonDecode(res.body) as Map)['values'] as List? ?? [];
    final index = values.indexWhere((row) => row is List && row.isNotEmpty && row[0].toString() == id);
    if (index < 0) return;
    final metadata = await _client.get(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId?fields=sheets.properties'),
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 15));
    _requireSuccess(metadata, 'Could not locate $sheetName');
    final sheets = (jsonDecode(metadata.body) as Map)['sheets'] as List? ?? [];
    final properties = sheets.whereType<Map>().map((sheet) => sheet['properties']).whereType<Map>()
        .where((props) => props['title'] == sheetName).firstOrNull;
    if (properties == null || properties['sheetId'] is! num) {
      throw StateError('The $sheetName tab could not be located. Please retry.');
    }
    final deleted = await _client.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId:batchUpdate'),
      headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
      body: jsonEncode({'requests': [{'deleteDimension': {'range': {
        'sheetId': properties['sheetId'], 'dimension': 'ROWS',
        'startIndex': index + 1, 'endIndex': index + 2,
      }}}]}),
    ).timeout(const Duration(seconds: 20));
    _requireSuccess(deleted, 'Could not delete the $sheetName record');
  }

  /// Ensures the standard Drive folders exist; permission failures remain visible.
  Future<Map<String, String>> ensureFolderStructure(String accessToken, String rootFolderId) async {
    if (rootFolderId.isEmpty) throw StateError('Connect a company Drive folder before uploading.');
    final cached = _subfolderCache[rootFolderId];
    if (cached != null && standardSubfolders.every(cached.containsKey)) return cached;
    final folders = Map<String, String>.from(cached ?? {});
    final query = Uri.encodeComponent(
      "'${rootFolderId.replaceAll("'", "\\'")}' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
    );
    final response = await _client.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files?q=$query&fields=files(id,name)&pageSize=1000'),
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 15));
    _requireSuccess(response, 'Could not access the company Drive folder');
    final files = (jsonDecode(response.body) as Map)['files'] as List? ?? [];
    for (final file in files.whereType<Map>()) {
      if (file['name'] is String && file['id'] is String) {
        folders[file['name'] as String] = file['id'] as String;
      }
    }
    for (final name in standardSubfolders) {
      folders[name] ??= await _createDriveFolder(accessToken, rootFolderId, name);
    }
    _subfolderCache[rootFolderId] = folders;
    return folders;
  }

  Future<String> _createDriveFolder(String accessToken, String parent, String name) async {
    final response = await _client.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files'),
      headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'mimeType': 'application/vnd.google-apps.folder', 'parents': [parent]}),
    ).timeout(const Duration(seconds: 15));
    _requireSuccess(response, 'Could not create the $name Drive folder');
    final id = (jsonDecode(response.body) as Map)['id']?.toString() ?? '';
    if (id.isEmpty) throw StateError('Google Drive did not return a folder identifier.');
    return id;
  }

  Future<String> getSubfolderId(String accessToken, String rootFolderId, String subfolderName) async {
    final folders = await ensureFolderStructure(accessToken, rootFolderId);
    final existing = folders[subfolderName];
    if (existing != null && existing.isNotEmpty) return existing;
    final created = await _createDriveFolder(accessToken, rootFolderId, subfolderName);
    folders[subfolderName] = created;
    return created;
  }

  /// Automatically detects the appropriate subfolder based on file name, MIME type, or category.
  static String detectSubfolder({String? fileName, String? mimeType, String? category}) {
    if (category != null && standardSubfolders.contains(category)) {
      return category;
    }

    final lowerName = (fileName ?? '').toLowerCase();
    final lowerMime = (mimeType ?? '').toLowerCase();

    // 1. Invoices & Receipts
    if (lowerName.startsWith('inv-') ||
        lowerName.contains('invoice') ||
        lowerName.contains('receipt') ||
        lowerName.contains('tax_invoice') ||
        lowerName.contains('bill_payment')) {
      return 'Invoices';
    }

    // 2. Quotations
    if (lowerName.startsWith('qt-') ||
        lowerName.startsWith('qtn-') ||
        lowerName.contains('quotation') ||
        lowerName.contains('quote') ||
        lowerName.contains('estimate') ||
        lowerName.contains('proposal')) {
      return 'Quotations';
    }

    // 3. Payroll & Attendance & HR
    if (lowerName.contains('payslip') ||
        lowerName.contains('payroll') ||
        lowerName.contains('salary') ||
        lowerName.contains('attendance') ||
        lowerName.contains('wps') ||
        lowerName.contains('employee') ||
        lowerName.contains('timesheet')) {
      return 'Payroll';
    }

    // 4. Financial & Audit Reports
    if (lowerName.contains('finance-') ||
        lowerName.contains('report') ||
        lowerName.contains('pnl') ||
        lowerName.contains('profit_loss') ||
        lowerName.contains('balance_sheet') ||
        lowerName.contains('vat_return') ||
        lowerName.contains('statement') ||
        lowerName.contains('audit') ||
        lowerName.contains('trial_balance')) {
      return 'Reports';
    }

    // 5. Assets, Logos & Branding
    if (lowerMime.startsWith('image/') ||
        lowerName.contains('logo') ||
        lowerName.contains('asset') ||
        lowerName.contains('brand') ||
        lowerName.contains('shareholder') ||
        lowerName.contains('agreement') ||
        lowerName.contains('contract') ||
        lowerName.contains('passport') ||
        lowerName.contains('emirates_id') ||
        lowerName.contains('visa')) {
      return 'Assets';
    }

    return 'Assets';
  }

  /// Uploads any file or document directly into the structured Google Drive folder hierarchy.
  Future<String> uploadDriveFile(
    String accessToken,
    String rootFolderId,
    String fileName,
    Uint8List bytes, {
    String mimeType = 'application/octet-stream',
    String? subfolder,
  }) async {
      if (rootFolderId.isEmpty || bytes.isEmpty || fileName.trim().isEmpty) {
        throw StateError('Choose a file and connect the company Drive folder before uploading.');
      }
      final targetSubfolder = subfolder ?? detectSubfolder(fileName: fileName, mimeType: mimeType);
      final targetFolderId = await getSubfolderId(accessToken, rootFolderId, targetSubfolder);
      final folderId = targetFolderId.isNotEmpty ? targetFolderId : rootFolderId;

      const boundary = 'tpc_drive_boundary_xyz';
      final metadata = jsonEncode({
        'name': fileName,
        'parents': folderId.isNotEmpty ? [folderId] : [],
        'mimeType': mimeType,
      });

      final body = <int>[];
      body.addAll(utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n'));
      body.addAll(utf8.encode('--$boundary\r\nContent-Type: $mimeType\r\n\r\n'));
      body.addAll(bytes);
      body.addAll(utf8.encode('\r\n--$boundary--\r\n'));

      final uploadRes = await _client.post(
        Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: Uint8List.fromList(body),
      ).timeout(const Duration(seconds: 40));

      _requireSuccess(uploadRes, 'Google Drive upload failed');
      final data = Map<String, dynamic>.from(jsonDecode(uploadRes.body) as Map);
      final id = data['id']?.toString() ?? '';
      if (id.isEmpty) {
        throw StateError('Google Drive did not confirm the uploaded file. Please retry.');
      }
      return data['webViewLink'] as String? ?? 'https://drive.google.com/file/d/$id/view';
  }

  /// Uploads a PDF to the user's structured Drive folder and returns its web link.
  Future<String> uploadPdfFile(
    String accessToken,
    String folderId,
    String fileName,
    Uint8List bytes, {
    String? subfolder,
  }) async {
    return uploadDriveFile(
      accessToken,
      folderId,
      fileName,
      bytes,
      mimeType: 'application/pdf',
      subfolder: subfolder ?? detectSubfolder(fileName: fileName, mimeType: 'application/pdf'),
    );
  }

  /// Uploads an image (PNG/JPG) asset to the user's structured Assets Drive folder.
  Future<String> uploadImageFile(
    String accessToken,
    String folderId,
    String fileName,
    Uint8List bytes, {
    String mimeType = 'image/png',
    String? subfolder = 'Assets',
  }) async {
    return uploadDriveFile(
      accessToken,
      folderId,
      fileName,
      bytes,
      mimeType: mimeType,
      subfolder: subfolder ?? 'Assets',
    );
  }

  static String? driveFileId(String driveUrl) {
    final uri = Uri.tryParse(driveUrl);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty ||
        !const ['drive.google.com', 'docs.google.com'].contains(uri.host)) {
      return null;
    }
    final match = RegExp(r'/d/([a-zA-Z0-9_-]+)(?:/|$)').firstMatch(uri.path);
    final id = match?.group(1) ?? uri.queryParameters['id'];
    return id != null && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) ? id : null;
  }

  /// Fetches private Drive bytes with the signed-in user's token. View links
  /// return HTML, so they cannot be used directly as profile image URLs.
  Future<Map<String, dynamic>> downloadDriveFile(String accessToken, String driveUrl) async {
    final fileId = driveFileId(driveUrl);
    if (fileId == null) throw StateError('The saved Google Drive file link is invalid.');
    final response = await _client.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 30));
    _requireSuccess(response, 'Could not load the Google Drive file');
    if (response.bodyBytes.isEmpty || response.bodyBytes.length > 5 * 1024 * 1024) {
      throw StateError('The Google Drive file is empty or exceeds 5 MB.');
    }
    return {
      'base64': base64Encode(response.bodyBytes),
      'mimeType': (response.headers['content-type'] ?? 'application/octet-stream').split(';').first,
    };
  }

  /// Deletes a Drive file identified by one of Drive's standard view links.
  /// Returns false for an unrecognised URL so callers never delete a file
  /// outside the company's managed Drive workspace by accident.
  Future<bool> deleteDriveFile(String accessToken, String driveUrl) async {
    final fileId = driveFileId(driveUrl);
    if (fileId == null || fileId.isEmpty) return false;
    try {
      final response = await _client.delete(
        Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 20));
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
