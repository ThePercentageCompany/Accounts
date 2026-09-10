import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
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

  @override
  void initState() {
    super.initState();
    page = widget.initialPage;
    activeFilterKind = widget.filterKind;
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

  Future<void> finance([Map<String, dynamic>? old]) async {
    final d = await officeForm(
      context,
      old == null ? 'Record Transaction / Bill' : 'Edit Bill / Entry',
      old ?? {
        'id': const Uuid().v4(),
        'version': 0,
        'kind': 'expense',
        'date': today(),
        'dueDate': '',
        'paidDate': today(),
        'status': 'unpaid',
        'account': 'Bank',
        'amount': '0',
        'category': 'Office',
        'party': '',
        'reference': '',
        'notes': '',
      },
      const [
        InputSpec('kind', 'Transaction Type', options: ['expense', 'income'], icon: CupertinoIcons.arrow_right_arrow_left),
        InputSpec('party', 'Supplier / Client / Payee', icon: CupertinoIcons.person),
        InputSpec('reference', 'Bill / Invoice / Reference #', icon: CupertinoIcons.tag),
        InputSpec('category', 'Category', required: true, icon: CupertinoIcons.folder),
        InputSpec('date', 'Date', required: true, icon: CupertinoIcons.calendar),
        InputSpec('dueDate', 'Due Date (optional)', icon: CupertinoIcons.clock),
        InputSpec('amount', 'Amount (AED)', required: true, icon: CupertinoIcons.money_dollar),
        InputSpec('status', 'Payment Status', options: ['unpaid', 'paid'], icon: CupertinoIcons.checkmark_alt_circle),
        InputSpec('paidDate', 'Payment Date (if paid)', icon: CupertinoIcons.calendar_today),
        InputSpec('account', 'Account', options: ['Bank', 'Cash'], icon: CupertinoIcons.creditcard),
        InputSpec('notes', 'Notes', icon: CupertinoIcons.text_quote),
      ],
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
                final titleText = ['Employees', 'Attendance', 'Payroll', 'Company Finance'][page];
                final subtitleText = [
                  'Staff directory, contracts, visa tracking and salaries.',
                  'Daily attendance, clocking and approved overtime hours.',
                  'Monthly payroll calculation, salary slips and approvals.',
                  'Cash flow, supplier bills, expenses and income summary.',
                ][page];

                Widget? actionButton;
                if (page == 0) {
                  actionButton = FilledButton.icon(
                    onPressed: () => employee(),
                    icon: const Icon(CupertinoIcons.person_add_solid, size: 16),
                    label: const Text('Add Employee'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.pastelBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                  );
                } else if (page == 3) {
                  actionButton = FilledButton.icon(
                    onPressed: () => finance(),
                    icon: const Icon(CupertinoIcons.plus_circle_fill, size: 16),
                    label: const Text('Add Entry'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.pastelBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                  );
                }

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        titleText,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                          fontSize: 13.5,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (actionButton != null) ...[
                        const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous Day',
            icon: const Icon(CupertinoIcons.chevron_left, size: 18),
            onPressed: () => _shiftDay(-1),
          ),
          const SizedBox(width: 6),
          const Icon(CupertinoIcons.calendar, size: 17),
          const SizedBox(width: 8),
          Text(
            day,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Next Day',
            icon: const Icon(CupertinoIcons.chevron_right, size: 18),
            onPressed: () => _shiftDay(1),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => day = today()),
            child: const Text('Today', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous Month',
            icon: const Icon(CupertinoIcons.chevron_left, size: 18),
            onPressed: () => _shiftMonth(-1),
          ),
          const SizedBox(width: 6),
          const Icon(CupertinoIcons.calendar_today, size: 17),
          const SizedBox(width: 8),
          Text(
            month,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Next Month',
            icon: const Icon(CupertinoIcons.chevron_right, size: 18),
            onPressed: () => _shiftMonth(1),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => month = today().substring(0, 7)),
            child: const Text('This Month', style: TextStyle(fontWeight: FontWeight.w700)),
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
    final eligible = state.data.employees
        .where((e) => e['joinDate'].toString().compareTo(day) <= 0 && (e['endDate'] == '' || e['endDate'].toString().compareTo(day) >= 0))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eligible.isEmpty)
          const EmptyState(
            icon: CupertinoIcons.calendar,
            title: 'No eligible employees',
            message: 'Add active employee records with joining dates on or before this day.',
          )
        else
          for (final e in eligible) ...[
            Builder(
              builder: (context) {
                Map<String, dynamic>? record;
                for (final row in state.data.attendance) {
                  if (row['employeeId'] == e['id'] && row['date'] == day) {
                    record = row;
                  }
                }
                final status = record?['status']?.toString() ?? 'not marked';

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
                        color: isDark ? AppTheme.pastelIndigoBgDark : AppTheme.pastelIndigoBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          e['name'].toString().isNotEmpty ? e['name'].toString().substring(0, 1).toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.pastelIndigo, fontSize: 16),
                        ),
                      ),
                    ),
                    title: Text(e['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, letterSpacing: -0.2)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            AppBadge.status(status == 'not marked' ? 'Unmarked' : status, isSmall: true),
                            if (record != null && record['checkIn'].toString().isNotEmpty)
                              Text(
                                '${record['checkIn']} – ${record['checkOut']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (record != null && (record['overtimeHours']?.toString() != '0' && record['overtimeHours']?.toString() != '0.00'))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.pastelOrangeBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${record['overtimeHours']}h OT',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.pastelOrange),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: FilledButton.tonalIcon(
                      onPressed: () => attendance(e, record),
                      icon: const Icon(CupertinoIcons.calendar_badge_plus, size: 15),
                      label: const Text('Mark'),
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                    ),
                    onTap: () => attendance(e, record),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget payrollView(OfficeState state, bool demo, bool isDark) {
    final eligible = state.data.employees
        .where((e) => e['joinDate'].toString().substring(0, 7).compareTo(month) <= 0 && (e['endDate'] == '' || e['endDate'].toString().substring(0, 7).compareTo(month) >= 0))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eligible.isEmpty)
          const EmptyState(
            icon: CupertinoIcons.money_dollar_circle,
            title: 'No eligible payroll records',
            message: 'Add active employees with joining dates in or before this month.',
          )
        else
          for (final e in eligible) ...[
            Builder(
              builder: (context) {
                Map<String, dynamic>? record;
                for (final p in state.data.payroll) {
                  if (p['employee']['id'] == e['id'] && p['month'] == month) {
                    record = p;
                  }
                }
                final p = record;
                final status = p?['status']?.toString() ?? 'not generated';

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
                                  Text(
                                    e['name'],
                                    style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                                  ),
                                  Text(
                                    'Code: ${e['code']} • Month: $month',
                                    style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary),
                                  ),
                                ],
                              ),
                            ),
                            AppBadge.status(status == 'not generated' ? 'Draft' : status),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (p != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Net Salary Payout', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                    Text(
                                      money((p['netCents'] as num).toInt()),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.pastelMint,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
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
                                const SizedBox(height: 6),
                                Text(
                                  'Marked ${p['markedDays']} / ${p['scheduledDays']} scheduled days • Unpaid: ${p['absentDays']}d',
                                  style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
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

    var entries = state.data.entries
        .where((e) => e['date'].toString().startsWith(month) || e['status'] == 'unpaid')
        .toList();
    if (activeFilterKind != null) {
      entries = entries.where((e) => e['kind'] == activeFilterKind).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Financial Metrics Grid
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
                for (final e in summary.entries)
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      title: e.key.toUpperCase(),
                      value: money(e.value),
                      icon: e.key.contains('income') || e.key.contains('collection')
                          ? CupertinoIcons.arrow_down_left_circle_fill
                          : e.key.contains('Expense') || e.key.contains('Payroll')
                              ? CupertinoIcons.arrow_up_right_circle_fill
                              : CupertinoIcons.creditcard_fill,
                      accentColor: e.key.contains('income') || e.key.contains('collection')
                          ? AppTheme.pastelMint
                          : e.key.contains('Expense') || e.key.contains('Payroll')
                              ? AppTheme.pastelRose
                              : AppTheme.pastelBlue,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),

        // Action Buttons Row
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => finance(),
              icon: const Icon(CupertinoIcons.plus_circle_fill, size: 16),
              label: const Text('Add Transaction / Bill'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.pastelBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
            ),
            OutlinedButton.icon(
              onPressed: () => guarded(() async {
                await preview(await context.read<OfficeDocuments>().financialReport(billing.company.name, month, summary, state.data.entries), 'Finance-$month.pdf');
              }),
              icon: const Icon(CupertinoIcons.doc_plaintext, size: 16),
              label: const Text('Print / Export Report'),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
            ),
            if (!demo)
              OutlinedButton.icon(
                onPressed: () => guarded(() async {
                  final bytes = await context.read<OfficeDocuments>().financialReport(billing.company.name, month, summary, state.data.entries);
                  await run('reportArchive', {'month': month, 'requestId': const Uuid().v4(), 'pdf': base64Encode(bytes)});
                }),
                icon: const Icon(CupertinoIcons.cloud_upload, size: 16),
                label: const Text('Save Report to Drive'),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
              ),
          ],
        ),
        const SizedBox(height: 24),

        const Text('Transactions & Bills', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        const SizedBox(height: 10),

        if (entries.isEmpty)
          const EmptyState(
            icon: CupertinoIcons.creditcard,
            title: 'No transactions for this month',
            message: 'Add supplier bills, office expenses or other income records.',
          )
        else
          for (final e in entries) ...[
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e['party'].isNotEmpty ? e['party'] : 'General'} / ${e['category']}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2),
                              ),
                              Text(
                                '${e['date']}${e['dueDate'].isNotEmpty ? ' • Due ${e['dueDate']}' : ''}',
                                style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${e['kind'] == 'expense' ? '-' : '+'}${money((e['amountCents'] as num).toInt())}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: -0.3,
                                color: e['kind'] == 'expense' ? AppTheme.pastelRose : AppTheme.pastelMint,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AppBadge.status(e['status'], isSmall: true),
                          ],
                        ),
                      ],
                    ),
                    documents(e),
                    if (e['status'] == 'unpaid') ...[
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => finance(e), child: const Text('Edit')),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => billPayment(e),
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.pastelMint, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                            child: const Text('Mark Paid'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => voidBill(e),
                            child: const Text('Void', style: TextStyle(color: AppTheme.pastelRose)),
                          ),
                          if (!demo) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Attach file',
                              icon: const Icon(CupertinoIcons.paperclip),
                              onPressed: () => upload('Finance', e),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
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
