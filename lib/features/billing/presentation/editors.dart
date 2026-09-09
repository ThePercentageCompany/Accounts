import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/date_field.dart';
import '../domain/models.dart';
import '../domain/invoice_document_service.dart';
import '../domain/totals.dart';
import 'billing_cubit.dart';
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
      if (bytes == null || bytes.length > 20000) {
        throw const FormatException('Choose a PNG or JPG logo under 20 KB.');
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
                                    'PNG or JPG, up to 20 KB. Applied to newly issued invoices.',
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

  @override
  void initState() {
    super.initState();
    final data = context.read<BillingCubit>().state.data;
    invoice = widget.invoice ??
        Invoice(
          id: const Uuid().v4(),
          date: today(),
          customer: data.customers.first,
          company: data.company,
          notes: data.company.notes,
          terms: data.company.terms,
        );
    rows = invoice.items.map((x) => {'key': const Uuid().v4(), 'description': x.description, 'quantity': x.quantity, 'rate': x.rate}).toList();
    if (rows.isEmpty) addRow();
  }

  void addRow() {
    rows.add({'key': const Uuid().v4(), 'description': '', 'quantity': '1', 'rate': '0.00'});
  }

  Invoice current() => invoice.copyWith(
        items: rows.map((x) => LineItem(description: x['description']!, quantity: x['quantity']!, rate: x['rate']!)).toList(),
      );

  void changed(VoidCallback update) {
    setState(() {
      update();
      dirty = true;
    });
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
          title: const Text('Issue this Invoice?'),
          content: const Text(
            'A unique sequential invoice number will be assigned. Items, prices and customer details will then be locked.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.pastelBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
              child: const Text('Issue Invoice'),
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
            const SnackBar(content: Text('Invoice issued. PDF archive failed; retry Save PDF to Drive from the invoice.')),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved successfully.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.pastelRose, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
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
            appBar: AppBar(
              title: Text(widget.invoice == null ? 'New Invoice' : 'Edit Draft'),
              actions: [
                TextButton(
                  onPressed: state.busy ? null : () => save(),
                  child: const Text('Save Draft'),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    onPressed: state.busy ? null : () => save(issue: true),
                    icon: const Icon(CupertinoIcons.checkmark_alt, size: 16),
                    label: const Text('Issue'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.pastelBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Form(
                  key: form,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      // Section 1: Customer & Dates
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
                              const Text('Customer & Billing Dates', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: invoice.customer.id,
                                      decoration: const InputDecoration(
                                        labelText: 'Customer',
                                        prefixIcon: Icon(CupertinoIcons.person, size: 18),
                                      ),
                                      isExpanded: true,
                                      items: [
                                        for (final c in state.data.customers)
                                          DropdownMenuItem(
                                            value: c.id,
                                            child: Text(c.name, overflow: TextOverflow.ellipsis),
                                          ),
                                      ],
                                      onChanged: state.busy
                                          ? null
                                          : (id) => changed(
                                                () => invoice = invoice.copyWith(
                                                  customer: state.data.customers.firstWhere((x) => x.id == id),
                                                ),
                                              ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    tooltip: 'Add new customer',
                                    icon: const Icon(CupertinoIcons.person_badge_plus, size: 18),
                                    onPressed: state.busy ? null : () => editCustomer(context),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              DatePickerField(
                                label: 'Invoice date',
                                value: invoice.date,
                                onChanged: (v) => changed(() => invoice = invoice.copyWith(date: v)),
                                isRequired: true,
                                validator: validateDate,
                              ),
                              DatePickerField(
                                label: 'Due date (optional)',
                                value: invoice.dueDate,
                                onChanged: (v) => changed(() => invoice = invoice.copyWith(dueDate: v)),
                                validator: (v) => v == null || v.isEmpty
                                    ? null
                                    : validateDate(v) ?? (v.compareTo(invoice.date) < 0 ? 'Must be on or after invoice date' : null),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Section 2: Items
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Line Items', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                                  Text(
                                    '${rows.length} item${rows.length > 1 ? 's' : ''}',
                                    style: TextStyle(
                                      color: isDark ? AppTheme.iosDarkTextSecondary : AppTheme.iosLightTextSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              for (var n = 0; n < rows.length; n++) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Center(
                                              child: Text('${n + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: rows[n]['description'],
                                              maxLength: 500,
                                              decoration: const InputDecoration(
                                                labelText: 'Item Description / Service',
                                                counterText: '',
                                              ),
                                              validator: requiredText,
                                              onChanged: (v) => changed(() => rows[n]['description'] = v),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            tooltip: 'Remove line item',
                                            icon: const Icon(CupertinoIcons.trash, color: AppTheme.pastelRose, size: 18),
                                            onPressed: rows.length > 1 ? () => changed(() => rows.removeAt(n)) : null,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final isSmall = constraints.maxWidth < 420;
                                          final qtyField = TextFormField(
                                            initialValue: rows[n]['quantity'],
                                            decoration: const InputDecoration(labelText: 'Qty'),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            onChanged: (v) => changed(() => rows[n]['quantity'] = v),
                                            validator: (v) {
                                              try {
                                                return scaled(v ?? '', 3) > 0 ? null : 'Must exceed 0';
                                              } catch (e) {
                                                return 'Valid number';
                                              }
                                            },
                                          );

                                          final rateField = TextFormField(
                                            initialValue: rows[n]['rate'],
                                            decoration: const InputDecoration(labelText: 'Unit Price (AED)'),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            onChanged: (v) => changed(() => rows[n]['rate'] = v),
                                            validator: (v) {
                                              try {
                                                scaled(v ?? '', 2);
                                                return null;
                                              } catch (e) {
                                                return 'Valid amount';
                                              }
                                            },
                                          );

                                          final totalWidget = Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                              Text(
                                                itemAmount(n),
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.3),
                                              ),
                                            ],
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
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    const Text('Line Total:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                                    Text(
                                                      itemAmount(n),
                                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.3),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          }

                                          return Row(
                                            children: [
                                              Expanded(flex: 2, child: qtyField),
                                              const SizedBox(width: 10),
                                              Expanded(flex: 3, child: rateField),
                                              const SizedBox(width: 12),
                                              Expanded(flex: 2, child: totalWidget),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: rows.length < 30 ? () => changed(addRow) : null,
                                icon: const Icon(CupertinoIcons.plus, size: 16),
                                label: const Text('Add Line Item'),
                                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Section 3: Discounts, Taxes & Totals
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
                              const Text('Discounts, Taxes & Totals', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: field(
                                      'Discount amount (AED)',
                                      invoice.discount,
                                      (v) => changed(() => invoice = invoice.copyWith(discount: v)),
                                      max: 12,
                                      prefixIcon: CupertinoIcons.tag,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: field(
                                      'Tax / VAT % (e.g. 5 for UAE)',
                                      invoice.taxRate,
                                      (v) => changed(() => invoice = invoice.copyWith(taxRate: v)),
                                      max: 6,
                                      prefixIcon: CupertinoIcons.percent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Live Calculation Box
                              if (totals != null)
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    children: [
                                      totalRow('Subtotal (Items)', totals.subtotal),
                                      if (totals.discount > 0) totalRow('Discount', -totals.discount, isNegative: true),
                                      if (totals.tax > 0) totalRow('Tax / VAT (${invoice.taxRate}%)', totals.tax),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Grand Total',
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                                          ),
                                          Text(
                                            money(totals.total),
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                              color: isDark ? AppTheme.pastelMint : AppTheme.pastelMint,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const Text(
                                  'Check quantity, unit price, discount and tax numbers.',
                                  style: TextStyle(color: AppTheme.pastelRose, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Section 4: Terms & Notes
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
                              const Text('Payment Terms & Notes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                              const SizedBox(height: 16),
                              field('Payment Terms', invoice.terms, (v) => changed(() => invoice = invoice.copyWith(terms: v)), max: 300, prefixIcon: CupertinoIcons.doc_plaintext),
                              field('Public Notes / Instructions', invoice.notes, (v) => changed(() => invoice = invoice.copyWith(notes: v)), max: 1000, lines: 3, prefixIcon: CupertinoIcons.text_quote),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bottom Action Buttons (Responsive)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 500;
                          final saveDraftBtn = OutlinedButton(
                            onPressed: state.busy ? null : () => save(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            ),
                            child: const Text('Save Draft'),
                          );

                          final previewPdfBtn = OutlinedButton.icon(
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
                            icon: const Icon(CupertinoIcons.doc_plaintext, size: 16),
                            label: const Text('Preview PDF'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            ),
                          );

                          final issueBtn = FilledButton.icon(
                            onPressed: state.busy ? null : () => save(issue: true),
                            icon: const Icon(CupertinoIcons.checkmark_alt, size: 16),
                            label: const Text('Issue Invoice'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.pastelBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            ),
                          );

                          if (isCompact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                issueBtn,
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: saveDraftBtn),
                                    const SizedBox(width: 10),
                                    Expanded(child: previewPdfBtn),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: saveDraftBtn),
                              const SizedBox(width: 10),
                              Expanded(child: previewPdfBtn),
                              const SizedBox(width: 10),
                              Expanded(child: issueBtn),
                            ],
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
      },
    );
  }

  String itemAmount(int n) {
    try {
      return money(lineTotal(LineItem(description: '', quantity: rows[n]['quantity']!, rate: rows[n]['rate']!)));
    } catch (e) {
      return '—';
    }
  }

  Widget totalRow(String label, int value, {bool isNegative = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(
              '${isNegative ? '-' : ''}${money(value.abs())}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isNegative ? AppTheme.pastelRose : null,
              ),
            ),
          ],
        ),
      );
}
