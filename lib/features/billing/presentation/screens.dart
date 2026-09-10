import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/models.dart';
import '../domain/totals.dart';
import '../domain/invoice_document_service.dart';
import 'billing_cubit.dart';
import 'editors.dart';

String today() => DateTime.now().toIso8601String().substring(0, 10);

Future<void> showPdf(BuildContext context, Invoice invoice, {Payment? receipt}) async {
  final bytes = await context.read<InvoiceDocumentService>().render(invoice, receipt: receipt);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(receipt != null ? 'Payment Receipt' : invoice.number.isEmpty ? 'Draft Preview' : invoice.number),
        ),
        body: PdfPreview(
          build: (_) => bytes,
          pdfFileName: '${invoice.number.isEmpty ? 'Draft' : invoice.number}${receipt != null ? '-receipt-${receipt.id}' : ''}.pdf',
          allowPrinting: true,
          allowSharing: true,
          canChangeOrientation: false,
          canChangePageFormat: false,
        ),
      ),
    ),
  );
}

class InvoicesView extends StatefulWidget {
  final VoidCallback onNewInvoice;
  final bool isOverview;

  const InvoicesView({
    super.key,
    required this.onNewInvoice,
    this.isOverview = false,
  });

  @override
  State<InvoicesView> createState() => _InvoicesViewState();
}

