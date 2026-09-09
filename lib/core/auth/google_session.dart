import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'google_workspace_service.dart';

const connectedMode = bool.fromEnvironment('CONNECTED', defaultValue: false);
const googleScopes = [
  'https://www.googleapis.com/auth/spreadsheets',
  'https://www.googleapis.com/auth/drive',
  'https://www.googleapis.com/auth/userinfo.email',
];

class GoogleSession extends ChangeNotifier {
  GoogleSignInAccount? user;
  bool authorized = false;
  bool isCheckingWorkspace = false;
  WorkspaceConfig? workspace;
  String? error;

  final GoogleWorkspaceService workspaceService = GoogleWorkspaceService();

  Future<void> initialize() async {
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
        try {
          final auth = await user!.authorizationClient.authorizationForScopes(googleScopes);
          authorized = auth != null;
          if (authorized) {
            await _loadOrDiscoverWorkspace();
          }
        } catch (_) {
          authorized = false;
        }
      }
      if (event is GoogleSignInAuthenticationEventSignOut) {
        user = null;
        authorized = false;
        workspace = null;
      }
      notifyListeners();
    }, onError: (Object e) {
      final msg = e.toString();
      if (!msg.contains('AbortError') && !msg.contains('aborted') && !msg.contains('signal is aborted')) {
        error = msg;
      }
      notifyListeners();
    });

    try {
      await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (_) {}
  }

  Future<void> _loadOrDiscoverWorkspace() async {
    if (user == null) return;
    isCheckingWorkspace = true;
    notifyListeners();

    try {
      final email = user!.email;
      // 1. Try local cache
      var saved = await GoogleWorkspaceService.loadSavedWorkspace(email);
      if (saved != null) {
        workspace = saved;
        isCheckingWorkspace = false;
        notifyListeners();
        return;
      }

      // 2. Discover in user's Drive
      final tokenStr = await token();
      final discovered = await workspaceService.findExistingWorkspace(tokenStr);
      if (discovered != null) {
        workspace = discovered;
        await GoogleWorkspaceService.saveWorkspace(email, discovered);
      } else {
        workspace = null;
      }
    } catch (e) {
      // Non-fatal, let user onboard
      workspace = null;
    } finally {
      isCheckingWorkspace = false;
      notifyListeners();
    }
  }

  Future<void> setWorkspace(WorkspaceConfig config) async {
    workspace = config;
    if (user != null) {
      await GoogleWorkspaceService.saveWorkspace(user!.email, config);
    }
    notifyListeners();
  }

  Future<void> clearWorkspace() async {
    if (user != null) {
      await GoogleWorkspaceService.clearSavedWorkspace(user!.email);
    }
    workspace = null;
    notifyListeners();
  }

  Future<void> refreshWorkspaceDiscovery() async {
    await _loadOrDiscoverWorkspace();
  }

  Future<void> signIn() async {
    try {
      error = null;
      await GoogleSignIn.instance.authenticate();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> authorize() async {
    try {
      error = null;
      await user!.authorizationClient.authorizeScopes(googleScopes);
      authorized = true;
      await _loadOrDiscoverWorkspace();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<String> token() async {
    final auth = await user?.authorizationClient.authorizationForScopes(googleScopes);
    if (auth == null) {
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

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    user = null;
    authorized = false;
    workspace = null;
    notifyListeners();
  }
}
