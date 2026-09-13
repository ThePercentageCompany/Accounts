import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/features/billing/domain/totals.dart';
import 'package:tpc_invoice/features/office/data/local_office_repository.dart';
import 'package:tpc_invoice/features/office/domain/office_repository.dart';
import 'package:tpc_invoice/features/office/presentation/capital_equity_screen.dart';
import 'package:tpc_invoice/features/office/presentation/office_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Capital Transactions & Office Repository Tests', () {
    test('Large capital scaling handles corporate amounts up to 10 billion AED', () {
      final scaledAmount = scaled('5000000.00', 2); // 5 Million AED
      expect(scaledAmount, 500000000);

      final scaledBillion = scaled('1000000000.00', 2); // 1 Billion AED
      expect(scaledBillion, 100000000000);
    });

    test('LocalOfficeRepository saves cash capital transaction and generates balanced journal', () async {
      final repo = LocalOfficeRepository();
      
      // Save shareholder
      await repo.command('shareholderSave', {
        'id': 'SHR-001',
        'name': 'Founder Alice',
        'ownershipPercentage': 100.0,
        'agreedCapital': 500000.0,
      });

      // Save capital contribution
      await repo.command('capitalTransactionSave', {
        'id': 'CAP-001',
        'shareholderId': 'SHR-001',
        'shareholderName': 'Founder Alice',
        'transactionType': 'capitalContribution',
        'contributionType': 'bank',
        'amount': '150000.00',
        'amountCents': 15000000,
        'bankAccountId': 'Bank',
        'date': '2026-09-13',
      });

      final rawData = await repo.command('officeLoad');
      final data = OfficeData.fromJson(rawData);
      expect(data.capitalTransactions.length, 1);
      final cap = data.capitalTransactions.first;
      expect(cap['amountCents'], 15000000);
      expect(cap['shareholderName'], 'Founder Alice');
      expect(cap['journalId'], isNotNull);

      // Verify journal
      final journals = data.journals;
      final journal = journals.firstWhere((j) => j['id'] == cap['journalId']);
      expect(journal['totalDebitCents'], 15000000);
      expect(journal['totalCreditCents'], 15000000);
      expect(journal['isBalanced'], isTrue);
    });

    test('LocalOfficeRepository edits capital transaction and replaces journal entry cleanly', () async {
      final repo = LocalOfficeRepository();

      await repo.command('shareholderSave', {
        'id': 'SHR-002',
        'name': 'Founder Bob',
        'ownershipPercentage': 100.0,
        'agreedCapital': 200000.0,
      });

      // Initial save: 50,000 AED
      await repo.command('capitalTransactionSave', {
        'id': 'CAP-002',
        'shareholderId': 'SHR-002',
        'shareholderName': 'Founder Bob',
        'transactionType': 'capitalContribution',
        'contributionType': 'cash',
        'amount': '50000.00',
        'amountCents': 5000000,
        'bankAccountId': 'Cash',
        'date': '2026-09-13',
      });

      var rawData = await repo.command('officeLoad');
      var data = OfficeData.fromJson(rawData);
      final initialJournalId = data.capitalTransactions.first['journalId'];
      expect(data.journals.where((j) => j['id'] == initialJournalId).length, 1);
      expect(data.journals.firstWhere((j) => j['id'] == initialJournalId)['totalDebitCents'], 5000000);

      // Edit save: updated to 75,000 AED
      await repo.command('capitalTransactionSave', {
        'id': 'CAP-002',
        'shareholderId': 'SHR-002',
        'shareholderName': 'Founder Bob',
        'transactionType': 'capitalContribution',
        'contributionType': 'cash',
        'amount': '75000.00',
        'amountCents': 7500000,
        'bankAccountId': 'Cash',
        'date': '2026-09-13',
      });

      rawData = await repo.command('officeLoad');
      data = OfficeData.fromJson(rawData);
      expect(data.capitalTransactions.length, 1);
      expect(data.capitalTransactions.first['amountCents'], 7500000);
      // Ensure only 1 active journal exists for this transaction (old was replaced)
      final newJournalId = data.capitalTransactions.first['journalId'];
      expect(data.journals.where((j) => j['id'] == initialJournalId).isEmpty, isTrue);
      expect(data.journals.where((j) => j['id'] == newJournalId).length, 1);
      expect(data.journals.firstWhere((j) => j['id'] == newJournalId)['totalDebitCents'], 7500000);
    });

    test('LocalOfficeRepository deletes capital transaction and removes its journal entry', () async {
      final repo = LocalOfficeRepository();

      await repo.command('capitalTransactionSave', {
        'id': 'CAP-003',
        'shareholderId': 'SHR-003',
        'shareholderName': 'Founder Charlie',
        'transactionType': 'capitalContribution',
        'contributionType': 'bank',
        'amount': '30000.00',
        'amountCents': 3000000,
        'bankAccountId': 'Bank',
        'date': '2026-09-13',
      });

      var rawData = await repo.command('officeLoad');
      var data = OfficeData.fromJson(rawData);
      expect(data.capitalTransactions.length, 1);
      final journalId = data.capitalTransactions.first['journalId'];
      expect(data.journals.where((j) => j['id'] == journalId).length, 1);

      await repo.command('capitalTransactionDelete', {'id': 'CAP-003'});

      rawData = await repo.command('officeLoad');
      data = OfficeData.fromJson(rawData);
      expect(data.capitalTransactions.isEmpty, isTrue);
      expect(data.journals.where((j) => j['id'] == journalId).isEmpty, isTrue);
    });

    test('OfficeCubit.runBatch executes multiple sequential commands without dropping due to busy state', () async {
      final repo = LocalOfficeRepository();
      final cubit = OfficeCubit(repo);

      final success = await cubit.runBatch([
        const MapEntry('shareholderSave', {
          'id': 'SHR-004',
          'name': 'Partner Dave',
          'ownershipPercentage': 50.0,
          'agreedCapital': 100000.0,
        }),
        const MapEntry('assetSave', {
          'id': 'AST-004',
          'name': 'Studio Camera',
          'costCents': 2500000,
          'acquisitionType': 'shareholderContribution',
          'shareholderId': 'SHR-004',
          'skipJournal': true,
        }),
        const MapEntry('capitalTransactionSave', {
          'id': 'CAP-004',
          'shareholderId': 'SHR-004',
          'shareholderName': 'Partner Dave',
          'transactionType': 'capitalContribution',
          'contributionType': 'asset',
          'assetName': 'Studio Camera',
          'amountCents': 2500000,
          'amount': '25000.00',
          'date': '2026-09-13',
        }),
      ]);

      expect(success, isTrue);

      final data = cubit.state.data;
      expect(data.shareholders.where((s) => s['id'] == 'SHR-004').length, 1);
      expect(data.assets.where((a) => a['id'] == 'AST-004').length, 1);
      expect(data.capitalTransactions.where((c) => c['id'] == 'CAP-004').length, 1);

      // Only ONE journal created for the contribution (asset skipped duplicating it)
      expect(data.journals.length, 1);
      expect(data.journals.first['lines'].first['accountId'], 'fixed_asset');
    });

    testWidgets('CapitalEquityScreen records contribution and saves transaction seamlessly in UI', (tester) async {
      final repo = LocalOfficeRepository();
      final cubit = OfficeCubit(repo);
      await cubit.run();

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OfficeCubit>.value(
            value: cubit,
            child: const CapitalEquityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Contributions tab
      await tester.tap(find.text('Contributions'));
      await tester.pumpAndSettle();

      // Click "Record Contribution"
      await tester.tap(find.text('Record Contribution'));
      await tester.pumpAndSettle();

      // Verify modal is displayed
      expect(find.text('Record Capital Contribution'), findsOneWidget);
      expect(find.text('Save Transaction'), findsOneWidget);

      // Enter Shareholder Name and Amount
      await tester.enterText(find.widgetWithText(TextField, 'Shareholder Full Name *'), 'Elena Rostova');
      await tester.enterText(find.widgetWithText(TextField, 'Amount (AED) *'), '45000.00');
      await tester.pumpAndSettle();

      // Click "Save Transaction"
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();

      // Verify dialog closed and contribution is visible in list
      expect(find.text('Record Capital Contribution'), findsNothing);
      expect(find.text('Elena Rostova'), findsOneWidget);
      expect(find.text('+AED 45000.00'), findsOneWidget);
    });
  });
}
