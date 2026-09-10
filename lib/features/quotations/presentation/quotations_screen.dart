import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/stat_card.dart';
import '../../billing/domain/totals.dart';
import '../../billing/presentation/billing_cubit.dart';
import '../../billing/presentation/editors.dart';
import '../data/quotation_pdf.dart';
import '../domain/quotation.dart';
import 'quotation_cubit.dart';
import 'quotation_editor.dart';

class QuotationsView extends StatefulWidget {
  final VoidCallback? onNewQuotation;

  const QuotationsView({super.key, this.onNewQuotation});

  @override
  State<QuotationsView> createState() => _QuotationsViewState();
}

class _QuotationsViewState extends State<QuotationsView> {
  String _searchQuery = '';
  String _statusFilter = 'all';

  final List<Map<String, dynamic>> _filterOptions = [
    {'id': 'all', 'label': 'All Quotes', 'icon': CupertinoIcons.square_grid_2x2_fill},
    {'id': 'draft', 'label': 'Drafts', 'icon': CupertinoIcons.doc_text},
    {'id': 'sent', 'label': 'Sent', 'icon': CupertinoIcons.paperplane_fill},
    {'id': 'accepted', 'label': 'Accepted', 'icon': CupertinoIcons.checkmark_alt_circle_fill},
    {'id': 'converted', 'label': 'Converted', 'icon': CupertinoIcons.arrow_right_circle_fill},
    {'id': 'declined', 'label': 'Declined', 'icon': CupertinoIcons.xmark_circle_fill},
  ];

  Future<void> _openEditor([Quotation? quotation]) async {
    final billing = context.read<BillingCubit>().state.data;
    if (billing.customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one customer before creating a quotation.')),
      );
      return;
    }

