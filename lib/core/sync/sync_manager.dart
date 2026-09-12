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
  }

  Future<void> deleteCachedRecord(String spreadsheetId, String tabName, String recordId) async {
    final existing = await loadCachedRecords(spreadsheetId, tabName);
    final updated = existing.where((r) => r['id']?.toString() != recordId).toList();
    await saveCachedRecords(spreadsheetId, tabName, updated);
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
