import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/google_workspace_service.dart';
import '../auth/employee_gateway.dart';
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
  final String? actorId;
  final int? expectedVersion;

  const PendingOperation({
    required this.id,
    required this.spreadsheetId,
    required this.tabName,
    required this.recordId,
    required this.action,
    this.data,
    required this.timestamp,
    this.actorId,
    this.expectedVersion,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'spreadsheetId': spreadsheetId,
        'tabName': tabName,
        'recordId': recordId,
        'action': action,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        if (actorId != null) 'actorId': actorId,
        if (expectedVersion != null) 'expectedVersion': expectedVersion,
      };

  factory PendingOperation.fromJson(Map<String, dynamic> json) => PendingOperation(
        id: json['id'] as String,
        spreadsheetId: json['spreadsheetId'] as String,
        tabName: json['tabName'] as String,
        recordId: json['recordId'] as String,
        action: json['action'] as String,
        data: json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : null,
        timestamp: DateTime.parse(json['timestamp'] as String),
        actorId: json['actorId'] as String?,
        expectedVersion: (json['expectedVersion'] as num?)?.toInt(),
      );
}

class SyncManager extends ChangeNotifier {
  static final SyncManager instance = SyncManager();
  SyncManager({GoogleWorkspaceService? service})
      : _service = service ?? GoogleWorkspaceService();

  final GoogleWorkspaceService _service;
  Future<void> _localWrites = Future<void>.value();