    final cubit = context.read<QuotationCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: context.read<BillingCubit>()),
          ],
          child: QuotationEditor(quotation: quotation),
        ),
      ),
    );
  }

  Future<void> _previewPdf(Quotation quotation) async {
    final pdfService = PdfQuotationDocumentService();
    try {
      final bytes = await pdfService.render(quotation);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 800,
            height: 700,
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  'Quotation ${quotation.number.isNotEmpty ? quotation.number : "(Draft)"}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              body: PdfPreview(
                build: (format) => bytes,
                allowPrinting: true,
                allowSharing: true,
                canChangeOrientation: false,
                canChangePageFormat: false,
                initialPageFormat: PdfPageFormat.a4,
                pdfFileName: 'Quotation_${quotation.number.isNotEmpty ? quotation.number : "Draft"}.pdf',
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate PDF: $e')),
        );
      }
    }
  }

  Future<void> _convertToInvoice(Quotation quotation) async {
    final billingCubit = context.read<BillingCubit>();
    final quotationCubit = context.read<QuotationCubit>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(CupertinoIcons.arrow_right_arrow_left_circle_fill, color: AppTheme.pastelTeal),
            SizedBox(width: 10),
            Text('Convert to Invoice?'),
          ],
        ),
        content: Text(
          'This will generate an official invoice draft in the Billing module for ${quotation.customer.name} and mark this quotation as Converted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.pastelTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: const Text('Convert Now'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final invoice = await quotationCubit.convertToInvoice(quotation, billingCubit);
      if (invoice != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice draft created for ${quotation.customer.name}!'),
            action: SnackBarAction(
              label: 'Open Invoice',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider.value(
                      value: billingCubit,
                      child: InvoiceEditor(invoice: invoice),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _duplicateQuotation(Quotation q) async {
    final cubit = context.read<QuotationCubit>();
    final duplicate = q.copyWith(
      id: const Uuid().v4(),
      number: '',
      status: 'draft',
      date: DateTime.now().toIso8601String().substring(0, 10),
      version: 0,
      convertedInvoiceId: '',
      issuedAt: '',
    );

    final ok = await cubit.save(duplicate);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotation duplicated as new draft.')),
      );
    }
  }

  Future<void> _updateStatus(Quotation q, String newStatus) async {
    final cubit = context.read<QuotationCubit>();
    final ok = await cubit.updateStatus(q.id, newStatus);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to ${newStatus.toUpperCase()}')),
      );
    }
  }

  Future<void> _deleteQuotation(Quotation q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Quotation?'),
        content: Text('Are you sure you want to permanently delete quotation ${q.number.isNotEmpty ? q.number : "(Draft)"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.pastelRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final ok = await context.read<QuotationCubit>().delete(q.id);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation deleted.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cubitState = context.watch<QuotationCubit>().state;
    final allQuotations = cubitState.quotations;

    // Filter & Search
    final filtered = allQuotations.where((q) {
      if (_statusFilter != 'all' && q.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchNum = q.number.toLowerCase().contains(query);
        final matchCustomer = q.customer.name.toLowerCase().contains(query);
        final matchNotes = q.notes.toLowerCase().contains(query);
        if (!matchNum && !matchCustomer && !matchNotes) return false;
      }
      return true;
    }).toList();

    // Metrics computation
    int totalQuotations = allQuotations.length;
    int acceptedValue = 0;
    int pendingValue = 0;
    int acceptedCount = 0;

    for (final q in allQuotations) {
      try {
        final t = QuotationTotals.of(q);
        if (q.status == 'accepted' || q.status == 'converted') {
          acceptedValue += t.total;
          acceptedCount++;
        } else if (q.status == 'sent' || q.status == 'draft') {
          pendingValue += t.total;
        }
      } catch (_) {}
    }

    final conversionRate = totalQuotations > 0 ? ((acceptedCount / totalQuotations) * 100).toStringAsFixed(0) : '0';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header & Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Title Bar (Responsive)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 540;
                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Quotations & Estimates',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Commercial proposals & customer estimates',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () => _openEditor(),
                              icon: const Icon(CupertinoIcons.plus, size: 16),
                              label: const Text('New Quotation'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.pastelTeal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quotations & Estimates',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Commercial proposals, price estimates & customer quotes',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          FilledButton.icon(
                            onPressed: () => _openEditor(),
                            icon: const Icon(CupertinoIcons.plus, size: 16),
                            label: const Text('New Quotation'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.pastelTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Hero Stat Cards (Apple Health/Finance Squircle Style)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      return isWide
                          ? Row(
                              children: [
                                Expanded(
                                  child: StatCard(
                                    title: 'Total Quotes',
                                    value: '$totalQuotations',
                                    subtitle: 'Issued to date',
                                    icon: CupertinoIcons.doc_chart,
                                    accentColor: AppTheme.pastelTeal,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: StatCard(
                                    title: 'Accepted Value',
                                    value: money(acceptedValue),
                                    subtitle: '$acceptedCount proposals won',
                                    icon: CupertinoIcons.checkmark_seal_fill,
                                    accentColor: AppTheme.pastelMint,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: StatCard(
                                    title: 'Pending Pipeline',
                                    value: money(pendingValue),
                                    subtitle: 'Awaiting client review',
                                    icon: CupertinoIcons.clock_fill,
                                    accentColor: AppTheme.pastelOrange,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: StatCard(
                                    title: 'Win Rate',
                                    value: '$conversionRate%',
                                    subtitle: 'Quote to invoice ratio',
                                    icon: CupertinoIcons.chart_pie_fill,
                                    accentColor: AppTheme.pastelPurple,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: StatCard(
                                        title: 'Total Quotes',
                                        value: '$totalQuotations',
                                        subtitle: 'Issued to date',
                                        icon: CupertinoIcons.doc_chart,
                                        accentColor: AppTheme.pastelTeal,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: StatCard(
                                        title: 'Accepted Value',
                                        value: money(acceptedValue),
                                        subtitle: '$acceptedCount proposals',
                                        icon: CupertinoIcons.checkmark_seal_fill,
                                        accentColor: AppTheme.pastelMint,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: StatCard(
                                        title: 'Pending Pipeline',
                                        value: money(pendingValue),
                                        subtitle: 'Awaiting client',
                                        icon: CupertinoIcons.clock_fill,
                                        accentColor: AppTheme.pastelOrange,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: StatCard(
                                        title: 'Win Rate',
                                        value: '$conversionRate%',
                                        subtitle: 'Quote to invoice',
                                        icon: CupertinoIcons.chart_pie_fill,
                                        accentColor: AppTheme.pastelPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Search Bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search quotations by number, customer, notes...',
                      prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),

                  const SizedBox(height: 14),

                  // Status Filter Pill Chips (iOS Segmented Control Style)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterOptions.map((f) {
                        final isSelected = _statusFilter == f['id'];
                        final count = f['id'] == 'all'
                            ? allQuotations.length
                            : allQuotations.where((q) => q.status == f['id']).length;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(
                              f['icon'] as IconData,
                              size: 14,
                              color: isSelected ? Colors.white : AppTheme.pastelTeal,
                            ),
                            label: Text(
                              '${f['label']} ($count)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.pastelTeal,
                            backgroundColor: isDark ? AppTheme.iosDarkSurfaceElevated : AppTheme.iosLightSurfaceElevated,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                              side: BorderSide(
                                color: isSelected ? AppTheme.pastelTeal : (isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder),
                                width: 0.5,
                              ),
                            ),
                            onSelected: (_) => setState(() => _statusFilter = f['id'] as String),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quotation Inset Grouped List
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: CupertinoIcons.doc_text,
                title: _searchQuery.isNotEmpty ? 'No Matching Quotations' : 'No Quotations Yet',
                message: _searchQuery.isNotEmpty
                    ? 'Try adjusting your search terms or filter.'
                    : 'Create your first price quotation or proposal to send to clients.',
                actionLabel: 'New Quotation',
                onAction: () => _openEditor(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final quote = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildQuotationCard(quote, isDark),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 60),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationCard(Quotation q, bool isDark) {
    int total = 0;
    try {
      total = QuotationTotals.of(q).total;
    } catch (_) {}

    final isExpired = q.validUntil.isNotEmpty &&
        q.validUntil.compareTo(DateTime.now().toIso8601String().substring(0, 10)) < 0 &&
        q.status != 'accepted' &&
        q.status != 'converted';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusVal),
        side: BorderSide(
          color: isDark ? AppTheme.zohoDarkBorder : AppTheme.zohoLightBorder,
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: () => _openEditor(q),
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusVal),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon Squircle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.pastelTeal.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.doc_on_clipboard_fill,
                  color: AppTheme.pastelTeal,
                  size: 22,
                ),
              ),

              const SizedBox(width: 14),

              // Title, Customer & Expiry
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            q.number.isNotEmpty ? q.number : 'Draft Quotation',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(q.status, isExpired),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      q.customer.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          'Issued: ${q.date}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                          ),
                        ),
                        if (q.validUntil.isNotEmpty)
                          Text(
                            '• Valid until: ${q.validUntil}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isExpired ? FontWeight.w600 : FontWeight.normal,
                              color: isExpired
                                  ? AppTheme.pastelRose
                                  : (isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Amount & Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _previewPdf(q),
                        icon: const Icon(CupertinoIcons.printer_fill, size: 18),
                        tooltip: 'View & Print PDF',
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(CupertinoIcons.ellipsis_vertical, size: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onSelected: (action) {
                          switch (action) {
                            case 'pdf':
                              _previewPdf(q);
                              break;
                            case 'convert':
                              _convertToInvoice(q);
                              break;
                            case 'edit':
                              _openEditor(q);
                              break;
                            case 'duplicate':
                              _duplicateQuotation(q);
                              break;
                            case 'accept':
                              _updateStatus(q, 'accepted');
                              break;
                            case 'sent':
                              _updateStatus(q, 'sent');
                              break;
                            case 'decline':
                              _updateStatus(q, 'declined');
                              break;
                            case 'delete':
                              _deleteQuotation(q);
                              break;
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'pdf',
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.printer, size: 16),
                                SizedBox(width: 10),
                                Text('View / Print PDF'),
                              ],
                            ),
                          ),
                          if (q.status != 'converted')
                            const PopupMenuItem(
                              value: 'convert',
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.arrow_right_arrow_left, size: 16, color: AppTheme.pastelTeal),
                                  SizedBox(width: 10),
                                  Text('Convert to Invoice', style: TextStyle(color: AppTheme.pastelTeal, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.pencil, size: 16),
                                SizedBox(width: 10),
                                Text('Edit Quotation'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.doc_on_doc, size: 16),
                                SizedBox(width: 10),
                                Text('Duplicate Quotation'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          if (q.status != 'accepted')
                            const PopupMenuItem(
                              value: 'accept',
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.checkmark_alt_circle, size: 16, color: AppTheme.pastelMint),
                                  SizedBox(width: 10),
                                  Text('Mark as Accepted'),
                                ],
                              ),
                            ),
                          if (q.status != 'sent')
                            const PopupMenuItem(
                              value: 'sent',
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.paperplane, size: 16, color: AppTheme.pastelBlue),
                                  SizedBox(width: 10),
                                  Text('Mark as Sent'),
                                ],
                              ),
                            ),
                          if (q.status != 'declined')
                            const PopupMenuItem(
                              value: 'decline',
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.xmark_circle, size: 16, color: AppTheme.pastelRose),
                                  SizedBox(width: 10),
                                  Text('Mark as Declined'),
                                ],
                              ),
                            ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.trash, size: 16, color: AppTheme.pastelRose),
                                SizedBox(width: 10),
                                Text('Delete', style: TextStyle(color: AppTheme.pastelRose)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isExpired) {
    if (isExpired) {
      return const AppBadge(
        label: 'EXPIRED',
        variant: BadgeVariant.danger,
        icon: CupertinoIcons.exclamationmark_circle_fill,
      );
    }

    switch (status) {
      case 'accepted':
        return const AppBadge(
          label: 'ACCEPTED',
          variant: BadgeVariant.success,
          icon: CupertinoIcons.checkmark_alt_circle_fill,
        );
      case 'sent':
        return const AppBadge(
          label: 'SENT',
          variant: BadgeVariant.info,
          icon: CupertinoIcons.paperplane_fill,
        );
      case 'converted':
        return const AppBadge(
          label: 'CONVERTED',
          variant: BadgeVariant.info,
          icon: CupertinoIcons.arrow_right_circle_fill,
        );
      case 'declined':
        return const AppBadge(
          label: 'DECLINED',
          variant: BadgeVariant.danger,
          icon: CupertinoIcons.xmark_circle_fill,
        );
      case 'draft':
      default:
        return const AppBadge(
          label: 'DRAFT',
          variant: BadgeVariant.warning,
          icon: CupertinoIcons.doc_text_fill,
        );
    }
  }
}

