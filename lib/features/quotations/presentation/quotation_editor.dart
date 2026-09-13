import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/date_field.dart';
import '../../billing/domain/models.dart';
import '../../billing/presentation/billing_cubit.dart';
import '../../billing/presentation/editors.dart';
import '../data/quotation_pdf.dart';
import '../domain/quotation.dart';
import 'quotation_cubit.dart';

class QuotationEditor extends StatefulWidget {
  final Quotation? quotation;

  const QuotationEditor({super.key, this.quotation});

  @override
  State<QuotationEditor> createState() => _QuotationEditorState();
}

class _QuotationEditorState extends State<QuotationEditor> {
  final _formKey = GlobalKey<FormState>();
  bool _dirty = false;

  late String _id;
  late String _number;
  late String _date;
  late String _validUntil;
  late String _status;
  Customer? _customer;
  late Company _company;
  late List<Map<String, String>> _rows;
  late String _discount;
  late String _taxRate;
  late String _notes;
  late String _terms;
  late int _version;
  late String _convertedInvoiceId;
  late String _issuedAt;

  String _reference = '';
  String _validityTerms = '30 Days';
  String _currency = 'AED - UAE Dirham (د.إ)';
  int _mobileTab = 0; // 0 = Edit Form, 1 = Live Preview

  @override
  void initState() {
    super.initState();
    final billing = context.read<BillingCubit>().state.data;
    final old = widget.quotation;

    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);
    final expiryStr = now.add(const Duration(days: 30)).toIso8601String().substring(0, 10);

    if (old != null) {
      _id = old.id;
      _number = old.number;
      _date = old.date;
      _validUntil = old.validUntil;
      _status = old.status;
      _customer = old.customer;
      _company = old.company;
      _discount = old.discount.isNotEmpty ? old.discount : '0.00';
      _taxRate = old.taxRate.isNotEmpty ? old.taxRate : '5.00';
      _notes = old.notes;
      _terms = old.terms;
      _version = old.version;
      _convertedInvoiceId = old.convertedInvoiceId;
      _issuedAt = old.issuedAt;

      _rows = old.items
          .map((x) => {
                'key': const Uuid().v4(),
                'description': x.description,
                'quantity': x.quantity,
                'rate': x.rate,
                'discount': '0.00',
                'vat': old.taxRate.isNotEmpty ? old.taxRate : '5',
              })
          .toList();
    } else {
      _id = const Uuid().v4();
      _number = '';
      _date = todayStr;
      _validUntil = expiryStr;
      _status = 'draft';
      _customer = billing.customers.isNotEmpty ? billing.customers.first : null;
      _company = billing.company;
      _discount = '0.00';
      _taxRate = '5.00';
      _notes = 'This quotation is valid for 30 days from issue date.';
      _terms = '1. 50% advance upon confirmation, 50% on project delivery.\n2. Please confirm your acceptance by signing or replying via email.\n3. Thank you for your business!';
      _version = 0;
      _convertedInvoiceId = '';
      _issuedAt = '';

      _rows = [
        {
          'key': const Uuid().v4(),
          'description': 'Website Redesign & UI/UX\nComplete modern accounting UI design and frontend implementation',
          'quantity': '1',
          'rate': '5000.00',
          'discount': '0.00',
          'vat': '5',
        },
        {
          'key': const Uuid().v4(),
          'description': 'Cloud Integration & Sync Setup\nOffline-first synchronization with Google Workspace and secure drive backups',
          'quantity': '1',
          'rate': '2500.00',
          'discount': '0.00',
          'vat': '5',
        },
      ];
    }

