import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../sync/sync_manager.dart';
import 'google_workspace_service.dart';

const connectedMode = bool.fromEnvironment('CONNECTED', defaultValue: false);
const googleScopes = [
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/drive',
  'https://www.googleapis.com/auth/userinfo.email',
  'https://www.googleapis.com/auth/userinfo.profile',
];

bool _isIgnorableAuthError(Object e) {
  final msg = e.toString().toLowerCase();
  return msg.contains('aborterror') ||
      msg.contains('aborted') ||
      msg.contains('signal is aborted') ||
      msg.contains('canceled') ||
      msg.contains('cancelled') ||
      msg.contains('dismissed') ||
      msg.contains('interrupted') ||
      msg.contains('popup_closed') ||
      msg.contains('closed by user');
}

class GoogleSession extends ChangeNotifier {
  GoogleSignInAccount? user;
  String? cachedEmail;
  String? cachedDisplayName;
  String? cachedPhotoUrl;
  String? _inMemoryAccessToken;
  bool authorized = false;
  bool isAuthorizing = false;
  bool isCheckingWorkspace = false;
  bool isOffline = false;
  WorkspaceConfig? workspace;
  String? error;
  bool _initialized = false;
  Timer? _automaticSyncTimer;
  Future<void>? _identityHandling;
  Future<void>? _authorizationHandling;

  final GoogleWorkspaceService workspaceService = GoogleWorkspaceService();
  final SyncManager syncManager = SyncManager.instance;

  String get effectiveEmail => user?.email ?? cachedEmail ?? 'Offline User';

  String get effectiveDisplayName {
    final direct = user?.displayName?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final cached = cachedDisplayName?.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    if (effectiveEmail.isNotEmpty && effectiveEmail != 'Offline User') {
      final prefix = effectiveEmail.split('@').first;
      final parts = prefix.split(RegExp(r'[._-]')).where((p) => p.isNotEmpty);
      if (parts.isNotEmpty) {
        return parts.map((p) => p[0].toUpperCase() + (p.length > 1 ? p.substring(1) : '')).join(' ');
      }
      return prefix;
    }
    return workspace?.companyName ?? 'Account Owner';
  }

  String? get effectivePhotoUrl => user?.photoUrl ?? cachedPhotoUrl;

  static const _cachedEmailKey = 'tpc_cached_user_email';
  static const _cachedNameKey = 'tpc_cached_user_name';
  static const _cachedPhotoKey = 'tpc_cached_user_photo';
  static const _cachedWorkspaceKey = 'tpc_cached_workspace_global';
  static const defaultClientId = '110697421185-klclvve50ibedrqjc830doqrenp44hif.apps.googleusercontent.com';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await syncManager.initialize();
    await _loadCachedSession();

