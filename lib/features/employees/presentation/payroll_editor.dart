import 'package:tpc_invoice/core/widgets/forms/currency_fields.dart';
import 'package:tpc_invoice/core/widgets/forms/payment_method_dropdown.dart';
import 'package:tpc_invoice/core/widgets/forms/validated_text_field.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:flutter/material.dart';

class PayrollEditor extends StatefulWidget {
  const PayrollEditor({
    super.key,
    required this.employees,
    this.record,
    this.preview,
    this.rateLoader,
  });
  final ExchangeRateLoader? rateLoader;
  final List<Map<String, dynamic>> employees;
  final Map<String, dynamic>? record;
  final Future<Map<String, dynamic>> Function(Map<String, Object?>)? preview;
  @override
  State<PayrollEditor> createState() => _PayrollEditorState();
}

class _PayrollEditorState extends State<PayrollEditor> {
  final form = GlobalKey<FormState>();
  late final fx = CurrencyDraft(record: widget.record);
  Map<String, dynamic>? totals;
  String? previewError;
  bool calculating = false;
  int revision = 0;
  int salaryRequest = 0;
  Map<String, dynamic>? compensation;
  bool loadingSalary = false;
  String? salaryError;

  Future<void> loadCompensation() async {
    final selectedId = employeeId;
    final request = ++salaryRequest;
    if (selectedId == null || widget.preview == null) return;
    setState(() {
      compensation = null;
      loadingSalary = true;
      salaryError = null;
    });
    try {
      final result = await widget.preview!({
        'employeeId': selectedId,
        'month': month.text.trim(),
        'bonus': 0,
        'deductions': 0,
      });
      if (!mounted || request != salaryRequest) return;
      setState(() {
        compensation = Map<String, dynamic>.from(result['totals'] as Map);
      });
    } catch (_) {
      if (!mounted || request != salaryRequest) return;
      setState(() => salaryError = 'Could not refresh employee salary. Retry.');
    } finally {
      if (mounted && request == salaryRequest) {
        setState(() => loadingSalary = false);
      }
    }
  }

  void invalidate() {
    if (!mounted) return;
    setState(() {
      revision++;
      totals = null;
      previewError = null;
    });
  }

  @override
  void initState() {
    super.initState();
    month.addListener(invalidate);
    bonus.addListener(invalidate);
    deductions.addListener(invalidate);
    fx.currency.addListener(invalidate);
    fx.rate.addListener(invalidate);
    if (employeeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) loadCompensation();
      });
    }
  }

  Map<String, Object?> values() => {
        ...fx.values,
        'month': month.text.trim(),
        'employeeId': employeeId!,
        'bonus': double.parse(bonus.text.trim()),
        'deductions': double.parse(deductions.text.trim()),
        'bonusNotes': bonusNotes.text.trim(),
        'deductionNotes': deductionNotes.text.trim(),
      };
  Future<void> calculate() async {
    if (!AppFormValidation.validate(form.currentState!) ||
        widget.preview == null ||
        calculating) {
      return;
    }
    final requestedRevision = revision;
    setState(() {
      calculating = true;
      previewError = null;
      totals = null;
    });
    try {
      final result = await widget.preview!(values());
      if (mounted && requestedRevision == revision) {
        setState(
          () => totals = Map<String, dynamic>.from(result['totals'] as Map),
        );
      }
    } catch (error) {
      if (mounted && requestedRevision == revision) {
        setState(() => previewError = '$error');
      }
    } finally {
      if (mounted) setState(() => calculating = false);
    }
  }

  late String? employeeId = widget.record?['employeeId'] as String?;
  late final month = TextEditingController(
    text:
        '${widget.record?['month'] ?? DateTime.now().toIso8601String().substring(0, 7)}',
  );
  late final bonus = TextEditingController(
    text: '${widget.record?['bonus'] ?? 0}',
  );
  late final deductions = TextEditingController(
    text: '${widget.record?['deductions'] ?? 0}',
  );
  late final bonusNotes = TextEditingController(
    text: '${widget.record?['bonusNotes'] ?? ''}',
  );
  late final deductionNotes = TextEditingController(
    text: '${widget.record?['deductionNotes'] ?? ''}',
  );
  @override
  void dispose() {
    fx.currency.removeListener(invalidate);
    fx.rate.removeListener(invalidate);
    bonusNotes.dispose();
    deductionNotes.dispose();
    month.dispose();
    bonus.dispose();
    deductions.dispose();
    fx.dispose();
    super.dispose();
  }

  String? amount(String? input) {
    final text = input?.trim() ?? '', value = double.tryParse(text);
    return value == null ||
            !value.isFinite ||
            value < 0 ||
            value > 1e12 ||
            !AppValidators.decimalPattern.hasMatch(text)
        ? 'Enter a nonnegative amount, up to two decimals.'
        : null;
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title: Text(
          widget.record == null ? 'Create payroll draft' : 'Edit payroll draft',
        ),
        content: SizedBox(
          width: 680,
          child: Form(
            key: form,
            child: PopupFormFields(
              children: [
                CurrencyFields(
                    draft: fx,
                    transactionDate: month,
                    month: true,
                    loadRate: widget.rateLoader),
                SearchableRecordField(
                  initialValue: employeeId,
                  decoration: const InputDecoration(labelText: 'Employee'),
                  items: [
                    for (final row in widget.employees)
                      DropdownMenuItem(
                        value: row['recordId'] as String,
                        child: Text('${row['fullName']}'),
                      ),
                  ],
                  onChanged: widget.record == null
                      ? (value) {
                          employeeId = value;
                          final selected = widget.employees
                              .where((e) => e['recordId'] == value)
                              .firstOrNull;
                          if ('${selected?['currency'] ?? ''}'.isNotEmpty) {
                            fx.currency.text = '${selected!['currency']}';
                          }
                          invalidate();
                          loadCompensation();
                        }
                      : null,
                  validator: (value) =>
                      value == null ? 'Choose an employee.' : null,
                ),
                if (employeeId != null) ...[
                  for (final employee in widget.employees.where(
                    (row) => row['recordId'] == employeeId,
                  ))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final field in const {
                          'basicSalary': 'Monthly basic salary',
                          'allowances': 'Monthly allowances',
                        }.entries)
                          Text(
                            '${field.value}: ${employee['currency'] ?? fx.currency.text} ${num.tryParse('${compensation?[field.key] ?? employee[field.key]}')?.toStringAsFixed(2) ?? (loadingSalary ? 'Loading...' : 'Unavailable')}',
                          ),
                        if (loadingSalary)
                          const Text('Refreshing selected employee salary...'),
                        if (salaryError != null)
                          TextButton(
                            onPressed: loadCompensation,
                            child: Text(salaryError!),
                          ),
                      ],
                    ),
                  const Text(
                    'Full monthly compensation. Approved overtime for the selected month is added by the server; salary is not prorated.',
                  ),
                ],
                CalendarFormField(
                  controller: month,
                  mode: CalendarFieldMode.month,
                  enabled: widget.record == null,
                  decoration: const InputDecoration(
                    labelText: 'Payroll month (YYYY-MM)',
                  ),
                  validator: (value) => RegExp(
                    r'^\d{4}-(0[1-9]|1[0-2])$',
                  ).hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Use YYYY-MM.',
                ),
                ValidatedTextField(
                  required: true,
                  controller: bonus,
                  kind: AppInputKind.money,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Bonus'),
                  validator: amount,
                ),
                ValidatedTextField(
                  required: true,
                  controller: deductions,
                  kind: AppInputKind.money,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Deductions'),
                  validator: amount,
                ),
                ValidatedTextField(
                  controller: bonusNotes,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bonus notes (optional)',
                    hintText: 'Reason for the bonus',
                  ),
                ),
                ValidatedTextField(
                  controller: deductionNotes,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Deduction notes (optional)',
                    hintText: 'Reason for the deduction',
                  ),
                ),
                if (widget.preview != null) ...[
                  LoadingButton.outlined(
                    onPressed: calculating ? null : calculate,
                    child: Text(
                      calculating
                          ? 'Calculating payroll…'
                          : 'Calculate payroll',
                    ),
                  ),
                  if (previewError != null)
                    Text(
                      previewError!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  if (totals != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Payroll preview',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            for (final entry in const {
                              'basicSalary': 'Basic salary',
                              'allowances': 'Allowances',
                              'overtimeAmount': 'Approved overtime',
                              'bonus': 'Bonus',
                              'deductions': 'Deductions',
                              'grossSalary': 'Gross salary',
                              'netSalary': 'Net salary',
                            }.entries)
                              Text(
                                '${entry.value}: ${(num.tryParse('${totals![entry.key]}') ?? 0).toStringAsFixed(2)}',
                              ),
                            const Text(
                              'Saving refreshes amounts. Approval checks that salary and overtime have not changed.',
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          LoadingButton.text(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          LoadingButton(
            onPressed: () {
              if (!AppFormValidation.validate(form.currentState!)) return;
              Navigator.pop(context, values());
            },
            child: const Text('Save draft'),
          ),
        ],
      );
}

