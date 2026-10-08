import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:tpc_invoice/core/cache/cache_lifecycle_stub.dart'
    if (dart.library.js_interop) 'package:tpc_invoice/core/cache/cache_lifecycle_web.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'offline_store.dart';
import 'sync_lock_stub.dart' if (dart.library.js_interop) 'sync_lock_web.dart';

/// Durable, ordered per-account/workspace outbox. The server owns validation,
/// numbering, calculations and posting; local overlays never update reports.
class OfflineOutbox extends ChangeNotifier {
  OfflineOutbox({
    required this.store,
    required this.scope,
    required this.isCurrent,
    required this.verifyIdentity,
    required this.send,
    required this.changed,
    this.automatic = true,
    DateTime Function()? clock,
    double Function()? random,
  })  : clock = clock ?? DateTime.now,
        random = random ?? Random().nextDouble {
    lifecycle = CacheLifecycle(() {
      if (automatic) sync().ignore();
    }, (kind, target) {
      if (kind == 'outbox' && target == scope) {
        reload().then((_) async {
          if (automatic) await sync();
        }).ignore();
      }
    });
    if (automatic) {
      timer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (lifecycle.visible) reload().then((_) => sync()).ignore();
      });
    }
  }
  final OfflineStore store;
  final String scope;
  final bool Function() isCurrent;
  final Future<void> Function() verifyIdentity;
  final Future<Map<String, dynamic>> Function(Map<String, Object?>) send;
  final void Function(String) changed;
  final bool automatic;
  final DateTime Function() clock;
  final double Function() random;
  late final CacheLifecycle lifecycle;
  Timer? timer;
  bool syncing = false, authenticationRequired = false, offline = false;
  bool _disposed = false;
  Object? storageError;
  Map<String, dynamic> data = emptyPartition();
  List<Map<String, Object?>> get pending => (data['operations'] as List)
      .map((op) => Map<String, Object?>.from(op as Map))
      .toList();
  bool get hasFailed => pending.any((op) => op['state'] == 'failed');
  String get status => storageError != null
      ? 'Device storage unavailable'
      : authenticationRequired
          ? 'Sign in to sync'
          : syncing
              ? 'Syncing'
              : hasFailed
                  ? "Couldn't sync"
                  : offline
                      ? 'Offline'
                      : pending.isNotEmpty
                          ? 'Changes pending'
                          : 'Synced';
  static bool supports(String table, String action, [Map? record]) =>
      const ['create', 'update', 'delete'].contains(action) &&
      (const ['Customers', 'ProductsServices', 'Tasks', 'Projects']
              .contains(table) ||
          (table == 'TaskComments' && action == 'create') ||
          (const ['Invoices', 'Quotations'].contains(table) &&
              (action == 'create' || record?['status'] == 'DRAFT')));

  Future<void> reload() async {
    try {
      data = await store.read(scope);
      storageError = null;
      _notify();
    } catch (error) {
      if (error is! SaasApiException) storageError = error;
      _notify();
      rethrow;
    }
  }

  Future<void> _edit(void Function(Map<String, dynamic>) edit) async {
    try {
      data = await store.change(scope, edit);
      storageError = null;
      _notify();
      lifecycle.broadcast('outbox', scope);
    } catch (error) {
      if (error is! SaasApiException) {
        storageError = error;
      }
      _notify();
      rethrow;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> enqueue(
    String table,
    String action,
    Map<String, Object?> values, {
    String? recordId,
    required int expectedVersion,
    Map<String, dynamic>? base,
    String? operationId,
    bool local = true,
    bool rejected = false,
  }) async {
    if (!isCurrent()) {
      throw StateError(
        'Verify the original account and workspace before saving.',
      );
    }
    final id = operationId ?? const Uuid().v4();
    await _edit((partition) {
      final localId = (partition['ids'] as Map)[recordId] as String? ??
          recordId ??
          'local_$id';
      final ops = partition['operations'] as List;
      if (ops.any((op) => op['operationId'] == id)) return; // migration replay
      final records = partition['records'] as Map;
      final key = '$table:$localId';
      final previous = ops
          .where((op) => op['localId'] == localId && op['table'] == table)
          .lastOrNull;
      if (previous?['state'] == 'failed') {
        throw const SaasApiException(
          'PENDING',
          'Correct or discard the rejected edit before editing this record.',
        );
      }
      final resolvedValues = copyJson(values);
      for (final mapping in (partition['ids'] as Map).entries) {
        resolvedValues.addAll(Map<String, dynamic>.from(_replace(
                resolvedValues, mapping.key as String, mapping.value as String)
            as Map));
      }
      final version = previous == null && action != 'create'
          ? max(expectedVersion, (records[key]?['recordVersion'] as int?) ?? 0)
          : expectedVersion;
      final sequence = (partition['sequence'] as int) + 1;
      partition['sequence'] = sequence;
      ops.add({
        'operationId': id,
        'table': table,
        'action': action,
        'expectedVersion': version,
        if (recordId != null) 'recordId': localId,
        if (!const [
          'delete',
          'post',
          'issue',
          'send',
          'convert',
          'approve',
          'capitalize',
          'capitalPost',
          'loanPost',
        ].contains(action))
          'values': resolvedValues,
        'localId': localId,
        'sequence': sequence,
        'state': rejected ? 'failed' : 'pending',
        if (rejected)
          'error': 'This saved change was rejected. Review or discard it.',
        'attempts': 0,
        'retryAt': 0,
        'submitted': false,
        'local': local,
        if (previous != null) 'dependsOn': previous['operationId'],
      });
      if (local) {
        final old = copyJson(records[key] as Map? ?? base ?? {});
        records[key] = {
          ...old,
          ...resolvedValues,
          'recordId': localId,
          'recordVersion': version,
          if (const ['Invoices', 'Quotations'].contains(table))
            'status': 'DRAFT',
          'isDeleted': action == 'delete',
          'syncStatus': 'PENDING',
          '_operationId': id,
          '_localOnly': true,
        };
      }
    });
    changed(table);
    if (automatic && local) unawaited(sync());
  }

  List<Map<String, dynamic>> overlay(
    String table,
    List<Map<String, dynamic>> server,
  ) {
    if (!isCurrent()) return server;
    final records = {for (final r in server) '${r['recordId']}': copyJson(r)};
    for (final entry in (data['records'] as Map).entries) {
      if (!entry.key.toString().startsWith('$table:')) continue;
      final row = copyJson(entry.value as Map);
      final current = records['${row['recordId']}'];
      // A fresh server version supersedes acknowledged provisional fields.
      if (row['syncStatus'] == 'SYNCED' &&
          current != null &&
          (current['recordVersion'] as num? ?? 0) >=
              (row['recordVersion'] as num? ?? 0)) {
        continue;
      }
      records['${row['recordId']}'] = row;
    }
    return records.values
        .where((r) => r['isDeleted'] != true || r['syncStatus'] == 'FAILED')
        .toList();
  }

  Future<void> reconcile(
    String table,
    List<Map<String, dynamic>> server,
  ) async {
    if (!isCurrent()) return;
    await _edit((partition) {
      final records = partition['records'] as Map;
      records.removeWhere((key, raw) {
        if (!key.toString().startsWith('$table:') ||
            raw['syncStatus'] != 'SYNCED') {
          return false;
        }
        final row =
            server.where((r) => r['recordId'] == raw['recordId']).firstOrNull;
        return (raw['isDeleted'] == true && row == null) ||
            (row != null &&
                (row['recordVersion'] as num? ?? 0) >=
                    (raw['recordVersion'] as num? ?? 0));
      });
      // Retain mappings for stale editors opened before acknowledgement.
    });
  }

  Future<void> retry() async {
    authenticationRequired = false;
    await _edit((p) {
      for (final op in p['operations'] as List) {
        // Reopen only the known pre-write envelope rejection. Business and
        // version failures still require correction rather than blind retries.
        if (op['state'] == 'failed' &&
            op['errorCode'] == 'INVALID_BATCH' &&
            op['error'] == 'Supply between 1 and 20 operations.') {
          op['state'] = 'pending';
        }
        if (op['state'] != 'failed') op['retryAt'] = 0;
      }
    });
    await sync();
  }

  Future<void> correctRejected(
    String id,
    Map<String, Object?> values, {
    required int expectedVersion,
  }) async {
    final replacementId = const Uuid().v4();
    await _edit((p) {
      final ops = p['operations'] as List;
      final op = ops.where((r) => r['operationId'] == id).firstOrNull;
      if (op == null || op['state'] != 'failed' || op['local'] != true) {
        throw const SaasApiException(
          'PENDING',
          'Only a definitely rejected local edit can be corrected.',
        );
      }
      final history = p.putIfAbsent('rejections', () => <dynamic>[]) as List;
      history.add(copyJson(op as Map));
      if (history.length > 50) history.removeAt(0);
      (op as Map<String, dynamic>).addAll(<String, dynamic>{
        'operationId': replacementId,
        'values': copyJson(values),
        'expectedVersion': expectedVersion,
        'state': 'pending',
        'submitted': false,
        'attempts': 0,
        'retryAt': 0,
      });
      op.remove('error');
      op.remove('errorCode');
      if (op['action'] == 'delete') op.remove('values');
      for (final next in ops) {
        if (next['dependsOn'] == id) next['dependsOn'] = replacementId;
      }
      final key = '${op['table']}:${op['localId']}';
      final record = p['records'][key] as Map<String, dynamic>;
      record.addAll(<String, dynamic>{
        ...copyJson(values),
        'recordVersion': expectedVersion,
        'syncStatus': 'PENDING',
        '_operationId': replacementId,
      });
      record.remove('_syncError');
    });
    changed('');
    if (automatic) sync().ignore();
  }

  /// Only definitely rejected operations can be discarded. An uncertain write
  /// retains its immutable operation ID and payload until the server acknowledges.
  Future<void> discardRejected() async {
    await _edit((p) {
      final ops = p['operations'] as List;
      final rejected = ops.where((op) => op['state'] == 'failed').toList();
      for (final op in rejected) {
        if (ops.any(
          (next) =>
              next['dependsOn'] == op['operationId'] ||
              (next != op && next.toString().contains(op['localId'] as String)),
        )) {
          throw const SaasApiException(
            'DEPENDENT_CHANGES',
            'Dependent changes exist. Export and resolve them before discarding this edit.',
          );
        }
        ops.remove(op);
        (p['records'] as Map).remove('${op['table']}:${op['localId']}');
      }
    });
    changed('');
  }

  Future<void> sync() async {
    if (_disposed || syncing || authenticationRequired || !isCurrent()) return;
    syncing = true;
    _notify();
    try {
      await withSyncLock(scope, () async {
        await reload();
        while (!_disposed && isCurrent() && pending.isNotEmpty) {
          final first = pending.first;
          if (first['state'] == 'failed' ||
              clock().millisecondsSinceEpoch < (first['retryAt'] as int)) {
            break;
          }
          try {
            // Recheck via a real request, not navigator.onLine or cached claims.
            await verifyIdentity();
            if (!isCurrent()) return;
            Map<String, Object?>? payload;
            await _edit((p) {
              final op = (p['operations'] as List).first;
              if (op['operationId'] != first['operationId'] ||
                  op['state'] == 'failed') {
                return;
              }
              op['submitted'] = true;
              payload = {
                for (final key in [
                  'operationId',
                  'table',
                  'action',
                  'recordId',
                  'expectedVersion',
                  'values',
                ])
                  if (op.containsKey(key)) key: op[key],
              };
            });
            if (payload == null) continue;
            final response =
                first['backgroundAck'] is Map && first['local'] == true
                    ? {
                        'results': [first['backgroundAck']]
                      }
                    : await send(payload!);
            final results = response['results'];
            if (results is! List ||
                results.length != 1 ||
                results.first is! Map ||
                results.first['operationId'] != first['operationId']) {
              throw const SaasApiException(
                'INVALID_RESPONSE',
                'Cannot confirm sync. The same change will be retried.',
              );
            }
            final result = results.first as Map;
            if (result['status'] == 'FAILED') {
              final error = result['error'] as Map;
              throw SaasApiException('${error['code']}', '${error['message']}');
            }
            if (result['status'] != 'APPLIED' ||
                result['recordId'] is! String ||
                result['version'] is! int) {
              throw const SaasApiException(
                'INVALID_RESPONSE',
                'Server acknowledgement is incomplete. Retry with the same change ID.',
              );
            }
            await _ack(first, result);
            offline = false;
            changed(first['table'] as String);
          } catch (error) {
            if (storageError != null) rethrow;
            await _failure(first, error);
            break;
          }
        }
      });
    } catch (error) {
      storageError = error;
    } finally {
      syncing = false;
      _notify();
    }
  }

  Object? _replace(Object? value, String from, String to) {
    if (value is String) return value == from ? to : value;
    if (value is List) return value.map((v) => _replace(v, from, to)).toList();
    if (value is Map) {
      return {
        for (final e in value.entries)
          e.key.toString(): _replace(e.value, from, to),
      };
    }
    return value;
  }

  Future<void> _ack(Map op, Map result) => _edit((p) {
        final ops = p['operations'] as List;
        final from = op['localId'] as String, to = result['recordId'] as String;
        (p['ids'] as Map)[from] = to;
        ops.removeWhere((item) => item['operationId'] == op['operationId']);
        for (final next in ops) {
          if (next['submitted'] == true) continue;
          if (next['dependsOn'] == op['operationId']) {
            next['expectedVersion'] = result['version'];
            next.remove('dependsOn');
          }
          next['recordId'] = _replace(next['recordId'], from, to);
          if (next['recordId'] == null) next.remove('recordId');
          if (next.containsKey('values')) {
            next['values'] = _replace(next['values'], from, to);
          }
          next['localId'] = _replace(next['localId'], from, to);
        }
        final records = p['records'] as Map;
        final old = records.remove('${op['table']}:$from');
        if (old != null) {
          final pendingForRow = ops.any(
            (n) => n['table'] == op['table'] && n['localId'] == to,
          );
          records['${op['table']}:$to'] = {
            ...copyJson(old as Map),
            'recordId': to,
            'recordVersion': result['version'],
            'syncStatus': pendingForRow ? 'PENDING' : 'SYNCED',
          };
        }
        for (final key in records.keys.toList()) {
          records[key] = _replace(records[key], from, to);
        }
      });

  Future<void> _failure(Map op, Object error) async {
    final apiError = error is SaasApiException ? error : null;
    final auth = apiError?.status == 401 ||
        apiError?.requiresSignIn == true ||
        apiError?.code == 'SYNC_ACCOUNT_MISMATCH';
    final transient = auth ||
        apiError == null ||
        apiError.code == 'NETWORK' ||
        apiError.code == 'INVALID_RESPONSE' ||
        apiError.code == 'SERVICE_UNAVAILABLE' ||
        apiError.code.contains('PENDING') ||
        apiError.status == 429 ||
        apiError.status >= 500;
    authenticationRequired = auth;
    offline = apiError?.code == 'NETWORK';
    await _edit((p) {
      final row = (p['operations'] as List)
          .where((r) => r['operationId'] == op['operationId'])
          .firstOrNull;
      if (row == null) return;
      final attempts = (row['attempts'] as int) + 1;
      row['attempts'] = attempts;
      row['state'] = transient ? 'pending' : 'failed';
      row['error'] = apiError?.message ??
          'Could not reach the service. Your saved change is retained.';
      row['errorCode'] = apiError?.code ?? 'NETWORK';
      final delay = apiError?.retryAfter?.inMilliseconds ??
          (min(300000, 1000 * pow(2, min(attempts, 8))) * (0.5 + random()))
              .round();
      row['retryAt'] = clock().millisecondsSinceEpoch + delay;
      final record = (p['records'] as Map)['${op['table']}:${op['localId']}'];
      if (record != null) {
        record['syncStatus'] = transient ? 'PENDING' : 'FAILED';
        record['_syncError'] = row['error'];
      }
    });
    changed(op['table'] as String);
  }

  void pause() {
    authenticationRequired = true;
    _notify();
  }

  void resumeAuthentication() {
    authenticationRequired = false;
    if (automatic) sync().ignore();
  }

  @override
  void dispose() {
    _disposed = true;
    timer?.cancel();
    lifecycle.dispose();
    super.dispose();
  }
}