class _InvoicesViewState extends State<InvoicesView> {
  String query = '';
  String filterStatus = 'all'; // all, unpaid, paid, overdue, draft

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, state) {
        final all = state.data.invoices;
        final issued = all.where((i) => i.status == 'issued');
        final revenue = issued.fold<int>(0, (sum, i) => sum + Totals.of(i).total);
        final paid = issued.fold<int>(0, (sum, i) => sum + Totals.of(i).paid);
        final outstanding = revenue - paid;
        final overdueCount = issued.where((i) => Totals.of(i).balance > 0 && i.dueDate.isNotEmpty && i.dueDate.compareTo(today()) < 0).length;

        // Filter invoices
        final filtered = all.where((i) {
          final matchesQuery = '${i.number} ${i.customer.name} ${i.status}'.toLowerCase().contains(query.toLowerCase());
          if (!matchesQuery) return false;

          final balance = Totals.of(i).balance;
          final isOverdue = i.status == 'issued' && balance > 0 && i.dueDate.isNotEmpty && i.dueDate.compareTo(today()) < 0;

          if (filterStatus == 'unpaid') return i.status == 'issued' && balance > 0 && !isOverdue;
          if (filterStatus == 'paid') return i.status == 'issued' && balance == 0;
          if (filterStatus == 'overdue') return isOverdue;
          if (filterStatus == 'draft') return i.status == 'draft';
          return true;
        }).toList()..sort((a, b) => b.date.compareTo(a.date));

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // KPI Summary Cards
            if (widget.isOverview) ...[
              _buildAppleHeroCard(context, state, isDark),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth > 900
                      ? (constraints.maxWidth - 36) / 3
                      : constraints.maxWidth > 600
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth;

                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: StatCard(
                          title: 'TOTAL INVOICED',
                          value: money(revenue),
                          icon: CupertinoIcons.doc_text,
                          accentColor: AppTheme.pastelBlue,
                          subtitle: '${issued.length} issued invoices',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: StatCard(
                          title: 'COLLECTED REVENUE',
                          value: money(paid),
                          icon: CupertinoIcons.checkmark_seal_fill,
                          accentColor: AppTheme.pastelMint,
                          progress: revenue > 0 ? paid / revenue : 0,
                          subtitle: '${revenue > 0 ? (paid * 100 ~/ revenue) : 0}% recovery rate',
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: StatCard(
                          title: 'OUTSTANDING BALANCE',
                          value: money(outstanding),
                          icon: CupertinoIcons.clock,
                          accentColor: overdueCount > 0 ? AppTheme.pastelRose : AppTheme.pastelOrange,
                          subtitle: overdueCount > 0 ? '$overdueCount overdue invoices' : 'All accounts current',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Invoices',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                  ),
                  TextButton.icon(
                    onPressed: widget.onNewInvoice,
                    icon: const Icon(CupertinoIcons.plus, size: 16),
                    label: const Text('New Invoice'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invoices',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                      ),
                      Text(
                        'Manage, track and collect customer invoices.',
                        style: TextStyle(
                          color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                          fontSize: 14,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: widget.onNewInvoice,
                    icon: const Icon(CupertinoIcons.plus_circle_fill, size: 16),
                    label: const Text('New Invoice'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.pastelBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],

            // iOS Search Bar
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                decoration: InputDecoration(
                  fillColor: Colors.transparent,
                  prefixIcon: const Icon(CupertinoIcons.search, size: 18, color: Colors.grey),
                  hintText: 'Search customer, invoice #, status...',
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Colors.grey),
                          onPressed: () => setState(() => query = ''),
                        )
                      : null,
                ),
                onChanged: (s) => setState(() => query = s),
              ),
            ),
            const SizedBox(height: 14),

            // iOS Segmented Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterSegment('all', 'All (${all.length})', isDark),
                  _filterSegment('unpaid', 'Unpaid', isDark),
                  _filterSegment('paid', 'Paid', isDark),
                  _filterSegment('overdue', 'Overdue ($overdueCount)', isDark),
                  _filterSegment('draft', 'Drafts', isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Invoices List
            if (filtered.isEmpty)
              EmptyState(
                icon: CupertinoIcons.doc_text,
                title: query.isNotEmpty || filterStatus != 'all' ? 'No matching invoices' : 'No invoices yet',
                message: query.isNotEmpty || filterStatus != 'all'
                    ? 'Try searching with different terms or changing status filter.'
                    : 'Create your first invoice to bill customers and collect payments.',
                actionLabel: query.isEmpty && filterStatus == 'all' ? 'New Invoice' : null,
                onAction: query.isEmpty && filterStatus == 'all' ? widget.onNewInvoice : null,
              )
            else
              for (final invoice in filtered) ...[
                _buildInvoiceCard(context, invoice, isDark),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }

  Widget _buildAppleHeroCard(BuildContext context, BillingState state, bool isDark) {
    final companyName = state.data.company.name.isNotEmpty ? state.data.company.name : 'TPC Business';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;

        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0F264A), const Color(0xFF111827)]
                  : [AppTheme.zohoBlue, AppTheme.zohoBlueDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.cardRadiusVal),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : AppTheme.zohoBlue).withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.badgeRadiusVal),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.calendar, size: 12, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            today(),
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      companyName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Executive Invoicing, Billing, People & Corporate Finance.',
                      style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: -0.1),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: widget.onNewInvoice,
                      icon: const Icon(CupertinoIcons.plus, size: 16, color: AppTheme.zohoBlue),
                      label: const Text('New Invoice', style: TextStyle(color: AppTheme.zohoBlue, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppTheme.badgeRadiusVal),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(CupertinoIcons.calendar, size: 12, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  today(),
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            companyName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Executive Invoicing, Billing, People & Corporate Finance.',
                            style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: -0.1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    FilledButton.icon(
                      onPressed: widget.onNewInvoice,
                      icon: const Icon(CupertinoIcons.plus, size: 16, color: AppTheme.zohoBlue),
                      label: const Text('Invoice', style: TextStyle(color: AppTheme.zohoBlue, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _filterSegment(String key, String label, bool isDark) {
    final isSelected = filterStatus == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => filterStatus = key),
        borderRadius: BorderRadius.circular(AppTheme.badgeRadiusVal),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.zohoBlue
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(AppTheme.badgeRadiusVal),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary),
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(BuildContext context, Invoice invoice, bool isDark) {
    final cubit = context.read<BillingCubit>();
    final totals = Totals.of(invoice);
    final isIssued = invoice.status == 'issued';
    final isOverdue = isIssued && totals.balance > 0 && invoice.dueDate.isNotEmpty && invoice.dueDate.compareTo(today()) < 0;

    String statusText;
    if (invoice.status == 'draft') {
      statusText = 'Draft';
    } else if (totals.balance == 0) {
      statusText = 'Paid';
    } else if (isOverdue) {
      statusText = 'Overdue';
    } else {
      statusText = 'Unpaid';
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusVal),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: InkWell(
        onTap: () {
          if (invoice.status == 'draft') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(value: cubit, child: InvoiceEditor(invoice: invoice)),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(value: cubit, child: InvoiceDetail(id: invoice.id)),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              // Customer Avatar Squircle
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.pastelBlueBgDark : AppTheme.pastelBlueBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    invoice.customer.name.isNotEmpty ? invoice.customer.name.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.pastelBlue,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            invoice.number.isEmpty ? 'Draft Invoice' : invoice.number,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppBadge.status(statusText, isSmall: true),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${invoice.customer.name} • ${invoice.date}${invoice.dueDate.isNotEmpty ? ' • Due ${invoice.dueDate}' : ''}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Amount & Chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(totals.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (totals.paid > 0 && totals.balance > 0)
                    Text(
                      'Bal: ${money(totals.balance)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isOverdue ? AppTheme.pastelRose : AppTheme.pastelOrange,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomersView extends StatefulWidget {
  const CustomersView({super.key});

  @override
  State<CustomersView> createState() => _CustomersViewState();
}

class _CustomersViewState extends State<CustomersView> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, state) {
        final customers = state.data.customers
            .where((c) => '${c.name} ${c.email} ${c.phone} ${c.trn}'.toLowerCase().contains(search.toLowerCase()))
            .toList();

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customers',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                    ),
                    Text(
                      'Client directory, contact info and tax registrations.',
                      style: TextStyle(
                        color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                        fontSize: 14,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: state.busy ? null : () => editCustomer(context),
                  icon: const Icon(CupertinoIcons.person_add_solid, size: 16),
                  label: const Text('Add Customer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.pastelBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                decoration: InputDecoration(
                  fillColor: Colors.transparent,
                  prefixIcon: const Icon(CupertinoIcons.search, size: 18, color: Colors.grey),
                  hintText: 'Search customers by name, email, phone or TRN...',
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Colors.grey),
                          onPressed: () => setState(() => search = ''),
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => search = v),
              ),
            ),
            const SizedBox(height: 16),

            if (customers.isEmpty)
              EmptyState(
                icon: CupertinoIcons.person_2,
                title: search.isNotEmpty ? 'No matching customers' : 'No customers added yet',
                message: search.isNotEmpty
                    ? 'Check your search query or add a new customer record.'
                    : 'Add your clients to issue invoices and track receivables.',
                actionLabel: search.isEmpty ? 'Add Customer' : null,
                onAction: search.isEmpty ? () => editCustomer(context) : null,
              )
            else
              for (final c in customers) ...[
                _buildCustomerCard(context, c, isDark),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }

  Widget _buildCustomerCard(BuildContext context, Customer c, bool isDark) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000), width: 0.8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.pastelPurpleBgDark : AppTheme.pastelPurpleBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              c.name.isNotEmpty ? c.name.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.pastelPurple,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.2)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (c.email.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.mail, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(c.email, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                if (c.phone.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.phone, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(c.phone, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                if (c.trn.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('TRN: ${c.trn}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            if (c.address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                c.address,
                style: TextStyle(fontSize: 12, color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: const Icon(CupertinoIcons.chevron_forward, size: 16, color: Colors.grey),
        onTap: () => editCustomer(context, c),
      ),
    );
  }
}

class InvoiceDetail extends StatelessWidget {
  final String id;
  const InvoiceDetail({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, state) {
        final c = context.read<BillingCubit>();
        final matches = state.data.invoices.where((x) => x.id == id);
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Invoice')),
            body: const Center(child: Text('Invoice not found.')),
          );
        }
        final invoice = matches.first;
        final totals = Totals.of(invoice);
        final isIssued = invoice.status == 'issued';
        final isOverdue = isIssued && totals.balance > 0 && invoice.dueDate.isNotEmpty && invoice.dueDate.compareTo(today()) < 0;

        Future<void> guarded(Future<void> Function() action) async {
          final ok = await c.run(action);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c.state.error ?? 'Operation failed')));
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(invoice.number.isEmpty ? 'Draft Invoice' : invoice.number),
            actions: [
              IconButton(
                tooltip: 'Preview / Print / Share PDF',
                icon: const Icon(CupertinoIcons.doc_plaintext),
                onPressed: state.busy ? null : () => guarded(() => showPdf(context, invoice)),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Apple Wallet / Card Style Balance Hero
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [const Color(0xFF007AFF), const Color(0xFF5856D6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.black : AppTheme.pastelBlue).withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invoice.customer.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Issued ${invoice.date}${invoice.dueDate.isNotEmpty ? ' • Due ${invoice.dueDate}' : ''}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            AppBadge.status(
                              invoice.status == 'draft'
                                  ? 'Draft'
                                  : totals.balance == 0
                                      ? 'Paid'
                                      : isOverdue
                                          ? 'Overdue'
                                          : 'Unpaid',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BALANCE DUE',
                                  style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  money(totals.balance),
                                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total: ${money(totals.total)}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                Text(
                                  'Paid: ${money(totals.paid)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(
                            value: totals.total > 0 ? (totals.paid / totals.total).clamp(0.0, 1.0) : 0,
                            minHeight: 6,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.pastelMint),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Action Buttons Toolbar
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: state.busy ? null : () => guarded(() => showPdf(context, invoice)),
                        icon: const Icon(CupertinoIcons.printer_fill, size: 16),
                        label: const Text('Print / PDF / Share'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.pastelBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                      ),
                      if (invoice.status == 'issued' && totals.balance > 0)
                        FilledButton.icon(
                          onPressed: state.busy ? null : () => recordPayment(context, invoice),
                          icon: const Icon(CupertinoIcons.money_dollar_circle_fill, size: 16),
                          label: const Text('Record Payment'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.pastelMint,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: state.busy || c.repository.isDemo
                            ? null
                            : () => guarded(() async {
                                  final bytes = await context.read<InvoiceDocumentService>().render(invoice);
                                  await c.repository.archive(invoice, bytes);
                                }),
                        icon: const Icon(CupertinoIcons.cloud_upload, size: 16),
                        label: Text(invoice.archivedVersion == invoice.version ? 'PDF Archived' : 'Save to Drive'),
                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                      ),
                      if (invoice.driveUrl.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => launchUrl(Uri.parse(invoice.driveUrl), mode: LaunchMode.externalApplication),
                          icon: const Icon(CupertinoIcons.arrow_up_right_square, size: 15),
                          label: const Text('Open in Drive'),
                        ),
                      if (invoice.status == 'issued' && invoice.payments.isEmpty)
                        TextButton(
                          onPressed: state.busy
                              ? null
                              : () async {
                                  final yes = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Void this invoice?'),
                                      content: const Text(
                                        'The invoice number stays in your records as voided. Create a new invoice for a replacement.',
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        FilledButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: FilledButton.styleFrom(backgroundColor: AppTheme.pastelRose),
                                          child: const Text('Void invoice'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (yes == true) {
                                    await guarded(() async => await c.repository.voidInvoice(invoice));
                                  }
                                },
                          child: const Text('Void invoice', style: TextStyle(color: AppTheme.pastelRose)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Line Items Section
                  const Text('Line Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  const SizedBox(height: 10),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000), width: 0.8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          for (int i = 0; i < invoice.items.length; i++) ...[
                            if (i > 0) const Divider(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        invoice.items[i].description,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: -0.1),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${invoice.items[i].quantity} × ${money(scaled(invoice.items[i].rate, 2))}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  money(lineTotal(invoice.items[i])),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Payment History Section
                  const Text('Payment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  const SizedBox(height: 10),
                  if (invoice.payments.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Center(
                          child: Text(
                            'No payments recorded yet.',
                            style: TextStyle(
                              color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    for (final p in invoice.payments) ...[
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000), width: 0.8),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.pastelMintBgDark : AppTheme.pastelMintBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(CupertinoIcons.checkmark_alt, size: 18, color: AppTheme.pastelMint),
                            ),
                          ),
                          title: Text(
                            '${money(p.cents)} on ${p.date}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, letterSpacing: -0.2),
                          ),
                          subtitle: Text(
                            'Account: ${p.account}${p.reference.isNotEmpty ? ' • Ref: ${p.reference}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Payment receipt',
                                icon: const Icon(CupertinoIcons.doc_text, size: 19),
                                onPressed: state.busy ? null : () => guarded(() => showPdf(context, invoice, receipt: p)),
                              ),
                              if (!c.repository.isDemo)
                                IconButton(
                                  tooltip: 'Archive receipt to Drive',
                                  icon: const Icon(CupertinoIcons.cloud_upload, size: 19),
                                  onPressed: state.busy
                                      ? null
                                      : () => guarded(() async {
                                            final bytes = await context.read<InvoiceDocumentService>().render(invoice, receipt: p);
                                            await c.repository.archive(invoice, bytes, paymentId: p.id);
                                          }),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> recordPayment(BuildContext context, Invoice invoice) async {
  final form = GlobalKey<FormState>();
  String amount = '';
  String reference = '';
  String date = today();
  String account = 'Bank';
  final cubit = context.read<BillingCubit>();

  final payment = await showDialog<Payment>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Record Payment'),
      content: Form(
        key: form,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: account,
                decoration: const InputDecoration(labelText: 'Received into'),
                items: const [
                  DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                ],
                onChanged: (v) => account = v!,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.pastelMintBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Outstanding balance:', style: TextStyle(color: AppTheme.pastelMint, fontWeight: FontWeight.w600)),
                    Text(money(Totals.of(invoice).balance), style: const TextStyle(color: AppTheme.pastelMint, fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Amount (AED)',
                  prefixIcon: Icon(CupertinoIcons.money_dollar, size: 18),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => amount = v,
                validator: (v) {
                  try {
                    final n = scaled(v ?? '', 2);
                    return n <= 0 || n > Totals.of(invoice).balance
                        ? 'Enter an amount within the outstanding balance'
                        : null;
                  } catch (e) {
                    return 'Enter a valid amount';
                  }
                },
              ),
              const SizedBox(height: 12),
              DatePickerField(
                label: 'Payment date',
                value: date,
                onChanged: (v) => date = v,
                isRequired: true,
                validator: validateDate,
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Reference / payment method (optional)',
                  prefixIcon: Icon(CupertinoIcons.tag, size: 18),
                ),
                maxLength: 200,
                onChanged: (v) => reference = v,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(
                ctx,
                Payment(
                  id: const Uuid().v4(),
                  cents: scaled(amount, 2),
                  date: date,
                  reference: reference,
                  account: account,
                ),
              );
            }
          },
          style: FilledButton.styleFrom(backgroundColor: AppTheme.pastelBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
          child: const Text('Save Payment'),
        ),
      ],
    ),
  );

  if (payment != null) {
    Invoice? updated;
    final ok = await cubit.run(() async {
      updated = await cubit.repository.pay(invoice, payment);
    });
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cubit.state.error ?? 'Payment failed')));
      return;
    }
    if (!cubit.repository.isDemo && updated != null) {
      final renderer = context.read<InvoiceDocumentService>();
      final archived = await cubit.run(() async {
        await cubit.repository.archive(updated!, await renderer.render(updated!));
        await cubit.repository.archive(updated!, await renderer.render(updated!, receipt: payment), paymentId: payment.id);
      });
      if (!archived && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment saved. PDF archive failed. Use Save PDF to Drive to retry.')),
        );
      }
    }
  }
}