  // A tab snapshot and the offline mirror must be committed together. Otherwise
  // an older cloud response can win a race against a newly saved local edit.
  Future<T> _writeLocally<T>(Future<T> Function() write) {
    final result = _localWrites.then((_) => write());
    _localWrites = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  SyncStatus _status = SyncStatus.synced;
  SyncStatus get status => _status;

  String? _lastError;
  String? get lastError => _lastError;

  DateTime? _lastSyncedTime;
  DateTime? get lastSyncedTime => _lastSyncedTime;

  List<PendingOperation> _pendingQueue = [];
  String? _employeeScope;
  int _dataRevision = 0;
  int get dataRevision => _dataRevision;
  List<PendingOperation> get pendingQueue => List.unmodifiable(
      _pendingQueue.where((op) => op.actorId == _employeeScope));
  int get pendingCount => pendingQueue.length;

  Future<void> useEmployeeScope(String? employeeId) async {
    await waitForIdle();
    await _localWrites;
    _employeeScope = employeeId;
    _lastError = null;
    _status = pendingCount == 0 ? SyncStatus.synced : SyncStatus.pendingChanges;
    notifyListeners();
  }

  Future<void>? _initialization;
  Future<void> Function(Object error)? onAuthorizationFailure;

  bool _isAuthorizationFailure(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('status 401') ||
        message.contains('(401)') ||
        message.contains('unauthorized') ||
        message.contains('invalid credentials') ||
        message.contains('authentication credentials');
  }

  Future<void> initialize() => _initialization ??= _loadPendingQueue();

  /// Clears in-memory pending queue, error states, remote tab caches, and resets sync status.
  Future<void> clearAll() async {
    _pendingQueue.clear();
    _employeeScope = null;
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

  String _cacheKey(String spreadsheetId, String tabName) =>
      'tpc_tab_cache_${spreadsheetId}_${_employeeScope == null ? '' : 'employee_${_employeeScope}_'}$tabName';

  Future<List<Map<String, dynamic>>> loadCachedRecords(String spreadsheetId, String tabName) async {
    await _localWrites;
    return _loadCachedRecords(spreadsheetId, tabName);
  }

  Future<List<Map<String, dynamic>>> _loadCachedRecords(String spreadsheetId, String tabName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(spreadsheetId, tabName));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCachedRecords(String spreadsheetId, String tabName, List<Map<String, dynamic>> records) =>
      _writeLocally(() => _saveCachedRecords(spreadsheetId, tabName, records));

  Future<void> _saveCachedRecords(String spreadsheetId, String tabName, List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey(spreadsheetId, tabName), jsonEncode(records));
  }

  Future<void> upsertCachedRecord(String spreadsheetId, String tabName, String recordId, Map<String, dynamic> record) =>
      _writeLocally(() => _upsertCachedRecord(spreadsheetId, tabName, recordId, record));

  Future<void> _upsertCachedRecord(String spreadsheetId, String tabName, String recordId, Map<String, dynamic> record) async {
    final existing = await _loadCachedRecords(spreadsheetId, tabName);
    final updated = [...existing.where((r) => r['id']?.toString() != recordId), record];
    await _saveCachedRecords(spreadsheetId, tabName, updated);
    await mirrorTabRecordToLocalStorage(tabName, recordId, record, isDelete: false);
  }

  Future<void> deleteCachedRecord(String spreadsheetId, String tabName, String recordId) =>
      _writeLocally(() => _deleteCachedRecord(spreadsheetId, tabName, recordId));

  Future<void> _deleteCachedRecord(String spreadsheetId, String tabName, String recordId) async {
    final existing = await _loadCachedRecords(spreadsheetId, tabName);
    final updated = existing.where((r) => r['id']?.toString() != recordId).toList();
    await _saveCachedRecords(spreadsheetId, tabName, updated);
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
    if (_employeeScope != null) return;
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
        if (pendingCount > 0) {
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
  }

  Future<void> enqueueOperation({
    required String spreadsheetId,
    required String tabName,
    required String recordId,
    required String action,
    Map<String, dynamic>? data,
    int? expectedVersion,
  }) async {
    await initialize();
    await _writeLocally(() async {
    final previous = _pendingQueue.where((op) => op.spreadsheetId == spreadsheetId &&
        op.tabName == tabName && op.recordId == recordId && op.actorId == _employeeScope).firstOrNull;
    final baseVersion = previous?.expectedVersion ?? expectedVersion ??
        ((data?['version'] as num?)?.toInt() ?? 1) - 1;
    // Remove previous pending ops for the same record to keep queue compact
    _pendingQueue.removeWhere((op) => op.spreadsheetId == spreadsheetId && op.tabName == tabName && op.recordId == recordId && op.actorId == _employeeScope);

    _pendingQueue.add(
      PendingOperation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        spreadsheetId: spreadsheetId,
        tabName: tabName,
        recordId: recordId,
        action: action,
        data: data,
        timestamp: DateTime.now(),
        actorId: _employeeScope,
        expectedVersion: baseVersion < 0 ? 0 : baseVersion,
      ),
    );
    await _savePendingQueue();
    // Reapply the mutation within the same local write as the outbox entry.
    // Repositories may have saved it just before an older cloud pull completed.
    if (action == 'upsert' && data != null) {
      await _upsertCachedRecord(spreadsheetId, tabName, recordId, data);
    } else if (action == 'delete') {
      await _deleteCachedRecord(spreadsheetId, tabName, recordId);
    }
    });
    if (_isBackgroundSyncing && _employeeScope == null) {
      _syncRequestedWhileRunning = true;
    }
    if (_status != SyncStatus.error) {
      _status = _isBackgroundSyncing ? SyncStatus.syncing
          : pendingCount == 0 ? SyncStatus.synced : SyncStatus.pendingChanges;
    }
    notifyListeners();
  }

  bool _isBackgroundSyncing = false;
  bool get isBackgroundSyncing => _isBackgroundSyncing;
  bool _syncRequestedWhileRunning = false;
  ({String token, String spreadsheetId, void Function()? onDataRefreshed})?
      _queuedOwnerSync;

  /// Lets feature startup wait for an already-running pull instead of reading
  /// stale cached rows while another sync is replacing them.
  Future<void> waitForIdle() async {
    while (_isBackgroundSyncing) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  /// Discard private snapshots on logout, but retain unsent edits for the same
  /// employee to retry after authenticating again. Owner caches are untouched.
  Future<void> clearEmployeeSnapshots() async {
    if (_employeeScope == null) return;
    final prefs = await SharedPreferences.getInstance();
    final marker = '_employee_${_employeeScope}_';
    for (final key in prefs.getKeys().where((key) =>
        key.startsWith('tpc_tab_cache_') && key.contains(marker))) {
      await prefs.remove(key);
    }
  }

  /// All employee traffic is mediated by the owner gateway; Google credentials
  /// are never passed to or synthesized for an employee device.
  Future<Map<String, dynamic>> syncEmployee({
    required EmployeeGateway gateway,
    required String sessionToken,
    required String spreadsheetId,
  }) async {
    await waitForIdle();
    if (_employeeScope == null) throw StateError('Employee session is not active.');
    _isBackgroundSyncing = true;
    _status = SyncStatus.syncing;
    notifyListeners();
    final sent = pendingQueue.where((op) => op.spreadsheetId == spreadsheetId).take(100).toList();
    try {
      final result = await gateway.call('sync', sessionToken: sessionToken, data: {
        'operations': [for (final op in sent) {
          'id': op.id, 'tabName': op.tabName, 'recordId': op.recordId,
          'action': op.action, 'expectedVersion': op.expectedVersion ?? 0,
          if (op.data != null) 'data': op.data,
          if (op.data != null) 'row': SheetSchema.recordToRow(op.tabName, op.data!),
        }],
      });
      final acknowledged = (result['acknowledged'] as List? ?? []).map((id) => id.toString()).toSet();
      _pendingQueue.removeWhere((op) => sent.contains(op) && acknowledged.contains(op.id));
      await _savePendingQueue();
      final rejected = (result['rejected'] as List? ?? []).whereType<Map>().toList();
      final rejectedIds = rejected.map((op) => op['id']?.toString()).toSet();
      final readable = (result['readableTabs'] as List? ?? []).map((v) => v.toString()).toSet();
      final tabs = Map<String, dynamic>.from(result['tabs'] as Map? ?? {});
      var changed = false;
      for (final tab in SheetSchema.dataTabsToSync) {
        final rows = (tabs[tab] as List? ?? []).whereType<List>().toList();
        final records = <Map<String, dynamic>>[];
        if (rows.isNotEmpty) {
          final headers = rows.first.map((v) => v.toString()).toList();
          final indices = SheetSchema.getHeaders(tab).map(headers.indexOf).toList();
          for (final row in rows.skip(1)) {
            final aligned = [for (final index in indices)
              index >= 0 && index < row.length ? row[index] : ''];
            if (aligned.isEmpty || aligned.first.toString().isEmpty) continue;
            records.add(SheetSchema.rowToRecord(tab, aligned));
          }
        }
        // Edits made while the request was running remain visible until their
        // own acknowledgement. Rejected or newly forbidden edits stay only in
        // the outbox, never masquerading as accepted server records.
        if (readable.contains(tab)) {
          for (final op in pendingQueue.where((op) =>
              op.spreadsheetId == spreadsheetId && op.tabName == tab && !rejectedIds.contains(op.id))) {
            records.removeWhere((record) => record['id']?.toString() == op.recordId);
            if (op.action == 'upsert' && op.data != null) records.add(op.data!);
          }
        }
        final before = await loadCachedRecords(spreadsheetId, tab);
        changed = changed || jsonEncode(before) != jsonEncode(records);
        await saveCachedRecords(spreadsheetId, tab, records);
      }
      if (changed) _dataRevision++;
      _lastSyncedTime = DateTime.now();
      _lastError = rejected.isEmpty ? null : rejected.map((r) => r['message'] ?? 'Pending change rejected').join('\n');
      _status = rejected.isNotEmpty ? SyncStatus.error : pendingCount > 0 ? SyncStatus.pendingChanges : SyncStatus.synced;
      return result;
    } catch (e) {
      _lastError = e.toString();
      _status = e is EmployeeGatewayException && e.code != 'NETWORK'
          ? SyncStatus.error : pendingCount > 0 ? SyncStatus.pendingChanges : SyncStatus.offline;
      rethrow;
    } finally {
      _isBackgroundSyncing = false;
      notifyListeners();
    }
  }

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
        final billingMap = Map<String, dynamic>.from(jsonDecode(billingRaw) as Map);
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
        final quotesDecoded = jsonDecode(quotesRaw);
        final quotesList = quotesDecoded is List ? quotesDecoded : [];
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
        final officeMap = Map<String, dynamic>.from(jsonDecode(officeRaw) as Map);
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
    await initialize();
    if (_employeeScope != null) throw StateError('Employees must sync through the owner gateway.');
    // A CRUD operation may arrive while an earlier pass is uploading. Keep the
    // UI non-blocking, but guarantee a follow-up pass once that upload ends.
    if (_isBackgroundSyncing) {
      _syncRequestedWhileRunning = true;
      _queuedOwnerSync = (token: token, spreadsheetId: spreadsheetId,
          onDataRefreshed: onDataRefreshed);
      return;
    }
    _isBackgroundSyncing = true;
    try {
      do {
        _syncRequestedWhileRunning = false;
        _status = SyncStatus.syncing;
        notifyListeners();
        await _syncOwnerOnce(token: token, spreadsheetId: spreadsheetId,
            onDataRefreshed: onDataRefreshed);
        final requested = _queuedOwnerSync;
        _queuedOwnerSync = null;
        if (requested != null) {
          token = requested.token;
          spreadsheetId = requested.spreadsheetId;
          onDataRefreshed = requested.onDataRefreshed;
        }
      } while (_syncRequestedWhileRunning);
    } finally {
      _isBackgroundSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncOwnerOnce({
    required String token,
    required String spreadsheetId,
    void Function()? onDataRefreshed,
  }) async {
    try {
      // 1. Push all local mutations before reading remote data. Never overwrite
      // a pending local edit with an older cloud row after a failed upload.
      final pushed = await syncPendingChanges(token: token, spreadsheetId: spreadsheetId);
      if (!pushed) return;

      // 2. Fetch all latest remote tabs in a single batch request
      final tabs = SheetSchema.dataTabsToSync;
      final batchData = await _service.readAllTabsBatch(token, spreadsheetId, tabs);

      final changed = await _writeLocally(() async {
        final merged = <String, List<Map<String, dynamic>>>{};
        var changed = false;
        for (final entry in batchData.entries) {
          // The user can save or delete a row while the cloud read is running.
          // Keep these pending changes in both the cache and offline mirror.
          final records = List<Map<String, dynamic>>.of(entry.value);
          for (final op in pendingQueue.where((op) =>
              op.spreadsheetId == spreadsheetId && op.tabName == entry.key)) {
            records.removeWhere((record) => record['id']?.toString() == op.recordId);
            if (op.action == 'upsert' && op.data != null) records.add(op.data!);
          }
          final before = await _loadCachedRecords(spreadsheetId, entry.key);
          changed = changed || jsonEncode(before) != jsonEncode(records);
          await _saveCachedRecords(spreadsheetId, entry.key, records);
          merged[entry.key] = records;
        }
        await _mirrorRemoteToLocalStorage(merged);
        return changed;
      });
      if (changed) _dataRevision++;

      _status = pendingCount > 0 ? SyncStatus.pendingChanges : SyncStatus.synced;
      _lastSyncedTime = DateTime.now();
      _lastError = null;

      if (changed && onDataRefreshed != null) {
        onDataRefreshed();
      }
    } catch (e) {
      _lastError = e.toString();
      if (_isAuthorizationFailure(e) && onAuthorizationFailure != null) {
        unawaited(onAuthorizationFailure!(e));
      }
      _status = SyncStatus.error;
    }
  }

  Future<void> _mirrorRemoteToLocalStorage(Map<String, List<Map<String, dynamic>>> batchData) async {
    if (_employeeScope != null) return;
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
        if (batchData.containsKey('Invoices')) {
          billingMap['invoices'] = batchData['Invoices'];
        }
        if (batchData.containsKey('Customers')) {
          billingMap['customers'] = batchData['Customers'];
        }
        if (batchData.containsKey('Settings')) {
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
      if (batchData.containsKey('Quotations')) {
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
        if (batchData.containsKey(entry.key)) {
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
    await initialize();
    if (_employeeScope != null) throw StateError('Employees must sync through the owner gateway.');

    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    final remaining = _pendingQueue.where((op) => op.spreadsheetId == spreadsheetId && op.actorId == null).toList();
    final successfullySynced = <PendingOperation>[];
    var failed = false;

    for (final op in remaining) {
      try {
        if (op.action == 'upsert' && op.data != null) {
          await _service.upsertTabRecord(token, op.spreadsheetId, op.tabName, op.recordId, op.data!);
        } else if (op.action == 'delete') {
          await _service.deleteTabRecord(token, op.spreadsheetId, op.tabName, op.recordId);
        } else {
          throw StateError('Invalid pending operation: ${op.action}');
        }
        successfullySynced.add(op);
      } catch (e) {
        failed = true;
        _lastError = 'Sync paused: $e';
        _status = SyncStatus.error;
        if (_isAuthorizationFailure(e) && onAuthorizationFailure != null) {
          unawaited(onAuthorizationFailure!(e));
        }
        break;
      }
    }

    // Remove successfully synced ops
    await _writeLocally(() async {
      _pendingQueue.removeWhere((op) => successfullySynced.contains(op));
      await _savePendingQueue();
    });

    if (failed) {
      _status = SyncStatus.error;
    } else if (_isBackgroundSyncing) {
      _status = SyncStatus.syncing;
    } else if (pendingCount == 0) {
      _status = SyncStatus.synced;
      _lastSyncedTime = DateTime.now();
      _lastError = null;
    } else if (_status != SyncStatus.error) {
      _status = SyncStatus.pendingChanges;
    }

    notifyListeners();
    return !failed && !_pendingQueue.any((op) => op.spreadsheetId == spreadsheetId && op.actorId == null);
  }

  void markOffline() {
    _status = pendingCount > 0 ? SyncStatus.pendingChanges : SyncStatus.offline;
    notifyListeners();
  }

  void markSynced() {
    _status = pendingCount > 0 ? SyncStatus.pendingChanges : SyncStatus.synced;
    _lastSyncedTime = DateTime.now();
    notifyListeners();
  }
}
