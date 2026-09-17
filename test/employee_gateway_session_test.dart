import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/auth/employee_gateway.dart';
import 'package:tpc_invoice/core/auth/google_session.dart';
import 'package:tpc_invoice/core/auth/google_workspace_service.dart';
import 'package:tpc_invoice/core/sync/sync_manager.dart';

const gatewayUrl = 'https://script.google.com/macros/s/trusted-company/exec';
const invite = WorkspaceConfig(
  spreadsheetId: '',
  driveFolderId: '',
  companyName: 'Company',
  employeeId: 'employee-1',
  isEmployee: true,
  employeeGatewayUrl: gatewayUrl,
);

Map<String, dynamic> employeeWorkspace(List<String> sections) => {
  'spreadsheetId': 'owner-sheet',
  'driveFolderId': 'owner-folder',
  'companyName': 'Verified Company',
  'employeeId': 'employee-1',
  'employeeName': 'Verified Employee',
  'employeeRole': 'Staff',
  'isEmployee': true,
  'allowedSections': sections,
};

class RecordingGateway extends EmployeeGateway {
  RecordingGateway() : super(endpoint: gatewayUrl);

  final List<Map<String, dynamic>> calls = [];
  List<String> sections = ['Dashboard', 'Invoices'];
  bool rejectSession = false;
  Completer<void>? syncGate;