    if (_rows.isEmpty) {
      _addRow();
    }
  }

  void _markDirty(VoidCallback fn) {
    setState(() {
      fn();
      _dirty = true;
    });
  }

  void _addRow() {
    _rows.add({
      'key': const Uuid().v4(),
      'description': '',
      'quantity': '1',
      'rate': '0.00',
      'discount': '0.00',
      'vat': _taxRate.isNotEmpty ? _taxRate : '5',
    });
  }

  void _applyValidityTerms(String terms) {
    final baseDate = DateTime.tryParse(_date) ?? DateTime.now();
    DateTime newValid;
    if (terms == '15 Days') {
      newValid = baseDate.add(const Duration(days: 15));
    } else if (terms == '30 Days') {
      newValid = baseDate.add(const Duration(days: 30));
    } else if (terms == '45 Days') {
      newValid = baseDate.add(const Duration(days: 45));
    } else if (terms == '60 Days') {
      newValid = baseDate.add(const Duration(days: 60));
    } else if (terms == 'Due on Receipt') {
      newValid = baseDate;
    } else {
      newValid = baseDate.add(const Duration(days: 30));
    }

    final formatted = newValid.toIso8601String().substring(0, 10);
    _markDirty(() {
      _validityTerms = terms;
      _validUntil = formatted;
    });
  }

  String _cleanNum(String? val, {int decimals = 2, String fallback = '0.00'}) {
    if (val == null || val.trim().isEmpty) return fallback;
    final clean = val.replaceAll(',', '').replaceAll('%', '').trim();
    final d = double.tryParse(clean);
    if (d == null || d.isNaN || d.isInfinite || d < 0) return fallback;
    return d.toStringAsFixed(decimals);
  }

  Quotation _buildQuotation() {
    final lineItems = _rows
        .map((x) {
          final desc = (x['description'] ?? '').trim().isNotEmpty
              ? (x['description'] ?? '').trim()
              : 'Service item';
          final qty = _cleanNum(x['quantity'], decimals: 3, fallback: '1.000');
          final rate = _cleanNum(x['rate'], decimals: 2, fallback: '0.00');
          return LineItem(
            description: desc,
            quantity: qty,
            rate: rate,
          );
        })
        .toList();

    return Quotation(
      id: _id,
      number: _number,
      date: _date,
      validUntil: _validUntil,
      customer: _customer ?? const Customer(id: '', name: 'Customer'),
      company: _company,
      items: lineItems.isEmpty
          ? [const LineItem(description: 'Service item', quantity: '1.000', rate: '0.00')]
          : lineItems,
      discount: _cleanNum(_discount, decimals: 2, fallback: '0.00'),
      taxRate: _cleanNum(_taxRate, decimals: 2, fallback: '5.00'),
      status: _status,
      notes: _notes,
      terms: _terms,
      version: _version,
      convertedInvoiceId: _convertedInvoiceId,
      issuedAt: _issuedAt,
    );
  }

  double _computeRowAmount(Map<String, String> row) {
    try {
      final q = double.tryParse(row['quantity'] ?? '1') ?? 1.0;
      final r = double.tryParse(row['rate'] ?? '0.00') ?? 0.0;
      final d = double.tryParse(row['discount'] ?? '0.00') ?? 0.0;
      return (q * r) - d;
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _previewPdfDialog() async {
    if (_customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a customer first.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final pdfService = PdfQuotationDocumentService();
    try {
      final q = _buildQuotation();
      final bytes = await pdfService.render(q);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadiusVal)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 850,
            height: 750,
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  'Quotation Preview - ${q.number.isNotEmpty ? q.number : "(Draft)"}',
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
                pdfFileName: 'Quotation_${q.number.isNotEmpty ? q.number : "Draft"}.pdf',
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate PDF preview: $e')),
        );
      }
    }
  }

  Future<void> _saveDraft() async {
    if (_customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a customer first.')),
      );
      return;
    }
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<QuotationCubit>();
    final q = _buildQuotation();
    final ok = await cubit.save(q);

    if (ok && mounted) {
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotation saved as draft.')),
      );
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cubit.state.error ?? 'Could not save quotation.')),
      );
    }
  }

  Future<void> _issueQuotation() async {
    if (_customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a customer first.')),
      );
      return;
    }
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadiusVal)),
        title: const Text('Issue & Send Quotation?'),
        content: const Text(
          'An official sequential quotation number will be registered and marked as Sent for client approval.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.zohoBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
            ),
            child: const Text('Issue & Send'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final cubit = context.read<QuotationCubit>();
    final q = _buildQuotation();
    final issued = await cubit.issue(q);

    if (issued != null && mounted) {
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quotation ${issued.number} issued successfully!')),
      );
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cubit.state.error ?? 'Could not issue quotation.')),
      );
    }
  }

  Future<void> _deleteQuotation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Quotation?'),
        content: Text('Are you sure you want to permanently delete quotation ${_number.isNotEmpty ? _number : "(Draft)"}?'),
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
      setState(() => _dirty = false);
      final ok = await context.read<QuotationCubit>().delete(_id);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation deleted.')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1050;

    final billingData = context.watch<BillingCubit>().state.data;
    final customers = billingData.customers;

    QuotationTotals? totals;
    try {
      if (_customer != null) {
        totals = QuotationTotals.of(_buildQuotation());
      }
    } catch (_) {
      totals = null;
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadiusVal)),
            title: const Text('Discard Unsaved Changes?'),
            content: const Text('You have unsaved edits in this quotation. Are you sure you want to discard them?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.zohoRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                ),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (leave == true && mounted) {
          setState(() => _dirty = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.zohoDarkBg : AppTheme.zohoLightBg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Bar & Breadcrumbs
              _buildTopBar(context, isDark),

              // Mobile Tab Switcher (Form vs Live Preview)
              if (!isDesktop) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _mobileTab = 0),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _mobileTab == 0
                                    ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  'Edit Quotation Form',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _mobileTab == 0 ? FontWeight.w700 : FontWeight.w500,
                                    color: _mobileTab == 0
                                        ? (isDark ? Colors.white : AppTheme.zohoBlue)
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _mobileTab = 1),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _mobileTab == 1
                                    ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  'Live Preview',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _mobileTab == 1 ? FontWeight.w700 : FontWeight.w500,
                                    color: _mobileTab == 1
                                        ? (isDark ? Colors.white : AppTheme.zohoBlue)
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // 2. Main Content Body
              Expanded(
                child: Form(
                  key: _formKey,
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Form Column (60% width)
                            Expanded(
                              flex: 6,
                              child: ListView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(24, 8, 16, 32),
                                children: [
                                  _buildQuotationInformationCard(context, isDark, customers),
                                  const SizedBox(height: 18),
                                  _buildQuotationItemsCard(context, isDark),
                                  const SizedBox(height: 18),
                                  _buildTermsAndTotalsCard(context, isDark, totals),
                                  const SizedBox(height: 24),
                                  _buildBottomActionsBar(context, isDark),
                                ],
                              ),
                            ),

                            // Right Live Preview Column (40% width)
                            Expanded(
                              flex: 4,
                              child: ListView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(8, 8, 24, 32),
                                children: [
                                  _buildLivePreviewCard(context, isDark, totals),
                                ],
                              ),
                            ),
                          ],
                        )
                      : (_mobileTab == 0
                          // Mobile Form View
                          ? ListView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              children: [
                                _buildQuotationInformationCard(context, isDark, customers),
                                const SizedBox(height: 16),
                                _buildQuotationItemsCard(context, isDark),
                                const SizedBox(height: 16),
                                _buildTermsAndTotalsCard(context, isDark, totals),
                                const SizedBox(height: 20),
                                _buildBottomActionsBar(context, isDark),
                                const SizedBox(height: 24),
                              ],
                            )
                          // Mobile Preview View
                          : ListView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              children: [
                                _buildLivePreviewCard(context, isDark, totals),
                                const SizedBox(height: 24),
                              ],
                            )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 1. Top Header & Breadcrumbs Bar
  // -------------------------------------------------------------
  Widget _buildTopBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title and Breadcrumb
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.quotation == null ? 'Create Quotation' : 'Edit Quotation',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      'Home',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '>',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      'Quotations',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '>',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  Text(
                    widget.quotation == null ? 'Create Quotation' : 'Edit Quotation',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.zohoBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.quotation != null) ...[
                TextButton.icon(
                  onPressed: _deleteQuotation,
                  icon: const Icon(CupertinoIcons.trash, size: 15, color: AppTheme.pastelRose),
                  label: const Text('Delete Quotation', style: TextStyle(color: AppTheme.pastelRose, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(CupertinoIcons.arrow_left, size: 14),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 2. Quotation Information Card
  // -------------------------------------------------------------
  Widget _buildQuotationInformationCard(BuildContext context, bool isDark, List<Customer> customers) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.zohoCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quotation Information',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;

              // Row 1: Customer & Reference
              final customerCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _customer?.id,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(CupertinoIcons.person, size: 18),
                      hintText: 'Select Customer',
                    ),
                    isExpanded: true,
                    items: [
                      for (final c in customers)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null) {
                        _markDirty(() {
                          _customer = customers.firstWhere((c) => c.id == id);
                        });
                      }
                    },
                    validator: (v) => v == null ? 'Please select a customer' : null,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        await editCustomer(context);
                        if (context.mounted) {
                          final latest = context.read<BillingCubit>().state.data.customers;
                          if (latest.isNotEmpty) {
                            _markDirty(() => _customer = latest.last);
                          }
                        }
                      },
                      icon: const Icon(CupertinoIcons.plus, size: 13, color: AppTheme.zohoBlue),
                      label: const Text(
                        'Add New',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.zohoBlue),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              );

              final referenceCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reference (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: _reference,
                    decoration: const InputDecoration(
                      hintText: 'e.g. RFP-2024-88',
                    ),
                    onChanged: (v) => _markDirty(() => _reference = v),
                  ),
                  const SizedBox(height: 24),
                ],
              );

              // Row 2: Quotation Number & Validity Terms
              final quoteNumCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quotation Number *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: _number.isNotEmpty ? _number : 'QT-2024-001',
                    decoration: const InputDecoration(
                      hintText: 'QT-2024-001',
                    ),
                    onChanged: (v) => _markDirty(() => _number = v),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              );

              final validityTermsCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Validity Terms', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _validityTerms,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: '30 Days', child: Text('30 Days')),
                      DropdownMenuItem(value: '15 Days', child: Text('15 Days')),
                      DropdownMenuItem(value: '45 Days', child: Text('45 Days')),
                      DropdownMenuItem(value: '60 Days', child: Text('60 Days')),
                      DropdownMenuItem(value: 'Due on Receipt', child: Text('Due on Receipt')),
                      DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                    ],
                    onChanged: (v) {
                      if (v != null) _applyValidityTerms(v);
                    },
                  ),
                ],
              );

              // Row 3: Quotation Date & Currency
              final quoteDateCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DatePickerField(
                    label: 'Quotation Date *',
                    value: _date,
                    onChanged: (v) => _markDirty(() {
                      _date = v;
                      _applyValidityTerms(_validityTerms);
                    }),
                    isRequired: true,
                    validator: validateDate,
                  ),
                ],
              );

              final currencyCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Currency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'AED - UAE Dirham (د.إ)', child: Text('AED - UAE Dirham (د.إ)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'USD - US Dollar (\$)', child: Text('USD - US Dollar (\$)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'THB - Thai Baht (฿)', child: Text('THB - Thai Baht (฿)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'EUR - Euro (€)', child: Text('EUR - Euro (€)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'GBP - British Pound (£)', child: Text('GBP - British Pound (£)', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) {
                      if (v != null) _markDirty(() => _currency = v);
                    },
                  ),
                ],
              );

              // Row 4: Valid Until Date & Notes
              final validUntilCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DatePickerField(
                    label: 'Valid Until *',
                    value: _validUntil,
                    onChanged: (v) => _markDirty(() => _validUntil = v),
                    isRequired: true,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Required'
                        : validateDate(v) ?? (v.compareTo(_date) < 0 ? 'Must be on or after quote date' : null),
                  ),
                ],
              );

              final notesCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: _notes,
                    decoration: const InputDecoration(
                      hintText: 'Enter internal notes or remarks...',
                    ),
                    onChanged: (v) => _markDirty(() => _notes = v),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  children: [
                    customerCol,
                    referenceCol,
                    quoteNumCol,
                    const SizedBox(height: 14),
                    validityTermsCol,
                    const SizedBox(height: 14),
                    quoteDateCol,
                    currencyCol,
                    const SizedBox(height: 14),
                    validUntilCol,
                    notesCol,
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: customerCol),
                      const SizedBox(width: 16),
                      Expanded(child: referenceCol),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: quoteNumCol),
                      const SizedBox(width: 16),
                      Expanded(child: validityTermsCol),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: quoteDateCol),
                      const SizedBox(width: 16),
                      Expanded(child: currencyCol),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: validUntilCol),
                      const SizedBox(width: 16),
                      Expanded(child: notesCol),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 3. Quotation Items Table Card
  // -------------------------------------------------------------
  Widget _buildQuotationItemsCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.zohoCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quotation Items & Scope',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                '${_rows.length} item${_rows.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Desktop vs Mobile Table View
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 650;

              if (isSmall) {
                // Mobile stacked item cards
                return Column(
                  children: [
                    for (int n = 0; n < _rows.length; n++) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(AppTheme.cardRadiusVal),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: AppTheme.zohoBlue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${n + 1}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.zohoBlue),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _rows[n]['description'],
                                    decoration: const InputDecoration(
                                      labelText: 'Service / Scope of Work',
                                      hintText: 'e.g. Website Redesign',
                                    ),
                                    onChanged: (v) => _markDirty(() => _rows[n]['description'] = v),
                                  ),
                                ),
                                if (_rows.length > 1) ...[
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.trash, color: AppTheme.zohoRed, size: 18),
                                    onPressed: () => _markDirty(() => _rows.removeAt(n)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: _rows[n]['quantity'],
                                    decoration: const InputDecoration(labelText: 'Qty'),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (v) => _markDirty(() => _rows[n]['quantity'] = v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    initialValue: _rows[n]['rate'],
                                    decoration: const InputDecoration(labelText: 'Unit Price'),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (v) => _markDirty(() => _rows[n]['rate'] = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Amount (AED):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                                Text(
                                  _computeRowAmount(_rows[n]).toStringAsFixed(2),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.zohoBlue),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              // Full Wide Table
              return Table(
                columnWidths: const {
                  0: FixedColumnWidth(26), // #
                  1: FlexColumnWidth(4.2), // Description
                  2: FlexColumnWidth(1.2), // Qty
                  3: FlexColumnWidth(2.2), // Unit Price
                  4: FlexColumnWidth(1.5), // Discount
                  5: FlexColumnWidth(1.8), // VAT
                  6: FlexColumnWidth(2.0), // Amount
                  7: FixedColumnWidth(36), // Action
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  // Header Row
                  TableRow(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    children: [
                      _buildItemsHeader('#', isDark),
                      _buildItemsHeader('Service / Description', isDark),
                      _buildItemsHeader('Quantity', isDark),
                      _buildItemsHeader('Unit Price (AED)', isDark),
                      _buildItemsHeader('Discount', isDark),
                      _buildItemsHeader('VAT (%)', isDark),
                      _buildItemsHeader('Amount (AED)', isDark),
                      _buildItemsHeader('Action', isDark),
                    ],
                  ),

                  // Data Rows
                  for (int n = 0; n < _rows.length; n++)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '${n + 1}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
                          child: TextFormField(
                            initialValue: _rows[n]['description'],
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'Service scope\nDetailed description',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 13),
                            onChanged: (v) => _markDirty(() => _rows[n]['description'] = v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: TextFormField(
                            initialValue: _rows[n]['quantity'],
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => _markDirty(() => _rows[n]['quantity'] = v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: TextFormField(
                            initialValue: _rows[n]['rate'],
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => _markDirty(() => _rows[n]['rate'] = v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: TextFormField(
                            initialValue: _rows[n]['discount'],
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => _markDirty(() => _rows[n]['discount'] = v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: DropdownButtonFormField<String>(
                            initialValue: _rows[n]['vat'] ?? '5',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(value: '5', child: Text('5%', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: '0', child: Text('0%', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: '7', child: Text('7%', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'exempt', child: Text('Exempt', style: TextStyle(fontSize: 11))),
                            ],
                            onChanged: (v) => _markDirty(() {
                              _rows[n]['vat'] = v ?? '5';
                              if (v == '0' || v == 'exempt') {
                                _taxRate = '0';
                              } else if (v != null) {
                                _taxRate = v;
                              }
                            }),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Text(
                            _computeRowAmount(_rows[n]).toStringAsFixed(2),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.trash, color: AppTheme.zohoRed, size: 16),
                          tooltip: 'Delete item',
                          onPressed: _rows.length > 1 ? () => _markDirty(() => _rows.removeAt(n)) : null,
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Add Item Button
          FilledButton.icon(
            onPressed: _rows.length < 30 ? () => _markDirty(_addRow) : null,
            icon: const Icon(CupertinoIcons.plus, size: 14),
            label: const Text('+ Add Item'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.zohoBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 4. Terms & Conditions and Totals Summary Card
  // -------------------------------------------------------------
  Widget _buildTermsAndTotalsCard(BuildContext context, bool isDark, QuotationTotals? totals) {
    final subtotalVal = totals != null ? (totals.subtotal / 100.0) : 0.0;
    final discountVal = totals != null ? (totals.discount / 100.0) : 0.0;
    final vatVal = totals != null ? (totals.tax / 100.0) : 0.0;
    final totalVal = totals != null ? (totals.total / 100.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.zohoCardDecoration(isDark),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          final termsCol = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Terms & Commercial Conditions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _terms,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter commercial terms & payment schedules...',
                ),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
                onChanged: (v) => _markDirty(() => _terms = v),
              ),
            ],
          );

          final totalsCol = Column(
            children: [
              _buildSummaryRow('Subtotal', subtotalVal.toStringAsFixed(2), isDark),
              const SizedBox(height: 8),
              _buildSummaryRow('Discount (AED)', discountVal.toStringAsFixed(2), isDark),
              const SizedBox(height: 8),
              _buildSummaryRow('VAT 5%', vatVal.toStringAsFixed(2), isDark),
              const SizedBox(height: 14),

              // Highlighted Total Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.zohoBlueBgDark : const Color(0xFFEBF3FC),
                  borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal),
                  border: Border.all(
                    color: isDark ? AppTheme.zohoBlue : const Color(0xFFBFDBFE),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total (AED)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.zohoBlueDark,
                      ),
                    ),
                    Text(
                      totalVal.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFF60A5FA) : AppTheme.zohoBlue,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              children: [
                termsCol,
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),
                totalsCol,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: termsCol),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: totalsCol),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String title, String amount, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 5. Bottom Form Actions Bar
  // -------------------------------------------------------------
  Widget _buildBottomActionsBar(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Save as Draft
        OutlinedButton(
          onPressed: _saveDraft,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
          ),
          child: const Text('Save as Draft'),
        ),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview Button
            OutlinedButton.icon(
              onPressed: _previewPdfDialog,
              icon: const Icon(CupertinoIcons.eye, size: 15),
              label: const Text('Preview'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
              ),
            ),
            const SizedBox(width: 10),

            // Save & Send Button
            FilledButton.icon(
              onPressed: _issueQuotation,
              icon: const Icon(CupertinoIcons.paperplane_fill, size: 15),
              label: const Text('Save & Send'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.zohoBlue,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 6. Right Column: Real-Time Live Quotation Preview Card
  // -------------------------------------------------------------
  Widget _buildLivePreviewCard(BuildContext context, bool isDark, QuotationTotals? totals) {
    final subtotalVal = totals != null ? (totals.subtotal / 100.0) : 0.0;
    final vatVal = totals != null ? (totals.tax / 100.0) : 0.0;
    final totalVal = totals != null ? (totals.total / 100.0) : 0.0;

    final company = _company;
    final customer = _customer ?? const Customer(id: '', name: 'Creative Solutions LLC');

    return Container(
      decoration: AppTheme.zohoCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text(
                  'Quotation Preview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _previewPdfDialog,
                  icon: const Icon(CupertinoIcons.arrow_down_to_line, size: 14),
                  label: const Text('Download PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Paper Document Sheet (Clean White Paper matching Mockup)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Document Header: Logo & Details | QUOTATION title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Company Info
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(CupertinoIcons.building_2_fill, color: AppTheme.zohoBlue, size: 24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    company.name.isNotEmpty ? company.name : 'ABC Service LLC',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    company.address.isNotEmpty ? company.address : 'Dubai, United Arab Emirates',
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  ),
                                  if (company.trn.isNotEmpty)
                                    Text('TRN: ${company.trn}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  Text(company.email.isNotEmpty ? company.email : 'info@abcservice.ae', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                  Text(company.phone.isNotEmpty ? company.phone : '+971 50 123 4567', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // QUOTATION title & Meta
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'QUOTATION',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quote No: ${_number.isNotEmpty ? _number : "QT-2024-001"}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          Text('Date: $_date', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                          Text('Valid Until: $_validUntil', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Bill To Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF1F5F9), width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quotation For:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                        const SizedBox(height: 2),
                        Text(
                          customer.name.isNotEmpty ? customer.name : 'Creative Solutions LLC',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          customer.address.isNotEmpty ? customer.address : 'Office 101, Business Bay, Dubai, UAE',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                        ),
                        if (customer.trn.isNotEmpty)
                          Text('TRN: ${customer.trn}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Items Table
                  Table(
                    columnWidths: const {
                      0: FixedColumnWidth(24), // #
                      1: FlexColumnWidth(4.5), // Description
                      2: FlexColumnWidth(1.2), // Qty
                      3: FlexColumnWidth(2.2), // Unit Price
                      4: FlexColumnWidth(2.2), // Amount
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      // Header Row
                      TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
                        ),
                        children: [
                          _buildPreviewHeader('#'),
                          _buildPreviewHeader('Description'),
                          _buildPreviewHeader('Qty', align: TextAlign.center),
                          _buildPreviewHeader('Unit Price\n(AED)', align: TextAlign.right),
                          _buildPreviewHeader('Amount\n(AED)', align: TextAlign.right),
                        ],
                      ),

                      // Item Rows
                      for (int n = 0; n < _rows.length; n++)
                        TableRow(
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC), width: 0.8)),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text('${n + 1}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                              child: Text(
                                _rows[n]['description']?.isNotEmpty == true ? _rows[n]['description']! : 'Service item',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                _rows[n]['quantity'] ?? '1',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                (double.tryParse(_rows[n]['rate'] ?? '0') ?? 0.0).toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                _computeRowAmount(_rows[n]).toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Subtotals in Preview
                  Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Column(
                        children: [
                          _buildPreviewSummaryRow('Subtotal', 'AED ${subtotalVal.toStringAsFixed(2)}'),
                          const SizedBox(height: 4),
                          _buildPreviewSummaryRow('VAT 5%', 'AED ${vatVal.toStringAsFixed(2)}'),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF3FC),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'AED ${totalVal.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: AppTheme.zohoBlue),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Terms in Preview
                  const Text('Terms & Conditions:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  const SizedBox(height: 2),
                  Text(
                    _terms,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), height: 1.3),
                  ),
                  const SizedBox(height: 18),

                  // Signature / Thank you
                  Center(
                    child: Column(
                      children: const [
                        Text(
                          'Thank You!',
                          style: TextStyle(
                            fontFamily: 'cursive',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text('For your business', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bottom Colored Accent Bar
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.zohoBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.phone, size: 10, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(company.phone.isNotEmpty ? company.phone : '+971 50 123 4567', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.mail, size: 10, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(company.email.isNotEmpty ? company.email : 'info@abcservice.ae', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(CupertinoIcons.globe, size: 10, color: Color(0xFF64748B)),
                          SizedBox(width: 4),
                          Text('www.thepercentage.ae', style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewHeader(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildPreviewSummaryRow(String title, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
        Text(amount, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
      ],
    );
  }
}
