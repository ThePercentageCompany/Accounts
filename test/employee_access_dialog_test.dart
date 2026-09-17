import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/auth/google_session.dart';
import 'package:tpc_invoice/core/auth/google_workspace_service.dart';
import 'package:tpc_invoice/core/widgets/qr_code.dart';
import 'package:tpc_invoice/features/office/domain/office_repository.dart';
import 'package:tpc_invoice/features/office/presentation/employee_access_dialog.dart';
import 'package:tpc_invoice/features/office/presentation/office_cubit.dart';

const _employee = <String, dynamic>{
  'id': 'employee-1',
  'code': 'STAFF001',
  'name': 'Amina',
  'email': 'amina@example.com',
  'systemRole': 'Accountant',
  'allowedSections': ['Dashboard', 'Reports'],
  'active': true,
  'version': 1,
};
const _gateway = 'https://script.google.com/macros/s/deployment/exec';

class _OfficeRepository implements OfficeRepository {
  _OfficeRepository(this.events);
  final List<String> events;
  Map<String, dynamic> employee = Map<String, dynamic>.from(_employee);
  bool failSave = false;
  @override
  bool get isDemo => false;
  @override
  Future<Map<String, dynamic>> command(String action,
      [Map<String, dynamic>? data]) async {
    if (action == 'employeeSave') {
      events.add('save');
      if (failSave) throw StateError('Unable to save employee');
      employee = {...data!, 'version': (employee['version'] as int) + 1};
    }
    return {
      'employees': [employee]
    };
  }
}

class _OwnerSession extends GoogleSession {
  _OwnerSession(this.events) {
    authorized = true;
    workspace = const WorkspaceConfig(
        spreadsheetId: 'sheet',
        driveFolderId: 'folder',
        companyName: 'Company');
  }
  final List<String> events;
  bool configured = true;
  bool existing = false;
  bool failProvision = false;
  final List<bool> resets = [];
  @override
  String get employeeGatewayUrl => configured ? _gateway : '';
  @override
  Future<void> syncNow() async {
    events.add('sync');
  }

  @override
  Future<Map<String, dynamic>> provisionEmployeeAccess(String employeeId,
      {bool reset = false}) async {
    events.add('provision');
    resets.add(reset);
    if (failProvision) throw StateError('Employee gateway unavailable');
    return {
      'employeeId': employeeId,
      'exists': true,
      if (!existing || reset)
        'loginCode': reset ? 'NEWC-ODE1-2345-6789' : 'SECR-ET12-3456-7890',
    };
  }

  @override
  String employeeInviteLink(
          {required String employeeId, required String companyName}) =>
      WorkspaceConfig(
        spreadsheetId: '',
        driveFolderId: '',
        companyName: companyName,
        employeeId: employeeId,
        employeeGatewayUrl: _gateway,
        isEmployee: true,
      ).toInviteLink();
}

void main() {
  late List<String> events;
  late _OwnerSession session;
  late _OfficeRepository repository;
  late OfficeCubit cubit;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    events = [];
    session = _OwnerSession(events);
    repository = _OfficeRepository(events);
    cubit = OfficeCubit(repository);
  });
  tearDown(() async {
    await cubit.close();
    session.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: EmployeeAccessDialog(
      employee: _employee,
      session: session,
      cubit: cubit,
    ))));
    await tester.pumpAndSettle();
  }

  testWidgets('preserves saved customized sections for a named role',
      (tester) async {
    await open(tester);
    FilterChip chip(String section) =>
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, section));
    expect(chip('Reports').selected, isTrue);
    expect(chip('Invoices').selected, isFalse);
    expect(find.byType(QrImageView), findsNothing);
    await tester.tap(find.text('Save Permissions'));
    await tester.pumpAndSettle();
    expect(repository.employee['allowedSections'], ['Dashboard', 'Reports']);
    expect(repository.employee['systemRole'], 'Accountant');
    expect(events, ['save', 'sync']);
    expect(find.text('Permissions saved online.'), findsOneWidget);
  });

  testWidgets(
      'saves before provisioning and keeps private code outside QR and record',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Save & Create QR'));
    await tester.pumpAndSettle();
    expect(events, ['save', 'provision']);
    expect(find.text('SECR-ET12-3456-7890'), findsOneWidget);
    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    final invite = WorkspaceConfig.fromInvitePayload(qr.data);
    expect(invite?.employeeId, 'employee-1');
    expect(invite?.employeeGatewayUrl, _gateway);
    expect(qr.data, isNot(contains('SECR')));
    expect(qr.data, isNot(contains('STAFF001')));
    expect(qr.data, isNot(contains('allowedSections')));
    expect(repository.employee.containsKey('loginCode'), isFalse);

    String? clipboard;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.ensureVisible(find.text('Copy Employee QR Link'));
    await tester.tap(find.text('Copy Employee QR Link'));
    await tester.pumpAndSettle();
    expect(clipboard, qr.data);
    expect(WorkspaceConfig.fromInvitePayload(clipboard!)?.employeeId,
        'employee-1');
  });

  testWidgets('failed save never provisions or exposes a QR', (tester) async {
    repository.failSave = true;
    await open(tester);
    await tester.tap(find.text('Save & Create QR'));
    await tester.pumpAndSettle();
    expect(events, ['save']);
    expect(find.textContaining('Unable to save employee'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('failed provisioning surfaces the error and supports retry',
      (tester) async {
    session.failProvision = true;
    await open(tester);
    await tester.tap(find.text('Save & Create QR'));
    await tester.pumpAndSettle();
    expect(find.text('Employee gateway unavailable'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    session.failProvision = false;
    await tester.tap(find.text('Save & Create QR'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(repository.employee['version'], 3);
  });

  testWidgets('existing credential is reset only after explicit confirmation',
      (tester) async {
    session.existing = true;
    await open(tester);
    await tester.tap(find.text('Save & Create QR'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('private-login-code')), findsNothing);
    expect(find.textContaining('Login access already exists.'), findsOneWidget);
    await tester.ensureVisible(find.text('Reset Private Login Code'));
    await tester.tap(find.text('Reset Private Login Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(session.resets, [false]);
    await tester.tap(find.text('Reset Private Login Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset code'));
    await tester.pumpAndSettle();
    expect(session.resets, [false, true]);
    expect(find.text('NEWC-ODE1-2345-6789'), findsOneWidget);
  });

  testWidgets('unconfigured gateway disables access actions', (tester) async {
    session.configured = false;
    await open(tester);
    expect(find.textContaining('Employee login is not configured.'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save & Create QR'))
            .onPressed,
        isNull);
    expect(find.byType(QrImageView), findsNothing);
    expect(events, isEmpty);
  });

  testWidgets('employee sessions cannot issue or change login access',
      (tester) async {
    session.workspace = const WorkspaceConfig(
      spreadsheetId: 'sheet',
      driveFolderId: 'folder',
      companyName: 'Company',
      employeeId: 'employee-2',
      employeeRole: 'Admin',
      isEmployee: true,
    );
    await open(tester);
    expect(find.textContaining('Only the company owner'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save & Create QR'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Save Permissions'))
            .onPressed,
        isNull);
    expect(events, isEmpty);
  });
}
