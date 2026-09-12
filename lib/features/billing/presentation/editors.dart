import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/auth/google_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/date_field.dart';
import '../domain/models.dart';
import '../domain/invoice_document_service.dart';
import '../domain/totals.dart';
import 'billing_cubit.dart';
import '../../office/presentation/office_cubit.dart';
import 'screens.dart';

String? validateDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return 'Use YYYY-MM-DD';
  final date = DateTime.tryParse(value);
  return date == null || date.toIso8601String().substring(0, 10) != value ? 'Enter a valid date' : null;
}

String? requiredText(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;

Widget field(
  String label,
  String value,
  ValueChanged<String> changed, {
  bool required = false,
  int max = 600,
  int lines = 1,
  String? Function(String?)? validator,
  IconData? prefixIcon,
  String? hint,
}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
        ),
        maxLines: lines,
        maxLength: max,
        onChanged: changed,
        validator: validator ?? (required ? requiredText : null),
      ),
    );

Future<void> editCustomer(BuildContext context, [Customer? old]) async {
  final cubit = context.read<BillingCubit>();
  final form = GlobalKey<FormState>();
  var data = (old ?? Customer(id: const Uuid().v4(), name: '')).toJson();

  final result = await showDialog<Customer>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(old == null ? 'Add Customer' : 'Edit Customer'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field('Customer / Company Name', data['name'], (v) => data['name'] = v, required: true, max: 200, prefixIcon: CupertinoIcons.building_2_fill),
                field('Email Address', data['email'], (v) => data['email'] = v, max: 200, prefixIcon: CupertinoIcons.mail),
                field('Phone Number', data['phone'], (v) => data['phone'] = v, max: 80, prefixIcon: CupertinoIcons.phone),
                field('Billing Address', data['address'], (v) => data['address'] = v, lines: 2, prefixIcon: CupertinoIcons.location_solid),
                field('TRN / Tax Registration (optional)', data['trn'], (v) => data['trn'] = v, max: 80, prefixIcon: CupertinoIcons.tag),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(ctx, Customer.fromJson(data));
            }
          },
          style: FilledButton.styleFrom(backgroundColor: AppTheme.pastelBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
          child: const Text('Save Customer'),
        ),
      ],
    ),
  );

  if (result != null) {
    final ok = await cubit.run(() => cubit.repository.saveCustomer(result));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cubit.state.error ?? 'Save failed')));
    }
  }
}

class CompanyEditor extends StatefulWidget {
  final Company company;
  const CompanyEditor({super.key, required this.company});

  @override
  State<CompanyEditor> createState() => _CompanyEditorState();
}

class _CompanyEditorState extends State<CompanyEditor> {
  final form = GlobalKey<FormState>();
  late Map<String, dynamic> data;

  @override
  void initState() {
    super.initState();
    data = widget.company.toJson();
  }

