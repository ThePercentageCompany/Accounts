import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/billing/data/invoice_pdf.dart';
import 'package:tpc_invoice/features/billing/data/local_repository.dart';
import 'package:tpc_invoice/features/billing/domain/invoice_document_service.dart';
import 'package:tpc_invoice/features/billing/presentation/billing_cubit.dart';
import 'package:tpc_invoice/features/billing/presentation/editors.dart';

void main() {
  testWidgets('InvoiceEditor mounts with split layout and live preview on desktop', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalRepository();
    final cubit = BillingCubit(repository);
    await cubit.refresh();

    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          RepositoryProvider<InvoiceDocumentService>(create: (_) => PdfInvoiceDocumentService()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const InvoiceEditor(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Create Invoice'), findsWidgets);
    expect(find.text('Invoice Information'), findsOneWidget);
    expect(find.text('Invoice Items'), findsOneWidget);
    expect(find.text('Invoice Preview'), findsOneWidget);
    expect(find.textContaining('Terms & Conditions'), findsWidgets);
    expect(find.text('Save as Draft'), findsOneWidget);
    expect(find.text('Save & Send'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);

    await cubit.close();
  });
}
