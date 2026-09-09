import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../sync/sync_manager.dart';
import 'google_workspace_service.dart';

const connectedMode = bool.fromEnvironment('CONNECTED', defaultValue: false);
const googleScopes = [
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/drive',
  'https://www.googleapis.com/auth/userinfo.email',
];

class GoogleSession extends ChangeNotifier {
  GoogleSignInAccount? user;
  String? cachedEmail;
  String? cachedDisplayName;
  bool authorized = false;
  bool isAuthorizing = false;
  bool isCheckingWorkspace = false;
  bool isOffline = false;
  WorkspaceConfig? workspace;
  String? error;

  final GoogleWorkspaceService workspaceService = GoogleWorkspaceService();
  final SyncManager syncManager = SyncManager.instance;

  String get effectiveEmail => user?.email ?? cachedEmail ?? 'Offline User';
  String get effectiveDisplayName => user?.displayName ?? cachedDisplayName ?? effectiveEmail;

  static const _cachedEmailKey = 'tpc_cached_user_email';
  static const _cachedNameKey = 'tpc_cached_user_name';
  static const _cachedWorkspaceKey = 'tpc_cached_workspace_global';

  Future<void> initialize() async {
    await syncManager.initialize();
    await _loadCachedSession();

    const client = String.fromEnvironment('GOOGLE_CLIENT_ID');
    const server = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    await GoogleSignIn.instance.initialize(
      clientId: client.isEmpty ? null : client,
      serverClientId: server.isEmpty ? null : server,
    );

    GoogleSignIn.instance.authenticationEvents.listen((event) async {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        user = event.user;
        error = null;
        isOffline = false;
        await _saveUserToCache(user!.email, user!.displayName ?? '');
        try {
          final auth = await user!.authorizationClient.authorizationForScopes(googleScopes);
          authorized = auth != null;
          if (authorized) {
            await _loadOrDiscoverWorkspace();
          }
        } catch (_) {
          authorized = false;
        }
        notifyListeners();
      }
      if (event is GoogleSignInAuthenticationEventSignOut) {
        user = null;
        authorized = false;
        isAuthorizing = false;
        workspace = null;
        isOffline = false;
        await _clearCachedSession();
        notifyListeners();
      }
    }, onError: (Object e) {
      final msg = e.toString();
      if (!msg.contains('AbortError') && !msg.contains('aborted') && !msg.contains('signal is aborted')) {
        error = msg;
      }
      notifyListeners();
    });

    try {
      await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (user != null) {
        isOffline = false;
      }
    } catch (_) {
      // If network fails during initial lightweight auth, use cached session
      if (cachedEmail != null && workspace != null) {
        isOffline = true;
        authorized = true;
        syncManager.markOffline();
      }
    }
    notifyListeners();
  }

  Future<void> _loadCachedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      cachedEmail = prefs.getString(_cachedEmailKey);
      cachedDisplayName = prefs.getString(_cachedNameKey);

      final wsRaw = prefs.getString(_cachedWorkspaceKey);
      if (wsRaw != null && wsRaw.isNotEmpty) {
        workspace = WorkspaceConfig.fromJson(jsonDecode(wsRaw) as Map<String, dynamic>);
        authorized = true;
        isOffline = true;
      }
    } catch (_) {}
  }

  Future<void> _saveUserToCache(String email, String name) async {
    try {
      cachedEmail = email;
      cachedDisplayName = name;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedEmailKey, email);
      await prefs.setString(_cachedNameKey, name);
    } catch (_) {}
  }

  Future<void> _clearCachedSession() async {
    try {
      cachedEmail = null;
      cachedDisplayName = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedEmailKey);
      await prefs.remove(_cachedNameKey);
      await prefs.remove(_cachedWorkspaceKey);
    } catch (_) {}
  }

  Future<void> _loadOrDiscoverWorkspace() async {
    if (user == null && cachedEmail == null) return;
    isCheckingWorkspace = true;
    notifyListeners();

    try {
      final email = effectiveEmail;
      // 1. Try local cache
      var saved = await GoogleWorkspaceService.loadSavedWorkspace(email);
      if (saved != null) {
        await setWorkspace(saved);
        return;
      }

      // 2. Discover in user's Drive if online
      if (user != null) {
        final tokenStr = await token();
        final discovered = await workspaceService.findExistingWorkspace(tokenStr);
        if (discovered != null) {
          await setWorkspace(discovered);
          isOffline = false;
          // Trigger sync of pending queue
          await syncManager.syncPendingChanges(token: tokenStr, spreadsheetId: discovered.spreadsheetId);
        } else {
          workspace = null;
        }
      }
    } catch (e) {
      if (workspace != null) {
        isOffline = true;
        syncManager.markOffline();
      } else {
        workspace = null;
      }
    } finally {
      isCheckingWorkspace = false;
      notifyListeners();
    }
  }

  Future<void> setWorkspace(WorkspaceConfig config) async {
    workspace = config;
    final email = effectiveEmail;
    await GoogleWorkspaceService.saveWorkspace(email, config);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedWorkspaceKey, jsonEncode(config.toJson()));
    notifyListeners();
  }

  Future<void> clearWorkspace() async {
    final email = effectiveEmail;
    await GoogleWorkspaceService.clearSavedWorkspace(email);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedWorkspaceKey);
    workspace = null;
    notifyListeners();
  }

  Future<void> refreshWorkspaceDiscovery() async {
    await _loadOrDiscoverWorkspace();
  }

  Future<void> signIn() async {
    try {
      error = null;
      isAuthorizing = true;
      notifyListeners();
      final account = await GoogleSignIn.instance.authenticate();
      user = account;
      isOffline = false;
      await _saveUserToCache(user!.email, user!.displayName ?? '');
      final auth = await user!.authorizationClient.authorizationForScopes(googleScopes);
      if (auth != null) {
        authorized = true;
        await _loadOrDiscoverWorkspace();
      }
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('AbortError') && !msg.contains('aborted') && !msg.contains('signal is aborted')) {
        error = msg;
      }
    } finally {
      isAuthorizing = false;
      notifyListeners();
    }
  }

  Future<void> authorize() async {
    if (user == null) {
      await signIn();
      return;
    }
    try {
      error = null;
      isAuthorizing = true;
      notifyListeners();

      await user!.authorizationClient.authorizeScopes(googleScopes);
      authorized = true;
      isOffline = false;
      await _loadOrDiscoverWorkspace();
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('AbortError') && !msg.contains('aborted') && !msg.contains('signal is aborted')) {
        error = msg;
      }
      authorized = false;
    } finally {
      isAuthorizing = false;
      notifyListeners();
    }
  }

  Future<String?> tryGetToken() async {
    try {
      final auth = await user?.authorizationClient.authorizationForScopes(googleScopes);
      return auth?.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<String> token() async {
    final auth = await user?.authorizationClient.authorizationForScopes(googleScopes);
    if (auth == null) {
      if (isOffline && workspace != null) {
        throw StateError('Currently working in offline mode.');
      }
      authorized = false;
      notifyListeners();
      throw StateError('Reconnect your Google account.');
    }
    return auth.accessToken;
  }

  void expire() {
    authorized = false;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (workspace == null) return;
    final tok = await tryGetToken();
    if (tok != null) {
      isOffline = false;
      await syncManager.syncPendingChanges(token: tok, spreadsheetId: workspace!.spreadsheetId);
    } else {
      isOffline = true;
      syncManager.markOffline();
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    user = null;
    authorized = false;
    isAuthorizing = false;
    workspace = null;
    isOffline = false;
    await _clearCachedSession();
    notifyListeners();
  }
}
