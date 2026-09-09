import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/date_field.dart';
import '../../billing/domain/models.dart';
import '../../billing/domain/totals.dart';
import '../../billing/presentation/billing_cubit.dart';
import '../../billing/presentation/editors.dart';
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

  late String _id;
  late String _number;
  late String _date;
  late String _validUntil;
  late String _status;
  Customer? _customer;
  late Company _company;
  late List<LineItem> _items;
  late String _discount;
  late String _taxRate;
  late String _notes;
  late String _terms;
  late int _version;
  late String _convertedInvoiceId;
  late String _issuedAt;

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
      _items = List.from(old.items);
      _discount = old.discount;
      _taxRate = old.taxRate;
      _notes = old.notes;
      _terms = old.terms;
      _version = old.version;
      _convertedInvoiceId = old.convertedInvoiceId;
      _issuedAt = old.issuedAt;
    } else {
      _id = const Uuid().v4();
      _number = '';
      _date = todayStr;
      _validUntil = expiryStr;
      _status = 'draft';
      _customer = billing.customers.isNotEmpty ? billing.customers.first : null;
      _company = billing.company;
      _items = [const LineItem(description: 'Professional Services', quantity: '1', rate: '1000.00')];
      _discount = '0.00';
      _taxRate = '5.00';
      _notes = 'This quotation is valid for 30 days from issue date.';
      _terms = '50% advance upon confirmation, 50% on delivery.';
      _version = 0;
      _convertedInvoiceId = '';
      _issuedAt = '';
    }
  }

  void _applyExpiryPreset(int days) {
    final base = DateTime.tryParse(_date) ?? DateTime.now();
    final target = base.add(Duration(days: days));
    setState(() {
      _validUntil = target.toIso8601String().substring(0, 10);
    });
  }

  Quotation _buildQuotation() {
    return Quotation(
      id: _id,
      number: _number,
      date: _date,
      validUntil: _validUntil,
      customer: _customer!,
      company: _company,
      items: _items,
      discount: _discount,
      taxRate: _taxRate,
      status: _status,
      notes: _notes,
      terms: _terms,
      version: _version,
      convertedInvoiceId: _convertedInvoiceId,
      issuedAt: _issuedAt,
    );
  }

  Future<void> _saveDraft() async {
    if (_customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a customer first.')),
      );
      return;
    }
    if (_items.isEmpty) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quotation draft saved successfully.')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _issueQuotation() async {
    if (_customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a customer first.')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final cubit = context.read<QuotationCubit>();
    final q = _buildQuotation();
    final issued = await cubit.issue(q);

    if (issued != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quotation ${issued.number} issued successfully!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final billingData = context.watch<BillingCubit>().state.data;
    final customers = billingData.customers;

    // Calculate live totals safely
    QuotationTotals? totals;
    try {
      if (_customer != null) {
        totals = QuotationTotals.of(_buildQuotation());
      }
    } catch (_) {
      totals = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.quotation == null ? 'New Quotation' : 'Edit Quotation ${_number.isNotEmpty ? _number : "(Draft)"}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonal(
              onPressed: _saveDraft,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              child: const Text('Save Draft'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SECTION 1: Client Details
                  _buildSectionCard(
                    isDark: isDark,
                    title: 'Client Information',
                    icon: CupertinoIcons.person_crop_circle_fill,
                    iconColor: AppTheme.pastelBlue,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _customer?.id,
                                decoration: const InputDecoration(
                                  labelText: 'Select Customer',
                                  prefixIcon: Icon(CupertinoIcons.person_2, size: 18),
                                ),
                                items: customers.map((c) {
                                  return DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (id) {
                                  if (id != null) {
                                    setState(() {
                                      _customer = customers.firstWhere((x) => x.id == id);
                                    });
                                  }
                                },
                                validator: (v) => v == null ? 'Please select a customer' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton.filledTonal(
                              onPressed: () async {
                                await editCustomer(context);
                                if (context.mounted) {
                                  final latestCustomers = context.read<BillingCubit>().state.data.customers;
                                  if (latestCustomers.isNotEmpty) {
                                    setState(() => _customer = latestCustomers.last);
                                  }
                                }
                              },
                              icon: const Icon(CupertinoIcons.person_add, size: 20),
                              tooltip: 'Add New Customer',
                            ),
                          ],
                        ),
                        if (_customer != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.iosDarkSurfaceElevated : AppTheme.iosLightSurfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _customer!.name,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      if (_customer!.address.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          _customer!.address,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                                          ),
                                        ),
                                      ],
                                       if (_customer!.email.isNotEmpty || _customer!.phone.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          '${_customer!.email}${_customer!.phone.isNotEmpty ? " • ${_customer!.phone}" : ""}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_customer!.trn.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.pastelIndigoBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'TRN: ${_customer!.trn}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.pastelIndigo,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SECTION 2: Quotation Schedule & Validity
                  _buildSectionCard(
                    isDark: isDark,
                    title: 'Quotation Dates & Validity',
                    icon: CupertinoIcons.calendar,
                    iconColor: AppTheme.pastelOrange,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 500;
                            final dateCol = DatePickerField(
                              label: 'Quotation Issue Date',
                              value: _date,
                              onChanged: (v) => setState(() => _date = v),
                            );
                            final validCol = DatePickerField(
                              label: 'Valid Until / Expiry Date',
                              value: _validUntil,
                              onChanged: (v) => setState(() => _validUntil = v),
                            );

                            return isWide
                                ? Row(
                                    children: [
                                      Expanded(child: dateCol),
                                      const SizedBox(width: 16),
                                      Expanded(child: validCol),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      dateCol,
                                      const SizedBox(height: 12),
                                      validCol,
                                    ],
                                  );
                          },
                        ),

                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Quick Presets:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                              ),
                            ),
                            _buildPresetChip('+7 Days', () => _applyExpiryPreset(7)),
                            _buildPresetChip('+14 Days', () => _applyExpiryPreset(14)),
                            _buildPresetChip('+30 Days', () => _applyExpiryPreset(30)),
                            _buildPresetChip('+60 Days', () => _applyExpiryPreset(60)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SECTION 3: Line Items
                  _buildSectionCard(
                    isDark: isDark,
                    title: 'Itemized Pricing & Scope',
                    icon: CupertinoIcons.list_bullet,
                    iconColor: AppTheme.pastelTeal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < _items.length; i++) ...[
                          _buildLineItemRow(i, isDark),
                          if (i < _items.length - 1) const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            setState(() {
                              _items.add(const LineItem(
                                description: 'Additional Item / Service',
                                quantity: '1',
                                rate: '500.00',
                              ));
                            });
                          },
                          icon: const Icon(CupertinoIcons.plus, size: 16),
                          label: const Text('Add Line Item'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SECTION 4: Tax, Discount & Terms
                  _buildSectionCard(
                    isDark: isDark,
                    title: 'Tax, Discounts & Commercial Terms',
                    icon: CupertinoIcons.percent,
                    iconColor: AppTheme.pastelPurple,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 500;
                            final taxWidget = TextFormField(
                              initialValue: _taxRate,
                              decoration: const InputDecoration(
                                labelText: 'VAT Rate (%)',
                                prefixIcon: Icon(CupertinoIcons.percent, size: 18),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) => setState(() => _taxRate = v),
                            );

                            final discountWidget = TextFormField(
                              initialValue: _discount,
                              decoration: const InputDecoration(
                                labelText: 'Special Discount (AED)',
                                prefixIcon: Icon(CupertinoIcons.minus_circle, size: 18),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) => setState(() => _discount = v),
                            );

                            return isWide
                                ? Row(
                                    children: [
                                      Expanded(child: taxWidget),
                                      const SizedBox(width: 16),
                                      Expanded(child: discountWidget),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      taxWidget,
                                      const SizedBox(height: 12),
                                      discountWidget,
                                    ],
                                  );
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _terms,
                          decoration: const InputDecoration(
                            labelText: 'Commercial & Payment Terms',
                            prefixIcon: Icon(CupertinoIcons.doc_plaintext, size: 18),
                          ),
                          maxLines: 2,
                          onChanged: (v) => setState(() => _terms = v),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _notes,
                          decoration: const InputDecoration(
                            labelText: 'Quotation Notes & Scope Conditions',
                            prefixIcon: Icon(CupertinoIcons.text_quote, size: 18),
                          ),
                          maxLines: 2,
                          onChanged: (v) => setState(() => _notes = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SECTION 5: Real-time Calculation Summary
                  if (totals != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF142B38), const Color(0xFF0F1E29)]
                              : [AppTheme.pastelTealBg, Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.pastelTeal.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.pastelTeal.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.pastelTeal.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(CupertinoIcons.money_dollar_circle_fill, color: AppTheme.pastelTeal, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Quotation Financial Summary',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _buildSummaryRow('Item Total', totals.subtotal, isDark),
                          if (totals.discount > 0) ...[
                            const SizedBox(height: 6),
                            _buildSummaryRow('Discount Applied', -totals.discount, isDark, isNegative: true),
                          ],
                          const SizedBox(height: 6),
                          _buildSummaryRow('Net Subtotal', totals.subtotal - totals.discount, isDark),
                          if (totals.tax > 0) ...[
                            const SizedBox(height: 6),
                            _buildSummaryRow('VAT ($_taxRate%)', totals.tax, isDark),
                          ],
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Grand Total Quotation',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              Text(
                                money(totals.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: AppTheme.pastelTeal,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _issueQuotation,
                          icon: const Icon(CupertinoIcons.checkmark_seal_fill, size: 18),
                          label: const Text('Issue Quotation'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.pastelTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder,
          width: 0.6,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildLineItemRow(int index, bool isDark) {
    final item = _items[index];

    int currentLineTotal = 0;
    try {
      currentLineTotal = lineTotal(item);
    } catch (_) {
      currentLineTotal = 0;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.iosDarkSurfaceElevated : AppTheme.iosLightSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.pastelTeal.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.pastelTeal),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: item.description,
                  decoration: const InputDecoration(
                    labelText: 'Item Description / Scope of Work',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) {
                    _items[index] = item.copyWith(description: v);
                    setState(() {});
                  },
                ),
              ),
              if (_items.length > 1) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() => _items.removeAt(index));
                  },
                  icon: const Icon(CupertinoIcons.trash, color: AppTheme.pastelRose, size: 18),
                  tooltip: 'Remove Item',
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 420;
              final qtyField = TextFormField(
                initialValue: item.quantity,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  _items[index] = item.copyWith(quantity: v);
                  setState(() {});
                },
              );

              final rateField = TextFormField(
                initialValue: item.rate,
                decoration: const InputDecoration(
                  labelText: 'Unit Rate (AED)',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  _items[index] = item.copyWith(rate: v);
                  setState(() {});
                },
              );

              final totalBox = Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppTheme.iosDarkBorder : AppTheme.iosLightBorder,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: isSmall ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: isSmall ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Line Total',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                          ),
                        ),
                        Text(
                          money(currentLineTotal),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              if (isSmall) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(flex: 2, child: qtyField),
                        const SizedBox(width: 10),
                        Expanded(flex: 3, child: rateField),
                      ],
                    ),
                    const SizedBox(height: 10),
                    totalBox,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 2, child: qtyField),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: rateField),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: totalBox),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, int cents, bool isDark, {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
          ),
        ),
        Text(
          isNegative ? '- ${money(cents.abs())}' : money(cents),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            color: isNegative ? AppTheme.pastelRose : null,
          ),
        ),
      ],
    );
  }
}
