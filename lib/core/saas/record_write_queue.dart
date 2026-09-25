import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'saas_api.dart';

/// One durable owner/company queue. Only individually acknowledged operations
/// are removed; an HTTP 200 batch can still contain a failed operation.
class RecordWriteQueue {
  RecordWriteQueue(this.api, this.preferences, String ownerId, this.companyId)
    : storageKey = 'saas_records_${ownerId}_$companyId';
  final SaasApi api;
  final SharedPreferences preferences;
  final String companyId;
  final String storageKey;
  bool _busy = false;
  List<Map<String, Object?>> get pending =>
      (preferences
              .getKeys()
              .where((key) => key.startsWith('${storageKey}_'))
              .toList()
            ..sort())
          .map(
            (key) => Map<String, Object?>.from(
              jsonDecode(preferences.getString(key)!) as Map,
            ),
          )
          .toList();
  Future<void> _store(Map<String, Object?> operation) async {
    if (!await preferences.setString(
      '${storageKey}_${operation['operationId']}',
      jsonEncode(operation),
    )) {
      throw const SaasApiException(
        'LOCAL_STORAGE',
        'Cannot save pending changes on this device.',
      );
    }
  }

  Future<void> enqueue(
    String table,
    String action,
    Map<String, Object?> values, {
    String? recordId,
    required int expectedVersion,
  }) async {
    if (_busy) {
      throw const SaasApiException('BUSY', 'Wait for the pending request.');
    }
    _busy = true;
    try {
      await preferences.reload();
      final operations = pending;
      if (operations.isNotEmpty) {
        throw const SaasApiException(
          'PENDING',
          'Retry the pending change before editing another record.',
        );
      }
      await _store({
        'operationId': const Uuid().v4(),
        'table': table,
        'action': action,
        'expectedVersion': expectedVersion,
        if (recordId != null) 'recordId': recordId,
        if (action != 'delete') 'values': values,
      });
    } finally {
      _busy = false;
    }
  }

  Future<void> flush() async {
    if (_busy) {
      throw const SaasApiException('BUSY', 'Wait for the pending request.');
    }
    _busy = true;
    try {
      await preferences.reload();
      var operations = pending;
      if (operations.isEmpty) return;
      final batch = operations.take(20).toList();
      final response = await api.sync(companyId, batch);
      final results = response['results'];
      if (results is! List || results.length != batch.length) {
        throw const SaasApiException(
          'INVALID_RESPONSE',
          'Cannot confirm this change. Retry with the same request.',
        );
      }
      // Validate all identities before acknowledging any result.
      for (var i = 0; i < results.length; i++) {
        if (results[i] is! Map ||
            results[i]['operationId'] != batch[i]['operationId'] ||
            !const [
              'APPLIED',
              'FAILED',
              'NOT_ATTEMPTED',
            ].contains(results[i]['status'])) {
          throw const SaasApiException(
            'INVALID_RESPONSE',
            'Cannot confirm the result. Pending changes are retained.',
          );
        }
      }
      final applied = results
          .where((r) => r['status'] == 'APPLIED')
          .map((r) => r['operationId'])
          .toSet();
      operations = operations
          .where((r) => !applied.contains(r['operationId']))
          .toList();
      for (final id in applied) {
        if (!await preferences.remove('${storageKey}_$id')) {
          throw const SaasApiException(
            'LOCAL_STORAGE',
            'Saved online. Retry to confirm local progress.',
          );
        }
      }
      final failed = results.where((r) => r['status'] == 'FAILED').firstOrNull;
      if (failed != null) {
        final error = failed['error'] as Map;
        throw SaasApiException(
          error['code'] as String,
          error['message'] as String,
        );
      }
      if (operations.isNotEmpty) {
        throw const SaasApiException(
          'PENDING',
          'Some changes are still pending. Retry to continue.',
        );
      }
    } finally {
      _busy = false;
    }
  }
}
