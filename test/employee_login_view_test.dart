import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpc_invoice/core/auth/employee_gateway.dart';
import 'package:tpc_invoice/core/auth/employee_login_view.dart';
import 'package:tpc_invoice/core/auth/google_session.dart';
import 'package:tpc_invoice/core/auth/google_workspace_service.dart';

const _endpoint = 'https://script.google.com/macros/s/test-deployment/exec';
const _invite = WorkspaceConfig(
  spreadsheetId: '', driveFolderId: '', companyName: 'Acme & Co?',
  employeeId: 'employee-1', employeeGatewayUrl: _endpoint, isEmployee: true,
);

class _LoginSession extends GoogleSession {
  _LoginSession() : super(employeeGateway: EmployeeGateway(endpoint: _endpoint));
  String? submittedInvite;
  String? submittedCode;
  bool rejectCode = false;

  @override
  Future<void> pairWithEmployeeInvite(String inviteCodeOrJson, {required String employeeCode}) async {
    submittedInvite = inviteCodeOrJson;
    submittedCode = employeeCode;
    if (rejectCode) throw const EmployeeGatewayException('Employee code is incorrect or has been reset.');
  }
}

void main() {
  test('v2 links round-trip on hosted web, localhost and hash routes', () {
    for (final base in ['https://accounts.example/app/#/old', 'http://localhost:8080/']) {
      final link = _invite.toInviteLink(appBaseUri: Uri.parse(base));
      expect(link, startsWith(base.split('#').first));
      final parsed = WorkspaceConfig.fromInvitePayload(link)!;
      expect(parsed.employeeId, 'employee-1');
      expect(parsed.employeeGatewayUrl, _endpoint);
      expect(parsed.companyName, 'Acme & Co?');
      expect(parsed.allowedSections, isNull);
      expect(parsed.employeeCode, isNull);
    }
    final payload = Uri.encodeComponent(_invite.toInvitePayload());
    expect(WorkspaceConfig.fromInvitePayload('https://accounts.example/#/employee-login?invite=$payload')!.employeeId, 'employee-1');
    expect(WorkspaceConfig.fromInvitePayload('TPC_INVITE:${_invite.toInvitePayload()}')!.employeeId, 'employee-1');
    expect(WorkspaceConfig.fromInvitePayload('https://accounts.example/?invite=${Uri.encodeComponent('TPC_INVITE:${_invite.toInvitePayload()}')}')!.employeeId, 'employee-1');
    expect(WorkspaceConfig.fromInvitePayload('not an invite'), isNull);
    expect(WorkspaceConfig.fromInvitePayload(_invite.toInvitePayload().replaceFirst('employee-1', 'invalid employee')), isNull);
  });

  Future<void> showLogin(WidgetTester tester, _LoginSession session,
      {Future<String?> Function(BuildContext)? scan}) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp(home: EmployeeLoginView(session: session, scanQr: scan)));
  }

  testWidgets('scanning accepts v2 invite before requesting a private code', (tester) async {
    final session = _LoginSession();
    await showLogin(tester, session, scan: (_) async => _invite.toInviteLink());
    await tester.tap(find.text('Scan QR'));
    await tester.pumpAndSettle();
    expect(find.text('Employee QR accepted for Acme & Co?'), findsOneWidget);
    expect(session.submittedInvite, isNull);
    await tester.enterText(find.byType(TextFormField), 'ABCD-EFGH-IJKL-MNOP-QRST');
    await tester.tap(find.text('Sign in to workspace'));
    await tester.pumpAndSettle();
    expect(WorkspaceConfig.fromInvitePayload(session.submittedInvite!)!.employeeId, 'employee-1');
    expect(session.submittedCode, 'ABCD-EFGH-IJKL-MNOP-QRST');
    expect(tester.takeException(), isNull);
  });

  testWidgets('paste link works without camera and login errors remain visible', (tester) async {
    final session = _LoginSession()..rejectCode = true;
    await showLogin(tester, session);
    await tester.tap(find.text('Paste employee login link'));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), _invite.toInviteLink());
    await tester.tap(find.text('Use link'));
    await tester.pumpAndSettle();
    expect(session.pendingEmployeeInvite, isNotNull);
    await tester.tap(find.text('Sign in to workspace'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your private login code.'), findsOneWidget);
    expect(session.submittedCode, isNull);
    await tester.enterText(find.byType(TextFormField), 'wrong-code');
    await tester.tap(find.text('Sign in to workspace'));
    await tester.pumpAndSettle();
    expect(find.text('Employee code is incorrect or has been reset.'), findsOneWidget);
  });

  testWidgets('invalid rescan clears earlier employee and disables sign in', (tester) async {
    final session = _LoginSession()..acceptEmployeeInvite(_invite.toInvitePayload());
    await showLogin(tester, session, scan: (_) async => 'unrelated QR');
    await tester.tap(find.text('Scan a different QR'));
    await tester.pumpAndSettle();
    expect(session.pendingEmployeeInvite, isNull);
    expect(find.text('This employee QR is not supported. Ask your manager for a new QR.'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Sign in to workspace'));
    expect(button.onPressed, isNull);
  });

  testWidgets('camera failure shows link fallback without crashing', (tester) async {
    await showLogin(tester, _LoginSession(), scan: (_) async => throw StateError('camera unavailable'));
    await tester.tap(find.text('Scan QR'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to open the camera. Try again or paste the employee login link.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