  @override
  Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> data = const {},
    String? sessionToken,
    String? ownerAccessToken,
  }) async {
    calls.add({'action': action, 'data': data, 'sessionToken': sessionToken});
    if (action == 'login') {
      return {
        'workspace': employeeWorkspace(sections),
        'sessionToken': 'private-session-token',
        'expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      };
    }
    if (action == 'sync') {
      if (syncGate != null) await syncGate!.future;
      if (rejectSession) {
        throw const EmployeeGatewayException('Employee access revoked.', 'UNAUTHORIZED');
      }
      return {
        'workspace': employeeWorkspace(sections),
        'acknowledged': [for (final op in data['operations'] as List) op['id']],
        'rejected': [],
        'readableTabs': ['Employees'],
        'tabs': {},
      };
    }
    if (action == 'logout') return {};
    throw StateError('Unexpected gateway action: $action');
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final sync = SyncManager.instance;
  late RecordingGateway gateway;
  late GoogleSession session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await sync.clearAll();
    gateway = RecordingGateway();
    session = GoogleSession(employeeGateway: gateway);
  });

  tearDown(() async {
    session.dispose();
    await sync.clearAll();
    binding.platformDispatcher.clearDefaultRouteNameTestValue();
  });

  Future<void> login() => session.pairWithEmployeeInvite(
    invite.toInvitePayload(), employeeCode: 'PRIVATE-EMPLOYEE-CODE',
  );

  test('rejecting a QR clears the previously selected employee', () {
    expect(session.acceptEmployeeInvite(invite.toInvitePayload()), isTrue);
    expect(session.pendingEmployeeInvite, isNotNull);
    expect(session.acceptEmployeeInvite(invite.toInvitePayload().replaceAll(
      'trusted-company', 'untrusted-company')), isFalse);
    expect(session.pendingEmployeeInvite, isNull);
    expect(gateway.calls, isEmpty);
  });

  test('launch employee link works even when Google initialization is unavailable', () async {
    binding.platformDispatcher.defaultRouteNameTestValue = invite.toInviteLink();
    await session.initialize();
    expect(session.pendingEmployeeInvite, isNotNull);
    expect(session.employeeLoginRequested, isTrue);
    expect(session.authorized, isFalse);
  });

  test('employee sync uses gateway and refreshes permissions without Google', () async {
    await login();
    expect(session.authorized, isTrue);
    expect(session.isCodeEmployeeSession, isTrue);
    expect(session.isSectionAllowed('Invoices'), isTrue);
    expect(await session.tryGetToken(), isNull);
    await expectLater(session.token(), throwsStateError);
    await sync.enqueueOperation(
      spreadsheetId: 'owner-sheet', tabName: 'Invoices', recordId: 'invoice-1',
      action: 'delete', expectedVersion: 1,
    );
    gateway.sections = ['Dashboard'];

    await session.syncNow();

    expect(session.isOffline, isFalse);
    expect(session.isSectionAllowed('Invoices'), isFalse);
    expect(session.isSectionAllowed('Dashboard'), isTrue);
    expect(sync.pendingCount, 0);
    final request = gateway.calls.last;
    expect(request['action'], 'sync');
    expect(request['sessionToken'], 'private-session-token');
    expect((request['data']['operations'] as List).single['recordId'], 'invoice-1');
  });

  test('concurrent employee sync requests share one gateway request', () async {
    await login();
    gateway.syncGate = Completer<void>();
    final first = session.syncNow();
    final second = session.syncNow();
    await Future<void>.delayed(Duration.zero);
    expect(gateway.calls.where((call) => call['action'] == 'sync').length, 2);
    gateway.syncGate!.complete();
    await Future.wait([first, second]);
  });

  test('employee logout revokes token, clears snapshots and retains isolated pending edits', () async {
    await sync.saveCachedRecords('owner-sheet', 'Invoices', [{'id': 'owner-private'}]);
    await login();
    await sync.saveCachedRecords('owner-sheet', 'Invoices', [{'id': 'employee-private'}]);
    await sync.enqueueOperation(
      spreadsheetId: 'owner-sheet', tabName: 'Invoices', recordId: 'pending-employee-edit',
      action: 'delete', expectedVersion: 1,
    );

    await session.signOut();

    expect(session.authorized, isFalse);
    expect(session.isCodeEmployeeSession, isFalse);
    expect(session.workspace, isNull);
    expect(gateway.calls.last['action'], 'logout');
    expect(sync.pendingCount, 0);
    expect((await sync.loadCachedRecords('owner-sheet', 'Invoices')).single['id'], 'owner-private');
    await sync.useEmployeeScope('employee-1');
    expect(await sync.loadCachedRecords('owner-sheet', 'Invoices'), isEmpty);
    expect(sync.pendingQueue.single.recordId, 'pending-employee-edit');
  });

  test('revoked employee session signs out and clears restricted data', () async {
    await login();
    gateway.rejectSession = true;

    await expectLater(session.syncNow(), throwsA(isA<EmployeeGatewayException>()));

    expect(session.authorized, isFalse);
    expect(session.isCodeEmployeeSession, isFalse);
    expect(session.workspace, isNull);
    expect(session.error, 'Employee access revoked.');
  });

  test('gateway posts credentials only in the body and follows only ContentService redirect', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        return http.Response('', 302, headers: {
          'location': 'https://script.googleusercontent.com/macros/echo?response=opaque',
        });
      }
      return http.Response(jsonEncode({'ok': true, 'result': {'accepted': true}}), 200);
    });
    final service = EmployeeGateway(endpoint: gatewayUrl, client: client);
    expect(await service.call('login', data: {'loginCode': 'secret'}), {'accepted': true});
    expect(requests.first.url.toString(), gatewayUrl);
    expect(jsonDecode(requests.first.body)['data']['loginCode'], 'secret');
    expect(requests.last.method, 'GET');
    expect(requests.last.body, isEmpty);
  });

  test('gateway rejects unexpected redirects and malformed success results', () async {
    for (final response in [
      http.Response('', 302, headers: {'location': 'https://example.com/steal'}),
      http.Response('{"ok":true,"result":"invalid"}', 200),
    ]) {
      final service = EmployeeGateway(endpoint: gatewayUrl,
        client: MockClient((_) async => response));
      await expectLater(service.call('login'), throwsA(isA<EmployeeGatewayException>()
        .having((error) => error.code, 'code', 'CONFIGURATION')));
    }
  });
}