  Future<void> pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null || bytes.length > 1024 * 1024) {
        throw const FormatException('Choose a PNG or JPG logo under 1 MB.');
      }
      final png = bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78 && bytes[3] == 71;
      final jpg = bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216;
      if (!png && !jpg) throw const FormatException('Use a valid PNG or JPEG image.');
      if (mounted) setState(() => data['logo'] = base64Encode(bytes));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, state) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Company Settings',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                      ),
                      Text(
                        'Configure your branding, company profile, and bank details for invoices.',
                        style: TextStyle(
                          color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                          fontSize: 14,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Logo Upload Card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000), width: 0.8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Company Branding & Logo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.2)),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isSmall = constraints.maxWidth < 460;
                              final logoBox = Container(
                                width: isSmall ? 110 : 130,
                                height: isSmall ? 60 : 70,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: (data['logo'] as String).isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(base64Decode(data['logo']), fit: BoxFit.contain),
                                      )
                                    : const Center(
                                        child: Icon(CupertinoIcons.photo, color: Colors.grey, size: 28),
                                      ),
                              );

                              final actionsAndHelp = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: state.busy ? null : pickLogo,
                                        icon: const Icon(CupertinoIcons.cloud_upload, size: 16),
                                        label: const Text('Upload Logo'),
                                        style: FilledButton.styleFrom(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                        ),
                                      ),
                                      if ((data['logo'] as String).isNotEmpty)
                                        TextButton.icon(
                                          onPressed: () => setState(() => data['logo'] = ''),
                                          icon: const Icon(CupertinoIcons.trash, size: 15, color: AppTheme.pastelRose),
                                          label: const Text('Remove', style: TextStyle(color: AppTheme.pastelRose)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'PNG or JPG, up to 1 MB. Applied to newly issued invoices and quotations.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                                    ),
                                  ),
                                ],
                              );

                              if (isSmall) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    logoBox,
                                    const SizedBox(height: 12),
                                    actionsAndHelp,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  logoBox,
                                  const SizedBox(width: 16),
                                  Expanded(child: actionsAndHelp),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Business Details Card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000), width: 0.8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Business Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.2)),
                          const SizedBox(height: 16),
                          field('Company Name', data['name'], (v) => data['name'] = v, required: true, prefixIcon: CupertinoIcons.building_2_fill),
                          field('Invoice Prefix (e.g. TPC, INV)', data['prefix'], (v) => data['prefix'] = v, required: true, validator: (v) => RegExp(r'^[A-Z0-9]{1,12}$').hasMatch(v ?? '') ? null : 'Use 1-12 uppercase letters or digits', prefixIcon: CupertinoIcons.tag),
                          field('TRN / Tax Registration Number', data['trn'], (v) => data['trn'] = v, prefixIcon: CupertinoIcons.doc_text),
                          field('Email Address', data['email'], (v) => data['email'] = v, prefixIcon: CupertinoIcons.mail),
                          field('Phone Number', data['phone'], (v) => data['phone'] = v, prefixIcon: CupertinoIcons.phone),
                          field('Company Address', data['address'], (v) => data['address'] = v, lines: 2, prefixIcon: CupertinoIcons.location_solid),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Bank & Payment Details Card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000), width: 0.8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bank & Payment Information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.2)),
                          const SizedBox(height: 16),
                          field('Account Holder Name', data['accountHolder'], (v) => data['accountHolder'] = v, prefixIcon: CupertinoIcons.person),
                          field('Bank Name', data['bank'], (v) => data['bank'] = v, prefixIcon: CupertinoIcons.building_2_fill),
                          field('Account Number', data['accountNumber'], (v) => data['accountNumber'] = v, prefixIcon: CupertinoIcons.number),
                          field('IBAN', data['iban'], (v) => data['iban'] = v, prefixIcon: CupertinoIcons.creditcard),
                          field('Default Payment Terms', data['terms'], (v) => data['terms'] = v, lines: 2, prefixIcon: CupertinoIcons.doc_plaintext),
                          field('Default Notes', data['notes'], (v) => data['notes'] = v, lines: 2, prefixIcon: CupertinoIcons.text_badge_checkmark),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: state.busy
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            final cubit = context.read<BillingCubit>();
                            final ok = await cubit.run(() => cubit.repository.saveCompany(Company.fromJson(data)));
                            if (ok) {
                              data = cubit.state.data.company.toJson();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company settings saved.')));
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.pastelBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: const Text('Save Company Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 24),

                  // Current Account & Logout Section
                  Builder(
                    builder: (context) {
                      GoogleSession? session;
                      try {
                        session = Provider.of<GoogleSession>(context, listen: false);
                      } catch (_) {}

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(CupertinoIcons.square_arrow_right, color: Color(0xFFEF4444), size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current Session',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    session?.effectiveEmail ?? 'Local Demo Workspace',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Row(
                                      children: [
                                        Icon(CupertinoIcons.square_arrow_right, color: Color(0xFFEF4444), size: 22),
                                        SizedBox(width: 10),
                                        Text('Log Out', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    content: const Text(
                                      'Are you sure you want to log out of your TPC Business account? All local cache and browser data will be cleared.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFFEF4444),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && session != null) {
                                  await session.signOut();
                                  if (context.mounted) {
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                  }
                                }
                              },
                              icon: const Icon(CupertinoIcons.square_arrow_right, size: 14, color: Color(0xFFEF4444)),
                              label: const Text('Log Out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 12.5)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFEF4444), width: 0.8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
}

class InvoiceEditor extends StatefulWidget {
  final Invoice? invoice;
  const InvoiceEditor({super.key, this.invoice});

  @override
  State<InvoiceEditor> createState() => _InvoiceEditorState();
}

class _InvoiceEditorState extends State<InvoiceEditor> {
  final form = GlobalKey<FormState>();
  late Invoice invoice;
  late List<Map<String, String>> rows;
  bool dirty = false;

  String reference = '';
  String paymentTerms = 'Net 30';
  String currency = 'AED - UAE Dirham (د.إ)';
  String termsAndConditions =
      '1. Payment is due within 30 days from the invoice date.\n2. Please include the invoice number in your payment.\n3. Thank you for your business!';
  String invoiceNotes = '';
  int _mobileTab = 0; // 0 = Edit Form, 1 = Live Preview

  @override
  void initState() {
    super.initState();
    final data = context.read<BillingCubit>().state.data;
    invoice = widget.invoice ??
        Invoice(
          id: const Uuid().v4(),
          date: today(),
          customer: data.customers.isNotEmpty ? data.customers.first : const Customer(id: '', name: 'Customer'),
          company: data.company,
          notes: data.company.notes,
          terms: data.company.terms,
          taxRate: '5',
        );

    if (invoice.terms.isNotEmpty) {
      paymentTerms = invoice.terms;
    }
    if (invoice.notes.isNotEmpty) {
      invoiceNotes = invoice.notes;
    }

    rows = invoice.items
        .map((x) => {
              'key': const Uuid().v4(),
              'description': x.description,
              'quantity': x.quantity,
              'rate': x.rate,
              'discount': '0.00',
              'vat': invoice.taxRate.isNotEmpty ? invoice.taxRate : '5',
            })
        .toList();

    if (rows.isEmpty) {
      rows.add({
        'key': const Uuid().v4(),
        'description': 'Website Development\nCustom website design and development',
        'quantity': '1',
        'rate': '5000.00',
        'discount': '0.00',
        'vat': '5',
      });
      rows.add({
        'key': const Uuid().v4(),
        'description': 'SEO Services\nMonthly SEO management',
        'quantity': '1',
        'rate': '2000.00',
        'discount': '0.00',
        'vat': '5',
      });
    }

    // Auto compute due date if not set
    if (invoice.dueDate.isEmpty) {
      _applyPaymentTerms(paymentTerms, updateState: false);
    }
  }

  void _applyPaymentTerms(String terms, {bool updateState = true}) {
    final baseDate = DateTime.tryParse(invoice.date) ?? DateTime.now();
    DateTime newDue;
    if (terms == 'Due on Receipt') {
      newDue = baseDate;
    } else if (terms == 'Net 15') {
      newDue = baseDate.add(const Duration(days: 15));
    } else if (terms == 'Net 30') {
      newDue = baseDate.add(const Duration(days: 30));
    } else if (terms == 'Net 45') {
      newDue = baseDate.add(const Duration(days: 45));
    } else if (terms == 'Net 60') {
      newDue = baseDate.add(const Duration(days: 60));
    } else {
      newDue = baseDate.add(const Duration(days: 30));
    }

    final formatted = newDue.toIso8601String().substring(0, 10);
    if (updateState) {
      changed(() {
        paymentTerms = terms;
        invoice = invoice.copyWith(dueDate: formatted, terms: terms);
      });
    } else {
      paymentTerms = terms;
      invoice = invoice.copyWith(dueDate: formatted, terms: terms);
    }
  }

  void addRow() {
    rows.add({
      'key': const Uuid().v4(),
      'description': '',
      'quantity': '1',
      'rate': '0.00',
      'discount': '0.00',
      'vat': invoice.taxRate.isNotEmpty ? invoice.taxRate : '5',
    });
  }

  Invoice current() {
    return invoice.copyWith(
      items: rows
          .map((x) => LineItem(
                description: x['description'] ?? '',
                quantity: x['quantity'] ?? '1',
                rate: x['rate'] ?? '0.00',
              ))
          .toList(),
      notes: invoiceNotes,
      terms: paymentTerms,
    );
  }

  void changed(VoidCallback update) {
    setState(() {
      update();
      dirty = true;
    });
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

  Future<void> save({bool issue = false}) async {
    if (!form.currentState!.validate()) return;
    try {
      Totals.of(current());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }

    if (issue) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Issue & Send Invoice?'),
          content: const Text(
            'A unique sequential invoice number will be assigned. Items, prices and customer details will then be locked.',
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
      if (yes != true || !mounted) return;
    }

    final cubit = context.read<BillingCubit>();
    final ok = await cubit.run(() async {
      invoice = await cubit.repository.saveDraft(current());
      if (issue) invoice = await cubit.repository.issue(invoice);
    });

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cubit.state.error ?? 'Save failed')));
      return;
    }

    setState(() => dirty = false);
    if (issue) {
      if (!cubit.repository.isDemo) {
        final archived = await cubit.run(() async {
          final bytes = await context.read<InvoiceDocumentService>().render(invoice);
          await cubit.repository.archive(invoice, bytes);
        });
        if (!archived && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice issued. PDF archive saved to Drive.')),
          );
        }
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(value: cubit, child: InvoiceDetail(id: invoice.id)),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice saved as draft.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1050;

    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, state) {
        Totals? totals;
        try {
          totals = Totals.of(current());
        } catch (_) {}

        return PopScope(
          canPop: !dirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final leave = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Discard Unsaved Changes?'),
                content: const Text('You have unsaved edits in this invoice. Are you sure you want to discard them?'),
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
              setState(() => dirty = false);
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
                                      'Edit Invoice Form',
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
                      key: form,
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
                                      _buildInvoiceInformationCard(context, isDark, state),
                                      const SizedBox(height: 18),
                                      _buildInvoiceItemsCard(context, isDark),
                                      const SizedBox(height: 18),
                                      _buildTermsAndTotalsCard(context, isDark, totals),
                                      const SizedBox(height: 24),
                                      _buildBottomActionsBar(context, isDark, state),
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
                                    _buildInvoiceInformationCard(context, isDark, state),
                                    const SizedBox(height: 16),
                                    _buildInvoiceItemsCard(context, isDark),
                                    const SizedBox(height: 16),
                                    _buildTermsAndTotalsCard(context, isDark, totals),
                                    const SizedBox(height: 20),
                                    _buildBottomActionsBar(context, isDark, state),
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
      },
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
                widget.invoice == null ? 'Create Invoice' : 'Edit Invoice',
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
                      'Invoices',
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
                    widget.invoice == null ? 'Create Invoice' : 'Edit Invoice',
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

          // Back Button
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
    );
  }

  // -------------------------------------------------------------
  // 2. Invoice Information Card
  // -------------------------------------------------------------
  Widget _buildInvoiceInformationCard(BuildContext context, bool isDark, BillingState state) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.zohoCardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoice Information',
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
                    initialValue: state.data.customers.any((c) => c.id == invoice.customer.id)
                        ? invoice.customer.id
                        : (state.data.customers.isNotEmpty ? state.data.customers.first.id : null),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(CupertinoIcons.person, size: 18),
                      hintText: 'Select Customer',
                    ),
                    isExpanded: true,
                    items: [
                      for (final c in state.data.customers)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null) {
                        changed(() {
                          invoice = invoice.copyWith(
                            customer: state.data.customers.firstWhere((c) => c.id == id),
                          );
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => editCustomer(context),
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
                    initialValue: reference,
                    decoration: const InputDecoration(
                      hintText: 'Enter reference',
                    ),
                    onChanged: (v) => changed(() => reference = v),
                  ),
                  const SizedBox(height: 24),
                ],
              );

              // Row 2: Invoice Number & Payment Terms
              final invoiceNumCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invoice Number *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: invoice.number.isNotEmpty ? invoice.number : 'INV-2024-0001',
                    decoration: const InputDecoration(
                      hintText: 'INV-2024-0001',
                    ),
                    onChanged: (v) => changed(() => invoice = invoice.copyWith(number: v)),
                  ),
                ],
              );

              final paymentTermsCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Terms', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: paymentTerms,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'Net 30', child: Text('Net 30')),
                      DropdownMenuItem(value: 'Due on Receipt', child: Text('Due on Receipt')),
                      DropdownMenuItem(value: 'Net 15', child: Text('Net 15')),
                      DropdownMenuItem(value: 'Net 45', child: Text('Net 45')),
                      DropdownMenuItem(value: 'Net 60', child: Text('Net 60')),
                      DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                    ],
                    onChanged: (v) {
                      if (v != null) _applyPaymentTerms(v);
                    },
                  ),
                ],
              );

              // Row 3: Invoice Date & Currency
              final invoiceDateCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DatePickerField(
                    label: 'Invoice Date *',
                    value: invoice.date,
                    onChanged: (v) => changed(() {
                      invoice = invoice.copyWith(date: v);
                      _applyPaymentTerms(paymentTerms);
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
                    initialValue: currency,
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
                      if (v != null) changed(() => currency = v);
                    },
                  ),
                ],
              );

              // Row 4: Due Date & Notes
              final dueDateCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DatePickerField(
                    label: 'Due Date *',
                    value: invoice.dueDate,
                    onChanged: (v) => changed(() => invoice = invoice.copyWith(dueDate: v)),
                    validator: (v) => v == null || v.isEmpty
                        ? null
                        : validateDate(v) ?? (v.compareTo(invoice.date) < 0 ? 'Must be on or after invoice date' : null),
                  ),
                ],
              );

              final notesCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: invoiceNotes,
                    decoration: const InputDecoration(
                      hintText: 'Enter notes...',
                    ),
                    onChanged: (v) => changed(() => invoiceNotes = v),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  children: [
                    customerCol,
                    referenceCol,
                    invoiceNumCol,
                    const SizedBox(height: 14),
                    paymentTermsCol,
                    const SizedBox(height: 14),
                    invoiceDateCol,
                    currencyCol,
                    const SizedBox(height: 14),
                    dueDateCol,
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
                      Expanded(child: invoiceNumCol),
                      const SizedBox(width: 16),
                      Expanded(child: paymentTermsCol),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: invoiceDateCol),
                      const SizedBox(width: 16),
                      Expanded(child: currencyCol),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: dueDateCol),
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
  // 3. Invoice Items Table Card
  // -------------------------------------------------------------
  Widget _buildInvoiceItemsCard(BuildContext context, bool isDark) {
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
                'Invoice Items',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                '${rows.length} item${rows.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Desktop Table View
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 650;

              if (isSmall) {
                // Mobile stacked card rows
                return Column(
                  children: [
                    for (int n = 0; n < rows.length; n++) ...[
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
                                    initialValue: rows[n]['description'],
                                    decoration: const InputDecoration(
                                      labelText: 'Service / Description',
                                      hintText: 'e.g. Website Development',
                                    ),
                                    onChanged: (v) => changed(() => rows[n]['description'] = v),
                                  ),
                                ),
                                if (rows.length > 1) ...[
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.trash, color: AppTheme.zohoRed, size: 18),
                                    onPressed: () => changed(() => rows.removeAt(n)),
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
                                    initialValue: rows[n]['quantity'],
                                    decoration: const InputDecoration(labelText: 'Qty'),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (v) => changed(() => rows[n]['quantity'] = v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    initialValue: rows[n]['rate'],
                                    decoration: const InputDecoration(labelText: 'Unit Price'),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (v) => changed(() => rows[n]['rate'] = v),
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
                                  _computeRowAmount(rows[n]).toStringAsFixed(2),
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
                  for (int n = 0; n < rows.length; n++)
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
                            initialValue: rows[n]['description'],
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'Website Development\nCustom website design',
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 13),
                            onChanged: (v) => changed(() => rows[n]['description'] = v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: TextFormField(
                            initialValue: rows[n]['quantity'],
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => changed(() => rows[n]['quantity'] = v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: TextFormField(
                            initialValue: rows[n]['rate'],
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => changed(() => rows[n]['rate'] = v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: TextFormField(
                            initialValue: rows[n]['discount'],
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => changed(() => rows[n]['discount'] = v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: DropdownButtonFormField<String>(
                            initialValue: rows[n]['vat'] ?? '5',
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
                            onChanged: (v) => changed(() {
                              rows[n]['vat'] = v ?? '5';
                              if (v == '0' || v == 'exempt') {
                                invoice = invoice.copyWith(taxRate: '0');
                              } else if (v != null) {
                                invoice = invoice.copyWith(taxRate: v);
                              }
                            }),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Text(
                            _computeRowAmount(rows[n]).toStringAsFixed(2),
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
                          onPressed: rows.length > 1 ? () => changed(() => rows.removeAt(n)) : null,
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
            onPressed: rows.length < 30 ? () => changed(addRow) : null,
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
  Widget _buildTermsAndTotalsCard(BuildContext context, bool isDark, Totals? totals) {
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
                'Terms & Conditions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: termsAndConditions,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter invoice terms & conditions...',
                ),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
                onChanged: (v) => changed(() => termsAndConditions = v),
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
  Widget _buildBottomActionsBar(BuildContext context, bool isDark, BillingState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Save as Draft
        OutlinedButton(
          onPressed: state.busy ? null : () => save(issue: false),
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
              onPressed: state.busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      try {
                        await showPdf(context, current());
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      }
                    },
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
              onPressed: state.busy ? null : () => save(issue: true),
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
  // 6. Right Column: Real-Time Live Invoice Preview Card
  // -------------------------------------------------------------
  Widget _buildLivePreviewCard(BuildContext context, bool isDark, Totals? totals) {
    final subtotalVal = totals != null ? (totals.subtotal / 100.0) : 0.0;
    final vatVal = totals != null ? (totals.tax / 100.0) : 0.0;
    final totalVal = totals != null ? (totals.total / 100.0) : 0.0;

    final company = invoice.company;
    final customer = invoice.customer;

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
                  'Invoice Preview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (!form.currentState!.validate()) return;
                    try {
                      await showPdf(context, current());
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
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
                  // Document Header: Logo & Details | INVOICE title
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

                      // INVOICE title & Meta
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'INVOICE',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Invoice No: ${invoice.number.isNotEmpty ? invoice.number : "INV-2024-0001"}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          Text('Date: ${invoice.date}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                          Text('Due Date: ${invoice.dueDate.isNotEmpty ? invoice.dueDate : invoice.date}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
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
                        const Text('Bill To:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
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
                      for (int n = 0; n < rows.length; n++)
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
                                rows[n]['description']?.isNotEmpty == true ? rows[n]['description']! : 'Service item',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                rows[n]['quantity'] ?? '1',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                (double.tryParse(rows[n]['rate'] ?? '0') ?? 0.0).toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                _computeRowAmount(rows[n]).toStringAsFixed(2),
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
                    termsAndConditions,
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
