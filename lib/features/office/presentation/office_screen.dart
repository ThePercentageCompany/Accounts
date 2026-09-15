import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/auth/google_workspace_service.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/qr_code.dart';
import '../../../main.dart';
import '../../billing/domain/totals.dart';
import '../../billing/presentation/billing_cubit.dart';
import '../../billing/presentation/editors.dart';
import '../../billing/presentation/screens.dart';
import '../domain/office_documents.dart';
import '../domain/office_rules.dart';
import 'office_cubit.dart';

class InputSpec {
  final String key, label;
  final List<String>? options;
  final bool required;
  final IconData? icon;
  const InputSpec(this.key, this.label,
      {this.options, this.required = false, this.icon});
}

String _optionLabel(String value) => value
    .replaceAllMapped(RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}')
    .replaceFirstMapped(
        RegExp(r'^.'), (match) => match.group(0)!.toUpperCase());

Future<Map<String, dynamic>?> officeForm(
  BuildContext context,
  String title,
  Map<String, dynamic> initial,
  List<InputSpec> fields,
) async {
  final form = GlobalKey<FormState>();
  final values = Map<String, dynamic>.from(initial);

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: f.options != null
                        ? DropdownButtonFormField<String>(
                            initialValue: values[f.key]?.toString(),
                            decoration: InputDecoration(
                                labelText: f.label,
                                prefixIcon: f.icon != null
                                    ? Icon(f.icon, size: 18)
                                    : null),
                            isExpanded: true,
                            items: [
                              for (final o in f.options!)
                                DropdownMenuItem(
                                    value: o, child: Text(_optionLabel(o))),
                            ],
                            onChanged: (v) => values[f.key] = v,
                          )
                        : TextFormField(
                            initialValue: values[f.key]?.toString() ?? '',
                            decoration: InputDecoration(
                                labelText: f.label,
                                prefixIcon: f.icon != null
                                    ? Icon(f.icon, size: 18)
                                    : null),
                            maxLength:
                                f.key == 'notes' || f.key == 'adjustmentNote'
                                    ? 600
                                    : 150,
                            keyboardType: _officeInputType(f.key),
                            inputFormatters: _officeInputFormatters(f.key),
                            onChanged: (v) => values[f.key] = v,
                            validator: (v) {
                              if (f.required && (v == null || v.trim().isEmpty))
                                return 'Required';
                              if (f.key == 'email') {
                                return FormValidators.email(v, required: f.required);
                              }
                              if (f.key == 'phone') {
                                return FormValidators.phone(v, required: f.required);
                              }
                              if ((v ?? '').isNotEmpty &&
                                  [
                                    'date',
                                    'joinDate',
                                    'endDate',
                                    'dueDate',
                                    'paidDate',
                                    'visaExpiry'
                                  ].contains(f.key)) {
                                return validateDate(v);
                              }
                              if (f.key == 'month' &&
                                  (!RegExp(r'^\d{4}-\d{2}$')
                                          .hasMatch(v ?? '') ||
                                      validateDate('$v-01') != null)) {
                                return 'Use YYYY-MM';
                              }
                              if ([
                                'basic',
                                'allowances',
                                'amount',
                                'overtimeHours',
                                'overtimeRate',
                                'bonus',
                                'deductions'
                              ].contains(f.key)) {
                                return FormValidators.amount(v, required: f.required);
                              }
                              if (['divisor', 'baseDays', 'scheduledDays'].contains(f.key)) {
                                return FormValidators.wholeNumber(v,
                                    required: f.required, min: 1, max: 31);
                              }
                              return null;
                            },
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) Navigator.pop(ctx, values);
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.zohoBlue,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
          ),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

TextInputType _officeInputType(String key) {
  if (key == 'email') return TextInputType.emailAddress;
  if (key == 'phone') return TextInputType.phone;
  if (['basic', 'allowances', 'amount', 'overtimeHours', 'overtimeRate', 'bonus', 'deductions'].contains(key)) {
    return const TextInputType.numberWithOptions(decimal: true);
  }
  if (['divisor', 'baseDays', 'scheduledDays'].contains(key)) {
    return TextInputType.number;
  }
  return TextInputType.text;
}

List<TextInputFormatter>? _officeInputFormatters(String key) {
  if (key == 'phone') return FormValidators.phoneInput;
  if (['basic', 'allowances', 'amount', 'overtimeHours', 'overtimeRate', 'bonus', 'deductions'].contains(key)) {
    return FormValidators.decimalInput;
  }
  if (['divisor', 'baseDays', 'scheduledDays'].contains(key)) {
    return FormValidators.wholeNumberInput;
  }
  return null;
}

