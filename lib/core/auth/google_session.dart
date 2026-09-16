import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../sync/sync_manager.dart';
import '../utils/browser_storage_cleaner.dart';
import 'google_workspace_service.dart';
import 'employee_gateway.dart';

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
  GoogleSession({EmployeeGateway? employeeGateway})
      : _employeeGateway = employeeGateway ?? EmployeeGateway();

  final EmployeeGateway _employeeGateway;
  String? _employeeSessionToken;
  DateTime? _employeeSessionExpiresAt;
  Future<void>? _employeeSyncTask;
  DateTime? _lastEmployeeSync;
  bool _googleInitialized = false;
  bool _disposed = false;
  GoogleSignInAccount? user;
  String? cachedEmail;
  String? cachedDisplayName;
  String? cachedPhotoUrl;
  String? _inMemoryAccessToken;
  String? _pendingEmployeeInvite;
  bool _employeeLoginRequested = false;
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
  Future<void>? _forcedSignOut;

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

  bool get isEmployee => workspace?.isEmployee == true;
  String? get currentEmployeeRole => workspace?.employeeRole;
  String? get currentEmployeeId => workspace?.employeeId;
  String? get currentEmployeeName => workspace?.employeeName ?? effectiveDisplayName;
  List<String>? get allowedSections => workspace?.allowedSections;
  String? get pendingEmployeeInvite => _pendingEmployeeInvite;
  bool get employeeLoginRequested => _employeeLoginRequested;
  bool get isCodeEmployeeSession => _employeeSessionToken != null && workspace?.isEmployee == true;
  String get employeeGatewayUrl => _employeeGateway.isConfigured ? _employeeGateway.endpoint : '';

  /// Opens the employee-specific sign-in path before Google authentication.
  void requestEmployeeLogin() {
    _employeeLoginRequested = true;
    notifyListeners();
  }

  void cancelEmployeeLogin() {
    _employeeLoginRequested = false;
    _pendingEmployeeInvite = null;
    error = null;
    notifyListeners();
  }

  /// Accepts only a valid employee QR/deep-link payload from the scanner.
  bool acceptEmployeeInvite(String scannedValue) {
    final invite = WorkspaceConfig.fromInvitePayload(scannedValue);
    if (invite == null || !_employeeGateway.isConfigured ||
        invite.employeeGatewayUrl != _employeeGateway.endpoint || (invite.employeeId ?? '').isEmpty) {
      return false;
    }
    _pendingEmployeeInvite = invite.toInvitePayload();
    _employeeLoginRequested = true;
    notifyListeners();
    return true;
  }

  /// Checks whether a given section/tab title is permitted for the active session.
  bool isSectionAllowed(String sectionTitle) {
    if (!isEmployee) return true; // Company owner/admin has unrestricted access
    final allowed = allowedSections;
    if (allowed == null || allowed.isEmpty) return sectionTitle == 'Dashboard';
    final normalized = sectionTitle.toLowerCase().trim();
    return allowed.any((s) => s.toLowerCase().trim() == normalized);
  }

  /// Login codes are checked by the owner's gateway. They are never in a QR,
  /// cached workspace or Google credential store.
  Future<void> pairWithEmployeeInvite(
    String inviteCodeOrJson, {
    required String employeeCode,
  }) async {
    final config = WorkspaceConfig.fromInvitePayload(inviteCodeOrJson);
    if (config == null || (config.employeeId ?? '').isEmpty ||
        config.employeeGatewayUrl != employeeGatewayUrl || employeeGatewayUrl.isEmpty) {
      throw StateError('Scan a new employee QR issued by this company.');
    }
    if (employeeCode.trim().isEmpty) throw StateError('Enter your private employee login code.');
    final result = await _employeeGateway.call('login', data: {
      'employeeId': config.employeeId, 'loginCode': employeeCode.trim(),
    });
    final employeeWorkspace = WorkspaceConfig.fromJson(Map<String, dynamic>.from(result['workspace'] as Map));
    if (!employeeWorkspace.isEmployee || employeeWorkspace.employeeId != config.employeeId ||
        employeeWorkspace.spreadsheetId.isEmpty || employeeWorkspace.driveFolderId.isEmpty) {
      throw StateError('The employee service returned an invalid workspace.');
    }
    final token = result['sessionToken']?.toString() ?? '';
    final expiry = DateTime.tryParse(result['expiresAt']?.toString() ?? '');
    if (token.isEmpty || expiry == null || !expiry.isAfter(DateTime.now())) {
      throw StateError('The employee service returned an invalid session.');
    }
    _automaticSyncTimer?.cancel();
    await syncManager.useEmployeeScope(employeeWorkspace.employeeId);
    // A fresh online snapshot replaces any earlier, broader permissions.
    await syncManager.clearEmployeeSnapshots();
    _employeeSessionToken = token;
    _employeeSessionExpiresAt = expiry;
    user = null;
    _inMemoryAccessToken = null;
    workspace = employeeWorkspace;
    cachedEmail = employeeWorkspace.employeeEmail;
    cachedDisplayName = employeeWorkspace.employeeName;
    cachedPhotoUrl = null;
    try {
      final snapshot = await syncManager.syncEmployee(
        gateway: _employeeGateway, sessionToken: token,
        spreadsheetId: employeeWorkspace.spreadsheetId,
      );
      _applyEmployeeWorkspace(snapshot);
      _lastEmployeeSync = DateTime.now();
      authorized = true;
      isOffline = false;
      error = null;
      _pendingEmployeeInvite = null;
      _employeeLoginRequested = false;
      _startAutomaticSync();
      notifyListeners();
    } catch (_) {
      _employeeSessionToken = null;
      _employeeSessionExpiresAt = null;
      workspace = null;
      authorized = false;
      await syncManager.clearEmployeeSnapshots();
      await syncManager.useEmployeeScope(null);
      rethrow;
    }
  }

  String employeeInviteLink({required String employeeId, required String companyName}) {
    if (employeeGatewayUrl.isEmpty) throw StateError('Set up the employee gateway before generating QR codes.');
    return WorkspaceConfig(
      spreadsheetId: '', driveFolderId: '', companyName: companyName,
      employeeId: employeeId, isEmployee: true, employeeGatewayUrl: employeeGatewayUrl,
    ).toInviteLink();
  }

  Future<Map<String, dynamic>> provisionEmployeeAccess(String employeeId, {bool reset = false}) async {
    if (isEmployee || user == null || workspace == null) throw StateError('Only the company owner can issue login codes.');
    final ownerToken = await token();
    await syncNow();
    if (syncManager.pendingQueue.any((op) => op.spreadsheetId == workspace!.spreadsheetId &&
        op.tabName == 'Employees' && op.recordId == employeeId)) {
      throw StateError('Save this employee online before generating their login code.');
    }
    return _employeeGateway.call('provisionEmployee', ownerAccessToken: ownerToken, data: {
      'employeeId': employeeId, 'reset': reset,
      'spreadsheetId': workspace!.spreadsheetId, 'driveFolderId': workspace!.driveFolderId,
    });
  }

  void _applyEmployeeWorkspace(Map<String, dynamic> result) {
    final raw = result['workspace'];
    if (raw is! Map) throw StateError('Employee permissions were not returned by the service.');
    final updated = WorkspaceConfig.fromJson(Map<String, dynamic>.from(raw));
    if (!updated.isEmployee || updated.employeeId != workspace?.employeeId ||
        updated.spreadsheetId != workspace?.spreadsheetId || updated.driveFolderId != workspace?.driveFolderId) {
      throw const EmployeeGatewayException('Employee workspace changed. Sign in again.', 'UNAUTHORIZED');
    }
    workspace = updated;
    cachedDisplayName = updated.employeeName;
    cachedEmail = updated.employeeEmail;
  }

  Future<Map<String, dynamic>> _employeeRequest(String action, Map<String, dynamic> data) async {
    if (!isCodeEmployeeSession) throw StateError('Sign in as an employee first.');
    try {
      return await _employeeGateway.call(action, data: data, sessionToken: _employeeSessionToken);
    } on EmployeeGatewayException catch (e) {
      if (e.sessionExpired) await forceSignOut(reason: e.message);
      rethrow;
    }
  }

  Future<String> uploadEmployeeFile({required String tabName, required String recordId,
      required String name, required String mimeType, required Uint8List bytes}) async {
    await syncNow();
    if (syncManager.pendingQueue.any((op) => op.tabName == tabName && op.recordId == recordId)) {
      throw StateError('Save this record online before uploading its file.');
    }
    final result = await _employeeRequest('upload', {
      'tabName': tabName, 'recordId': recordId, 'name': name,
      'mimeType': mimeType, 'base64': base64Encode(bytes),
    });
    final url = result['url']?.toString() ?? '';
    if (url.isEmpty) throw StateError('The owner Drive upload did not complete. Please retry.');
    return url;
  }

  Future<bool> deleteEmployeeFile(String url) async =>
      (await _employeeRequest('deleteFile', {'url': url}))['deleted'] == true;

  Future<Map<String, dynamic>> downloadEmployeeFile(String url) =>
      _employeeRequest('download', {'url': url});

  static const _cachedEmailKey = 'tpc_cached_user_email';
  static const _cachedNameKey = 'tpc_cached_user_name';
  static const _cachedPhotoKey = 'tpc_cached_user_photo';
  static const _cachedWorkspaceKey = 'tpc_cached_workspace_global';
  static const defaultClientId = '110697421185-klclvve50ibedrqjc830doqrenp44hif.apps.googleusercontent.com';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await syncManager.initialize();
    syncManager.onAuthorizationFailure = (error) => forceSignOut(
          reason: 'Google access is no longer authorized. Please sign in again.',
        );
    await _loadCachedSession();
    final launchInvite = WorkspaceConfig.fromInvitePayload(
        WidgetsBinding.instance.platformDispatcher.defaultRouteName);
    if (launchInvite != null) {
      _pendingEmployeeInvite = launchInvite.toInvitePayload();
    }

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
      // Authentication state is disposable; workspace data and offline queues
      // are not. Clearing all preferences here caused a web sign-out to erase
      // the local fallback before its next Google Sheets refresh completed.
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
          // A discovered workspace can contain newer records from another
          // device.  Pull it first; SyncManager safely flushes any queued
          // local mutations before it refreshes the local cache.
          await setWorkspace(discovered);
          isOffline = false;
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

  /// Activates a workspace and refreshes its local cache from Sheets.
  ///
  /// [migrateLocalData] is reserved for a workspace that has just been
  /// provisioned. Reconnecting to an existing workspace must pull first so
  /// an old local cache never overwrites newer cloud data.
  Future<void> setWorkspace(
    WorkspaceConfig config, {
    bool migrateLocalData = false,
  }) async {
    workspace = config;
    final email = effectiveEmail;
    await GoogleWorkspaceService.saveWorkspace(email, config);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedWorkspaceKey, jsonEncode(config.toJson()));
    notifyListeners();

    // A normal sign-in/reconnect flushes pending offline edits and then pulls
    // every Sheet tab into the local cache. This makes the app current before
    // its feature screens load, without requiring a manual refresh.
    if (config.spreadsheetId.isNotEmpty && config.spreadsheetId != 'local_demo_workspace') {
      try {
        final tok = await tryGetToken();
        if (tok != null) {
          isOffline = false;
          if (migrateLocalData) {
            await syncManager.migrateAndSyncLocalDataToCloud(
              spreadsheetId: config.spreadsheetId,
              token: tok,
            );
          } else {
            await syncManager.triggerBackgroundSync(
              token: tok,
              spreadsheetId: config.spreadsheetId,
            );
          }
          if (config.isEmployee) {
            await _refreshEmployeeAccess(config);
          }
        }
      } catch (e) {
        // Do not pretend a workspace is live when its initial cloud pull
        // failed. The cached records remain usable, but the UI can now show a
        // useful reconnect/sync error instead of silently showing stale data.
        isOffline = true;
        syncManager.markOffline();
        error = 'Could not refresh Google Sheets: $e';
      }
      _startAutomaticSync();
    } else {
      _automaticSyncTimer?.cancel();
      _automaticSyncTimer = null;
    }
  }

  Future<void> _refreshEmployeeAccess(WorkspaceConfig config) async {
    if (!config.isEmployee || config.spreadsheetId.isEmpty) return;
    final employees =
        await syncManager.loadCachedRecords(config.spreadsheetId, 'Employees');
    final employeeId = config.employeeId?.trim() ?? '';
    final employee = employees.cast<Map<String, dynamic>?>().firstWhere(
          (record) => record?['id']?.toString() == employeeId,
          orElse: () => null,
        );
    if (employee == null) {
      await forceSignOut(
        reason: 'This employee access code is no longer active. Contact your administrator.',
      );
      throw StateError('Employee access code is not active.');
    }

    final recordCode = employee['code']?.toString().trim() ?? '';
    final inviteCode = config.employeeCode?.trim() ?? '';
    if (recordCode.isEmpty || inviteCode.toLowerCase() != recordCode.toLowerCase()) {
      await forceSignOut(
        reason: 'This employee QR code is no longer valid. Ask your administrator for a new QR code.',
      );
      throw StateError('Employee QR code is no longer valid.');
    }

    if (employee['active'] == false ||
        employee['active']?.toString().toLowerCase() == 'false') {
      await forceSignOut(
        reason: 'Your employee account has been disabled. Contact your administrator.',
      );
      throw StateError('Employee account is disabled.');
    }

    final configuredGoogleEmail = employee['googleEmail']?.toString().trim() ?? '';
    final registeredEmail = (configuredGoogleEmail.isNotEmpty
            ? configuredGoogleEmail
            : employee['email']?.toString() ?? '')
        .toLowerCase();
    final signedInEmail = (user?.email ?? cachedEmail ?? '').trim().toLowerCase();
    if (registeredEmail.isEmpty || signedInEmail.isEmpty || registeredEmail != signedInEmail) {
      await forceSignOut(
        reason: 'Use the Google account registered for this employee profile.',
      );
      throw StateError('The signed-in Google account is not assigned to this employee.');
    }

    final rawSections = employee['allowedSections'];
    final sections = rawSections is List
        ? rawSections.map((value) => value.toString().trim()).where((value) => value.isNotEmpty).toList()
        : rawSections
            .toString()
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
    final refreshed = config.copyWith(
      employeeName: employee['name']?.toString(),
      employeeEmail: registeredEmail,
      employeeRole: employee['systemRole']?.toString() ?? 'Staff',
      allowedSections: sections.isEmpty ? const ['Dashboard'] : sections,
    );
    workspace = refreshed;
    await GoogleWorkspaceService.saveWorkspace(effectiveEmail, refreshed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedWorkspaceKey, jsonEncode(refreshed.toJson()));
    notifyListeners();
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
    await forceSignOut(
      reason: 'Your Google token is no longer available. Please sign in again.',
    );
    throw StateError('Reconnect your Google account.');
  }

  /// Revokes the local application session when Google rejects its token or
  /// the linked workspace permission was removed. Network failures use
  /// offline mode and do not call this method.
  Future<void> forceSignOut({
    String reason = 'Your Google session has expired. Please sign in again.',
  }) {
    if (_forcedSignOut != null) return _forcedSignOut!;
    final task = () async {
      authorized = false;
      error = reason;
      notifyListeners();
      await signOut();
      error = reason;
      notifyListeners();
    }();
    _forcedSignOut = task;
    task.whenComplete(() => _forcedSignOut = null);
    return task;
  }

  void expire([String? reason]) {
    unawaited(forceSignOut(
      reason: reason ?? 'Your Google session has expired. Please sign in again.',
    ));
  }

  Future<void> syncNow() async {
    if (workspace == null || workspace!.spreadsheetId.isEmpty || workspace!.spreadsheetId == 'local_demo_workspace') return;
    final tok = await tryGetToken();
    if (tok != null) {
      isOffline = false;
      await syncManager.triggerBackgroundSync(token: tok, spreadsheetId: workspace!.spreadsheetId);
      await syncManager.waitForIdle();
      if (workspace?.isEmployee == true) {
        await _refreshEmployeeAccess(workspace!);
      }
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
    cachedPhotoUrl = null;
    error = null;

    try {
      await syncManager.clearAll();
    } catch (_) {}

    try {
      await _clearCachedSession();
    } catch (_) {}

    try {
      await clearBrowserStorage();
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
