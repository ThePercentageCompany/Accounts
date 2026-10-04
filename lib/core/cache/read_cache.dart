import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:tpc_invoice/core/cache/cache_store.dart';
import 'package:tpc_invoice/core/cache/cache_lifecycle_stub.dart'
    if (dart.library.js_interop) 'package:tpc_invoice/core/cache/cache_lifecycle_web.dart';

String normalizedResource(String path) {
  final uri = Uri.parse(path);
  final query = <String, dynamic>{};
  for (final key in uri.queryParametersAll.keys.toList()..sort()) {
    query[key] = uri.queryParametersAll[key];
  }
  return jsonEncode([uri.path, query]);
}

Object? _canonical(Object? value) {
  if (value is Map) {
    return {
      for (final k in value.keys.map((k) => '$k').toList()..sort())
        k: _canonical(value[k]),
    };
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

String dataFingerprint(Map<String, dynamic> value) =>
    jsonEncode(_canonical(value));

class ReadCacheState {
  Map<String, dynamic>? data;
  DateTime? syncedAt;
  bool refreshing = false;
  bool offline = false;
  bool stale = true;
  Object? error;
  int failures = 0;
  DateTime? retryAt;
  int revision = 0;
  bool get initialLoading => data == null && refreshing;
}

/// One coordinator per API/session. Only verified contexts may use snapshots.
class ReadCache extends ChangeNotifier {
  ReadCache({
    CacheStore? store,
    DateTime Function()? now,
    this.recordsFreshness = const Duration(minutes: 2),
    this.reportsFreshness = const Duration(minutes: 1),
    this.retention = const Duration(days: 7),
    this.onAuthorizationFailure,
    this.isAuthorizationError,
    this.isOfflineError,
    this.retryDelay,
    this.isVisible,
    this.validateContext,
    bool automatic = true,
  }) : store = store ?? createCacheStore(),
       now = now ?? DateTime.now {
    _lifecycle = CacheLifecycle(() => resume(restartRetries: true), _message);
    if (automatic) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => resume());
    }
  }
  final CacheStore store;
  final DateTime Function() now;
  final Duration recordsFreshness, reportsFreshness, retention;
  final void Function(Object)? onAuthorizationFailure;
  final bool Function(Object)? isAuthorizationError, isOfflineError;
  final Duration? Function(Object)? retryDelay;
  final bool Function()? isVisible;
  final Future<void> Function()? validateContext;
  late final CacheLifecycle _lifecycle;
  Timer? _timer;
  String? scope, account;
  int _generation = 0;
  bool _disposed = false;
  bool _resuming = false;
  final _states = <String, ReadCacheState>{};
  final _loads = <String, Future<Map<String, dynamic>>>{};
  final _refreshes = <String, Future<Map<String, dynamic>>>{};
  final _loaders = <String, Future<Map<String, dynamic>> Function()>{};
  final _paths = <String, String>{};
  final _active = <String, int>{};

  void configure({required String scope, required String account}) {
    if (this.scope == scope && this.account == account) return;
    detach();
    this.scope = scope;
    this.account = account;
  }

  void detach() {
    _generation++;
    scope = null;
    account = null;
    _states.clear();
    _loads.clear();
    _refreshes.clear();
    _loaders.clear();
    _paths.clear();
    _active.clear();
    _notify();
  }

  Future<void> logout({bool broadcast = true}) async {
    final previous = account;
    detach();
    if (previous != null) {
      if (broadcast) _lifecycle.broadcast('logout', previous);
      await _safe(() => store.removeAccount(previous));
    }
  }

  void _message(String kind, String target) {
    if (kind == 'logout' && target == account) {
      unawaited(logout(broadcast: false));
      onAuthorizationFailure?.call(StateError('Signed out in another tab.'));
    } else if (kind == 'invalidate') {
      try {
        final event = jsonDecode(target) as Map;
        if (event['scope'] == scope) {
          final paths = Set<String>.from(event['paths'] as List);
          invalidate(
            (path) => paths.any(
              (p) =>
                  Uri.parse(path).path == p ||
                  (p.endsWith('/') && Uri.parse(path).path.startsWith(p)),
            ),
            broadcast: false,
          );
        }
      } catch (_) {}
    }
  }

  Duration freshness(String path) =>
      path.contains('/reports/') ? reportsFreshness : recordsFreshness;
  ReadCacheState? state(String path) => _states[normalizedResource(path)];
  void activate(String path) {
    final key = normalizedResource(path);
    _active[key] = (_active[key] ?? 0) + 1;
  }

  void deactivate(String path) {
    final key = normalizedResource(path);
    final count = (_active[key] ?? 0) - 1;
    if (count <= 0) {
      _active.remove(key);
    } else {
      _active[key] = count;
    }
  }

  bool _current(int generation) =>
      !_disposed && generation == _generation && scope != null;
  Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<Map<String, dynamic>> read(
    String path,
    Future<Map<String, dynamic>> Function() loader, {
    bool force = false,
  }) {
    if (scope == null) return loader();
    final key = normalizedResource(path);
    if (_states.length >= 128 && !_states.containsKey(key)) {
      final victims =
          _states.keys
              .where(
                (k) =>
                    !_active.containsKey(k) &&
                    !_refreshes.containsKey(k) &&
                    !_loads.containsKey(k),
              )
              .toList()
            ..sort(
              (a, b) => (_states[a]!.syncedAt ?? DateTime(1970)).compareTo(
                _states[b]!.syncedAt ?? DateTime(1970),
              ),
            );
      if (victims.isNotEmpty) {
        final victim = victims.first;
        _states.remove(victim);
        _loaders.remove(victim);
        _paths.remove(victim);
      }
    }
    _loaders[key] = loader;
    _paths[key] = path;
    if (force) return _refresh(key, loader, force: true);
    final present = _states[key]?.data;
    if (present != null) {
      _refreshIfStale(key);
      return Future.value(_copy(present));
    }
    final pending = _loads[key];
    if (pending != null) return pending;
    final generation = _generation,
        requestedScope = scope!,
        requestedAccount = account!;
    final storageKey = jsonEncode([requestedScope, key]);
    final future = (() async {
      final state = _states.putIfAbsent(key, ReadCacheState.new);
      Map<String, dynamic>? entry;
      try {
        entry = await store
            .read(storageKey)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      if (!_current(generation)) throw StateError('Workspace context changed.');
      try {
        if (state.data == null &&
            entry != null &&
            entry['schema'] == 2 &&
            entry['scope'] == requestedScope &&
            entry['account'] == requestedAccount &&
            entry['resource'] == key &&
            entry['complete'] == true) {
          final synced = DateTime.fromMillisecondsSinceEpoch(
            entry['syncedAt'] as int,
          );
          final age = now().difference(synced);
          if (!age.isNegative && age <= retention) {
            state.data = _copy(Map<String, dynamic>.from(entry['data'] as Map));
            state.syncedAt = synced;
            state.stale =
                entry['invalidated'] == true || age >= freshness(path);
          }
        }
      } catch (_) {
        /* Corrupt/schema-incompatible entries are rebuilt from the server. */
      }
      if (state.data != null) {
        _notify();
        _refreshIfStale(key);
        return _copy(state.data!);
      }
      return _refresh(key, loader);
    })();
    _loads[key] = future;
    future.then(
      (_) {
        if (identical(_loads[key], future)) _loads.remove(key);
      },
      onError: (Object _, StackTrace __) {
        if (identical(_loads[key], future)) _loads.remove(key);
      },
    );
    return future;
  }

  void _refreshIfStale(String key) {
    final state = _states[key];
    if (state == null || _loaders[key] == null) return;
    state.stale =
        state.stale ||
        state.syncedAt == null ||
        now().difference(state.syncedAt!) >= freshness(_paths[key]!);
    if (state.stale &&
        (state.retryAt == null || !now().isBefore(state.retryAt!))) {
      _refresh(key, _loaders[key]!).ignore();
    }
  }

  Future<Map<String, dynamic>> _refresh(
    String key,
    Future<Map<String, dynamic>> Function() loader, {
    bool force = false,
  }) {
    final pending = _refreshes[key];
    if (pending != null) return pending;
    final previous = _states[key];
    if (previous != null &&
        previous.error != null &&
        retryDelay?.call(previous.error!) != null &&
        previous.retryAt != null &&
        now().isBefore(previous.retryAt!)) {
      return previous.data != null
          ? Future.value(_copy(previous.data!))
          : Future.error(previous.error!);
    }
    final generation = _generation,
        requestedScope = scope!,
        requestedAccount = account!;
    final state = _states.putIfAbsent(key, ReadCacheState.new),
        revision = state.revision;
    state.refreshing = true;
    state.error = null;
    _notify();
    final future = (() async {
      try {
        final result = await loader();
        if (!_current(generation) || state.revision != revision) {
          throw StateError('Outdated response discarded.');
        }
        // API responses are complete snapshots, including empty lists and deletions.
        state.data = _copy(result);
        state.syncedAt = now();
        state.stale = false;
        state.offline = false;
        state.failures = 0;
        state.retryAt = null;
        final storageKey = jsonEncode([requestedScope, key]);
        final entry = <String, dynamic>{
          'schema': 2,
          'key': storageKey,
          'account': requestedAccount,
          'scope': requestedScope,
          'resource': key,
          'syncedAt': state.syncedAt!.millisecondsSinceEpoch,
          'freshForMs': freshness(_paths[key]!).inMilliseconds,
          'complete': true,
          'revision': null,
          'cursor': null,
          'etag': null,
          'data': state.data,
        };
        // Publish without waiting for disk; failed/quota-limited persistence is optional.
        unawaited(_safe(() => store.write(storageKey, entry)));
        return _copy(result);
      } catch (error) {
        if (!_current(generation) || state.revision != revision) rethrow;
        if (isAuthorizationError?.call(error) == true) {
          final oldAccount = account;
          detach();
          if (oldAccount != null) {
            _lifecycle.broadcast('logout', oldAccount);
            unawaited(_safe(() => store.removeAccount(oldAccount)));
          }
          onAuthorizationFailure?.call(error);
          rethrow;
        }
        state.error = error;
        state.stale = true;
        state.offline = isOfflineError?.call(error) == true;
        state.failures++;
        // Bounded attempts: resume/focus/manual refresh can explicitly restart later.
        final serverDelay = retryDelay?.call(error);
        state.retryAt = serverDelay != null
            ? now().add(serverDelay)
            : state.failures >= 4
            ? DateTime(9999)
            : now().add(Duration(seconds: [5, 15, 60][state.failures - 1]));
        if (state.data != null) return _copy(state.data!);
        rethrow;
      } finally {
        if (_current(generation) && state.revision == revision) {
          state.refreshing = false;
          _notify();
        }
      }
    })();
    _refreshes[key] = future;
    future.then(
      (_) {
        if (identical(_refreshes[key], future)) _refreshes.remove(key);
      },
      onError: (Object _, StackTrace __) {
        if (identical(_refreshes[key], future)) _refreshes.remove(key);
      },
    );
    return future;
  }

  void invalidate(
    bool Function(String path) affected, {
    bool broadcast = true,
    List<String>? broadcastPaths,
  }) {
    for (final key in _states.keys.toList()) {
      if (!affected(_paths[key] ?? '')) continue;
      final state = _states[key]!;
      state.stale = true;
      state.revision++;
      state.refreshing = false;
      state.failures = 0;
      state.retryAt = null;
      _refreshes.remove(key);
      _loads.remove(key);
    }
    final currentScope = scope;
    if (currentScope != null) {
      unawaited(_safe(() => store.invalidateScope(currentScope, affected)));
      if (broadcast) {
        // Send only resource paths, never records, credentials or permission claims.
        final paths =
            (broadcastPaths ??
            _paths.values
                .where(affected)
                .map((p) => Uri.parse(p).path)
                .toSet()
                .toList());
        _lifecycle.broadcast(
          'invalidate',
          jsonEncode({'scope': currentScope, 'paths': paths}),
        );
      }
    }
    _notify();
    for (final key in _active.keys.toList()) {
      _refreshIfStale(key);
    }
  }

  void invalidateAll({bool broadcast = true}) =>
      invalidate((_) => true, broadcast: broadcast);
  Future<void> resume({bool restartRetries = false}) async {
    if (!(isVisible?.call() ?? _lifecycle.visible) ||
        scope == null ||
        _active.isEmpty ||
        _resuming) {
      return;
    }
    _resuming = true;
    final generation = _generation;
    try {
      await validateContext?.call();
      if (!_current(generation)) return;
      for (final key in _active.keys.toList()) {
        if (restartRetries && _states[key]?.offline == true) {
          _states[key]!.failures = 0;
          _states[key]!.retryAt = null;
        }
        _refreshIfStale(key);
      }
    } catch (error) {
      if (_current(generation) && isAuthorizationError?.call(error) == true) {
        await logout();
        onAuthorizationFailure?.call(error);
      }
    } finally {
      _resuming = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _lifecycle.dispose();
    _states.clear();
    _loads.clear();
    _refreshes.clear();
    _active.clear();
    super.dispose();
  }
}
