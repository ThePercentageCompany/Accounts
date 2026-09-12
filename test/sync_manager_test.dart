import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/sync/sync_manager.dart';
import 'package:tpc_invoice/core/sync/sheet_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SyncManager initializes with clean state', () async {
    final manager = SyncManager.instance;
    await manager.initialize();

    expect(manager.pendingCount, 0);
    expect(manager.status, SyncStatus.synced);
  });

  test('SyncManager caches and retrieves tab records', () async {
    final manager = SyncManager.instance;
    await manager.initialize();

    const spreadsheetId = 'sheet_test_123';
    const tabName = 'Invoices';

    await manager.saveCachedRecords(spreadsheetId, tabName, [
      {'id': 'inv_1', 'number': 'INV-001', 'total': 100},
      {'id': 'inv_2', 'number': 'INV-002', 'total': 250},
    ]);

    final records = await manager.loadCachedRecords(spreadsheetId, tabName);
    expect(records.length, 2);
    expect(records[0]['id'], 'inv_1');
    expect(records[1]['number'], 'INV-002');

    // Test upsert
    await manager.upsertCachedRecord(spreadsheetId, tabName, 'inv_3', {
      'id': 'inv_3',
      'number': 'INV-003',
      'total': 500,
    });

    final updatedRecords = await manager.loadCachedRecords(spreadsheetId, tabName);
    expect(updatedRecords.length, 3);
    expect(updatedRecords.any((r) => r['id'] == 'inv_3'), isTrue);

    // Test delete
    await manager.deleteCachedRecord(spreadsheetId, tabName, 'inv_1');
    final afterDelete = await manager.loadCachedRecords(spreadsheetId, tabName);
    expect(afterDelete.length, 2);
    expect(afterDelete.any((r) => r['id'] == 'inv_1'), isFalse);
  });

  test('SyncManager enqueues offline operations and updates status', () async {
    final manager = SyncManager.instance;
    await manager.initialize();

    const spreadsheetId = 'sheet_test_123';
    await manager.enqueueOperation(
      spreadsheetId: spreadsheetId,
      tabName: 'Customers',
      recordId: 'cust_99',
      action: 'upsert',
      data: {'id': 'cust_99', 'name': 'Acme Corp'},
    );

    expect(manager.pendingCount, 1);
    expect(manager.status, SyncStatus.pendingChanges);

    // Compacts duplicate updates for same record
    await manager.enqueueOperation(
      spreadsheetId: spreadsheetId,
      tabName: 'Customers',
      recordId: 'cust_99',
      action: 'upsert',
      data: {'id': 'cust_99', 'name': 'Acme Corporation Updated'},
    );

    expect(manager.pendingCount, 1);
    expect(manager.pendingQueue.first.data?['name'], 'Acme Corporation Updated');
  });

  group('SheetSchema Multi-Column Formatting & Field Mapping Tests', () {
    test('All 16 sheet tabs have explicit human-readable headers', () {
      expect(SheetSchema.allTabs.length, 16);
      for (final tab in SheetSchema.allTabs) {
        final headers = SheetSchema.getHeaders(tab);
        expect(headers.isNotEmpty, isTrue, reason: '$tab must have headers');
        expect(headers.first, anyOf(contains('ID'), contains('Key')), reason: '$tab first header should be an ID or Key');
      }
    });

    test('Customers tab serializes every field into dedicated columns and deserializes cleanly', () {
      final customer = {
        'id': 'cust_001',
        'name': 'Percentage Tech Corp',
        'email': 'tech@percentage.ae',
        'phone': '+971 4 555 1234',
        'trn': '100200300400003',
        'address': 'DIFC Tower 2, Dubai',
        'version': 3,
      };

      final row = SheetSchema.recordToRow('Customers', customer);
      expect(row[0], 'cust_001');
      expect(row[1], 'Percentage Tech Corp');
      expect(row[2], 'tech@percentage.ae');
      expect(row[3], '+971 4 555 1234');
      expect(row[4], '100200300400003');
      expect(row[5], 'DIFC Tower 2, Dubai');
      expect(row[6], 3);

      final reconstructed = SheetSchema.rowToRecord('Customers', row);
      expect(reconstructed['id'], 'cust_001');
      expect(reconstructed['name'], 'Percentage Tech Corp');
      expect(reconstructed['email'], 'tech@percentage.ae');
      expect(reconstructed['trn'], '100200300400003');
    });

    test('Finance tab maps amount, VAT, and status to individual columns', () {
      final entry = {
        'id': 'exp_99',
        'date': '2026-09-11',
        'kind': 'expense',
        'category': 'Cloud Infrastructure',
        'description': 'AWS & Vercel Hosting',
        'amountCents': 250000,
        'vatPercent': 5.0,
        'vatCents': 12500,
        'status': 'paid',
        'paidDate': '2026-09-11',
        'account': 'Bank',
        'supplier': 'Amazon Web Services',
        'invoiceRef': 'INV-AWS-2026-09',
        'notes': 'Monthly production hosting',
        'version': 1,
      };

      final row = SheetSchema.recordToRow('Finance', entry);
      expect(row[0], 'exp_99');
      expect(row[1], '2026-09-11');
      expect(row[2], 'EXPENSE');
      expect(row[3], 'Cloud Infrastructure');
      expect(row[4], 'AWS & Vercel Hosting');
      expect(row[5], '2500.00'); // AED amount
      expect(row[6], '5.0'); // VAT %
      expect(row[7], '125.00'); // VAT AED
      expect(row[8], '2625.00'); // Total AED
      expect(row[9], 'PAID');
      expect(row[12], 'Bank');
      expect(row[13], 'Amazon Web Services');

      final reconstructed = SheetSchema.rowToRecord('Finance', row);
      expect(reconstructed['id'], 'exp_99');
      expect(reconstructed['category'], 'Cloud Infrastructure');
      expect(reconstructed['amountCents'], 250000);
    });

    test('Shareholders and Capital Transactions format financial data cleanly', () {
      final shareholder = {
        'id': 'sh_101',
        'name': 'Fatima Al Suwaidi',
        'role': 'Founding Partner',
        'sharesPercent': '35.0',
        'investedAmount': '175000.00',
        'date': '2026-01-01',
        'email': 'fatima@tpc.ae',
        'phone': '+971501234567',
        'status': 'active',
      };

      final row = SheetSchema.recordToRow('Shareholders', shareholder);
      expect(row[0], 'sh_101');
      expect(row[1], 'Fatima Al Suwaidi');
      expect(row[2], 'Founding Partner');
      expect(row[3], '35.00');
      expect(row[4], '175000.00');
      final capTx = {
        'id': 'ctx_55',
        'date': '2026-09-10',
        'shareholderId': 'sh_101',
        'shareholderName': 'Fatima Al Suwaidi',
        'transactionType': 'capitalContribution',
        'contributionType': 'cash',
        'amount': '50000.00',
        'assetName': '',
        'account': 'Bank',
        'status': 'completed',
        'reference': 'DEP-2026-0910',
      };

      final capRow = SheetSchema.recordToRow('CapitalTransactions', capTx);
      expect(capRow[0], 'ctx_55');
      expect(capRow[1], '2026-09-10');
      expect(capRow[2], 'sh_101');
      expect(capRow[3], 'Fatima Al Suwaidi');
      expect(capRow[4], 'CAPITALCONTRIBUTION');
      expect(capRow[5], 'CASH');
      expect(capRow[6], '50000.00');
      expect(capRow[8], 'Bank');
      expect(capRow[9], 'COMPLETED');

      final reconstructedSh = SheetSchema.rowToRecord('Shareholders', row);
      expect(reconstructedSh['id'], 'sh_101');
      expect(reconstructedSh['name'], 'Fatima Al Suwaidi');
      expect(reconstructedSh['ownershipPercentage'], 35.0);
      expect(reconstructedSh['agreedCapital'], 175000.0);

      final reconstructedCap = SheetSchema.rowToRecord('CapitalTransactions', capRow);
      expect(reconstructedCap['id'], 'ctx_55');
      expect(reconstructedCap['shareholderName'], 'Fatima Al Suwaidi');
      expect(reconstructedCap['amountCents'], 5000000);
      expect(reconstructedCap['transactionType'], 'capitalContribution');
    });

    test('getColLetter accurately computes column letters across boundaries', () {
      expect(SheetSchema.getColLetter(1), 'A');
      expect(SheetSchema.getColLetter(2), 'B');
      expect(SheetSchema.getColLetter(26), 'Z');
      expect(SheetSchema.getColLetter(27), 'AA');
      expect(SheetSchema.getColLetter(28), 'AB');
    });

    test('Settings tab maps Company data to dedicated columns and deserializes cleanly', () {
      final companyPayload = {
        'id': 'company',
        'value': {
          'name': 'The Percentage Company FZ LLC',
          'email': 'accounts@thepercentage.com',
          'phone': '+971 4 123 4567',
          'trn': '100456789000003',
          'prefix': 'TPC-2026',
          'address': 'Level 14, Boulevard Plaza Tower 1, Downtown Dubai, UAE',
          'bank': 'Emirates NBD',
          'accountHolder': 'The Percentage Company FZ LLC',
          'accountNumber': '1012345678901',
          'iban': 'AE0702600001012345678901',
          'terms': 'Payment due within 14 calendar days from invoice date.',
          'notes': 'Thank you for choosing The Percentage Company.',
          'version': 5,
        }
      };

      final row = SheetSchema.recordToRow('Settings', companyPayload);
      expect(row[0], 'company');
      expect(row[1], 'The Percentage Company FZ LLC');
      expect(row[2], 'accounts@thepercentage.com');
      expect(row[3], '+971 4 123 4567');
      expect(row[4], '100456789000003');
      expect(row[5], 'TPC-2026');
      expect(row[6], 'Level 14, Boulevard Plaza Tower 1, Downtown Dubai, UAE');
      expect(row[7], 'Emirates NBD');
      expect(row[8], 'The Percentage Company FZ LLC');
      expect(row[9], '1012345678901');
      expect(row[10], 'AE0702600001012345678901');
      expect(row[11], 'Payment due within 14 calendar days from invoice date.');
      expect(row[12], 'Thank you for choosing The Percentage Company.');
      expect(row[13], 5);

      // Reconstructed directly from dedicated scalar columns
      final reconstructed = SheetSchema.rowToRecord('Settings', row);
      expect(reconstructed['id'], 'company');
      final val = reconstructed['value'] as Map<String, dynamic>;
      expect(val['name'], 'The Percentage Company FZ LLC');
      expect(val['trn'], '100456789000003');
      expect(val['iban'], 'AE0702600001012345678901');

      // Reconstructed from partial column row (e.g. row created/edited manually in Google Sheets)
      final rowPartial = row.sublist(0, 14);
      final reconstructedFromCols = SheetSchema.rowToRecord('Settings', rowPartial);
      expect(reconstructedFromCols['id'], 'company');
      final valFromCols = reconstructedFromCols['value'] as Map<String, dynamic>;
      expect(valFromCols['name'], 'The Percentage Company FZ LLC');
      expect(valFromCols['email'], 'accounts@thepercentage.com');
      expect(valFromCols['phone'], '+971 4 123 4567');
      expect(valFromCols['trn'], '100456789000003');
      expect(valFromCols['prefix'], 'TPC-2026');
      expect(valFromCols['bank'], 'Emirates NBD');
      expect(valFromCols['accountHolder'], 'The Percentage Company FZ LLC');
      expect(valFromCols['accountNumber'], '1012345678901');
      expect(valFromCols['iban'], 'AE0702600001012345678901');
      expect(valFromCols['terms'], 'Payment due within 14 calendar days from invoice date.');
      expect(valFromCols['notes'], 'Thank you for choosing The Percentage Company.');
      expect(valFromCols['version'], 5);
    });

    test('rowToRecord provides backwards compatibility for legacy 2-column [ID, JSON] rows', () {
      final legacyRow = [
        'cust_legacy_1',
        '{"id":"cust_legacy_1","name":"Legacy Client","email":"legacy@client.com","trn":"998877"}'
      ];

      final record = SheetSchema.rowToRecord('Customers', legacyRow);
      expect(record['id'], 'cust_legacy_1');
      expect(record['name'], 'Legacy Client');
      expect(record['email'], 'legacy@client.com');
      expect(record['trn'], '998877');
    });
  });
}
