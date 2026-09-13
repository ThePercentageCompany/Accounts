import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/auth/google_session.dart';
import 'package:tpc_invoice/features/office/data/hybrid_office_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fixed asset CRUD replaces its acquisition journal and removes it on delete', () async {
    final session = GoogleSession();
    await session.useOfflineDemo();
    final repository = HybridOfficeRepository(session);

    final created = await repository.command('assetSave', {
      'id': 'AST-001',
      'name': 'Studio Camera',
      'code': 'CAM-001',
      'category': 'Cameras & Photography',
      'acquisitionType': 'companyPurchase',
      'paymentAccount': 'Bank',
      'cost': '7500.00',
      'residualValue': '500.00',
      'purchaseDate': '2026-09-13',
      'usefulLifeMonths': 36,
      'status': 'active',
    });
    expect(created['costCents'], 750000);
    expect(created['journalId'], isNotEmpty);

    var loaded = await repository.command('officeLoad');
    expect((loaded['assets'] as List).length, 1);
    expect((loaded['journals'] as List).where((j) => j['sourceId'] == 'AST-001').length, 1);

    final edited = await repository.command('assetSave', {
      ...created,
      'cost': '8000.00',
      'residualValue': '500.00',
      'purchaseDate': '2026-09-13',
      'usefulLifeMonths': 36,
    });
    expect(edited['costCents'], 800000);

    loaded = await repository.command('officeLoad');
    final journals = loaded['journals'] as List;
    expect(journals.where((j) => j['sourceId'] == 'AST-001').length, 1);
    expect(journals.singleWhere((j) => j['sourceId'] == 'AST-001')['totalDebitCents'], 800000);

    await repository.command('assetDelete', {'id': 'AST-001'});
    loaded = await repository.command('officeLoad');
    expect((loaded['assets'] as List), isEmpty);
    expect((loaded['journals'] as List).where((j) => j['sourceId'] == 'AST-001'), isEmpty);
  });
}
