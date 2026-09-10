import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/theme/app_theme.dart';
import 'package:tpc_invoice/features/billing/data/invoice_pdf.dart';
import 'package:tpc_invoice/features/billing/data/local_repository.dart';
import 'package:tpc_invoice/features/billing/domain/invoice_document_service.dart';
import 'package:tpc_invoice/features/billing/presentation/billing_cubit.dart';
import 'package:tpc_invoice/features/quotations/data/local_quotation_repository.dart';
import 'package:tpc_invoice/features/quotations/presentation/quotation_cubit.dart';
import 'package:tpc_invoice/features/quotations/presentation/quotation_editor.dart';

void main() {
  testWidgets('QuotationEditor mounts with split layout and live preview on desktop', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final billingRepo = LocalRepository();
    final billingCubit = BillingCubit(billingRepo);
    await billingCubit.refresh();

    final quoteRepo = LocalQuotationRepository();
    final quoteCubit = QuotationCubit(quoteRepo);
    await quoteCubit.refresh();

    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: billingCubit),
          BlocProvider.value(value: quoteCubit),
          RepositoryProvider<InvoiceDocumentService>(create: (_) => PdfInvoiceDocumentService()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const QuotationEditor(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Create Quotation'), findsWidgets);
    expect(find.text('Quotation Information'), findsOneWidget);
    expect(find.text('Quotation Items & Scope'), findsOneWidget);
    expect(find.text('Quotation Preview'), findsOneWidget);
    expect(find.textContaining('Terms & Commercial Conditions'), findsWidgets);

    await tester.ensureVisible(find.text('Save as Draft'));
    expect(find.text('Save as Draft'), findsOneWidget);
    expect(find.text('Save & Send'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);

    await billingCubit.close();
    await quoteCubit.close();
  });
}
