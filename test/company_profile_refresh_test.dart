import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/features/billing/data/local_repository.dart';
import 'package:tpc_invoice/features/billing/domain/models.dart';
import 'package:tpc_invoice/features/billing/presentation/billing_cubit.dart';
import 'package:tpc_invoice/features/billing/presentation/editors.dart';

void main() {
  testWidgets('profile accepts a synced logo while retaining unsaved text', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = BillingCubit(LocalRepository());
    addTearDown(cubit.close);
    const before = Company(name: 'Original company');
    const png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l1cAAAAASUVORK5CYII=';

    Future<void> show(Company company) => tester.pumpWidget(
      BlocProvider.value(value: cubit, child: MaterialApp(home: Scaffold(
        body: CompanyEditor(company: company),
      ))),
    );
    await show(before);
    final name = find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'Company Name');
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Unsaved company name');
    await show(before.copyWith(logo: png, logoDriveUrl: 'https://drive.google.com/file/d/logo/view', version: 1));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved company name'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    expect(tester.takeException(), isNull);
  });
}