    const client = String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: defaultClientId);
    const server = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    await GoogleSignIn.instance.initialize(
      clientId: client.isEmpty ? null : client,
      serverClientId: server.isEmpty ? null : server,
    );

    GoogleSignIn.instance.authenticationEvents.listen((event) async {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        await _handleIdentitySignIn(event.user);
      }
      if (event is GoogleSignInAuthenticationEventSignOut) {
        user = null;
        _inMemoryAccessToken = null;
        authorized = false;
        isAuthorizing = false;
        workspace = null;
        isOffline = false;
        error = null;
        await syncManager.clearAll();
        await _clearCachedSession();
        notifyListeners();
      }
    }, onError: (Object e) {
      if (!_isIgnorableAuthError(e)) {
        error = e.toString();
        notifyListeners();
      }
    });

    try {
      // The authentication event listener completes identity restoration. Do
      // not request scopes here: doing so after the web account chooser opens
      // a second Google account chooser.
      await GoogleSignIn.instance.attemptLightweightAuthentication();
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

  /// Handles Google Identity sign-in exactly once, then requests the Sheets
  /// and Drive permissions in that same sign-in flow.
  Future<void> _handleIdentitySignIn(GoogleSignInAccount account) async {
    if (_identityHandling != null) return _identityHandling!;
    final task = () async {
      user = account;
      error = null;
      isOffline = false;
      await _saveUserToCache(account.email, account.displayName ?? '', photoUrl: account.photoUrl);
      try {
        final auth = await account.authorizationClient.authorizationForScopes(googleScopes);
        if (auth != null && auth.accessToken.isNotEmpty) {
          _inMemoryAccessToken = auth.accessToken;
          authorized = true;
          _fetchUserProfileIfAvailable(_inMemoryAccessToken!);
          await _loadOrDiscoverWorkspace();
        } else {
          // The identity selection was user initiated, so continue directly
          // into the single required OAuth permission flow. The guards on
          // [authorize] ensure this cannot open competing prompts.
          await authorize();
        }
      } catch (_) {
        authorized = false;
      }
      notifyListeners();
    }();
    _identityHandling = task;
    try {
      await task;
    } finally {
      _identityHandling = null;
    }
  }

  Future<void> _fetchUserProfileIfAvailable(String accessToken) async {
    try {
      final res = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
        final name = (data['name'] as String?)?.trim();
        final picture = (data['picture'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          cachedDisplayName = name;
        }
        if (picture != null && picture.isNotEmpty) {
          cachedPhotoUrl = picture;
        }
        await _saveUserToCache(
          user?.email ?? cachedEmail ?? (data['email'] as String? ?? ''),
          cachedDisplayName ?? '',
          photoUrl: cachedPhotoUrl,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _loadCachedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      cachedEmail = prefs.getString(_cachedEmailKey);
      cachedDisplayName = prefs.getString(_cachedNameKey);
      cachedPhotoUrl = prefs.getString(_cachedPhotoKey);

      final wsRaw = prefs.getString(_cachedWorkspaceKey);
      if (wsRaw != null && wsRaw.isNotEmpty) {
        final ws = WorkspaceConfig.fromJson(Map<String, dynamic>.from(jsonDecode(wsRaw) as Map));
        // Never auto-restore offline/local demo sessions — always require Google Sign-In
        if (ws.spreadsheetId != 'local_demo_workspace' && ws.spreadsheetId.isNotEmpty) {
          workspace = ws;
          authorized = true;
          isOffline = true;
        }
      }
    } catch (_) {}
  }

  Future<void> _saveUserToCache(String email, String name, {String? photoUrl}) async {
    try {
      cachedEmail = email;
      cachedDisplayName = name;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        cachedPhotoUrl = photoUrl;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedEmailKey, email);
      await prefs.setString(_cachedNameKey, name);
      if (cachedPhotoUrl != null) {
        await prefs.setString(_cachedPhotoKey, cachedPhotoUrl!);
      }
    } catch (_) {}
  }

  Future<void> _clearCachedSession() async {
    try {
      cachedEmail = null;
      cachedDisplayName = null;
      cachedPhotoUrl = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedEmailKey);
      await prefs.remove(_cachedNameKey);
      await prefs.remove(_cachedPhotoKey);
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
          await syncManager.migrateAndSyncLocalDataToCloud(
            token: tokenStr,
            spreadsheetId: discovered.spreadsheetId,
          );
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

    // If connected to a real cloud workspace, automatically migrate any local offline data and sync
    if (config.spreadsheetId.isNotEmpty && config.spreadsheetId != 'local_demo_workspace') {
      try {
        final tok = await tryGetToken();
        if (tok != null) {
          isOffline = false;
          await syncManager.migrateAndSyncLocalDataToCloud(
            spreadsheetId: config.spreadsheetId,
            token: tok,
          );
        }
      } catch (_) {}
      _startAutomaticSync();
    } else {
      _automaticSyncTimer?.cancel();
      _automaticSyncTimer = null;
    }
  }

  /// Keeps the cloud cache fresh even when the user has not edited a record.
  /// Mutations still trigger an immediate sync through their repositories.
  void _startAutomaticSync() {
    _automaticSyncTimer?.cancel();
    _automaticSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      syncNow();
    });
  }

  Future<void> clearWorkspace() async {
    _automaticSyncTimer?.cancel();
    _automaticSyncTimer = null;
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

  Future<void> useOfflineDemo() async {
    const demoConfig = WorkspaceConfig(
      companyName: 'The Percentage Company (Local)',
      spreadsheetId: 'local_demo_workspace',
      driveFolderId: 'local_demo_folder',
    );
    user = null;
    cachedEmail = 'local@thepercentage.co';
    cachedDisplayName = 'Local Demo User';
    isOffline = true;
    authorized = true;
    error = null;
    await setWorkspace(demoConfig);
  }

  Future<void> signIn() async {
    try {
      error = null;
      isAuthorizing = true;
      notifyListeners();
      if (kIsWeb) {
        // The Google Identity web button owns the account chooser and emits a
        // sign-in event. Calling authorize here would cause a second prompt.
        if (user != null) await authorize();
        return;
      }
      // authenticate() emits the same event handled above.  Do not run a
      // second, competing authorizeScopes flow from this method.
      await GoogleSignIn.instance.authenticate();
    } catch (e) {
      if (!_isIgnorableAuthError(e)) {
        error = e.toString();
      }
    } finally {
      isAuthorizing = false;
      notifyListeners();
    }
  }

  Future<void> authorize() async {
    if (_authorizationHandling != null) return _authorizationHandling!;
    if (user == null) {
      await signIn();
      return;
    }
    final task = () async {
      try {
      error = null;
      isAuthorizing = true;
      notifyListeners();

      final auth = await user!.authorizationClient.authorizeScopes(googleScopes);
      if (auth.accessToken.isNotEmpty) {
        _inMemoryAccessToken = auth.accessToken;
        authorized = true;
        isOffline = false;
        _fetchUserProfileIfAvailable(_inMemoryAccessToken!);
        await _loadOrDiscoverWorkspace();
      }
    } catch (e) {
      if (!_isIgnorableAuthError(e)) {
        error = e.toString();
      }
      } finally {
        isAuthorizing = false;
        notifyListeners();
      }
    }();
    _authorizationHandling = task;
    try {
      await task;
    } finally {
      _authorizationHandling = null;
    }
  }

  Future<String?> tryGetToken() async {
    try {
      final auth = await user?.authorizationClient.authorizationForScopes(googleScopes);
      if (auth?.accessToken != null && auth!.accessToken.isNotEmpty) {
        _inMemoryAccessToken = auth.accessToken;
        return auth.accessToken;
      }
      return _inMemoryAccessToken;
    } catch (_) {
      return _inMemoryAccessToken;
    }
  }

  Future<String> token() async {
    try {
      final auth = await user?.authorizationClient.authorizationForScopes(googleScopes);
      if (auth?.accessToken != null && auth!.accessToken.isNotEmpty) {
        _inMemoryAccessToken = auth.accessToken;
        return auth.accessToken;
      }
    } catch (_) {}

    if (_inMemoryAccessToken != null && _inMemoryAccessToken!.isNotEmpty) {
      return _inMemoryAccessToken!;
    }

    if (user != null) {
      try {
        final auth = await user!.authorizationClient.authorizeScopes(googleScopes);
        if (auth.accessToken.isNotEmpty) {
          _inMemoryAccessToken = auth.accessToken;
          authorized = true;
          return auth.accessToken;
        }
      } catch (_) {}
    }

    if (isOffline && workspace != null) {
      throw StateError('Currently working in offline mode.');
    }
    authorized = false;
    notifyListeners();
    throw StateError('Reconnect your Google account.');
  }

  void expire() {
    authorized = false;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (workspace == null || workspace!.spreadsheetId.isEmpty || workspace!.spreadsheetId == 'local_demo_workspace') return;
    final tok = await tryGetToken();
    if (tok != null) {
      isOffline = false;
      await syncManager.triggerBackgroundSync(token: tok, spreadsheetId: workspace!.spreadsheetId);
    } else {
      isOffline = true;
      syncManager.markOffline();
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    _automaticSyncTimer?.cancel();
    _automaticSyncTimer = null;
    user = null;
    _inMemoryAccessToken = null;
    authorized = false;
    isAuthorizing = false;
    workspace = null;
    isOffline = false;
    cachedEmail = null;
    cachedDisplayName = null;
    error = null;

    try {
      await syncManager.clearAll();
    } catch (_) {}

    try {
      await _clearCachedSession();
    } catch (_) {}

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}

    notifyListeners();
  }
}
