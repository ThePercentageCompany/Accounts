import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/auth/company_onboarding_view.dart';
import 'package:tpc_invoice/core/auth/google_session.dart';
import 'package:tpc_invoice/core/auth/google_workspace_service.dart';
import 'package:tpc_invoice/features/billing/data/google_direct_repository.dart';
import 'package:tpc_invoice/features/office/data/google_direct_office_repository.dart';
import 'package:tpc_invoice/features/quotations/data/google_direct_quotation_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('WorkspaceConfig serializes and deserializes correctly', () {
    const config = WorkspaceConfig(
      spreadsheetId: 'sheet_12345',
      driveFolderId: 'folder_67890',
      companyName: 'The Percentage Company LLC',
      spreadsheetUrl: 'https://docs.google.com/spreadsheets/d/sheet_12345/edit',
      folderUrl: 'https://drive.google.com/drive/folders/folder_67890',
    );

    final json = config.toJson();
    final deserialized = WorkspaceConfig.fromJson(json);

    expect(deserialized.spreadsheetId, equals('sheet_12345'));
    expect(deserialized.driveFolderId, equals('folder_67890'));
    expect(deserialized.companyName, equals('The Percentage Company LLC'));
    expect(deserialized.spreadsheetUrl, equals('https://docs.google.com/spreadsheets/d/sheet_12345/edit'));
    expect(deserialized.folderUrl, equals('https://drive.google.com/drive/folders/folder_67890'));
  });

  test('GoogleWorkspaceService persists and clears workspace preferences', () async {
    const email = 'user@example.com';
    const config = WorkspaceConfig(
      spreadsheetId: 'sheet_abc',
      driveFolderId: 'folder_def',
      companyName: 'Acme FZ LLC',
    );

    var loaded = await GoogleWorkspaceService.loadSavedWorkspace(email);
    expect(loaded, isNull);

    await GoogleWorkspaceService.saveWorkspace(email, config);
    loaded = await GoogleWorkspaceService.loadSavedWorkspace(email);
    expect(loaded, isNotNull);
    expect(loaded!.companyName, equals('Acme FZ LLC'));
    expect(loaded.spreadsheetId, equals('sheet_abc'));

    await GoogleWorkspaceService.clearSavedWorkspace(email);
    loaded = await GoogleWorkspaceService.loadSavedWorkspace(email);
    expect(loaded, isNull);
  });

  test('GoogleWorkspaceService standardSubfolders contains 5 core directories', () {
    expect(
      GoogleWorkspaceService.standardSubfolders,
      equals(['Invoices', 'Quotations', 'Payroll', 'Assets', 'Reports']),
    );
  });

  test('GoogleWorkspaceService detectSubfolder routes files accurately', () {
    // Invoices
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'INV-2026-000001.pdf'), equals('Invoices'));
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'invoice_tax.pdf'), equals('Invoices'));
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'payment_receipt_REC12.pdf'), equals('Invoices'));

    // Quotations
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'QT-TPC-2026-000001.pdf'), equals('Quotations'));
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'QTN-2026-000005.pdf'), equals('Quotations'));
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'quotation_draft.pdf'), equals('Quotations'));

    // Payroll
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'Payslip_EMP001_2026-09.pdf'), equals('Payroll'));
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'payroll_summary.pdf'), equals('Payroll'));
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'attendance_report.pdf'), equals('Payroll'));

    // Reports
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'Financial_Report_2026-09.pdf'), equals('Reports'));
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'Finance-2026-09.pdf'), equals('Reports'));
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'pnl_statement.pdf'), equals('Reports'));
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'balance_sheet_2026.pdf'), equals('Reports'));
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'vat_return_q3.pdf'), equals('Reports'));

    // Assets
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'company_logo.png', mimeType: 'image/png'), equals('Assets'));
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'asset_photo.jpg', mimeType: 'image/jpeg'), equals('Assets'));
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'shareholder_agreement.pdf'), equals('Assets'));

    // Explicit category override
    expect(GoogleWorkspaceService.detectSubfolder(fileName: 'custom.pdf', category: 'Quotations'), equals('Quotations'));
  });

  test('GoogleDirect repositories report isDemo as false', () {
    final session = GoogleSession();
    final billingRepo = GoogleDirectBillingRepository(session);
    final officeRepo = GoogleDirectOfficeRepository(session);
    final quotationRepo = GoogleDirectQuotationRepository(session);

    expect(billingRepo.isDemo, isFalse);
    expect(officeRepo.isDemo, isFalse);
    expect(quotationRepo.isDemo, isFalse);
  });

  testWidgets('CompanyOnboardingView mounts with iOS styling and form fields', (tester) async {
    final session = GoogleSession();

    await tester.pumpWidget(
      MaterialApp(
        home: CompanyOnboardingView(session: session),
      ),
    );

    expect(find.text('Workspace Setup'), findsOneWidget);
    expect(find.text('Company Legal Name'), findsOneWidget);
    expect(find.text('Invoice Prefix'), findsOneWidget);
    expect(find.text('Quotation Prefix'), findsOneWidget);
    expect(find.text('Provision Google Workspace'), findsOneWidget);
  });
}