/// A dedicated, beautiful Zoho-styled transaction dialog for adding/editing Income & Expenses
class TransactionDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final String defaultKind;

  const TransactionDialog({
    super.key,
    this.initial,
    this.defaultKind = 'expense',
  });

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _kind;
  late TextEditingController _partyCtrl;
  late TextEditingController _referenceCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _dueDateCtrl;
  late TextEditingController _paidDateCtrl;
  late TextEditingController _notesCtrl;
  late String _category;
  late String _status;
  late String _account;

  static const List<String> _incomeCategories = [
    'Client Payment / Retainer',
    'Project Milestone',
    'Consulting / Professional Services',
    'Product / Service Sales',
    'Interest & Investment Return',
    'Refund / Reimbursement',
    'Other Income',
  ];

  static const List<String> _expenseCategories = [
    'Office Rent & Workspace',
    'Cloud & Server Infrastructure',
    'Software & SaaS Subscriptions',
    'Marketing & Advertising',
    'Hardware & Equipment',
    'Salaries & Contractor Fees',
    'Travel, Fuel & Logistics',
    'Utilities, Internet & Telecom',
    'Legal & Professional Services',
    'Office Supplies & Maintenance',
    'Bank Fees & Charges',
    'Taxes & Government Fees',
    'Miscellaneous Expense',
  ];

  static const List<String> _capitalCategories = [
    'Owner / Founder Capital',
    'Investor Equity Injection',
    'Shareholder / Director Loan',
    'Retained Earnings Transfer',
    'Other Capital',
  ];

  List<String> get _currentCategories {
    if (_kind == 'income') return _incomeCategories;
    if (_kind == 'capital') return _capitalCategories;
    return _expenseCategories;
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _kind = init?['kind']?.toString() ?? widget.defaultKind;
    _partyCtrl = TextEditingController(text: init?['party']?.toString() ?? '');
    _referenceCtrl =
        TextEditingController(text: init?['reference']?.toString() ?? '');

    if (init != null && init['amountCents'] != null) {
      final cents = (init['amountCents'] as num).toInt();
      _amountCtrl =
          TextEditingController(text: (cents / 100).toStringAsFixed(2));
    } else if (init != null && init['amount'] != null) {
      _amountCtrl = TextEditingController(text: init['amount'].toString());
    } else {
      _amountCtrl = TextEditingController(text: '');
    }

    _dateCtrl =
        TextEditingController(text: init?['date']?.toString() ?? today());
    _dueDateCtrl =
        TextEditingController(text: init?['dueDate']?.toString() ?? '');
    _paidDateCtrl =
        TextEditingController(text: init?['paidDate']?.toString() ?? today());
    _notesCtrl = TextEditingController(text: init?['notes']?.toString() ?? '');

    _status =
        init?['status']?.toString() ?? (_kind == 'expense' ? 'paid' : 'paid');
    _account = init?['account']?.toString() ?? 'Bank';

    final initialCat = init?['category']?.toString();
    if (initialCat != null && initialCat.isNotEmpty) {
      _category = initialCat;
    } else {
      _category = _currentCategories.first;
    }
  }

  @override
  void dispose() {
    _partyCtrl.dispose();
    _referenceCtrl.dispose();
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _dueDateCtrl.dispose();
    _paidDateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onKindChanged(String newKind) {
    if (_kind == newKind) return;
    setState(() {
      _kind = newKind;
      if (!_currentCategories.contains(_category)) {
        _category = _currentCategories.first;
      }
      if (_kind == 'income' || _kind == 'capital') {
        _status = 'paid';
      }
    });
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final parsed = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final cents = scaled(_amountCtrl.text.trim(), 2);
      if (cents <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amount must be greater than zero.')),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid numeric amount.')),
      );
      return;
    }

    final isPaid = _kind == 'income' || _kind == 'capital' || _status == 'paid';

    final result = {
      'id': widget.initial?['id'] ?? const Uuid().v4(),
      'version': widget.initial?['version'] ?? 0,
      'kind': _kind,
      'party': _partyCtrl.text.trim(),
      'reference': _referenceCtrl.text.trim(),
      'category': _category.trim().isNotEmpty
          ? _category.trim()
          : _currentCategories.first,
      'date': _dateCtrl.text.trim(),
      'dueDate': _dueDateCtrl.text.trim(),
      'amount': _amountCtrl.text.trim(),
      'status': isPaid ? 'paid' : 'unpaid',
      'paidDate': isPaid
          ? (_paidDateCtrl.text.trim().isNotEmpty
              ? _paidDateCtrl.text.trim()
              : _dateCtrl.text.trim())
          : '',
      'account': _account,
      'notes': _notesCtrl.text.trim(),
    };

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.initial != null;

    final themeColor = _kind == 'income'
        ? AppTheme.zohoGreen
        : (_kind == 'capital' ? const Color(0xFF8B5CF6) : AppTheme.zohoRed);

    final partyLabel = _kind == 'income'
        ? 'Customer / Client / Payer'
        : (_kind == 'capital'
            ? 'Shareholder / Investor / Contributor'
            : 'Supplier / Vendor / Payee');

    final partyHint = _kind == 'income'
        ? 'e.g. Acme Corp, John Doe'
        : (_kind == 'capital'
            ? 'e.g. Founder, Angel Investor, Holding Co.'
            : 'e.g. Amazon Web Services, Office Landlord, Etisalat');

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadiusVal)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 480;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isNarrow ? 16 : 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _kind == 'income'
                                      ? CupertinoIcons
                                          .arrow_down_left_circle_fill
                                      : (_kind == 'capital'
                                          ? CupertinoIcons.briefcase_fill
                                          : CupertinoIcons
                                              .arrow_up_right_circle_fill),
                                  color: themeColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  isEdit
                                      ? 'Edit Transaction'
                                      : 'Record Transaction',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill,
                              size: 20, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Kind Switcher Segmented Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildKindTab(
                              'income',
                              'Income',
                              CupertinoIcons.arrow_down_left,
                              AppTheme.zohoGreen,
                              isDark),
                          const SizedBox(width: 4),
                          _buildKindTab(
                              'expense',
                              'Expense',
                              CupertinoIcons.arrow_up_right,
                              AppTheme.zohoRed,
                              isDark),
                          const SizedBox(width: 4),
                          _buildKindTab(
                              'capital',
                              'Capital / Invest',
                              CupertinoIcons.briefcase,
                              const Color(0xFF8B5CF6),
                              isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amount & Date Field
                    if (isNarrow) ...[
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          labelText: 'Amount (AED) *',
                          prefixText: 'AED  ',
                          prefixStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: themeColor,
                            fontSize: 15,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          try {
                            final c = scaled(v.trim(), 2);
                            if (c <= 0) return 'Must exceed 0';
                          } catch (_) {
                            return 'Enter valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _dateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Date *',
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          suffixIcon: IconButton(
                            icon: const Icon(CupertinoIcons.calendar, size: 18),
                            onPressed: () => _pickDate(_dateCtrl),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          return validateDate(v.trim());
                        },
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: TextFormField(
                              controller: _amountCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800),
                              decoration: InputDecoration(
                                labelText: 'Amount (AED) *',
                                prefixText: 'AED  ',
                                prefixStyle: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: themeColor,
                                  fontSize: 15,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Required';
                                try {
                                  final c = scaled(v.trim(), 2);
                                  if (c <= 0) return 'Must exceed 0';
                                } catch (_) {
                                  return 'Enter valid amount';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 5,
                            child: TextFormField(
                              controller: _dateCtrl,
                              decoration: InputDecoration(
                                labelText: 'Date *',
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                                suffixIcon: IconButton(
                                  icon: const Icon(CupertinoIcons.calendar,
                                      size: 18),
                                  onPressed: () => _pickDate(_dateCtrl),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Required';
                                return validateDate(v.trim());
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Category Field
                    DropdownButtonFormField<String>(
                      initialValue: _currentCategories.contains(_category)
                          ? _category
                          : _currentCategories.first,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        prefixIcon: const Icon(CupertinoIcons.folder, size: 18),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                      ),
                      isExpanded: true,
                      items: [
                        for (final cat in _currentCategories)
                          DropdownMenuItem(
                              value: cat,
                              child:
                                  Text(cat, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Party / Supplier / Customer Field
                    TextFormField(
                      controller: _partyCtrl,
                      decoration: InputDecoration(
                        labelText: partyLabel,
                        hintText: partyHint,
                        prefixIcon: const Icon(CupertinoIcons.person, size: 18),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Reference & Due Date Row
                    if (isNarrow) ...[
                      TextFormField(
                        controller: _referenceCtrl,
                        decoration: InputDecoration(
                          labelText: 'Reference / Invoice / Bill #',
                          hintText: 'e.g. INV-2024-001 or BILL-99',
                          prefixIcon: const Icon(CupertinoIcons.tag, size: 18),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _dueDateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Due Date (optional)',
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          suffixIcon: IconButton(
                            icon: const Icon(CupertinoIcons.clock, size: 18),
                            onPressed: () => _pickDate(_dueDateCtrl),
                          ),
                        ),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            return validateDate(v.trim());
                          }
                          return null;
                        },
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: TextFormField(
                              controller: _referenceCtrl,
                              decoration: InputDecoration(
                                labelText: 'Reference / Invoice / Bill #',
                                hintText: 'e.g. INV-2024-001 or BILL-99',
                                prefixIcon:
                                    const Icon(CupertinoIcons.tag, size: 18),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 5,
                            child: TextFormField(
                              controller: _dueDateCtrl,
                              decoration: InputDecoration(
                                labelText: 'Due Date (optional)',
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                                suffixIcon: IconButton(
                                  icon: const Icon(CupertinoIcons.clock,
                                      size: 18),
                                  onPressed: () => _pickDate(_dueDateCtrl),
                                ),
                              ),
                              validator: (v) {
                                if (v != null && v.trim().isNotEmpty) {
                                  return validateDate(v.trim());
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Payment Status & Account Row
                    if (isNarrow) ...[
                      if (_kind == 'expense') ...[
                        DropdownButtonFormField<String>(
                          initialValue: _status,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Payment Status',
                            prefixIcon: const Icon(
                                CupertinoIcons.checkmark_alt_circle,
                                size: 18),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'paid',
                                child: Text('Paid Immediately',
                                    overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(
                                value: 'unpaid',
                                child: Text('Unpaid (Supplier Bill)',
                                    overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _status = v);
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      DropdownButtonFormField<String>(
                        initialValue: _account,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _status == 'unpaid'
                              ? 'Payable Account'
                              : 'Account / Method',
                          prefixIcon:
                              const Icon(CupertinoIcons.creditcard, size: 18),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Bank',
                              child: Text('Bank Account',
                                  overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(
                              value: 'Cash',
                              child: Text('Cash in Hand / Petty Cash',
                                  overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _account = v);
                        },
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_kind == 'expense') ...[
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _status,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Payment Status',
                                  prefixIcon: const Icon(
                                      CupertinoIcons.checkmark_alt_circle,
                                      size: 18),
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF8FAFC),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'paid',
                                      child: Text('Paid Immediately',
                                          overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(
                                      value: 'unpaid',
                                      child: Text('Unpaid (Supplier Bill)',
                                          overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _status = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _account,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: _status == 'unpaid'
                                    ? 'Payable Account'
                                    : 'Account / Method',
                                prefixIcon: const Icon(
                                    CupertinoIcons.creditcard,
                                    size: 18),
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Bank',
                                    child: Text('Bank Account',
                                        overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(
                                    value: 'Cash',
                                    child: Text('Cash in Hand / Petty Cash',
                                        overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _account = v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_status == 'paid' ||
                        _kind == 'income' ||
                        _kind == 'capital') ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _paidDateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Payment / Settlement Date',
                          prefixIcon: const Icon(CupertinoIcons.calendar_today,
                              size: 18),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          suffixIcon: IconButton(
                            icon: const Icon(CupertinoIcons.calendar, size: 18),
                            onPressed: () => _pickDate(_paidDateCtrl),
                          ),
                        ),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            return validateDate(v.trim());
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Notes / Particulars
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notes & Memo',
                        hintText:
                            'Additional particulars, contract notes, or descriptions...',
                        prefixIcon:
                            const Icon(CupertinoIcons.text_quote, size: 18),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    if (isNarrow)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.buttonRadiusVal)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _submit,
                              icon: const Icon(CupertinoIcons.checkmark_alt,
                                  size: 16),
                              label: Text(isEdit ? 'Update' : 'Save'),
                              style: FilledButton.styleFrom(
                                backgroundColor: themeColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.buttonRadiusVal)),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.buttonRadiusVal)),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _submit,
                            icon: const Icon(CupertinoIcons.checkmark_alt,
                                size: 16),
                            label: Text(isEdit
                                ? 'Update Transaction'
                                : 'Save Transaction'),
                            style: FilledButton.styleFrom(
                              backgroundColor: themeColor,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.buttonRadiusVal)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildKindTab(
      String kindKey, String label, IconData icon, Color color, bool isDark) {
    final isSelected = _kind == kindKey;
    return Expanded(
      child: InkWell(
        onTap: () => _onKindChanged(kindKey),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
            border: isSelected ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? color
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OfficeScreen extends StatefulWidget {
  final int initialPage;
  final String? filterKind;
  final bool showReports;

  const OfficeScreen({
    super.key,
    this.initialPage = 0,
    this.filterKind,
    this.showReports = false,
  });

  @override
  State<OfficeScreen> createState() => _OfficeScreenState();
}

class _OfficeScreenState extends State<OfficeScreen> {
  late int page;
  String day = today();
  String month = today().substring(0, 7);
  String search = '';
  String? activeFilterKind;
  String financeTab = 'all'; // 'all', 'income', 'expense', 'capital', 'unpaid'
  String financeSearch = '';
  String? financeCategoryFilter;
  String? financeAccountFilter;

  @override
  void initState() {
    super.initState();
    page = widget.initialPage;
    activeFilterKind = widget.filterKind;
    if (widget.filterKind != null) {
      financeTab = widget.filterKind!;
    }
  }

  Future<bool> run(String action, Map<String, dynamic> d) async =>
      context.read<OfficeCubit>().run(action, d);

  Future<void> preview(Uint8List bytes, String filename) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(filename)),
          body: PdfPreview(
            build: (_) => bytes,
            pdfFileName: filename,
            canChangeOrientation: false,
            canChangePageFormat: false,
          ),
        ),
      ),
    );
  }

  Future<void> guarded(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _shiftDay(int delta) {
    final current = DateTime.tryParse(day) ?? DateTime.now();
    final shifted = current.add(Duration(days: delta));
    setState(() => day = shifted.toIso8601String().substring(0, 10));
  }

  void _shiftMonth(int delta) {
    final parts = month.split('-');
    if (parts.length != 2) return;
    int y = int.tryParse(parts[0]) ?? DateTime.now().year;
    int m = int.tryParse(parts[1]) ?? DateTime.now().month;
    m += delta;
    if (m > 12) {
      m = 1;
      y += 1;
    } else if (m < 1) {
      m = 12;
      y -= 1;
    }
    setState(() => month = '$y-${m.toString().padLeft(2, '0')}');
  }

  Future<void> employee([Map<String, dynamic>? old]) async {
    final result = await officeForm(
      context,
      old == null ? 'Add Employee' : 'Edit Employee',
      old ??
          {
            'id': const Uuid().v4(),
            'version': 0,
            'joinDate': today(),
            'endDate': '',
            'active': true,
            'basic': '0',
            'allowances': '0'
          },
      const [
        InputSpec('code', 'Employee Code',
            required: true, icon: CupertinoIcons.tag),
        InputSpec('name', 'Full Name',
            required: true, icon: CupertinoIcons.person),
        InputSpec('department', 'Department',
            required: true, icon: CupertinoIcons.building_2_fill),
        InputSpec('title', 'Job Title',
            required: true, icon: CupertinoIcons.briefcase),
        InputSpec('email', 'Work Email Address',
            required: true, icon: CupertinoIcons.mail),
        InputSpec('phone', 'Mobile Number',
            required: true, icon: CupertinoIcons.phone),
        InputSpec('address', 'Address', icon: CupertinoIcons.location_solid),
        InputSpec('joinDate', 'Joining Date (YYYY-MM-DD)',
            required: true, icon: CupertinoIcons.calendar),
        InputSpec('endDate', 'Last Employment Date (optional)',
            icon: CupertinoIcons.calendar_badge_minus),
        InputSpec('basic', 'Monthly Basic Salary (AED)',
            required: true, icon: CupertinoIcons.money_dollar),
        InputSpec('allowances', 'Monthly Allowances (AED)',
            required: true, icon: CupertinoIcons.money_dollar_circle),
        InputSpec('bank', 'Salary Bank Name',
            required: true, icon: CupertinoIcons.building_2_fill),
        InputSpec('iban', 'Salary IBAN',
            required: true, icon: CupertinoIcons.creditcard),
        InputSpec('emiratesId', 'Emirates ID (optional)',
            icon: CupertinoIcons.person_crop_square),
        InputSpec('passport', 'Passport Number (optional)',
            icon: CupertinoIcons.book),
        InputSpec('visaExpiry', 'Visa Expiry (optional)',
            icon: CupertinoIcons.clock),
        InputSpec('notes', 'Notes', icon: CupertinoIcons.text_quote),
      ],
    );
    if (result != null) {
      for (final k in [
        'department',
        'title',
        'email',
        'phone',
        'address',
        'bank',
        'iban',
        'emiratesId',
        'passport',
        'visaExpiry',
        'notes',
        'endDate'
      ]) {
        result[k] ??= '';
      }
      await run('employeeSave', result);
    }
  }

  Future<void> deleteEmployee(Map<String, dynamic> employee) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete employee?'),
        content: Text(
            'Delete ${employee['name']} from the employee register? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.zohoRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (approved == true) await run('employeeDelete', {'id': employee['id']});
  }

  Future<void> showEmployeeAccessAndQr(Map<String, dynamic> employee) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cubit = context.read<OfficeCubit>();
    final ws = session.workspace;
    final spreadsheetId = ws?.spreadsheetId ?? '';
    final driveFolderId = ws?.driveFolderId ?? '';
    final companyName = ws?.companyName ?? 'The Percentage Company';

    var selectedRole = employee['systemRole']?.toString() ?? 'Staff';
    final allSections = [
      'Dashboard',
      'Invoices',
      'Quotations',
      'Income & Expenses',
      'Capital & Equity',
      'Fixed Assets',
      'Balance Sheet',
      'Customers',
      'Employees',
      'Payroll',
      'Reports',
      'Settings',
      'Office & Attendance',
    ];

    List<String> getPresetSections(String role) {
      switch (role) {
        case 'Admin':
          return List<String>.from(allSections);
        case 'Accountant':
          return [
            'Dashboard',
            'Invoices',
            'Quotations',
            'Income & Expenses',
            'Capital & Equity',
            'Fixed Assets',
            'Balance Sheet',
            'Customers',
            'Reports',
          ];
        case 'Sales':
          return ['Dashboard', 'Invoices', 'Quotations', 'Customers'];
        case 'HR & Payroll':
          return [
            'Dashboard',
            'Employees',
            'Payroll',
            'Office & Attendance',
            'Reports'
          ];
        case 'Staff':
          return ['Dashboard', 'Office & Attendance'];
        default:
          return employee['allowedSections'] is List
              ? List<String>.from(employee['allowedSections'] as List)
              : ['Dashboard', 'Office & Attendance'];
      }
    }

    var selectedSections = getPresetSections(selectedRole);
    final googleEmailCtrl = TextEditingController(
      text: employee['googleEmail']?.toString() ??
          employee['email']?.toString() ??
          '',
    );
    bool copied = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final invite = WorkspaceConfig(
            companyName: companyName,
            spreadsheetId: spreadsheetId,
            driveFolderId: driveFolderId,
            employeeId: employee['id']?.toString(),
            employeeCode: employee['code']?.toString(),
            employeeName: employee['name']?.toString(),
            employeeEmail: googleEmailCtrl.text.trim(),
            employeeRole: selectedRole,
            allowedSections: selectedSections,
            isEmployee: true,
          );
          final inviteLink = invite.toInviteLink();

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.pastelIndigoBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.qrcode_viewfinder,
                      color: AppTheme.pastelIndigo, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Access & QR Login • ${employee['name']}',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Role: $selectedRole (${selectedSections.length} sections assigned)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.iosDarkTextSecondary
                              : AppTheme.iosLightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section 1: Role Presets
                    DropdownButtonFormField<String>(
                      value: const [
                        'Admin',
                        'Accountant',
                        'Sales',
                        'HR & Payroll',
                        'Staff',
                        'Custom'
                      ].contains(selectedRole)
                          ? selectedRole
                          : 'Custom',
                      decoration: const InputDecoration(
                        labelText: 'Employee Role Preset',
                        prefixIcon:
                            Icon(CupertinoIcons.shield_lefthalf_fill, size: 18),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Admin',
                            child: Text('Admin / Director (Full Access)')),
                        DropdownMenuItem(
                            value: 'Accountant',
                            child: Text(
                                'Accountant (Finance, Assets, Balance Sheet, Reports)')),
                        DropdownMenuItem(
                            value: 'Sales',
                            child: Text(
                                'Sales & Invoicing (Invoices, Quotations, Customers)')),
                        DropdownMenuItem(
                            value: 'HR & Payroll',
                            child: Text(
                                'HR & Payroll Manager (Staff, Attendance, Payroll)')),
                        DropdownMenuItem(
                            value: 'Staff',
                            child: Text('General Staff (Attendance Only)')),
                        DropdownMenuItem(
                            value: 'Custom',
                            child: Text(
                                'Custom Permissions (Select Sections Below)')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setModalState(() {
                            selectedRole = v;
                            if (v != 'Custom') {
                              selectedSections = getPresetSections(v);
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Section 2: Google Email Binding
                    TextFormField(
                      controller: googleEmailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Authorized Google Email (for login)',
                        hintText: 'employee@gmail.com',
                        prefixIcon: Icon(CupertinoIcons.mail, size: 18),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Allowed Sections Checklist
                    const Text(
                      'Assigned Sections (UI/UX Visibility):',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final sec in allSections)
                          FilterChip(
                            label:
                                Text(sec, style: const TextStyle(fontSize: 12)),
                            selected: selectedSections.contains(sec),
                            selectedColor:
                                AppTheme.pastelIndigo.withValues(alpha: 0.2),
                            checkmarkColor: AppTheme.pastelIndigo,
                            onSelected: (selected) {
                              setModalState(() {
                                selectedRole = 'Custom';
                                if (selected) {
                                  if (!selectedSections.contains(sec))
                                    selectedSections.add(sec);
                                } else {
                                  selectedSections.remove(sec);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Section 4: Rendered QR Code
                    Center(
                      child: Column(
                        children: [
                          QrImageView(
                            data: inviteLink,
                            size: 190,
                            foregroundColor: const Color(0xFF0F172A),
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Scan to open the employee login link. Access is verified live against the employee record.',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? AppTheme.iosDarkTextSecondary
                                    : AppTheme.iosLightTextSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Copy Invite Code / Payload Button
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: inviteLink));
                        setModalState(() => copied = true);
                        Future.delayed(const Duration(seconds: 3), () {
                          if (dialogCtx.mounted)
                            setModalState(() => copied = false);
                        });
                      },
                      icon: Icon(
                          copied
                              ? CupertinoIcons.checkmark_alt
                              : CupertinoIcons.doc_on_clipboard,
                          size: 16,
                          color: copied ? AppTheme.pastelMint : null),
                      label: Text(
                          copied
                              ? 'Employee Login Link Copied!'
                              : 'Copy Employee Login Link',
                          style: TextStyle(
                              color: copied ? AppTheme.pastelMint : null,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close')),
              FilledButton.icon(
                onPressed: () async {
                  final updated = {
                    ...employee,
                    'systemRole': selectedRole,
                    'allowedSections': selectedSections,
                    'googleEmail': googleEmailCtrl.text.trim(),
                  };
                  await cubit.run('employeeSave', updated);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                },
                icon: const Icon(CupertinoIcons.checkmark, size: 16),
                label: const Text('Save Permissions'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.pastelIndigo),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> attendance(
      Map<String, dynamic> employee, Map<String, dynamic>? old) async {
    final cubit = context.read<OfficeCubit>();
    var selectedDate =
        DateTime.tryParse(old?['date']?.toString() ?? day) ?? DateTime.now();
    var status = old?['status']?.toString() ?? 'present';
    final checkIn =
        TextEditingController(text: old?['checkIn']?.toString() ?? '');
    final checkOut =
        TextEditingController(text: old?['checkOut']?.toString() ?? '');
    final overtime =
        TextEditingController(text: old?['overtimeHours']?.toString() ?? '0');
    final notes = TextEditingController(text: old?['notes']?.toString() ?? '');
    final now = TimeOfDay.now();
    String formatTime(TimeOfDay time) =>
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    TimeOfDay? parseTime(String value) {
      final parts = value.trim().split(':');
      if (parts.length != 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null ||
          minute == null ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59) return null;
      return TimeOfDay(hour: hour, minute: minute);
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> chooseTime(TextEditingController controller,
              {required bool isCheckIn}) async {
            final current = parseTime(controller.text) ??
                (isCheckIn
                    ? const TimeOfDay(hour: 9, minute: 0)
                    : const TimeOfDay(hour: 18, minute: 0));
            final chosen = await showTimePicker(
                context: dialogContext, initialTime: current);
            if (chosen != null)
              setDialogState(() => controller.text = formatTime(chosen));
          }

          Future<void> chooseDate() async {
            final chosen = await showDatePicker(
              context: dialogContext,
              initialDate: selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(DateTime.now().year + 5),
            );
            if (chosen != null) setDialogState(() => selectedDate = chosen);
          }

          final works = attendanceAllowsOvertime(status);
          return AlertDialog(
            title: Text('Mark Attendance • ${employee['name']}'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: chooseDate,
                      icon: const Icon(CupertinoIcons.calendar),
                      label: Text(
                          DateFormat('EEE, dd MMM yyyy').format(selectedDate)),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration:
                          const InputDecoration(labelText: 'Attendance Status'),
                      items: [
                        'present',
                        'absent',
                        'halfDay',
                        'paidLeave',
                        'unpaidLeave',
                        'sickLeave',
                        'vacation',
                        'halfDayPaidLeave',
                        'halfDayUnpaidLeave',
                        'fullDayPaidLeave',
                        'fullDayUnpaidLeave',
                        'off',
                        'holiday',
                      ]
                          .map((value) => DropdownMenuItem(
                              value: value, child: Text(_optionLabel(value))))
                          .toList(),
                      onChanged: (value) => setDialogState(() {
                        status = value ?? 'present';
                        if (status == 'present' && checkIn.text.isEmpty)
                          checkIn.text = formatTime(now);
                        if (status == 'present' && checkOut.text.isEmpty)
                          checkOut.text = formatTime(now);
                        if (!attendanceAllowsOvertime(status))
                          overtime.text = '0';
                      }),
                    ),
                    const SizedBox(height: 12),
                    if (works) ...[
                      Row(children: [
                        Expanded(
                            child: TextFormField(
                                controller: checkIn,
                                readOnly: true,
                                onTap: () =>
                                    chooseTime(checkIn, isCheckIn: true),
                                decoration: const InputDecoration(
                                    labelText: 'Check-in time',
                                    suffixIcon: Icon(CupertinoIcons.clock)))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextFormField(
                                controller: checkOut,
                                readOnly: true,
                                onTap: () =>
                                    chooseTime(checkOut, isCheckIn: false),
                                decoration: const InputDecoration(
                                    labelText: 'Check-out time',
                                    suffixIcon: Icon(CupertinoIcons.clock)))),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: overtime,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Approved OT hours',
                              hintText: '0.00',
                              prefixIcon: Icon(CupertinoIcons.stopwatch))),
                    ] else
                      const Text(
                          'Check-in, check-out, and OT are not required for this leave/day status.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: notes,
                        maxLines: 2,
                        decoration: const InputDecoration(
                            labelText: 'Notes (optional)')),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final date = DateFormat('yyyy-MM-dd').format(selectedDate);
                  final ot = double.tryParse(overtime.text.trim()) ?? -1;
                  if (ot < 0 || ot > 24) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                            content:
                                Text('OT hours must be between 0 and 24.')));
                    return;
                  }
                  if (works &&
                      checkIn.text.isNotEmpty &&
                      checkOut.text.isNotEmpty) {
                    final start = parseTime(checkIn.text);
                    final end = parseTime(checkOut.text);
                    if (start == null ||
                        end == null ||
                        end.hour * 60 + end.minute <=
                            start.hour * 60 + start.minute) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Check-out time must be after check-in time.')));
                      return;
                    }
                  }
                  final ok = await cubit.run('attendanceSave', {
                    'employeeId': employee['id'],
                    'date': date,
                    'status': status,
                    'checkIn': works ? checkIn.text : '',
                    'checkOut': works ? checkOut.text : '',
                    'overtimeHours': works ? overtime.text : '0',
                    'notes': notes.text.trim(),
                    'version': old?['version'] ?? 0,
                  });
                  if (dialogContext.mounted && ok)
                    Navigator.pop(dialogContext, true);
                  if (dialogContext.mounted && !ok)
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                        content: Text(cubit.state.error ??
                            'Could not save attendance.')));
                },
                child: const Text('Save Attendance'),
              ),
            ],
          );
        },
      ),
    );
    checkIn.dispose();
    checkOut.dispose();
    overtime.dispose();
    notes.dispose();
    if (saved == true && mounted)
      setState(() => day = DateFormat('yyyy-MM-dd').format(selectedDate));
  }

  /// Dedicated entry point for the Attendance module. Existing records can
  /// still be edited from each employee card; this makes adding a new daily
  /// mark explicit and discoverable.
  Future<void> addAttendance() async {
    final employees = context.read<OfficeCubit>().state.data.employees;
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add an employee before marking attendance.')));
      return;
    }
    final employeeId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Mark Attendance • $day'),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: employees.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final employee = employees[index];
              return ListTile(
                leading: const Icon(CupertinoIcons.person_circle),
                title: Text(employee['name']?.toString() ?? 'Employee'),
                subtitle: Text(employee['code']?.toString() ?? ''),
                onTap: () =>
                    Navigator.pop(dialogContext, employee['id']?.toString()),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'))
        ],
      ),
    );
    if (employeeId == null || !mounted) return;
    final employee = employees
        .where((item) => item['id']?.toString() == employeeId)
        .firstOrNull;
    if (employee == null) return;
    final existing = context
        .read<OfficeCubit>()
        .state
        .data
        .attendance
        .where((item) =>
            item['employeeId']?.toString() == employeeId &&
            item['date']?.toString() == day)
        .firstOrNull;
    await attendance(employee, existing);
  }

  Future<void> markAllPresent() async {
    final office = context.read<OfficeCubit>().state.data;
    final activeEmployees =
        office.employees.where((e) => e['active'] != false).toList();
    final unmarked = activeEmployees
        .where((e) => !office.attendance
            .any((a) => a['employeeId'] == e['id'] && a['date'] == day))
        .toList();
    if (unmarked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('All active employees are already marked for this date.')));
      return;
    }
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Mark all present?'),
              content: Text(
                  'This will mark ${unmarked.length} unmarked active employees as Present for $day. Check-in and check-out remain blank for later confirmation.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Mark Present'))
              ],
            ));
    if (confirm != true || !mounted) return;
    await context.read<OfficeCubit>().runBatch([
      for (final employee in unmarked)
        MapEntry('attendanceSave', {
          'employeeId': employee['id'],
          'date': day,
          'status': 'present',
          'checkIn': '',
          'checkOut': '',
          'overtimeHours': '0',
          'notes': 'Bulk marked present',
          'version': 0
        }),
    ]);
  }

  Future<void> payroll(Map<String, dynamic> employee,
      [Map<String, dynamic>? old]) async {
    final result = await officeForm(
      context,
      'Generate Payroll: ${employee['name']} ($month)',
      {
        ...?old,
        'employeeId': employee['id'],
        'month': month,
        'divisor': old?['divisor'] ?? '30',
        'baseDays': old?['baseDays'] ?? '30',
        'scheduledDays': old?['scheduledDays'] ?? '22',
        'overtimeRate': old?['overtimeRate'] ?? '0',
        'bonus': old?['bonus'] ?? '0',
        'deductions': old?['deductions'] ?? '0',
        'adjustmentNote': old?['adjustmentNote'] ?? '',
        'version': old?['version'] ?? 0,
      },
      const [
        InputSpec('divisor', 'Salary Daily Divisor (1-31)',
            required: true, icon: CupertinoIcons.calendar),
        InputSpec('baseDays', 'Base Days Before Absence Deduction',
            required: true, icon: CupertinoIcons.calendar_today),
        InputSpec('scheduledDays', 'Expected Scheduled Working Days',
            required: true, icon: CupertinoIcons.chart_bar),
        InputSpec('overtimeRate', 'Overtime Hourly Rate (AED)',
            required: true, icon: CupertinoIcons.stopwatch),
        InputSpec('bonus', 'Bonus (AED)',
            required: true, icon: CupertinoIcons.gift),
        InputSpec('deductions', 'Other Deductions (AED)',
            required: true, icon: CupertinoIcons.minus_circle),
        InputSpec('adjustmentNote', 'Proration / Adjustment Explanation',
            icon: CupertinoIcons.text_quote),
      ],
    );
    if (result != null) await run('payrollGenerate', result);
  }

  Future<void> payPayroll(Map<String, dynamic> p) async {
    final d = await officeForm(
      context,
      'Record Salary Payment',
      {
        'id': p['id'],
        'version': p['version'],
        'paidDate': today(),
        'account': 'Bank',
        'reference': ''
      },
      const [
        InputSpec('paidDate', 'Payment Date',
            required: true, icon: CupertinoIcons.calendar),
        InputSpec('account', 'Paid From',
            options: ['Bank', 'Cash'], icon: CupertinoIcons.creditcard),
        InputSpec('reference', 'Payment Reference', icon: CupertinoIcons.tag),
      ],
    );
    if (d != null) {
      final ok = await run('payrollPay', d);
      if (ok && mounted && !context.read<OfficeCubit>().repository.isDemo) {
        final updated = context
            .read<OfficeCubit>()
            .state
            .data
            .payroll
            .firstWhere((x) => x['id'] == p['id']);
        await archivePayroll(updated);
      }
    }
  }

  Future<void> archivePayroll(Map<String, dynamic> p) async =>
      guarded(() async {
        final bytes = await context.read<OfficeDocuments>().payslip(
              p,
              logo: context.read<BillingCubit>().state.data.company.logo,
            );
        await run('payrollArchive', {
          'id': p['id'],
          'version': p['version'],
          'pdf': base64Encode(bytes)
        });
      });

  Future<void> finance(
      [Map<String, dynamic>? old, String defaultKind = 'expense']) async {
    final d = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => TransactionDialog(
        initial: old,
        defaultKind: old?['kind'] ?? defaultKind,
      ),
    );
    if (d != null) await run('financeSave', d);
  }

  Future<void> billPayment(Map<String, dynamic> e) async {
    final d = await officeForm(
      context,
      'Pay Supplier Bill',
      {
        'id': e['id'],
        'version': e['version'],
        'paidDate': today(),
        'account': 'Bank'
      },
      const [
        InputSpec('paidDate', 'Payment Date',
            required: true, icon: CupertinoIcons.calendar),
        InputSpec('account', 'Paid From',
            options: ['Bank', 'Cash'], icon: CupertinoIcons.creditcard),
      ],
    );
    if (d != null) await run('financePay', d);
  }

  Future<void> upload(String table, Map<String, dynamic> record) async =>
      guarded(() async {
        final file = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
            withData: true);
        if (file == null) return;
        final f = file.files.single;
        if (f.bytes == null || f.size > 5000000)
          throw StateError('Select a file under 5 MB.');
        await run('documentUpload', {
          'table': table,
          'id': record['id'],
          'version': record['version'],
          'documentId': const Uuid().v4(),
          'name': f.name,
          'extension': f.extension,
          'bytes': base64Encode(f.bytes!),
        });
      });

  Widget documents(Map<String, dynamic> record) {
    final docs = (record['documents'] as List? ?? []);
    if (docs.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final d in docs)
            ActionChip(
              avatar: const Icon(CupertinoIcons.paperclip, size: 14),
              label: Text(d['name'], style: const TextStyle(fontSize: 12)),
              onPressed: () => launchUrl(Uri.parse(d['url']),
                  mode: LaunchMode.externalApplication),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<OfficeCubit, OfficeState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.error!),
              duration: const Duration(seconds: 7)));
        }
      },
      builder: (context, state) {
        final demo = context.read<OfficeCubit>().repository.isDemo;

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Module Header (Responsive)
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 560;
                final titleText = [
                  'Employees',
                  'Attendance',
                  'Payroll',
                  'Income & Expenses'
                ][page];
                final subtitleText = [
                  'Staff directory, contracts, visa tracking and salaries.',
                  'Daily attendance, clocking and approved overtime hours.',
                  'Monthly payroll calculation, salary slips and approvals.',
                  'Manage company cash flow, client receipts, supplier bills, and expenses.',
                ][page];

                Widget? actionButton;
                if (page == 0) {
                  actionButton = FilledButton.icon(
                    onPressed: () => employee(),
                    icon: const Icon(CupertinoIcons.person_add_solid, size: 16),
                    label: const Text('Add Employee'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.zohoBlue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.buttonRadiusVal)),
                    ),
                  );
                } else if (page == 1) {
                  actionButton = FilledButton.icon(
                    onPressed: addAttendance,
                    icon: const Icon(CupertinoIcons.checkmark_alt_circle_fill,
                        size: 16),
                    label: const Text('Mark Attendance'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.zohoBlue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.buttonRadiusVal)),
                    ),
                  );
                }

                if (isCompact) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleText,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              subtitleText,
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.iosDarkTextSecondary
                                    : AppTheme.iosLightTextSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (actionButton != null) ...[
                        const SizedBox(width: 8),
                        actionButton,
                      ],
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
                          Text(
                            titleText,
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleText,
                            style: TextStyle(
                              color: isDark
                                  ? AppTheme.iosDarkTextSecondary
                                  : AppTheme.iosLightTextSecondary,
                              fontSize: 14,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (actionButton != null) ...[
                      const SizedBox(width: 14),
                      actionButton,
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // Date / Month Navigators
            if (page == 1) _buildDayNavigator(isDark),
            if (page >= 2) _buildMonthNavigator(isDark),
            const SizedBox(height: 14),

            if (state.busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 16),
            ],

            if (page == 0)
              employeesView(state, demo, isDark)
            else if (page == 1)
              attendanceView(state, isDark)
            else if (page == 2)
              payrollView(state, demo, isDark)
            else
              financialView(state, demo, isDark),
          ],
        );
      },
    );
  }

  Widget _buildDayNavigator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _shiftDay(-1),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(CupertinoIcons.chevron_left, size: 14),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(CupertinoIcons.calendar, size: 14),
              const SizedBox(width: 4),
              Text(
                day,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.2),
              ),
              const SizedBox(width: 2),
              InkWell(
                onTap: () => _shiftDay(1),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(CupertinoIcons.chevron_right, size: 14),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () => setState(() => day = today()),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Today',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  color: isDark ? AppTheme.pastelBlue : AppTheme.zohoBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _shiftMonth(-1),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(CupertinoIcons.chevron_left, size: 14),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(CupertinoIcons.calendar_today, size: 14),
              const SizedBox(width: 4),
              Text(
                month,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.2),
              ),
              const SizedBox(width: 2),
              InkWell(
                onTap: () => _shiftMonth(1),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(CupertinoIcons.chevron_right, size: 14),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () => setState(() => month = today().substring(0, 7)),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'This Month',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  color: isDark ? AppTheme.pastelBlue : AppTheme.zohoBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget employeesView(OfficeState state, bool demo, bool isDark) {
    final filtered = state.data.employees
        .where((e) =>
            '${e['name']} ${e['code']} ${e['department']} ${e['title']}'
                .toLowerCase()
                .contains(search.toLowerCase()))
        .toList();

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            decoration: InputDecoration(
              fillColor: Colors.transparent,
              hintText: 'Search staff by name, code, department or title...',
              hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
              prefixIcon: const Icon(CupertinoIcons.search,
                  size: 18, color: Colors.grey),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(CupertinoIcons.clear_circled_solid,
                          size: 16, color: Colors.grey),
                      onPressed: () => setState(() => search = ''))
                  : null,
            ),
            onChanged: (v) => setState(() => search = v),
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          EmptyState(
            icon: CupertinoIcons.person_crop_circle_badge_checkmark,
            title: search.isNotEmpty
                ? 'No matching employees'
                : 'No employees added',
            message: search.isNotEmpty
                ? 'Check your search query or add a new team member.'
                : 'Add staff records to track attendance and generate monthly payroll.',
            actionLabel: search.isEmpty ? 'Add Employee' : null,
            onAction: search.isEmpty ? () => employee() : null,
          )
        else
          for (final e in filtered) ...[
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: isDark
                        ? const Color(0x20FFFFFF)
                        : const Color(0x10000000),
                    width: 0.8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.pastelTealBgDark
                                : AppTheme.pastelTealBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              e['name'].toString().isNotEmpty
                                  ? e['name']
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.pastelTeal,
                                  fontSize: 17),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      e['name'],
                                      style: const TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF2C2C2E)
                                          : const Color(0xFFE5E5EA),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      e['code'],
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if ((e['systemRole']?.toString() ?? '')
                                      .isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.pastelIndigo
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: AppTheme.pastelIndigo
                                                .withValues(alpha: 0.4),
                                            width: 0.8),
                                      ),
                                      child: Text(
                                        e['systemRole']
                                            .toString()
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.pastelIndigo),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${e['department'].isNotEmpty ? '${e['department']} • ' : ''}${e['title']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppTheme.iosDarkTextSecondary
                                      : AppTheme.iosLightTextSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              money(scaled(e['basic'].toString(), 2) +
                                  scaled(e['allowances'].toString(), 2)),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                  letterSpacing: -0.3),
                            ),
                            const Text('Monthly',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.calendar,
                                size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('Joined ${e['joinDate']}',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        if (e['endDate'].toString().isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.calendar_badge_minus,
                                  size: 13, color: AppTheme.pastelRose),
                              const SizedBox(width: 4),
                              Text('Ended ${e['endDate']}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.pastelRose)),
                            ],
                          ),
                        if (e['visaExpiry'].toString().isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.clock,
                                  size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('Visa: ${e['visaExpiry']}',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                      ],
                    ),
                    documents(e),
                    const SizedBox(height: 6),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => showEmployeeAccessAndQr(e),
                          icon: const Icon(CupertinoIcons.qrcode_viewfinder,
                              size: 15, color: AppTheme.pastelIndigo),
                          label: const Text('Access & QR Login',
                              style: TextStyle(
                                  color: AppTheme.pastelIndigo,
                                  fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side:
                                const BorderSide(color: AppTheme.pastelIndigo),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          onPressed: () => employee(e),
                          icon: const Icon(CupertinoIcons.pencil, size: 15),
                          label: const Text('Edit Record'),
                        ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          onPressed: () => deleteEmployee(e),
                          icon: const Icon(CupertinoIcons.trash,
                              size: 15, color: AppTheme.zohoRed),
                          label: const Text('Delete'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppTheme.zohoRed),
                        ),
                        if (!demo) ...[
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            onPressed: () => upload('Employees', e),
                            icon:
                                const Icon(CupertinoIcons.paperclip, size: 15),
                            label: const Text('Attach Doc'),
                            style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(100))),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget attendanceView(OfficeState state, bool isDark) {
    final employees = state.data.employees;
    final records =
        state.data.attendance.where((a) => a['date'] == day).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.zohoBlueBgDark : const Color(0xFFEBF3FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? AppTheme.zohoBlue : const Color(0xFFBFDBFE)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Daily Attendance',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(
                      'Selected date: $day • Record present, leave, vacation, or OT.',
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.iosDarkTextSecondary
                              : AppTheme.iosLightTextSecondary)),
                ],
              ),
              FilledButton.icon(
                onPressed: addAttendance,
                icon: const Icon(CupertinoIcons.checkmark_alt_circle_fill,
                    size: 16),
                label: const Text('Mark Attendance'),
                style:
                    FilledButton.styleFrom(backgroundColor: AppTheme.zohoBlue),
              ),
              OutlinedButton.icon(
                onPressed: markAllPresent,
                icon: const Icon(CupertinoIcons.person_2_fill, size: 16),
                label: const Text('Mark All Present'),
              ),
            ],
          ),
        ),
        if (employees.isEmpty)
          const EmptyState(
            icon: CupertinoIcons.person_2,
            title: 'No employees found',
            message: 'Add employees first to mark and track their attendance.',
          )
        else
          for (final e in employees) ...[
            Builder(
              builder: (context) {
                final a = records
                    .where((r) => r['employeeId'] == e['id'])
                    .firstOrNull;
                final status = a?['status'] ?? 'notMarked';

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                        color: isDark
                            ? const Color(0x20FFFFFF)
                            : const Color(0x10000000),
                        width: 0.8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e['name'],
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2)),
                              const SizedBox(height: 2),
                              Text(
                                '${e['code']} • ${e['department']}',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark
                                        ? AppTheme.iosDarkTextSecondary
                                        : AppTheme.iosLightTextSecondary),
                              ),
                              if (a != null &&
                                  (a['checkIn'].toString().isNotEmpty ||
                                      a['checkOut'].toString().isNotEmpty)) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'In: ${a['checkIn'].toString().isNotEmpty ? a['checkIn'] : '--:--'} • Out: ${a['checkOut'].toString().isNotEmpty ? a['checkOut'] : '--:--'}${a['overtimeHours'] != '0' ? ' • OT: ${a['overtimeHours']}h' : ''}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppTheme.iosDarkTextSecondary
                                          : AppTheme.iosLightTextSecondary),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            AppBadge.attendance(status),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Mark / Edit Attendance',
                              icon: const Icon(
                                  CupertinoIcons.pencil_circle_fill,
                                  size: 22),
                              onPressed: () => attendance(e, a),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
          ],
      ],
    );
  }

  Widget payrollView(OfficeState state, bool demo, bool isDark) {
    final employees = state.data.employees;
    final monthPayroll =
        state.data.payroll.where((p) => p['month'] == month).toList();

    return Column(
      children: [
        if (employees.isEmpty)
          const EmptyState(
            icon: CupertinoIcons.money_dollar,
            title: 'No employees available',
            message: 'Add staff directory members before running payroll.',
          )
        else
          for (final e in employees) ...[
            Builder(
              builder: (context) {
                final p = monthPayroll
                    .where((x) => x['employeeId'] == e['id'])
                    .firstOrNull;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                        color: isDark
                            ? const Color(0x20FFFFFF)
                            : const Color(0x10000000),
                        width: 0.8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e['name'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16.5,
                                          letterSpacing: -0.2)),
                                  Text('${e['code']} • ${e['department']}',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark
                                              ? AppTheme.iosDarkTextSecondary
                                              : AppTheme
                                                  .iosLightTextSecondary)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  p != null
                                      ? money((p['netCents'] as num).toInt())
                                      : 'AED 0.00',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16.5,
                                      letterSpacing: -0.3),
                                ),
                                const SizedBox(height: 4),
                                AppBadge.status(p?['status'] ?? 'uncalculated',
                                    isSmall: true),
                              ],
                            ),
                          ],
                        ),
                        if (p != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1C1C1E)
                                  : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Net Salary',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    Text(money((p['netCents'] as num).toInt()),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                  ],
                                ),
                                const Divider(height: 16),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    Text(
                                        'Base: ${money((p['baseCents'] as num).toInt())}',
                                        style: const TextStyle(fontSize: 12)),
                                    Text(
                                        'OT: ${money((p['overtimeCents'] as num).toInt())}',
                                        style: const TextStyle(fontSize: 12)),
                                    Text(
                                        'Bonus: ${money((p['bonusCents'] as num).toInt())}',
                                        style: const TextStyle(fontSize: 12)),
                                    Text(
                                        'Absence: -${money((p['absenceCents'] as num).toInt())}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.pastelRose)),
                                    Text(
                                        'Deductions: -${money((p['deductionCents'] as num).toInt())}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.pastelRose)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (p == null || p['status'] == 'draft')
                              FilledButton.icon(
                                onPressed: () => payroll(e, p),
                                icon: const Icon(CupertinoIcons.sparkles,
                                    size: 15),
                                label: Text(p == null
                                    ? 'Generate Draft'
                                    : 'Recalculate'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.pastelBlue,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(100))),
                              ),
                            if (p != null && p['status'] == 'draft')
                              FilledButton.icon(
                                onPressed: () => approve(p),
                                icon: const Icon(
                                    CupertinoIcons.checkmark_seal_fill,
                                    size: 15),
                                label: const Text('Approve'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.pastelMint,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(100))),
                              ),
                            if (p != null && p['status'] == 'approved')
                              FilledButton.icon(
                                onPressed: () => payPayroll(p),
                                icon: const Icon(
                                    CupertinoIcons.money_dollar_circle_fill,
                                    size: 15),
                                label: const Text('Record Payment'),
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.pastelMint,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(100))),
                              ),
                            if (p != null)
                              OutlinedButton.icon(
                                onPressed: () => guarded(() async {
                                  await preview(
                                      await context
                                          .read<OfficeDocuments>()
                                          .payslip(
                                            p,
                                            logo: context
                                                .read<BillingCubit>()
                                                .state
                                                .data
                                                .company
                                                .logo,
                                          ),
                                      'Payslip-${e['code']}-$month.pdf');
                                }),
                                icon: const Icon(CupertinoIcons.doc_text,
                                    size: 15),
                                label: const Text('View Payslip PDF'),
                                style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(100))),
                              ),
                            if (p != null && p['status'] != 'draft' && !demo)
                              OutlinedButton.icon(
                                onPressed: () => archivePayroll(p),
                                icon: const Icon(CupertinoIcons.cloud_upload,
                                    size: 15),
                                label: const Text('Save to Drive'),
                                style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(100))),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Future<void> approve(Map<String, dynamic> p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Payroll?'),
        content: const Text(
            'Confirm salary base days, overtime rates, and deductions are verified. Approved payroll and attendance will be locked.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.pastelBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100))),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (yes == true) {
      final ok =
          await run('payrollApprove', {'id': p['id'], 'version': p['version']});
      if (ok && mounted && !context.read<OfficeCubit>().repository.isDemo) {
        final updated = context
            .read<OfficeCubit>()
            .state
            .data
            .payroll
            .firstWhere((x) => x['id'] == p['id']);
        await archivePayroll(updated);
      }
    }
  }

  Widget financialView(OfficeState state, bool demo, bool isDark) {
    final billing = context.watch<BillingCubit>().state.data;
    final summary = financialSummary(billing.invoices, state.data, month);

    final allMonthEntries = state.data.entries
        .where((e) =>
            e['date'].toString().startsWith(month) || e['status'] == 'unpaid')
        .toList();

    final allCount = allMonthEntries.length;
    final incomeCount =
        allMonthEntries.where((e) => e['kind'] == 'income').length;
    final expenseCount =
        allMonthEntries.where((e) => e['kind'] == 'expense').length;
    final unpaidCount =
        allMonthEntries.where((e) => e['status'] == 'unpaid').length;

    final availableCategories = allMonthEntries
        .map((e) => e['category']?.toString() ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    var entries = List<Map<String, dynamic>>.from(allMonthEntries);

    // Apply Filter Tab
    if (financeTab == 'income') {
      entries = entries.where((e) => e['kind'] == 'income').toList();
    } else if (financeTab == 'expense') {
      entries = entries.where((e) => e['kind'] == 'expense').toList();
    } else if (financeTab == 'unpaid') {
      entries = entries.where((e) => e['status'] == 'unpaid').toList();
    }

    // Category filter
    if (financeCategoryFilter != null && financeCategoryFilter!.isNotEmpty) {
      entries =
          entries.where((e) => e['category'] == financeCategoryFilter).toList();
    }

    // Account filter
    if (financeAccountFilter != null && financeAccountFilter!.isNotEmpty) {
      entries =
          entries.where((e) => e['account'] == financeAccountFilter).toList();
    }

    // Search query filter
    if (financeSearch.trim().isNotEmpty) {
      final q = financeSearch.toLowerCase().trim();
      entries = entries.where((e) {
        final p = (e['party'] ?? '').toString().toLowerCase();
        final c = (e['category'] ?? '').toString().toLowerCase();
        final r = (e['reference'] ?? '').toString().toLowerCase();
        final n = (e['notes'] ?? '').toString().toLowerCase();
        final a = (e['amount'] ?? '').toString().toLowerCase();
        final cents = (e['amountCents'] ?? '').toString();
        return p.contains(q) ||
            c.contains(q) ||
            r.contains(q) ||
            n.contains(q) ||
            a.contains(q) ||
            cents.contains(q);
      }).toList();
    }

    // Sort: Unpaid on top, then descending by date
    entries.sort((a, b) {
      final aUnpaid = a['status'] == 'unpaid' ? 1 : 0;
      final bUnpaid = b['status'] == 'unpaid' ? 1 : 0;
      if (aUnpaid != bUnpaid) return bUnpaid.compareTo(aUnpaid);
      final aDate = (a['date'] ?? '').toString();
      final bDate = (b['date'] ?? '').toString();
      return bDate.compareTo(aDate);
    });

    final totalIncome =
        (summary['Invoice collections'] ?? 0) + (summary['Other income'] ?? 0);
    final totalExpenses =
        (summary['Expenses paid'] ?? 0) + (summary['Payroll paid'] ?? 0);
    final netCash = summary['Net cash movement'] ?? 0;
    final unpaidBills = summary['Supplier bills due (all dates)'] ?? 0;
    final bankMovement = summary['Bank movement'] ?? 0;
    final cashMovement = summary['Cash movement'] ?? 0;

    final capitalInflow = (summary['Capital / Investment'] ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Buttons Toolbar
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            if (isNarrow) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => finance(null, 'income'),
                          icon: const Icon(
                              CupertinoIcons.arrow_down_left_circle_fill,
                              size: 13),
                          label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Add Income',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11))),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.zohoGreen,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.buttonRadiusVal)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => finance(null, 'expense'),
                          icon: const Icon(
                              CupertinoIcons.arrow_up_right_circle_fill,
                              size: 13),
                          label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Add Expense',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11))),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.zohoRed,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.buttonRadiusVal)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<String>(
                        tooltip: 'Report options',
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        onSelected: (action) {
                          if (action == 'pdf') {
                            guarded(() async {
                              await preview(
                                await context
                                    .read<OfficeDocuments>()
                                    .financialReport(
                                      billing.company.name,
                                      month,
                                      summary,
                                      state.data.entries,
                                      logo: billing.company.logo,
                                    ),
                                'Finance-$month.pdf',
                              );
                            });
                          } else if (action == 'drive') {
                            guarded(() async {
                              final bytes = await context
                                  .read<OfficeDocuments>()
                                  .financialReport(
                                    billing.company.name,
                                    month,
                                    summary,
                                    state.data.entries,
                                    logo: billing.company.logo,
                                  );
                              await run('reportArchive', {
                                'month': month,
                                'requestId': const Uuid().v4(),
                                'pdf': base64Encode(bytes),
                              });
                            });
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'pdf',
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.doc_plaintext, size: 16),
                                SizedBox(width: 8),
                                Text('Export PDF Report',
                                    style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          if (!demo)
                            const PopupMenuItem(
                              value: 'drive',
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.cloud_upload, size: 16),
                                  SizedBox(width: 8),
                                  Text('Save to Drive',
                                      style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius:
                                BorderRadius.circular(AppTheme.buttonRadiusVal),
                            border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                          ),
                          child: Icon(
                            CupertinoIcons.ellipsis_vertical,
                            size: 16,
                            color: isDark
                                ? AppTheme.iosDarkTextPrimary
                                : AppTheme.iosLightTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => finance(null, 'income'),
                  icon: const Icon(CupertinoIcons.arrow_down_left_circle_fill,
                      size: 16),
                  label: const Text('Add Income'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.zohoGreen,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.buttonRadiusVal)),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => finance(null, 'expense'),
                  icon: const Icon(CupertinoIcons.arrow_up_right_circle_fill,
                      size: 16),
                  label: const Text('Add Expense'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.zohoRed,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.buttonRadiusVal)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => guarded(() async {
                    await preview(
                      await context.read<OfficeDocuments>().financialReport(
                            billing.company.name,
                            month,
                            summary,
                            state.data.entries,
                            logo: billing.company.logo,
                          ),
                      'Finance-$month.pdf',
                    );
                  }),
                  icon: const Icon(CupertinoIcons.doc_plaintext, size: 16),
                  label: const Text('Export PDF Report'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.buttonRadiusVal)),
                  ),
                ),
                if (!demo)
                  OutlinedButton.icon(
                    onPressed: () => guarded(() async {
                      final bytes =
                          await context.read<OfficeDocuments>().financialReport(
                                billing.company.name,
                                month,
                                summary,
                                state.data.entries,
                                logo: billing.company.logo,
                              );
                      await run('reportArchive', {
                        'month': month,
                        'requestId': const Uuid().v4(),
                        'pdf': base64Encode(bytes),
                      });
                    }),
                    icon: const Icon(CupertinoIcons.cloud_upload, size: 16),
                    label: const Text('Save to Drive'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.buttonRadiusVal)),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),

        // Financial Metrics Grid (Zoho Style Bento Grid - 4-col Desktop / 2x2 Bento Mobile)
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final isMobile = constraints.maxWidth <= 650;
            final spacing = isMobile ? 10.0 : 14.0;
            final cardWidth = isWide
                ? (constraints.maxWidth - (3 * spacing)) / 4
                : (constraints.maxWidth - spacing) / 2;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    title: 'TOTAL INCOME & RECEIPTS',
                    value: money(totalIncome),
                    icon: CupertinoIcons.arrow_down_left_circle_fill,
                    accentColor: AppTheme.zohoGreen,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    title: 'TOTAL EXPENSES & OUTFLOWS',
                    value: money(totalExpenses),
                    icon: CupertinoIcons.arrow_up_right_circle_fill,
                    accentColor: AppTheme.zohoRed,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    title: 'NET CASH MOVEMENT',
                    value: '${netCash >= 0 ? '+' : ''}${money(netCash)}',
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    accentColor:
                        netCash >= 0 ? AppTheme.zohoBlue : AppTheme.zohoRed,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    title: 'PENDING BILLS DUE',
                    value: money(unpaidBills),
                    icon: CupertinoIcons.clock_fill,
                    accentColor: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        // Bank vs Cash Movement mini bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(AppTheme.cardRadiusVal),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.zohoBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(CupertinoIcons.building_2_fill,
                        size: 13, color: AppTheme.zohoBlue),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Bank: ${bankMovement >= 0 ? '+' : ''}${money(bankMovement)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: bankMovement >= 0
                          ? AppTheme.zohoGreen
                          : AppTheme.zohoRed,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(CupertinoIcons.money_dollar,
                        size: 13, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Cash: ${cashMovement >= 0 ? '+' : ''}${money(cashMovement)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cashMovement >= 0
                          ? AppTheme.zohoGreen
                          : AppTheme.zohoRed,
                    ),
                  ),
                ],
              ),
              if (capitalInflow != 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(CupertinoIcons.briefcase_fill,
                          size: 13, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Capital: ${capitalInflow >= 0 ? '+' : ''}${money(capitalInflow)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                  ],
                ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(CupertinoIcons.doc_text,
                      size: 13, color: Colors.grey),
                  Text(
                    'Invoices: ${money(summary['Invoice collections'] ?? 0)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppTheme.iosDarkTextSecondary
                          : AppTheme.iosLightTextSecondary,
                    ),
                  ),
                  Text(
                    '• Salaries: ${money(summary['Payroll paid'] ?? 0)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppTheme.iosDarkTextSecondary
                          : AppTheme.iosLightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Filter Tabs & Controls (Capsule Pill Bar)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFinanceFilterTab(
                    'all', 'All Transactions', allCount, isDark,
                    accentColor: AppTheme.zohoBlue),
                const SizedBox(width: 4),
                _buildFinanceFilterTab('income', 'Income', incomeCount, isDark,
                    accentColor: AppTheme.zohoGreen),
                const SizedBox(width: 4),
                _buildFinanceFilterTab(
                    'expense', 'Expenses', expenseCount, isDark,
                    accentColor: AppTheme.zohoRed),
                const SizedBox(width: 4),
                _buildFinanceFilterTab(
                    'unpaid', 'Unpaid Bills', unpaidCount, isDark,
                    accentColor: const Color(0xFFF59E0B)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Search & Category Dropdown Bar (Mobile Responsive)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            final searchField = SizedBox(
              width: isNarrow ? constraints.maxWidth : 300,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by payee, ref, notes, amount...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  prefixIcon: const Icon(CupertinoIcons.search,
                      size: 16, color: Colors.grey),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
                  suffixIcon: financeSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_circled_solid,
                              size: 15, color: Colors.grey),
                          onPressed: () => setState(() => financeSearch = ''),
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => financeSearch = v),
              ),
            );

            final categoryFilter = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: financeCategoryFilter,
                  hint: const Text('All Categories',
                      style: TextStyle(fontSize: 13)),
                  isExpanded: isNarrow,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Categories',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    for (final cat in availableCategories)
                      DropdownMenuItem<String?>(
                        value: cat,
                        child: Text(cat, style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                  onChanged: (v) => setState(() => financeCategoryFilter = v),
                ),
              ),
            );

            final accountFilter = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: financeAccountFilter,
                  hint: const Text('All Accounts',
                      style: TextStyle(fontSize: 13)),
                  isExpanded: isNarrow,
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Accounts',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Bank',
                      child:
                          Text('Bank Account', style: TextStyle(fontSize: 13)),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Cash',
                      child:
                          Text('Cash in Hand', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                  onChanged: (v) => setState(() => financeAccountFilter = v),
                ),
              ),
            );

            if (isNarrow) {
              return Column(
                children: [
                  searchField,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (availableCategories.isNotEmpty) ...[
                        Expanded(child: categoryFilter),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: accountFilter),
                    ],
                  ),
                ],
              );
            }

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                searchField,
                if (availableCategories.isNotEmpty) categoryFilter,
                accountFilter,
              ],
            );
          },
        ),
        const SizedBox(height: 18),

        // Transactions List
        if (entries.isEmpty)
          EmptyState(
            icon: CupertinoIcons.arrow_right_arrow_left_circle,
            title: financeSearch.isNotEmpty ||
                    financeCategoryFilter != null ||
                    financeAccountFilter != null
                ? 'No matching transactions'
                : 'No transactions found for $month',
            message: financeSearch.isNotEmpty
                ? 'Try clearing your search or filter criteria.'
                : 'Add income receipts, supplier bills, or office expenses to manage your cash flow.',
            actionLabel: 'Add Income',
            onAction: () => finance(null, 'income'),
          )
        else
          for (final e in entries) ...[
            _buildTransactionCard(e, demo, isDark),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _buildFinanceFilterTab(
      String key, String label, int count, bool isDark,
      {Color accentColor = AppTheme.zohoBlue}) {
    final isSelected = financeTab == key;
    final isUnpaidTab = key == 'unpaid';
    final highlightUnpaid = isUnpaidTab && count > 0;

    return InkWell(
      onTap: () => setState(() => financeTab = key),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF0F172A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
          border: isSelected
              ? Border.all(
                  color: highlightUnpaid
                      ? const Color(0xFFF59E0B)
                      : (isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFFCBD5E1)),
                  width: highlightUnpaid ? 1.2 : 1.0,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (highlightUnpaid
                        ? const Color(0xFFF59E0B)
                        : (isDark ? Colors.white : const Color(0xFF0F172A)))
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? (highlightUnpaid
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                        : accentColor.withValues(alpha: 0.15))
                    : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? (highlightUnpaid
                          ? const Color(0xFFF59E0B)
                          : accentColor)
                      : (isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> e, bool demo, bool isDark) {
    final kind = e['kind']?.toString() ?? 'expense';
    final isIncome = kind == 'income';
    final isCapital = kind == 'capital';
    final isUnpaid = e['status'] == 'unpaid';

    final color = isIncome
        ? AppTheme.zohoGreen
        : (isCapital ? const Color(0xFF8B5CF6) : AppTheme.zohoRed);

    final icon = isIncome
        ? CupertinoIcons.arrow_down_left_circle_fill
        : (isCapital
            ? CupertinoIcons.briefcase_fill
            : CupertinoIcons.arrow_up_right_circle_fill);

    final amountCents = (e['amountCents'] as num?)?.toInt() ?? 0;
    final partyName = (e['party']?.toString() ?? '').trim();
    final category = (e['category']?.toString() ?? 'General').trim();
    final reference = (e['reference']?.toString() ?? '').trim();
    final date = (e['date']?.toString() ?? '').trim();
    final dueDate = (e['dueDate']?.toString() ?? '').trim();
    final notes = (e['notes']?.toString() ?? '').trim();
    final account = (e['account']?.toString() ?? 'Bank').trim();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadiusVal),
        side: BorderSide(
          color: isUnpaid
              ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isUnpaid ? 1.4 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              partyName.isNotEmpty ? partyName : category,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (reference.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                reference,
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  account == 'Cash'
                                      ? CupertinoIcons.money_dollar
                                      : CupertinoIcons.building_2_fill,
                                  size: 11,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 3),
                                Text(account,
                                    style: const TextStyle(
                                        fontSize: 10.5, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppTheme.iosDarkTextSecondary
                                  : AppTheme.iosLightTextSecondary,
                            ),
                          ),
                          if (dueDate.isNotEmpty)
                            Text(
                              '• Due $dueDate',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isUnpaid
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isUnpaid
                                    ? const Color(0xFFF59E0B)
                                    : Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          notes,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? AppTheme.iosDarkTextSecondary
                                : AppTheme.iosLightTextSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${isIncome ? '+' : (isCapital ? '+' : '-')}${money(amountCents)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.3,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppBadge.status(e['status'], isSmall: true),
                  ],
                ),
              ],
            ),
            documents(e),
            const Divider(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => finance(e),
                  icon: const Icon(CupertinoIcons.pencil, size: 13),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (isUnpaid) ...[
                  FilledButton.icon(
                    onPressed: () => billPayment(e),
                    icon: const Icon(CupertinoIcons.checkmark_alt, size: 13),
                    label:
                        const Text('Mark Paid', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.zohoGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.buttonRadiusVal)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => voidBill(e),
                    icon: const Icon(CupertinoIcons.xmark_circle,
                        size: 13, color: AppTheme.zohoRed),
                    label: const Text('Void',
                        style:
                            TextStyle(color: AppTheme.zohoRed, fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
                if (!demo)
                  IconButton(
                    tooltip: 'Attach receipt / invoice file',
                    icon: const Icon(CupertinoIcons.paperclip, size: 15),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: () => upload('Finance', e),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> voidBill(Map<String, dynamic> e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Unpaid Bill?'),
        content: const Text(
            'This will remove the unpaid bill from your payable balances.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.pastelRose,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100))),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (yes == true)
      await run('financeVoid', {'id': e['id'], 'version': e['version']});
  }
}
