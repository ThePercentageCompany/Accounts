import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/billing/domain/models.dart';

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

  const WorkspaceConfig({
    required this.spreadsheetId,
    required this.driveFolderId,
    required this.companyName,
    this.spreadsheetUrl,
    this.folderUrl,
  });

  Map<String, dynamic> toJson() => {
        'spreadsheetId': spreadsheetId,
        'driveFolderId': driveFolderId,
        'companyName': companyName,
        'spreadsheetUrl': spreadsheetUrl,
        'folderUrl': folderUrl,
      };

  factory WorkspaceConfig.fromJson(Map<String, dynamic> json) => WorkspaceConfig(
        spreadsheetId: json['spreadsheetId'] as String,
        driveFolderId: json['driveFolderId'] as String,
        companyName: json['companyName'] as String,
        spreadsheetUrl: json['spreadsheetUrl'] as String?,
        folderUrl: json['folderUrl'] as String?,
      );
}

class GoogleWorkspaceService {
  static const _prefsKeyPrefix = 'tpc_workspace_';

  static Future<WorkspaceConfig?> loadSavedWorkspace(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefsKeyPrefix$email');
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
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

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final files = (body['files'] as List?) ?? [];
      if (files.isEmpty) return null;

      final file = files.first as Map<String, dynamic>;
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
        final folderRes = await http.get(
          Uri.parse('https://www.googleapis.com/drive/v3/files?q=$folderQuery&fields=files(id,name,webViewLink)&pageSize=1'),
          headers: {'Authorization': 'Bearer $accessToken'},
        ).timeout(const Duration(seconds: 10));

        if (folderRes.statusCode == 200) {
          final folderBody = jsonDecode(folderRes.body) as Map<String, dynamic>;
          final folderFiles = (folderBody['files'] as List?) ?? [];
          if (folderFiles.isNotEmpty) {
            final f = folderFiles.first as Map<String, dynamic>;
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
    final folderRes = await http.post(
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
    final folderData = jsonDecode(folderRes.body) as Map<String, dynamic>;
    final folderId = folderData['id'] as String;

    // STEP 2: Create Spreadsheet with all 10 tabs
    onProgress?.call('Creating private Google Spreadsheet database...');
    final sheetTitles = [
      'Customers',
      'Invoices',
      'Settings',
      'Employees',
      'Attendance',
      'Payroll',
      'Finance',
      'Quotations',
      'Invoice Register',
      'Payment Register',
    ];

    final sheetRes = await http.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'properties': {'title': 'TPC Business - $companyName'},
        'sheets': sheetTitles.map((t) => {'properties': {'title': t}}).toList(),
      }),
    ).timeout(const Duration(seconds: 25));

    if (sheetRes.statusCode != 200 && sheetRes.statusCode != 201) {
      throw StateError('Failed to create Spreadsheet (${sheetRes.statusCode}): ${sheetRes.body}');
    }
    final sheetData = jsonDecode(sheetRes.body) as Map<String, dynamic>;
    final spreadsheetId = sheetData['spreadsheetId'] as String;
    final spreadsheetUrl = sheetData['spreadsheetUrl'] as String?;

    // STEP 3: Initialize Headers and initial Company Settings
    onProgress?.call('Writing initial schema & company settings...');
    final valueData = <Map<String, dynamic>>[];
    for (final title in sheetTitles) {
      if (title == 'Invoice Register') {
        valueData.add({
          'range': '$title!A1:I1',
          'values': [
            ['ID', 'Number', 'Date', 'Customer', 'Status', 'Total AED', 'Paid AED', 'Balance AED', 'PDF Link']
          ],
        });
      } else if (title == 'Payment Register') {
        valueData.add({
          'range': '$title!A1:E1',
          'values': [
            ['Payment ID', 'Invoice #', 'Date', 'Amount AED', 'Reference']
          ],
        });
      } else {
        valueData.add({
          'range': '$title!A1:B1',
          'values': [
            ['ID', 'JSON']
          ],
        });
      }
    }

    // Add company profile to Settings sheet
    valueData.add({
      'range': 'Settings!A2:B2',
      'values': [
        ['company', jsonEncode({'id': 'company', 'value': company.toJson()})]
      ],
    });

    await http.post(
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

    // STEP 4: Share View Access with Master Admin Account
    if (masterEmail.isNotEmpty && masterEmail.contains('@')) {
      onProgress?.call('Sharing view-only access with master admin ($masterEmail)...');
      try {
        // Share Spreadsheet
        await http.post(
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
        await http.post(
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

  // --- CRUD HELPERS FOR SPREADSHEETS ---

  /// Reads all JSON records from a sheet tab.
  Future<List<Map<String, dynamic>>> readTabRecords(String accessToken, String spreadsheetId, String sheetName) async {
    try {
      final url = Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$sheetName!A2:B');
      final res = await http.get(url, headers: {'Authorization': 'Bearer $accessToken'}).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final values = (body['values'] as List?) ?? [];

      final list = <Map<String, dynamic>>[];
      for (final row in values) {
        if (row is List && row.length >= 2) {
          try {
            final jsonStr = row[1].toString();
            final parsed = jsonDecode(jsonStr);
            if (parsed is Map) {
              list.add(Map<String, dynamic>.from(parsed));
            }
          } catch (_) {}
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Inserts or updates a JSON record by ID in a sheet tab.
  Future<void> upsertTabRecord(String accessToken, String spreadsheetId, String sheetName, String id, Map<String, dynamic> record) async {
    // Read existing IDs
    final getUrl = Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$sheetName!A2:A');
    final res = await http.get(getUrl, headers: {'Authorization': 'Bearer $accessToken'}).timeout(const Duration(seconds: 15));

    int targetRow = 2;
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final values = (body['values'] as List?) ?? [];
      final index = values.indexWhere((r) => r is List && r.isNotEmpty && r[0].toString() == id);
      if (index >= 0) {
        targetRow = index + 2;
      } else {
        targetRow = values.length + 2;
      }
    }

    final putUrl = Uri.parse(
      'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$sheetName!A$targetRow:B$targetRow?valueInputOption=USER_ENTERED',
    );

    final jsonPayload = jsonEncode(record);
    await http.put(
      putUrl,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'values': [
          [id, jsonPayload]
        ]
      }),
    ).timeout(const Duration(seconds: 20));
  }

  /// Deletes a record from a sheet tab by ID.
  Future<void> deleteTabRecord(String accessToken, String spreadsheetId, String sheetName, String id) async {
    // Read all records, filter out the ID, and rewrite
    final existing = await readTabRecords(accessToken, spreadsheetId, sheetName);
    final updated = existing.where((x) => x['id']?.toString() != id).toList();

    // Clear range
    await http.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$sheetName!A2:B:clear'),
      headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));

    if (updated.isNotEmpty) {
      final rows = updated.map((r) => [r['id']?.toString() ?? '', jsonEncode(r)]).toList();
      await http.put(
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$sheetName!A2:B${rows.length + 1}?valueInputOption=USER_ENTERED'),
        headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
        body: jsonEncode({'values': rows}),
      ).timeout(const Duration(seconds: 20));
    }
  }

  /// Uploads a PDF to the user's Drive folder and returns its web link.
  Future<String> uploadPdfFile(String accessToken, String folderId, String fileName, Uint8List bytes) async {
    try {
      const boundary = 'tpc_drive_boundary_xyz';
      final metadata = jsonEncode({
        'name': fileName,
        'parents': folderId.isNotEmpty ? [folderId] : [],
        'mimeType': 'application/pdf',
      });

      final body = <int>[];
      body.addAll(utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n'));
      body.addAll(utf8.encode('--$boundary\r\nContent-Type: application/pdf\r\n\r\n'));
      body.addAll(bytes);
      body.addAll(utf8.encode('\r\n--$boundary--\r\n'));

      final uploadRes = await http.post(
        Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: Uint8List.fromList(body),
      ).timeout(const Duration(seconds: 35));

      if (uploadRes.statusCode == 200 || uploadRes.statusCode == 201) {
        final data = jsonDecode(uploadRes.body) as Map<String, dynamic>;
        return data['webViewLink'] as String? ?? 'https://drive.google.com/file/d/${data['id']}/view';
      }
    } catch (_) {}
    return '';
  }
}