class PayrollPaymentEditor extends StatefulWidget {
  const PayrollPaymentEditor(
      {super.key, required this.amount, this.record, this.rateLoader});
  final Object? amount;
  final Map<String, dynamic>? record;
  final ExchangeRateLoader? rateLoader;
  @override
  State<PayrollPaymentEditor> createState() => _PayrollPaymentEditorState();
}

class _PayrollPaymentEditorState extends State<PayrollPaymentEditor> {
  late final fx =
      CurrencyDraft(record: {'currency': widget.record?['currency'] ?? ''});
  final form = GlobalKey<FormState>();
  String account = 'Bank';
  final date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final reference = TextEditingController();
  @override
  void dispose() {
    date.dispose();
    fx.dispose();
    reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title: const Text('Pay approved payroll'),
        content: Form(
          key: form,
          child: PopupFormFields(
            children: [
              CurrencyFields(
                  draft: fx,
                  transactionDate: date,
                  fixedCurrency: true,
                  loadRate: widget.rateLoader),
              Text('Net salary: ${widget.amount}'),
              CalendarFormField(
                controller: date,
                decoration: const InputDecoration(labelText: 'Payment date'),
                validator: (value) {
                  final text = value?.trim() ?? '',
                      parsed = DateTime.tryParse(text);
                  return AppValidators.datePattern.hasMatch(text) &&
                          parsed != null &&
                          parsed.toIso8601String().startsWith(text)
                      ? null
                      : 'Enter a valid date.';
                },
              ),
              PaymentMethodDropdown(
                value: account,
                decoration: const InputDecoration(labelText: 'Payment account'),
                onChanged: (value) => account = value ?? 'Bank',
              ),
              ValidatedTextField(
                controller: reference,
                kind: AppInputKind.reference,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Reference (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          LoadingButton.text(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          LoadingButton(
            onPressed: () {
              if (!AppFormValidation.validate(form.currentState!)) return;
              Navigator.pop(context, <String, Object?>{
                'paymentExchangeRate': double.parse(fx.rate.text),
                'paidDate': date.text.trim(),
                'paymentAccount': account,
                'paymentReference': reference.text.trim(),
              });
            },
            child: const Text('Record payment'),
          ),
        ],
      );
}
