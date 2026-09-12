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

    // STEP 1.5: Create Standard Structured Subfolders in Drive
    onProgress?.call('Creating structured Drive folders (Invoices, Quotations, Payroll, Assets, Reports)...');
    await ensureFolderStructure(accessToken, folderId);

    // STEP 2: Create Spreadsheet with all tabs defined in SheetSchema
    onProgress?.call('Creating private Google Spreadsheet database...');
    final sheetTitles = SheetSchema.allTabs;

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

    // Seed local cache with initial company settings
    try {
      await SyncManager.instance.saveCachedRecords(spreadsheetId, 'Settings', [
        {'id': 'company', 'value': company.toJson()}
      ]);
    } catch (_) {}

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

  /// Ensures all required tabs from SheetSchema exist in the spreadsheet.
  /// Automatically creates any missing tabs and sets up their column headers.
  Future<void> ensureAllTabsExist(String accessToken, String spreadsheetId) async {
    try {
      final res = await http.get(
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId?fields=sheets.properties.title'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final sheets = (body['sheets'] as List?) ?? [];
      final existingTitles = sheets
          .map((s) => (s['properties'] as Map<String, dynamic>?)?['title'] as String?)
          .whereType<String>()
          .toSet();

      final requiredTabs = SheetSchema.allTabs;
      final missingTabs = requiredTabs.where((t) => !existingTitles.contains(t)).toList();

      if (missingTabs.isEmpty) return;

      // 1. Add missing sheets via batchUpdate
      final addSheetRequests = missingTabs
          .map((title) => {
                'addSheet': {
                  'properties': {'title': title},
                }
              })
          .toList();

      final addRes = await http.post(
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId:batchUpdate'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'requests': addSheetRequests}),
      ).timeout(const Duration(seconds: 20));

      if (addRes.statusCode != 200 && addRes.statusCode != 201) return;

      // 2. Initialize headers for newly added sheets
      final headerData = <Map<String, dynamic>>[];
      for (final tab in missingTabs) {
        final headers = SheetSchema.getHeaders(tab);
        final endCol = SheetSchema.getColLetter(headers.length);
        headerData.add({
          'range': '$tab!A1:${endCol}1',
          'values': [headers],
        });
      }

      if (headerData.isNotEmpty) {
        await http.post(
          Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values:batchUpdate'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'valueInputOption': 'USER_ENTERED',
            'data': headerData,
          }),
        ).timeout(const Duration(seconds: 20));
      }
    } catch (_) {}
  }

  /// Ensures a single tab exists with appropriate headers.
  Future<void> ensureTabExists(String accessToken, String spreadsheetId, String tabName) async {
    try {
      final addRes = await http.post(
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId:batchUpdate'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'requests': [
            {
              'addSheet': {
                'properties': {'title': tabName},
              }
            }
          ]
        }),
      ).timeout(const Duration(seconds: 15));

      if (addRes.statusCode == 200 || addRes.statusCode == 201) {
        final headers = SheetSchema.getHeaders(tabName);
        final endCol = SheetSchema.getColLetter(headers.length);
        await http.put(
          Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$tabName!A1:${endCol}1?valueInputOption=USER_ENTERED'),
          headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'values': [headers]
          }),
        ).timeout(const Duration(seconds: 15));
      }
    } catch (_) {}
  }

  /// Reads all records from multiple sheet tabs in a SINGLE batch API request.
  Future<Map<String, List<Map<String, dynamic>>>> readAllTabsBatch(
    String accessToken,
    String spreadsheetId,
    List<String> tabNames,
  ) async {
    try {
      // First ensure all required tabs exist
      await ensureAllTabsExist(accessToken, spreadsheetId);

      final queryRanges = tabNames.map((t) => 'ranges=${Uri.encodeComponent('$t!A2:Z')}').join('&');
      final url = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values:batchGet?$queryRanges',
      );

      final res = await http.get(url, headers: {'Authorization': 'Bearer $accessToken'}).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        // Fallback: read tabs individually if batch range fails
        final fallbackMap = <String, List<Map<String, dynamic>>>{};
        for (final tab in tabNames) {
          final records = await readTabRecords(accessToken, spreadsheetId, tab);
          if (records.isNotEmpty) {
            fallbackMap[tab] = records;
          }
        }
        return fallbackMap;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final valueRanges = (body['valueRanges'] as List?) ?? [];

      final resultMap = <String, List<Map<String, dynamic>>>{};
      for (int i = 0; i < tabNames.length && i < valueRanges.length; i++) {
        final tabName = tabNames[i];
        final vr = valueRanges[i] as Map<String, dynamic>;
        final values = (vr['values'] as List?) ?? [];
        final list = <Map<String, dynamic>>[];
        for (final row in values) {
          if (row is List && row.isNotEmpty) {
            final record = SheetSchema.rowToRecord(tabName, row);
            if (record.isNotEmpty) {
              list.add(record);
            }
          }
        }
        resultMap[tabName] = list;
      }
      return resultMap;
    } catch (_) {
      return {};
    }
  }

  /// Reads all records from a sheet tab.
  Future<List<Map<String, dynamic>>> readTabRecords(String accessToken, String spreadsheetId, String sheetName) async {
    try {
      final url = Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$sheetName!A2:Z');
      var res = await http.get(url, headers: {'Authorization': 'Bearer $accessToken'}).timeout(const Duration(seconds: 15));

      if (res.statusCode == 400 || res.statusCode == 404) {
        await ensureTabExists(accessToken, spreadsheetId, sheetName);
        res = await http.get(url, headers: {'Authorization': 'Bearer $accessToken'}).timeout(const Duration(seconds: 15));
      }

      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final values = (body['values'] as List?) ?? [];

      final list = <Map<String, dynamic>>[];
      for (final row in values) {
        if (row is List && row.isNotEmpty) {
          final record = SheetSchema.rowToRecord(sheetName, row);
          if (record.isNotEmpty) {
            list.add(record);
          }
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Inserts or updates a record by ID in a sheet tab with human-readable column fields.
  Future<void> upsertTabRecord(String accessToken, String spreadsheetId, String sheetName, String id, Map<String, dynamic> record) async {
    // Read existing IDs
    final getUrl = Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$sheetName!A2:A');
    var res = await http.get(getUrl, headers: {'Authorization': 'Bearer $accessToken'}).timeout(const Duration(seconds: 15));

    if (res.statusCode == 400 || res.statusCode == 404) {
      await ensureTabExists(accessToken, spreadsheetId, sheetName);
      res = await http.get(getUrl, headers: {'Authorization': 'Bearer $accessToken'}).timeout(const Duration(seconds: 15));
    }

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

    final rowValues = SheetSchema.recordToRow(sheetName, record);
    final endCol = SheetSchema.getColLetter(rowValues.length);

    final putUrl = Uri.parse(
      'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$sheetName!A$targetRow:$endCol$targetRow?valueInputOption=USER_ENTERED',
    );

    var putRes = await http.put(
      putUrl,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'values': [rowValues]
      }),
    ).timeout(const Duration(seconds: 20));

    if (putRes.statusCode == 400 || putRes.statusCode == 404) {
      await ensureTabExists(accessToken, spreadsheetId, sheetName);
      await http.put(
        putUrl,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'values': [rowValues]
        }),
      ).timeout(const Duration(seconds: 20));
    }
  }

  /// Deletes a record from a sheet tab by ID.
  Future<void> deleteTabRecord(String accessToken, String spreadsheetId, String sheetName, String id) async {
    // Read all records, filter out the ID, and rewrite
    final existing = await readTabRecords(accessToken, spreadsheetId, sheetName);
    final updated = existing.where((x) => x['id']?.toString() != id).toList();

    // Clear range
    await http.post(
      Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$sheetName!A2:Z:clear'),
      headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));

    if (updated.isNotEmpty) {
      final rows = updated.map((r) => SheetSchema.recordToRow(sheetName, r)).toList();
      final maxCols = rows.map((r) => r.length).fold(1, (a, b) => a > b ? a : b);
      final endCol = SheetSchema.getColLetter(maxCols);
      await http.put(
        Uri.parse('https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId/values/$sheetName!A2:$endCol${rows.length + 1}?valueInputOption=USER_ENTERED'),
        headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
        body: jsonEncode({'values': rows}),
      ).timeout(const Duration(seconds: 20));
    }
  }

  /// Ensures the standard 5-folder subfolder hierarchy exists within the root Drive folder.
  /// Standard subfolders: Invoices, Quotations, Payroll, Assets, Reports.
  Future<Map<String, String>> ensureFolderStructure(String accessToken, String rootFolderId) async {
    if (rootFolderId.isEmpty) return {};
    final cached = _subfolderCache[rootFolderId];
    if (cached != null && standardSubfolders.every((f) => cached.containsKey(f))) {
      return cached;
    }

    final folderMap = Map<String, String>.from(cached ?? {});
    try {
      // 1. Query existing child folders
      final query = Uri.encodeComponent(
        "'$rootFolderId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      );
      final listRes = await http.get(
        Uri.parse('https://www.googleapis.com/drive/v3/files?q=$query&fields=files(id,name)&pageSize=50'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 15));

      if (listRes.statusCode == 200) {
        final body = jsonDecode(listRes.body) as Map<String, dynamic>;
        final files = (body['files'] as List?) ?? [];
        for (final f in files) {
          if (f is Map) {
            final name = f['name'] as String?;
            final id = f['id'] as String?;
            if (name != null && id != null) {
              folderMap[name] = id;
            }
          }
        }
      }

      // 2. Create any missing standard subfolders
      for (final subfolderName in standardSubfolders) {
        if (!folderMap.containsKey(subfolderName)) {
          final createRes = await http.post(
            Uri.parse('https://www.googleapis.com/drive/v3/files'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'name': subfolderName,
              'mimeType': 'application/vnd.google-apps.folder',
              'parents': [rootFolderId],
            }),
          ).timeout(const Duration(seconds: 15));

          if (createRes.statusCode == 200 || createRes.statusCode == 201) {
            final data = jsonDecode(createRes.body) as Map<String, dynamic>;
            folderMap[subfolderName] = data['id'] as String;
          }
        }
      }

      _subfolderCache[rootFolderId] = folderMap;
    } catch (_) {}

    return folderMap;
  }

  /// Gets the folder ID for a given subfolder name, creating it if it doesn't exist.
  Future<String> getSubfolderId(String accessToken, String rootFolderId, String subfolderName) async {
    if (rootFolderId.isEmpty) return '';
    final cached = _subfolderCache[rootFolderId]?[subfolderName];
    if (cached != null && cached.isNotEmpty) return cached;

    final structure = await ensureFolderStructure(accessToken, rootFolderId);
    return structure[subfolderName] ?? rootFolderId;
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
    try {
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

      final uploadRes = await http.post(
        Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: Uint8List.fromList(body),
      ).timeout(const Duration(seconds: 40));

      if (uploadRes.statusCode == 200 || uploadRes.statusCode == 201) {
        final data = jsonDecode(uploadRes.body) as Map<String, dynamic>;
        return data['webViewLink'] as String? ?? 'https://drive.google.com/file/d/${data['id']}/view';
      }
    } catch (_) {}
    return '';
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
}
