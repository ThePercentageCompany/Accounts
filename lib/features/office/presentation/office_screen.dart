import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/empty_state.dart';
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
  const InputSpec(this.key, this.label, {this.options, this.required = false, this.icon});
}

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
                            decoration: InputDecoration(labelText: f.label, prefixIcon: f.icon != null ? Icon(f.icon, size: 18) : null),
                            isExpanded: true,
                            items: [
                              for (final o in f.options!) DropdownMenuItem(value: o, child: Text(o)),
                            ],
                            onChanged: (v) => values[f.key] = v,
                          )
                        : TextFormField(
                            initialValue: values[f.key]?.toString() ?? '',
                            decoration: InputDecoration(labelText: f.label, prefixIcon: f.icon != null ? Icon(f.icon, size: 18) : null),
                            maxLength: f.key == 'notes' || f.key == 'adjustmentNote' ? 600 : 150,
                            onChanged: (v) => values[f.key] = v,
                            validator: (v) {
                              if (f.required && (v == null || v.trim().isEmpty)) return 'Required';
                              if ((v ?? '').isNotEmpty && ['date', 'joinDate', 'endDate', 'dueDate', 'paidDate', 'visaExpiry'].contains(f.key)) {
                                return validateDate(v);
                              }
                              if (f.key == 'month' && (!RegExp(r'^\d{4}-\d{2}$').hasMatch(v ?? '') || validateDate('$v-01') != null)) {
                                return 'Use YYYY-MM';
                              }
                              if (['basic', 'allowances', 'amount', 'overtimeHours', 'overtimeRate', 'bonus', 'deductions'].contains(f.key)) {
                                try {
                                  scaled(v ?? '', 2);
                                } catch (e) {
                                  return 'Enter a valid positive number';
                                }
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
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) Navigator.pop(ctx, values);
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.zohoBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
          ),
          child: const Text('Save'),
        ),
      ],
    ),
  );
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
    _referenceCtrl = TextEditingController(text: init?['reference']?.toString() ?? '');

    if (init != null && init['amountCents'] != null) {
      final cents = (init['amountCents'] as num).toInt();
      _amountCtrl = TextEditingController(text: (cents / 100).toStringAsFixed(2));
    } else if (init != null && init['amount'] != null) {
      _amountCtrl = TextEditingController(text: init['amount'].toString());
    } else {
      _amountCtrl = TextEditingController(text: '');
    }

    _dateCtrl = TextEditingController(text: init?['date']?.toString() ?? today());
    _dueDateCtrl = TextEditingController(text: init?['dueDate']?.toString() ?? '');
    _paidDateCtrl = TextEditingController(text: init?['paidDate']?.toString() ?? today());
    _notesCtrl = TextEditingController(text: init?['notes']?.toString() ?? '');

    _status = init?['status']?.toString() ?? (_kind == 'expense' ? 'paid' : 'paid');
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
      'category': _category.trim().isNotEmpty ? _category.trim() : _currentCategories.first,
      'date': _dateCtrl.text.trim(),
      'dueDate': _dueDateCtrl.text.trim(),
      'amount': _amountCtrl.text.trim(),
      'status': isPaid ? 'paid' : 'unpaid',
      'paidDate': isPaid ? (_paidDateCtrl.text.trim().isNotEmpty ? _paidDateCtrl.text.trim() : _dateCtrl.text.trim()) : '',
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
        : (_kind == 'capital' ? 'Shareholder / Investor / Contributor' : 'Supplier / Vendor / Payee');

    final partyHint = _kind == 'income'
        ? 'e.g. Acme Corp, John Doe'
        : (_kind == 'capital' ? 'e.g. Founder, Angel Investor, Holding Co.' : 'e.g. Amazon Web Services, Office Landlord, Etisalat');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadiusVal)),
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
                                      ? CupertinoIcons.arrow_down_left_circle_fill
                                      : (_kind == 'capital'
                                          ? CupertinoIcons.briefcase_fill
                                          : CupertinoIcons.arrow_up_right_circle_fill),
                                  color: themeColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  isEdit ? 'Edit Transaction' : 'Record Transaction',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 20, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Kind Switcher Segmented Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildKindTab('income', 'Income', CupertinoIcons.arrow_down_left, AppTheme.zohoGreen, isDark),
                          const SizedBox(width: 4),
                          _buildKindTab('expense', 'Expense', CupertinoIcons.arrow_up_right, AppTheme.zohoRed, isDark),
                          const SizedBox(width: 4),
                          _buildKindTab('capital', 'Capital / Invest', CupertinoIcons.briefcase, const Color(0xFF8B5CF6), isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amount & Date Field
                    if (isNarrow) ...[
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        decoration: InputDecoration(
                          labelText: 'Amount (AED) *',
                          prefixText: 'AED  ',
                          prefixStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: themeColor,
                            fontSize: 15,
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              decoration: InputDecoration(
                                labelText: 'Amount (AED) *',
                                prefixText: 'AED  ',
                                prefixStyle: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: themeColor,
                                  fontSize: 15,
                                ),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 5,
                            child: TextFormField(
                              controller: _dateCtrl,
                              decoration: InputDecoration(
                                labelText: 'Date *',
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Category Field
                    DropdownButtonFormField<String>(
                      initialValue: _currentCategories.contains(_category) ? _category : _currentCategories.first,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        prefixIcon: const Icon(CupertinoIcons.folder, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      ),
                      isExpanded: true,
                      items: [
                        for (final cat in _currentCategories)
                          DropdownMenuItem(value: cat, child: Text(cat, overflow: TextOverflow.ellipsis)),
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
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _dueDateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Due Date (optional)',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                                prefixIcon: const Icon(CupertinoIcons.tag, size: 18),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                            prefixIcon: const Icon(CupertinoIcons.checkmark_alt_circle, size: 18),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'paid', child: Text('Paid Immediately', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'unpaid', child: Text('Unpaid (Supplier Bill)', overflow: TextOverflow.ellipsis)),
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
                          labelText: _status == 'unpaid' ? 'Payable Account' : 'Account / Method',
                          prefixIcon: const Icon(CupertinoIcons.creditcard, size: 18),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Bank', child: Text('Bank Account', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'Cash', child: Text('Cash in Hand / Petty Cash', overflow: TextOverflow.ellipsis)),
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
                                  prefixIcon: const Icon(CupertinoIcons.checkmark_alt_circle, size: 18),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'paid', child: Text('Paid Immediately', overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'unpaid', child: Text('Unpaid (Supplier Bill)', overflow: TextOverflow.ellipsis)),
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
                                labelText: _status == 'unpaid' ? 'Payable Account' : 'Account / Method',
                                prefixIcon: const Icon(CupertinoIcons.creditcard, size: 18),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Bank', child: Text('Bank Account', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Cash', child: Text('Cash in Hand / Petty Cash', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _account = v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_status == 'paid' || _kind == 'income' || _kind == 'capital') ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _paidDateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Payment / Settlement Date',
                          prefixIcon: const Icon(CupertinoIcons.calendar_today, size: 18),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                        hintText: 'Additional particulars, contract notes, or descriptions...',
                        prefixIcon: const Icon(CupertinoIcons.text_quote, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _submit,
                              icon: const Icon(CupertinoIcons.checkmark_alt, size: 16),
                              label: Text(isEdit ? 'Update' : 'Save'),
                              style: FilledButton.styleFrom(
                                backgroundColor: themeColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
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
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _submit,
                            icon: const Icon(CupertinoIcons.checkmark_alt, size: 16),
                            label: Text(isEdit ? 'Update Transaction' : 'Save Transaction'),
                            style: FilledButton.styleFrom(
                              backgroundColor: themeColor,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
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

  Widget _buildKindTab(String kindKey, String label, IconData icon, Color color, bool isDark) {
    final isSelected = _kind == kindKey;
    return Expanded(
      child: InkWell(
        onTap: () => _onKindChanged(kindKey),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
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
                color: isSelected ? color : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? Colors.grey[400] : Colors.grey[600]),
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

  Future<bool> run(String action, Map<String, dynamic> d) async => context.read<OfficeCubit>().run(action, d);

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
      old ?? {'id': const Uuid().v4(), 'version': 0, 'joinDate': today(), 'endDate': '', 'active': true, 'basic': '0', 'allowances': '0'},
      const [
        InputSpec('code', 'Employee Code', required: true, icon: CupertinoIcons.tag),
        InputSpec('name', 'Full Name', required: true, icon: CupertinoIcons.person),
        InputSpec('department', 'Department', icon: CupertinoIcons.building_2_fill),
        InputSpec('title', 'Job Title', icon: CupertinoIcons.briefcase),
        InputSpec('email', 'Email Address', icon: CupertinoIcons.mail),
        InputSpec('phone', 'Phone Number', icon: CupertinoIcons.phone),
        InputSpec('address', 'Address', icon: CupertinoIcons.location_solid),
        InputSpec('joinDate', 'Joining Date (YYYY-MM-DD)', required: true, icon: CupertinoIcons.calendar),
        InputSpec('endDate', 'Last Employment Date (optional)', icon: CupertinoIcons.calendar_badge_minus),
        InputSpec('basic', 'Monthly Basic Salary (AED)', required: true, icon: CupertinoIcons.money_dollar),
        InputSpec('allowances', 'Monthly Allowances (AED)', required: true, icon: CupertinoIcons.money_dollar_circle),
        InputSpec('bank', 'Bank Name', icon: CupertinoIcons.building_2_fill),
        InputSpec('iban', 'IBAN', icon: CupertinoIcons.creditcard),
        InputSpec('emiratesId', 'Emirates ID (optional)', icon: CupertinoIcons.person_crop_square),
        InputSpec('passport', 'Passport Number (optional)', icon: CupertinoIcons.book),
        InputSpec('visaExpiry', 'Visa Expiry (optional)', icon: CupertinoIcons.clock),
        InputSpec('notes', 'Notes', icon: CupertinoIcons.text_quote),
      ],
    );
    if (result != null) {
      for (final k in ['department', 'title', 'email', 'phone', 'address', 'bank', 'iban', 'emiratesId', 'passport', 'visaExpiry', 'notes', 'endDate']) {
        result[k] ??= '';
      }
      await run('employeeSave', result);
    }
  }

  Future<void> attendance(Map<String, dynamic> employee, Map<String, dynamic>? old) async {
    final result = await officeForm(
      context,
      'Attendance: ${employee['name']} / $day',
      old ?? {'employeeId': employee['id'], 'date': day, 'status': 'present', 'checkIn': '', 'checkOut': '', 'overtimeHours': '0', 'notes': '', 'version': 0},
      const [
        InputSpec('status', 'Attendance Status', options: ['present', 'absent', 'halfDay', 'paidLeave', 'unpaidLeave', 'sickLeave', 'off', 'holiday'], icon: CupertinoIcons.checkmark_alt_circle),
        InputSpec('checkIn', 'Check-in (HH:MM)', icon: CupertinoIcons.arrow_down_right_circle),
        InputSpec('checkOut', 'Check-out (HH:MM)', icon: CupertinoIcons.arrow_up_left_circle),
        InputSpec('overtimeHours', 'Approved Overtime Hours', required: true, icon: CupertinoIcons.stopwatch),
        InputSpec('notes', 'Notes', icon: CupertinoIcons.text_quote),
      ],
    );
    if (result != null) await run('attendanceSave', result);
  }

  Future<void> payroll(Map<String, dynamic> employee, [Map<String, dynamic>? old]) async {
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
        InputSpec('divisor', 'Salary Daily Divisor (1-31)', required: true, icon: CupertinoIcons.calendar),
        InputSpec('baseDays', 'Base Days Before Absence Deduction', required: true, icon: CupertinoIcons.calendar_today),
        InputSpec('scheduledDays', 'Expected Scheduled Working Days', required: true, icon: CupertinoIcons.chart_bar),
        InputSpec('overtimeRate', 'Overtime Hourly Rate (AED)', required: true, icon: CupertinoIcons.stopwatch),
        InputSpec('bonus', 'Bonus (AED)', required: true, icon: CupertinoIcons.gift),
        InputSpec('deductions', 'Other Deductions (AED)', required: true, icon: CupertinoIcons.minus_circle),
        InputSpec('adjustmentNote', 'Proration / Adjustment Explanation', icon: CupertinoIcons.text_quote),
      ],
    );
    if (result != null) await run('payrollGenerate', result);
  }

  Future<void> payPayroll(Map<String, dynamic> p) async {
    final d = await officeForm(
      context,
      'Record Salary Payment',
      {'id': p['id'], 'version': p['version'], 'paidDate': today(), 'account': 'Bank', 'reference': ''},
      const [
        InputSpec('paidDate', 'Payment Date', required: true, icon: CupertinoIcons.calendar),
        InputSpec('account', 'Paid From', options: ['Bank', 'Cash'], icon: CupertinoIcons.creditcard),
        InputSpec('reference', 'Payment Reference', icon: CupertinoIcons.tag),
      ],
    );
    if (d != null) {
      final ok = await run('payrollPay', d);
      if (ok && mounted && !context.read<OfficeCubit>().repository.isDemo) {
        final updated = context.read<OfficeCubit>().state.data.payroll.firstWhere((x) => x['id'] == p['id']);
        await archivePayroll(updated);
      }
    }
  }

  Future<void> archivePayroll(Map<String, dynamic> p) async => guarded(() async {
        final bytes = await context.read<OfficeDocuments>().payslip(p);
        await run('payrollArchive', {'id': p['id'], 'version': p['version'], 'pdf': base64Encode(bytes)});
      });

  Future<void> finance([Map<String, dynamic>? old, String defaultKind = 'expense']) async {
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
      {'id': e['id'], 'version': e['version'], 'paidDate': today(), 'account': 'Bank'},
      const [
        InputSpec('paidDate', 'Payment Date', required: true, icon: CupertinoIcons.calendar),
        InputSpec('account', 'Paid From', options: ['Bank', 'Cash'], icon: CupertinoIcons.creditcard),
      ],
    );
    if (d != null) await run('financePay', d);
  }

  Future<void> upload(String table, Map<String, dynamic> record) async => guarded(() async {
        final file = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'], withData: true);
        if (file == null) return;
        final f = file.files.single;
        if (f.bytes == null || f.size > 5000000) throw StateError('Select a file under 5 MB.');
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
              onPressed: () => launchUrl(Uri.parse(d['url']), mode: LaunchMode.externalApplication),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!), duration: const Duration(seconds: 7)));
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
                final titleText = ['Employees', 'Attendance', 'Payroll', 'Income & Expenses'][page];
                final subtitleText = [
                  'Staff directory, contracts, visa tracking and salaries.',
                  'Daily attendance, clocking and approved overtime hours.',
                  'Monthly payroll calculation, salary slips and approvals.',
                  'Manage company cash flow, client receipts, supplier bills, expenses, and capital.',
                ][page];

                Widget? actionButton;
                if (page == 0) {
                  actionButton = FilledButton.icon(
                    onPressed: () => employee(),
                    icon: const Icon(CupertinoIcons.person_add_solid, size: 16),
                    label: const Text('Add Employee'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.zohoBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
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
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              subtitleText,
                              style: TextStyle(
                                color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
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
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleText,
                            style: TextStyle(
                              color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
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
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: -0.2),
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
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: -0.2),
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
        .where((e) => '${e['name']} ${e['code']} ${e['department']} ${e['title']}'.toLowerCase().contains(search.toLowerCase()))
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
              prefixIcon: const Icon(CupertinoIcons.search, size: 18, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: search.isNotEmpty ? IconButton(icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Colors.grey), onPressed: () => setState(() => search = '')) : null,
            ),
            onChanged: (v) => setState(() => search = v),
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          EmptyState(
            icon: CupertinoIcons.person_crop_circle_badge_checkmark,
            title: search.isNotEmpty ? 'No matching employees' : 'No employees added',
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
                side: BorderSide(color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000), width: 0.8),
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
                            color: isDark ? AppTheme.pastelTealBgDark : AppTheme.pastelTealBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              e['name'].toString().isNotEmpty ? e['name'].toString().substring(0, 1).toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.pastelTeal, fontSize: 17),
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
                                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      e['code'],
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${e['department'].isNotEmpty ? '${e['department']} • ' : ''}${e['title']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
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
                              money(scaled(e['basic'].toString(), 2) + scaled(e['allowances'].toString(), 2)),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, letterSpacing: -0.3),
                            ),
                            const Text('Monthly', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                            const Icon(CupertinoIcons.calendar, size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('Joined ${e['joinDate']}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        if (e['endDate'].toString().isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.calendar_badge_minus, size: 13, color: AppTheme.pastelRose),
                              const SizedBox(width: 4),
                              Text('Ended ${e['endDate']}', style: const TextStyle(fontSize: 12, color: AppTheme.pastelRose)),
                            ],
                          ),
                        if (e['visaExpiry'].toString().isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(CupertinoIcons.clock, size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('Visa: ${e['visaExpiry']}', style: const TextStyle(fontSize: 12)),
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
                        TextButton.icon(
                          onPressed: () => employee(e),
                          icon: const Icon(CupertinoIcons.pencil, size: 15),
                          label: const Text('Edit Record'),
                        ),
                        if (!demo) ...[
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            onPressed: () => upload('Employees', e),
                            icon: const Icon(CupertinoIcons.paperclip, size: 15),
                            label: const Text('Attach Doc'),
                            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
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
    final records = state.data.attendance.where((a) => a['date'] == day).toList();

    return Column(
      children: [
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
                final a = records.where((r) => r['employeeId'] == e['id']).firstOrNull;
                final status = a?['status'] ?? 'notMarked';

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000), width: 0.8),
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
                              Text(e['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                              const SizedBox(height: 2),
                              Text(
                                '${e['code']} • ${e['department']}',
                                style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary),
                              ),
                              if (a != null && (a['checkIn'].toString().isNotEmpty || a['checkOut'].toString().isNotEmpty)) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'In: ${a['checkIn'].toString().isNotEmpty ? a['checkIn'] : '--:--'} • Out: ${a['checkOut'].toString().isNotEmpty ? a['checkOut'] : '--:--'}${a['overtimeHours'] != '0' ? ' • OT: ${a['overtimeHours']}h' : ''}',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary),
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
                              icon: const Icon(CupertinoIcons.pencil_circle_fill, size: 22),
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
    final monthPayroll = state.data.payroll.where((p) => p['month'] == month).toList();

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
                final p = monthPayroll.where((x) => x['employeeId'] == e['id']).firstOrNull;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000), width: 0.8),
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
                                  Text(e['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, letterSpacing: -0.2)),
                                  Text('${e['code']} • ${e['department']}', style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  p != null ? money((p['netCents'] as num).toInt()) : 'AED 0.00',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, letterSpacing: -0.3),
                                ),
                                const SizedBox(height: 4),
                                AppBadge.status(p?['status'] ?? 'uncalculated', isSmall: true),
                              ],
                            ),
                          ],
                        ),
                        if (p != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Net Salary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(money((p['netCents'] as num).toInt()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                const Divider(height: 16),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    Text('Base: ${money((p['baseCents'] as num).toInt())}', style: const TextStyle(fontSize: 12)),
                                    Text('OT: ${money((p['overtimeCents'] as num).toInt())}', style: const TextStyle(fontSize: 12)),
                                    Text('Bonus: ${money((p['bonusCents'] as num).toInt())}', style: const TextStyle(fontSize: 12)),
                                    Text('Absence: -${money((p['absenceCents'] as num).toInt())}', style: const TextStyle(fontSize: 12, color: AppTheme.pastelRose)),
                                    Text('Deductions: -${money((p['deductionCents'] as num).toInt())}', style: const TextStyle(fontSize: 12, color: AppTheme.pastelRose)),
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
                                icon: const Icon(CupertinoIcons.sparkles, size: 15),
                                label: Text(p == null ? 'Generate Draft' : 'Recalculate'),
                                style: FilledButton.styleFrom(backgroundColor: AppTheme.pastelBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                              ),
                            if (p != null && p['status'] == 'draft')
                              FilledButton.icon(
                                onPressed: () => approve(p),
                                icon: const Icon(CupertinoIcons.checkmark_seal_fill, size: 15),
                                label: const Text('Approve'),
                                style: FilledButton.styleFrom(backgroundColor: AppTheme.pastelMint, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                              ),
                            if (p != null && p['status'] == 'approved')
                              FilledButton.icon(
                                onPressed: () => payPayroll(p),
                                icon: const Icon(CupertinoIcons.money_dollar_circle_fill, size: 15),
                                label: const Text('Record Payment'),
                                style: FilledButton.styleFrom(backgroundColor: AppTheme.pastelMint, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                              ),
                            if (p != null)
                              OutlinedButton.icon(
                                onPressed: () => guarded(() async {
                                  await preview(await context.read<OfficeDocuments>().payslip(p), 'Payslip-${e['code']}-$month.pdf');
                                }),
                                icon: const Icon(CupertinoIcons.doc_text, size: 15),
                                label: const Text('View Payslip PDF'),
                                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                              ),
                            if (p != null && p['status'] != 'draft' && !demo)
                              OutlinedButton.icon(
                                onPressed: () => archivePayroll(p),
                                icon: const Icon(CupertinoIcons.cloud_upload, size: 15),
                                label: const Text('Save to Drive'),
                                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
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
        content: const Text('Confirm salary base days, overtime rates, and deductions are verified. Approved payroll and attendance will be locked.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.pastelBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (yes == true) {
      final ok = await run('payrollApprove', {'id': p['id'], 'version': p['version']});
      if (ok && mounted && !context.read<OfficeCubit>().repository.isDemo) {
        final updated = context.read<OfficeCubit>().state.data.payroll.firstWhere((x) => x['id'] == p['id']);
        await archivePayroll(updated);
      }
    }
  }

  Widget financialView(OfficeState state, bool demo, bool isDark) {
    final billing = context.watch<BillingCubit>().state.data;
    final summary = financialSummary(billing.invoices, state.data, month);

    final allMonthEntries = state.data.entries
        .where((e) => e['date'].toString().startsWith(month) || e['status'] == 'unpaid')
        .toList();

    final allCount = allMonthEntries.length;
    final incomeCount = allMonthEntries.where((e) => e['kind'] == 'income').length;
    final expenseCount = allMonthEntries.where((e) => e['kind'] == 'expense').length;
    final capitalCount = allMonthEntries.where((e) => e['kind'] == 'capital').length;
    final unpaidCount = allMonthEntries.where((e) => e['status'] == 'unpaid').length;

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
    } else if (financeTab == 'capital') {
      entries = entries.where((e) => e['kind'] == 'capital').toList();
    } else if (financeTab == 'unpaid') {
      entries = entries.where((e) => e['status'] == 'unpaid').toList();
    }

    // Category filter
    if (financeCategoryFilter != null && financeCategoryFilter!.isNotEmpty) {
      entries = entries.where((e) => e['category'] == financeCategoryFilter).toList();
    }

    // Account filter
    if (financeAccountFilter != null && financeAccountFilter!.isNotEmpty) {
      entries = entries.where((e) => e['account'] == financeAccountFilter).toList();
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
        return p.contains(q) || c.contains(q) || r.contains(q) || n.contains(q) || a.contains(q) || cents.contains(q);
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

    final totalIncome = (summary['Invoice collections'] ?? 0) + (summary['Other income'] ?? 0);
    final totalExpenses = (summary['Expenses paid'] ?? 0) + (summary['Payroll paid'] ?? 0);
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
                          icon: const Icon(CupertinoIcons.arrow_down_left_circle_fill, size: 13),
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Add Income', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.zohoGreen,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => finance(null, 'expense'),
                          icon: const Icon(CupertinoIcons.arrow_up_right_circle_fill, size: 13),
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.zohoRed,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => finance(null, 'capital'),
                          icon: const Icon(CupertinoIcons.briefcase_fill, size: 13),
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Add Capital', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<String>(
                        tooltip: 'Report options',
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (action) {
                          if (action == 'pdf') {
                            guarded(() async {
                              await preview(
                                await context.read<OfficeDocuments>().financialReport(
                                      billing.company.name,
                                      month,
                                      summary,
                                      state.data.entries,
                                    ),
                                'Finance-$month.pdf',
                              );
                            });
                          } else if (action == 'drive') {
                            guarded(() async {
                              final bytes = await context.read<OfficeDocuments>().financialReport(
                                    billing.company.name,
                                    month,
                                    summary,
                                    state.data.entries,
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
                                Text('Export PDF Report', style: TextStyle(fontSize: 13)),
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
                                  Text('Save to Drive', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Icon(
                            CupertinoIcons.ellipsis_vertical,
                            size: 16,
                            color: isDark ? AppTheme.iosDarkTextPrimary : AppTheme.iosLightTextPrimary,
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
                  icon: const Icon(CupertinoIcons.arrow_down_left_circle_fill, size: 16),
                  label: const Text('Add Income'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.zohoGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => finance(null, 'expense'),
                  icon: const Icon(CupertinoIcons.arrow_up_right_circle_fill, size: 16),
                  label: const Text('Add Expense'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.zohoRed,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => finance(null, 'capital'),
                  icon: const Icon(CupertinoIcons.briefcase_fill, size: 16),
                  label: const Text('Add Capital / Investment'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
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
                          ),
                      'Finance-$month.pdf',
                    );
                  }),
                  icon: const Icon(CupertinoIcons.doc_plaintext, size: 16),
                  label: const Text('Export PDF Report'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                  ),
                ),
                if (!demo)
                  OutlinedButton.icon(
                    onPressed: () => guarded(() async {
                      final bytes = await context.read<OfficeDocuments>().financialReport(
                            billing.company.name,
                            month,
                            summary,
                            state.data.entries,
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
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
                    accentColor: netCash >= 0 ? AppTheme.zohoBlue : AppTheme.zohoRed,
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
                    child: const Icon(CupertinoIcons.building_2_fill, size: 13, color: AppTheme.zohoBlue),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Bank: ${bankMovement >= 0 ? '+' : ''}${money(bankMovement)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: bankMovement >= 0 ? AppTheme.zohoGreen : AppTheme.zohoRed,
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
                    child: const Icon(CupertinoIcons.money_dollar, size: 13, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Cash: ${cashMovement >= 0 ? '+' : ''}${money(cashMovement)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cashMovement >= 0 ? AppTheme.zohoGreen : AppTheme.zohoRed,
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
                      child: const Icon(CupertinoIcons.briefcase_fill, size: 13, color: Color(0xFF8B5CF6)),
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
                  const Icon(CupertinoIcons.doc_text, size: 13, color: Colors.grey),
                  Text(
                    'Invoices: ${money(summary['Invoice collections'] ?? 0)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                    ),
                  ),
                  Text(
                    '• Salaries: ${money(summary['Payroll paid'] ?? 0)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
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
                _buildFinanceFilterTab('all', 'All Transactions', allCount, isDark, accentColor: AppTheme.zohoBlue),
                const SizedBox(width: 4),
                _buildFinanceFilterTab('income', 'Income', incomeCount, isDark, accentColor: AppTheme.zohoGreen),
                const SizedBox(width: 4),
                _buildFinanceFilterTab('expense', 'Expenses', expenseCount, isDark, accentColor: AppTheme.zohoRed),
                const SizedBox(width: 4),
                _buildFinanceFilterTab('capital', 'Capital / Investment', capitalCount, isDark, accentColor: const Color(0xFF8B5CF6)),
                const SizedBox(width: 4),
                _buildFinanceFilterTab('unpaid', 'Unpaid Bills', unpaidCount, isDark, accentColor: const Color(0xFFF59E0B)),
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
                  prefixIcon: const Icon(CupertinoIcons.search, size: 16, color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  suffixIcon: financeSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_circled_solid, size: 15, color: Colors.grey),
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
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: financeCategoryFilter,
                  hint: const Text('All Categories', style: TextStyle(fontSize: 13)),
                  isExpanded: isNarrow,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Categories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: financeAccountFilter,
                  hint: const Text('All Accounts', style: TextStyle(fontSize: 13)),
                  isExpanded: isNarrow,
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Accounts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Bank',
                      child: Text('Bank Account', style: TextStyle(fontSize: 13)),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Cash',
                      child: Text('Cash in Hand', style: TextStyle(fontSize: 13)),
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
            title: financeSearch.isNotEmpty || financeCategoryFilter != null || financeAccountFilter != null
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

  Widget _buildFinanceFilterTab(String key, String label, int count, bool isDark, {Color accentColor = AppTheme.zohoBlue}) {
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
                      : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
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
                    ? (highlightUnpaid ? const Color(0xFFF59E0B) : (isDark ? Colors.white : const Color(0xFF0F172A)))
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
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? (highlightUnpaid ? const Color(0xFFF59E0B) : accentColor)
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
        : (isCapital ? CupertinoIcons.briefcase_fill : CupertinoIcons.arrow_up_right_circle_fill);

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
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                reference,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: color.withValues(alpha: 0.2)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  account == 'Cash' ? CupertinoIcons.money_dollar : CupertinoIcons.building_2_fill,
                                  size: 11,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 3),
                                Text(account, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text(
                            date,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                            ),
                          ),
                          if (dueDate.isNotEmpty)
                            Text(
                              '• Due $dueDate',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isUnpaid ? FontWeight.bold : FontWeight.normal,
                                color: isUnpaid ? const Color(0xFFF59E0B) : Colors.grey,
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
                            color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (isUnpaid) ...[
                  FilledButton.icon(
                    onPressed: () => billPayment(e),
                    icon: const Icon(CupertinoIcons.checkmark_alt, size: 13),
                    label: const Text('Mark Paid', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.zohoGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.buttonRadiusVal)),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => voidBill(e),
                    icon: const Icon(CupertinoIcons.xmark_circle, size: 13, color: AppTheme.zohoRed),
                    label: const Text('Void', style: TextStyle(color: AppTheme.zohoRed, fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
        content: const Text('This will remove the unpaid bill from your payable balances.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.pastelRose, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (yes == true) await run('financeVoid', {'id': e['id'], 'version': e['version']});
  }
}
