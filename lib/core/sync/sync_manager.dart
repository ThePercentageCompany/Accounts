import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/google_workspace_service.dart';
import 'sheet_schema.dart';

enum SyncStatus {
  synced,
  syncing,
  pendingChanges,
  offline,
  error,
}

class PendingOperation {
  final String id;
  final String spreadsheetId;
  final String tabName;
  final String recordId;
  final String action; // 'upsert' | 'delete'
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const PendingOperation({
    required this.id,
    required this.spreadsheetId,
    required this.tabName,
    required this.recordId,
    required this.action,
    this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'spreadsheetId': spreadsheetId,
        'tabName': tabName,
        'recordId': recordId,
        'action': action,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PendingOperation.fromJson(Map<String, dynamic> json) => PendingOperation(
        id: json['id'] as String,
        spreadsheetId: json['spreadsheetId'] as String,
        tabName: json['tabName'] as String,
        recordId: json['recordId'] as String,
        action: json['action'] as String,
        data: json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : null,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class SyncManager extends ChangeNotifier {
  static final SyncManager instance = SyncManager._internal();
  SyncManager._internal();

  final GoogleWorkspaceService _service = GoogleWorkspaceService();

  SyncStatus _status = SyncStatus.synced;
  SyncStatus get status => _status;

  String? _lastError;
  String? get lastError => _lastError;

  DateTime? _lastSyncedTime;
  DateTime? get lastSyncedTime => _lastSyncedTime;

  List<PendingOperation> _pendingQueue = [];
  List<PendingOperation> get pendingQueue => List.unmodifiable(_pendingQueue);
  int get pendingCount => _pendingQueue.length;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadPendingQueue();
  }

  /// Clears in-memory pending queue, error states, remote tab caches, and resets sync status.
  Future<void> clearAll() async {
    _pendingQueue.clear();
    _status = SyncStatus.synced;
    _lastError = null;
    _lastSyncedTime = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      final keysToRemove = prefs.getKeys().where((k) => k.startsWith('tpc_tab_cache_')).toList();
      for (final k in keysToRemove) {
        await prefs.remove(k);
      }
    } catch (_) {}
    notifyListeners();
  }

  // --- LOCAL PERSISTENT CACHE ---

  static String _cacheKey(String spreadsheetId, String tabName) => 'tpc_tab_cache_${spreadsheetId}_$tabName';

  Future<List<Map<String, dynamic>>> loadCachedRecords(String spreadsheetId, String tabName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(spreadsheetId, tabName));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCachedRecords(String spreadsheetId, String tabName, List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey(spreadsheetId, tabName), jsonEncode(records));
  }

  Future<void> upsertCachedRecord(String spreadsheetId, String tabName, String recordId, Map<String, dynamic> record) async {
    final existing = await loadCachedRecords(spreadsheetId, tabName);
    final updated = [...existing.where((r) => r['id']?.toString() != recordId), record];
    await saveCachedRecords(spreadsheetId, tabName, updated);
    await mirrorTabRecordToLocalStorage(tabName, recordId, record, isDelete: false);
  }

  Future<void> deleteCachedRecord(String spreadsheetId, String tabName, String recordId) async {
    final existing = await loadCachedRecords(spreadsheetId, tabName);
    final updated = existing.where((r) => r['id']?.toString() != recordId).toList();
    await saveCachedRecords(spreadsheetId, tabName, updated);
    await mirrorTabRecordToLocalStorage(tabName, recordId, null, isDelete: true);
  }

  /// Real-time mirror of single upsert/delete mutation directly into SharedPreferences
  /// local database so local demo storage is ALWAYS in sync with active changes.
  Future<void> mirrorTabRecordToLocalStorage(
    String tabName,
    String recordId,
    Map<String, dynamic>? data, {
    bool isDelete = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (tabName == 'Customers' || tabName == 'Invoices' || tabName == 'Settings') {
        final raw = prefs.getString('tpc_demo_v1');
        Map<String, dynamic> billing = {};
        if (raw != null && raw.isNotEmpty) {
          try {
            billing = Map<String, dynamic>.from(jsonDecode(raw) as Map);
          } catch (_) {}
        }
        if (tabName == 'Customers') {
          final list = (billing['customers'] as List?)?.map((x) => Map<String, dynamic>.from(x as Map)).toList() ?? [];
          final updated = list.where((x) => x['id']?.toString() != recordId).toList();
          if (!isDelete && data != null) updated.add(data);
          billing['customers'] = updated;
        } else if (tabName == 'Invoices') {
          final list = (billing['invoices'] as List?)?.map((x) => Map<String, dynamic>.from(x as Map)).toList() ?? [];
          final updated = list.where((x) => x['id']?.toString() != recordId).toList();
          if (!isDelete && data != null) updated.add(data);
          billing['invoices'] = updated;
        } else if (tabName == 'Settings') {
          if (!isDelete && data != null && data['id'] == 'company') {
            final compVal = data['value'] ?? data;
            if (compVal is Map) billing['company'] = Map<String, dynamic>.from(compVal);
          }
        }
        await prefs.setString('tpc_demo_v1', jsonEncode(billing));
      } else if (tabName == 'Quotations') {
        final raw = prefs.getString('tpc_quotations_v1');
        List<Map<String, dynamic>> list = [];
        if (raw != null && raw.isNotEmpty) {
          try {
            list = (jsonDecode(raw) as List).map((x) => Map<String, dynamic>.from(x as Map)).toList();
          } catch (_) {}
        }
        final updated = list.where((x) => x['id']?.toString() != recordId).toList();
        if (!isDelete && data != null) updated.add(data);
        await prefs.setString('tpc_quotations_v1', jsonEncode(updated));
      } else {
        // Office tabs
        final officeKeyMap = {
          'Employees': 'employees',
          'Attendance': 'attendance',
          'Payroll': 'payroll',
          'Finance': 'entries',
          'Shareholders': 'shareholders',
          'CapitalTransactions': 'capitalTransactions',
          'ShareholderLoans': 'shareholderLoans',
          'Assets': 'assets',
          'Journals': 'journals',
        };
        final targetKey = officeKeyMap[tabName];
        if (targetKey != null) {
          final raw = prefs.getString('tpc_office_demo_v2');
          Map<String, dynamic> office = {};
          if (raw != null && raw.isNotEmpty) {
            try {
              office = Map<String, dynamic>.from(jsonDecode(raw) as Map);
            } catch (_) {}
          }
          final list = (office[targetKey] as List?)?.map((x) => Map<String, dynamic>.from(x as Map)).toList() ?? [];
          final updated = list.where((x) => x['id']?.toString() != recordId).toList();
          if (!isDelete && data != null) updated.add(data);
          office[targetKey] = updated;
          await prefs.setString('tpc_office_demo_v2', jsonEncode(office));
        }
      }
    } catch (_) {}
  }

  // --- PENDING SYNC QUEUE ---

  static const String _queueKey = 'tpc_pending_sync_queue';

  Future<void> _loadPendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _pendingQueue = list.map((e) => PendingOperation.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        if (_pendingQueue.isNotEmpty) {
          _status = SyncStatus.pendingChanges;
        }
      } catch (_) {
        _pendingQueue = [];
      }
    }
    notifyListeners();
  }

  Future<void> _savePendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(_pendingQueue.map((e) => e.toJson()).toList()));
    _status = _pendingQueue.isEmpty ? SyncStatus.synced : SyncStatus.pendingChanges;
    notifyListeners();
  }

  Future<void> enqueueOperation({
    required String spreadsheetId,
    required String tabName,
    required String recordId,
    required String action,
    Map<String, dynamic>? data,
  }) async {
    // Remove previous pending ops for the same record to keep queue compact
    _pendingQueue.removeWhere((op) => op.spreadsheetId == spreadsheetId && op.tabName == tabName && op.recordId == recordId);

    _pendingQueue.add(
      PendingOperation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        spreadsheetId: spreadsheetId,
        tabName: tabName,
        recordId: recordId,
        action: action,
        data: data,
        timestamp: DateTime.now(),
      ),
    );
    await _savePendingQueue();
  }

  bool _isBackgroundSyncing = false;
  bool get isBackgroundSyncing => _isBackgroundSyncing;

  // --- SYNC ENGINE ---

  /// Automatically migrates all existing offline/local data to Google Sheets tabs
  /// and queues immediate cloud synchronization.
  Future<void> migrateAndSyncLocalDataToCloud({
    required String spreadsheetId,
    required String token,
  }) async {
    if (spreadsheetId.isEmpty || spreadsheetId == 'local_demo_workspace') return;
    final prefs = await SharedPreferences.getInstance();

    // 1. Billing Data (Customers, Invoices, Company Settings)
    final billingRaw = prefs.getString('tpc_demo_v1');
    if (billingRaw != null && billingRaw.isNotEmpty) {
      try {
        final billingMap = jsonDecode(billingRaw) as Map<String, dynamic>;
        // Customers
        final customers = (billingMap['customers'] as List?) ?? [];
        for (final c in customers) {
          if (c is Map) {
            final map = Map<String, dynamic>.from(c);
            final id = map['id']?.toString() ?? '';
            if (id.isNotEmpty && id != 'sample') {
              await upsertCachedRecord(spreadsheetId, 'Customers', id, map);
              await enqueueOperation(
                spreadsheetId: spreadsheetId,
                tabName: 'Customers',
                recordId: id,
                action: 'upsert',
                data: map,
              );
            }
          }
        }
        // Invoices
        final invoices = (billingMap['invoices'] as List?) ?? [];
        for (final inv in invoices) {
          if (inv is Map) {
            final map = Map<String, dynamic>.from(inv);
            final id = map['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              await upsertCachedRecord(spreadsheetId, 'Invoices', id, map);
              await enqueueOperation(
                spreadsheetId: spreadsheetId,
                tabName: 'Invoices',
                recordId: id,
                action: 'upsert',
                data: map,
              );
            }
          }
        }
        // Company Settings
        final company = billingMap['company'];
        if (company is Map && (company['name']?.toString().isNotEmpty == true)) {
          final compMap = Map<String, dynamic>.from(company);
          final payload = {'id': 'company', 'value': compMap};
          await upsertCachedRecord(spreadsheetId, 'Settings', 'company', payload);
          await enqueueOperation(
            spreadsheetId: spreadsheetId,
            tabName: 'Settings',
            recordId: 'company',
            action: 'upsert',
            data: payload,
          );
        }
      } catch (_) {}
    }

    // 2. Quotations Data
    final quotesRaw = prefs.getString('tpc_quotations_v1');
    if (quotesRaw != null && quotesRaw.isNotEmpty) {
      try {
        final quotesList = jsonDecode(quotesRaw) as List<dynamic>;
        for (final q in quotesList) {
          if (q is Map) {
            final map = Map<String, dynamic>.from(q);
            final id = map['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              await upsertCachedRecord(spreadsheetId, 'Quotations', id, map);
              await enqueueOperation(
                spreadsheetId: spreadsheetId,
                tabName: 'Quotations',
                recordId: id,
                action: 'upsert',
                data: map,
              );
            }
          }
        }
      } catch (_) {}
    }

    // 3. Office & Finance Data (Employees, Attendance, Payroll, Finance, Shareholders, Capital, Loans, Assets, Journals)
    final officeRaw = prefs.getString('tpc_office_demo_v2');
    if (officeRaw != null && officeRaw.isNotEmpty) {
      try {
        final officeMap = jsonDecode(officeRaw) as Map<String, dynamic>;
        final tabMapping = {
          'employees': 'Employees',
          'attendance': 'Attendance',
          'payroll': 'Payroll',
          'entries': 'Finance',
          'shareholders': 'Shareholders',
          'capitalTransactions': 'CapitalTransactions',
          'shareholderLoans': 'ShareholderLoans',
          'assets': 'Assets',
          'journals': 'Journals',
        };

        for (final entry in tabMapping.entries) {
          final items = (officeMap[entry.key] as List?) ?? [];
          for (final item in items) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final id = map['id']?.toString() ?? '';
              if (id.isNotEmpty) {
                await upsertCachedRecord(spreadsheetId, entry.value, id, map);
                await enqueueOperation(
                  spreadsheetId: spreadsheetId,
                  tabName: entry.value,
                  recordId: id,
                  action: 'upsert',
                  data: map,
                );
              }
            }
          }
        }
      } catch (_) {}
    }

    // Trigger non-blocking cloud push and sync
    try {
      await triggerBackgroundSync(token: token, spreadsheetId: spreadsheetId);
    } catch (_) {}
  }

  /// Triggers a non-blocking background sync of both pending queue and remote changes.
  Future<void> triggerBackgroundSync({
    required String token,
    required String spreadsheetId,
    void Function()? onDataRefreshed,
  }) async {
    if (_isBackgroundSyncing) return;
    _isBackgroundSyncing = true;
    _status = SyncStatus.syncing;
    notifyListeners();

    try {
      // 1. Push all offline pending mutations
      await syncPendingChanges(token: token, spreadsheetId: spreadsheetId);

      // 2. Fetch all latest remote tabs in a single batch request
      final tabs = SheetSchema.dataTabsToSync;
      final batchData = await _service.readAllTabsBatch(token, spreadsheetId, tabs);

      bool hasData = false;
      for (final entry in batchData.entries) {
        if (entry.value.isNotEmpty) {
          await saveCachedRecords(spreadsheetId, entry.key, entry.value);
          hasData = true;
        }
      }

      // Mirror remote data into local storage so local databases are always populated
      await _mirrorRemoteToLocalStorage(batchData);

      _status = SyncStatus.synced;
      _lastSyncedTime = DateTime.now();
      _lastError = null;

      if (hasData && onDataRefreshed != null) {
        onDataRefreshed();
      }
    } catch (e) {
      _lastError = e.toString();
      markOffline();
    } finally {
      _isBackgroundSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _mirrorRemoteToLocalStorage(Map<String, List<Map<String, dynamic>>> batchData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Mirror Billing (Invoices, Customers, Company)
      if (batchData.containsKey('Invoices') || batchData.containsKey('Customers') || batchData.containsKey('Settings')) {
        final existingBillingRaw = prefs.getString('tpc_demo_v1');
        Map<String, dynamic> billingMap = {};
        if (existingBillingRaw != null && existingBillingRaw.isNotEmpty) {
          try {
            billingMap = Map<String, dynamic>.from(jsonDecode(existingBillingRaw) as Map);
          } catch (_) {}
        }
        if (batchData.containsKey('Invoices') && batchData['Invoices']!.isNotEmpty) {
          billingMap['invoices'] = batchData['Invoices'];
        }
        if (batchData.containsKey('Customers') && batchData['Customers']!.isNotEmpty) {
          billingMap['customers'] = batchData['Customers'];
        }
        if (batchData.containsKey('Settings') && batchData['Settings']!.isNotEmpty) {
          final settings = batchData['Settings']!;
          for (final s in settings) {
            if (s['id'] == 'company') {
              final val = s['value'] ?? s;
              if (val is Map) {
                billingMap['company'] = Map<String, dynamic>.from(val);
              }
            }
          }
        }
        if (billingMap.isNotEmpty) {
          await prefs.setString('tpc_demo_v1', jsonEncode(billingMap));
        }
      }

      // Mirror Quotations
      if (batchData.containsKey('Quotations') && batchData['Quotations']!.isNotEmpty) {
        await prefs.setString('tpc_quotations_v1', jsonEncode(batchData['Quotations']));
      }

      // Mirror Office
      final officeKeyMap = {
        'Employees': 'employees',
        'Attendance': 'attendance',
        'Payroll': 'payroll',
        'Finance': 'entries',
        'Shareholders': 'shareholders',
        'CapitalTransactions': 'capitalTransactions',
        'ShareholderLoans': 'shareholderLoans',
        'Assets': 'assets',
        'Journals': 'journals',
      };

      final existingOfficeRaw = prefs.getString('tpc_office_demo_v2');
      Map<String, dynamic> officeMap = {};
      if (existingOfficeRaw != null && existingOfficeRaw.isNotEmpty) {
        try {
          officeMap = Map<String, dynamic>.from(jsonDecode(existingOfficeRaw) as Map);
        } catch (_) {}
      }

      bool hasOfficeUpdate = false;
      for (final entry in officeKeyMap.entries) {
        if (batchData.containsKey(entry.key) && batchData[entry.key]!.isNotEmpty) {
          officeMap[entry.value] = batchData[entry.key];
          hasOfficeUpdate = true;
        }
      }
      if (hasOfficeUpdate) {
        await prefs.setString('tpc_office_demo_v2', jsonEncode(officeMap));
      }
    } catch (_) {}
  }

  /// Attempts to push all offline changes and sync with Google Sheets.
  Future<bool> syncPendingChanges({
    required String token,
    required String spreadsheetId,
  }) async {
    if (_pendingQueue.isEmpty) {
      _status = SyncStatus.synced;
      notifyListeners();
      return true;
    }

    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    final remaining = List<PendingOperation>.from(_pendingQueue);
    final successfullySynced = <PendingOperation>[];

    for (final op in remaining) {
      try {
        if (op.action == 'upsert' && op.data != null) {
          await _service.upsertTabRecord(token, op.spreadsheetId, op.tabName, op.recordId, op.data!);
        } else if (op.action == 'delete') {
          await _service.deleteTabRecord(token, op.spreadsheetId, op.tabName, op.recordId);
        }
        successfullySynced.add(op);
      } catch (e) {
        _lastError = 'Sync paused: $e';
        _status = SyncStatus.error;
        break;
      }
    }

    // Remove successfully synced ops
    _pendingQueue.removeWhere((op) => successfullySynced.contains(op));
    await _savePendingQueue();

    if (_pendingQueue.isEmpty) {
      _status = SyncStatus.synced;
      _lastSyncedTime = DateTime.now();
      _lastError = null;
    } else if (_status != SyncStatus.error) {
      _status = SyncStatus.pendingChanges;
    }

    notifyListeners();
    return _pendingQueue.isEmpty;
  }

  void markOffline() {
    _status = _pendingQueue.isNotEmpty ? SyncStatus.pendingChanges : SyncStatus.offline;
    notifyListeners();
  }

  void markSynced() {
    _status = _pendingQueue.isNotEmpty ? SyncStatus.pendingChanges : SyncStatus.synced;
    _lastSyncedTime = DateTime.now();
    notifyListeners();
  }
}
