import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/features/billing/data/local_repository.dart';
import 'package:tpc_invoice/features/billing/domain/models.dart';
import 'package:tpc_invoice/features/billing/presentation/billing_cubit.dart';
import 'package:tpc_invoice/features/quotations/data/local_quotation_repository.dart';
import 'package:tpc_invoice/features/quotations/data/quotation_pdf.dart';
import 'package:tpc_invoice/features/quotations/domain/quotation.dart';
import 'package:tpc_invoice/features/quotations/presentation/quotation_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const sampleCustomer = Customer(
    id: 'cust_1',
    name: 'Al Futtaim Group',
    email: 'procurement@alfuttaim.ae',
    phone: '+971 4 123 4567',
    address: 'Festival City, Dubai',
    trn: '100200300400003',
  );

  const sampleCompany = Company(
    name: 'The Percentage FZ LLC',
    prefix: 'TPC',
    trn: '100999888777003',
  );

  test('QuotationTotals correctly computes subtotal, 5% VAT and discount', () {
    const quote = Quotation(
      id: 'q1',
      date: '2026-09-09',
      validUntil: '2026-10-09',
      customer: sampleCustomer,
      company: sampleCompany,
      items: [
        LineItem(description: 'Software Architecture Consulting', quantity: '2', rate: '5000.00'),
        LineItem(description: 'Cloud Migration Setup', quantity: '1', rate: '2500.00'),
      ],
      discount: '500.00',
      taxRate: '5.00',
    );

    final t = QuotationTotals.of(quote);

    // Subtotal: (2 * 5000) + (1 * 2500) = 12500.00 AED -> 1,250,000 cents
    expect(t.subtotal, 1250000);
    // Discount: 500.00 AED -> 50,000 cents
    expect(t.discount, 50000);
    // Net: 1,200,000 cents
    // 5% VAT: (1,200,000 * 500 + 5000) ~/ 10000 = 60,000 cents (600.00 AED)
    expect(t.tax, 60000);
    // Grand Total: 1,200,000 + 60,000 = 1,260,000 cents (12,600.00 AED)
    expect(t.total, 1260000);
  });

  test('LocalQuotationRepository persists, issues sequential numbers, and deletes', () async {
    final repo = LocalQuotationRepository();
    var list = await repo.load();
    expect(list, isEmpty);

    const quote = Quotation(
      id: 'q_test_1',
      date: '2026-09-09',
      customer: sampleCustomer,
      company: sampleCompany,
      items: [LineItem(description: 'Design Mockups', quantity: '1', rate: '3000.00')],
    );

    // Save draft
    final saved = await repo.save(quote);
    expect(saved.version, 1);
    expect(saved.status, 'draft');

    list = await repo.load();
    expect(list.length, 1);
    expect(list.first.id, 'q_test_1');

    // Issue quotation
    final issued = await repo.issue(saved);
    expect(issued.number, startsWith('QT-TPC-'));
    expect(issued.status, 'sent');
    expect(issued.issuedAt, isNotEmpty);

    // Update status
    final accepted = await repo.updateStatus(issued.id, 'accepted');
    expect(accepted.status, 'accepted');

    // Delete
    await repo.delete(accepted.id);
    list = await repo.load();
    expect(list, isEmpty);
  });

  test('PdfQuotationDocumentService renders valid A4 PDF document', () async {
    const quote = Quotation(
      id: 'q_pdf_1',
      number: 'QT-TPC-2026-000001',
      date: '2026-09-09',
      validUntil: '2026-10-09',
      customer: sampleCustomer,
      company: sampleCompany,
      items: [
        LineItem(description: 'Full-Stack Web App Development', quantity: '1', rate: '15000.00'),
        LineItem(description: 'DevOps & CI/CD Pipelines', quantity: '1', rate: '5000.00'),
      ],
      discount: '1000.00',
      taxRate: '5.00',
      status: 'sent',
    );

    final service = PdfQuotationDocumentService();
    final pdfBytes = await service.render(quote);

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.length, greaterThan(1000));
  });

  test('QuotationCubit converts accepted quotation directly to Invoice draft in Billing', () async {
    final billingRepo = LocalRepository();
    final billingCubit = BillingCubit(billingRepo);
    await billingCubit.refresh();

    final quoteRepo = LocalQuotationRepository();
    final quotationCubit = QuotationCubit(quoteRepo);

    const quote = Quotation(
      id: 'q_convert_1',
      number: 'QT-TPC-2026-000042',
      date: '2026-09-09',
      validUntil: '2026-10-09',
      customer: sampleCustomer,
      company: sampleCompany,
      items: [
        LineItem(description: 'Mobile App Frontend Architecture', quantity: '1', rate: '8000.00'),
      ],
      status: 'accepted',
    );

    await quotationCubit.save(quote);

    final invoice = await quotationCubit.convertToInvoice(quote, billingCubit);
    expect(invoice, isNotNull);
    expect(invoice!.customer.name, 'Al Futtaim Group');
    expect(invoice.items.first.description, 'Mobile App Frontend Architecture');
    expect(invoice.status, 'draft');

    // Quotation should now be marked as converted
    final updatedQuotes = await quoteRepo.load();
    final convertedQuote = updatedQuotes.firstWhere((x) => x.id == 'q_convert_1');
    expect(convertedQuote.status, 'converted');
    expect(convertedQuote.convertedInvoiceId, invoice.id);
  });
}
