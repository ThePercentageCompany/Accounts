import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/auth/google_session.dart';
import 'package:tpc_invoice/core/auth/google_workspace_service.dart';
import 'package:tpc_invoice/core/sync/sheet_schema.dart';
import 'package:tpc_invoice/core/widgets/qr_code.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Pure Dart QR Generator Tests', () {
    test('generates valid matrix for invite string', () {
      const inviteText = 'TPC_INVITE:{"companyName":"Test Co","spreadsheetId":"sheet123","role":"Accountant"}';
      final matrix = QrCodeGenerator.generate(inviteText);

      expect(matrix, isNotEmpty);
      expect(matrix.length, greaterThan(20));
      expect(matrix[0].length, equals(matrix.length));

      // Top-left finder pattern corner must be black
      expect(matrix[0][0], isTrue);
      // Top-right finder pattern corner must be black
      expect(matrix[0][matrix.length - 1], isTrue);
      // Bottom-left finder pattern corner must be black
      expect(matrix[matrix.length - 1][0], isTrue);
    });
  });

  group('WorkspaceConfig Invite Payload Serialization', () {
    test('correctly serializes and deserializes employee invite payload', () {
      final config = WorkspaceConfig(
        spreadsheetId: 'sheet_abc_123',
        driveFolderId: 'folder_xyz_456',
        companyName: 'Acme Global LLC',
        employeeId: 'emp-007',
        employeeCode: 'EMP007',
        employeeName: 'Jane Doe',
        employeeEmail: 'jane@acme.com',
        employeeRole: 'Accountant',
        allowedSections: ['Invoices', 'Quotations', 'Income & Expenses', 'Reports'],
        isEmployee: true,
      );

      final payload = config.toInvitePayload();
      expect(payload, contains('sheet_abc_123'));
      expect(payload, contains('Acme Global LLC'));

      // Test parsing raw JSON payload
      final parsedRaw = WorkspaceConfig.fromInvitePayload(payload);
      expect(parsedRaw, isNotNull);
      expect(parsedRaw!.spreadsheetId, equals('sheet_abc_123'));
      expect(parsedRaw.driveFolderId, equals('folder_xyz_456'));
      expect(parsedRaw.companyName, equals('Acme Global LLC'));
      expect(parsedRaw.employeeId, equals('emp-007'));
      expect(parsedRaw.employeeCode, equals('EMP007'));
      expect(parsedRaw.employeeName, equals('Jane Doe'));
      expect(parsedRaw.employeeEmail, equals('jane@acme.com'));
      expect(parsedRaw.employeeRole, equals('Accountant'));
      expect(parsedRaw.allowedSections, containsAll(['Invoices', 'Quotations', 'Income & Expenses', 'Reports']));
      expect(parsedRaw.isEmployee, isTrue);

      // Test parsing TPC_INVITE: prefixed payload
      final parsedPrefixed = WorkspaceConfig.fromInvitePayload('TPC_INVITE:$payload');
      expect(parsedPrefixed, isNotNull);
      expect(parsedPrefixed!.spreadsheetId, equals('sheet_abc_123'));
      expect(parsedPrefixed.employeeName, equals('Jane Doe'));

      final parsedLink = WorkspaceConfig.fromInvitePayload(config.toInviteLink());
      expect(parsedLink, isNotNull);
      expect(parsedLink!.employeeId, equals('emp-007'));
    });
  });

  group('GoogleSession RBAC Section Filtering', () {
    test('Owner has access to all sections', () {
      final session = GoogleSession();
      // Owner workspace (isEmployee == false)
      session.setWorkspace(const WorkspaceConfig(
        spreadsheetId: 'sheet_1',
        driveFolderId: 'folder_1',
        companyName: 'Parent Corp',
        isEmployee: false,
      ));

      expect(session.isEmployee, isFalse);
      expect(session.isSectionAllowed('Invoices'), isTrue);
      expect(session.isSectionAllowed('Employees'), isTrue);
      expect(session.isSectionAllowed('Capital & Equity'), isTrue);
      expect(session.isSectionAllowed('Fixed Assets'), isTrue);
      expect(session.isSectionAllowed('Office & Attendance'), isTrue);
    });

    test('Staff employee only accesses assigned sections', () {
      final session = GoogleSession();
      session.setWorkspace(const WorkspaceConfig(
        spreadsheetId: 'sheet_1',
        driveFolderId: 'folder_1',
        companyName: 'Parent Corp',
        isEmployee: true,
        employeeName: 'Sales Rep 1',
        employeeRole: 'Sales',
        allowedSections: ['Dashboard', 'Invoices', 'Quotations'],
      ));

      expect(session.isEmployee, isTrue);
      expect(session.currentEmployeeRole, equals('Sales'));
      expect(session.isSectionAllowed('Dashboard'), isTrue);
      expect(session.isSectionAllowed('Invoices'), isTrue);
      expect(session.isSectionAllowed('Quotations'), isTrue);
      // Disallowed sections
      expect(session.isSectionAllowed('Capital & Equity'), isFalse);
      expect(session.isSectionAllowed('Fixed Assets'), isFalse);
      expect(session.isSectionAllowed('Employees'), isFalse);
      expect(session.isSectionAllowed('Payroll'), isFalse);
    });

    test('Employee without assigned sections is restricted to dashboard', () {
      final session = GoogleSession();
      session.setWorkspace(const WorkspaceConfig(
        spreadsheetId: 'sheet_1',
        driveFolderId: 'folder_1',
        companyName: 'Parent Corp',
        isEmployee: true,
      ));

      expect(session.isSectionAllowed('Dashboard'), isTrue);
      expect(session.isSectionAllowed('Invoices'), isFalse);
    });
  });

  group('SheetSchema Employee Record Roundtrip with RBAC', () {
    test('serializes and deserializes employee record with role and permissions', () {
      final headers = SheetSchema.getHeaders('Employees');
      expect(headers, contains('System Role'));
      expect(headers, contains('Allowed Sections'));
      expect(headers, contains('Google Email'));
      expect(headers, contains('Created By'));
      expect(headers, contains('Updated By'));

      final originalRecord = {
        'id': 'emp-101',
        'code': 'EMP101',
        'name': 'John Smith',
        'department': 'Finance',
        'title': 'Senior Accountant',
        'email': 'john.smith@gmail.com',
        'phone': '+97150000000',
        'address': 'Dubai, UAE',
        'joinDate': '2026-01-01',
        'endDate': '',
        'basic': '12000',
        'allowances': '3000',
        'bank': 'Emirates NBD',
        'iban': 'AE2900000000000000000',
        'emiratesId': '784-1990-1234567-1',
        'passport': 'N12345678',
        'visaExpiry': '2028-01-01',
        'notes': 'Responsible for VAT and expenses',
        'systemRole': 'Accountant',
        'allowedSections': 'Invoices, Quotations, Income & Expenses, Reports',
        'googleEmail': 'john.smith@gmail.com',
        'active': true,
        'createdBy': 'Owner Admin',
        'updatedBy': 'Owner Admin',
        'version': 1,
      };

      final row = SheetSchema.recordToRow('Employees', originalRecord);
      final deserialized = SheetSchema.rowToRecord('Employees', row);

      expect(deserialized['id'], equals('emp-101'));
      expect(deserialized['name'], equals('John Smith'));
      expect(deserialized['systemRole'], equals('Accountant'));
      expect(deserialized['allowedSections'], equals(['Invoices', 'Quotations', 'Income & Expenses', 'Reports']));
      expect(deserialized['googleEmail'], equals('john.smith@gmail.com'));
      expect(deserialized['createdBy'], equals('Owner Admin'));
    });
  });
}
