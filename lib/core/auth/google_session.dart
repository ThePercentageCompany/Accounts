import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../sync/sync_manager.dart';
import '../utils/browser_storage_cleaner.dart';
import 'google_workspace_service.dart';

const connectedMode = bool.fromEnvironment('CONNECTED', defaultValue: false);
const googleScopes = [
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/drive',
  'https://www.googleapis.com/auth/userinfo.email',
  'https://www.googleapis.com/auth/userinfo.profile',
];

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
        await _saveUserToCache(user!.email, user!.displayName ?? '', photoUrl: user!.photoUrl);
        try {
          final auth = await user!.authorizationClient.authorizationForScopes(googleScopes);
          if (auth != null && auth.accessToken.isNotEmpty) {
            _inMemoryAccessToken = auth.accessToken;
            authorized = true;
            _fetchUserProfileIfAvailable(_inMemoryAccessToken!);
            await _loadOrDiscoverWorkspace();
          } else {
            // Attempt auto authorization of scopes
            try {
              final authNew = await user!.authorizationClient.authorizeScopes(googleScopes);
              if (authNew.accessToken.isNotEmpty) {
                _inMemoryAccessToken = authNew.accessToken;
                authorized = true;
                _fetchUserProfileIfAvailable(_inMemoryAccessToken!);
                await _loadOrDiscoverWorkspace();
              }
            } catch (_) {
              // Browser popup policy may require a direct user tap; UI will show 1-click proceed button
            }
          }
        } catch (_) {
          authorized = false;
        }
        notifyListeners();
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
        final auth = await user!.authorizationClient.authorizationForScopes(googleScopes);
        if (auth != null && auth.accessToken.isNotEmpty) {
          _inMemoryAccessToken = auth.accessToken;
          authorized = true;
          _fetchUserProfileIfAvailable(_inMemoryAccessToken!);
          await _loadOrDiscoverWorkspace();
        }
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

  Future<void> _fetchUserProfileIfAvailable(String accessToken) async {
    try {
      final res = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
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
        workspace = WorkspaceConfig.fromJson(jsonDecode(wsRaw) as Map<String, dynamic>);
        authorized = true;
        isOffline = true;
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
      await prefs.clear();
    } catch (_) {}
    try {
      await clearBrowserStorage();
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
      await _saveUserToCache(user!.email, user!.displayName ?? '', photoUrl: user!.photoUrl);
      
      try {
        final auth = await user!.authorizationClient.authorizeScopes(googleScopes);
        if (auth.accessToken.isNotEmpty) {
          _inMemoryAccessToken = auth.accessToken;
          authorized = true;
          _fetchUserProfileIfAvailable(_inMemoryAccessToken!);
          await _loadOrDiscoverWorkspace();
          return;
        }
      } catch (_) {
        final check = await user!.authorizationClient.authorizationForScopes(googleScopes);
        if (check != null && check.accessToken.isNotEmpty) {
          _inMemoryAccessToken = check.accessToken;
          authorized = true;
          _fetchUserProfileIfAvailable(_inMemoryAccessToken!);
          await _loadOrDiscoverWorkspace();
          return;
        }
      }
      authorized = false;
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

      final auth = await user!.authorizationClient.authorizeScopes(googleScopes);
      if (auth.accessToken.isNotEmpty) {
        _inMemoryAccessToken = auth.accessToken;
        authorized = true;
        isOffline = false;
        _fetchUserProfileIfAvailable(_inMemoryAccessToken!);
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
