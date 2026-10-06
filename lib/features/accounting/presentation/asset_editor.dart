import 'package:tpc_invoice/core/widgets/forms/payment_method_dropdown.dart';
import 'package:tpc_invoice/core/widgets/forms/validated_text_field.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:tpc_invoice/core/widgets/forms/category_field.dart';
import 'package:flutter/material.dart';

class AssetEditor extends StatefulWidget {
  const AssetEditor({super.key, this.record});
  final Map<String, dynamic>? record;
  @override
  State<AssetEditor> createState() => _AssetEditorState();
}

class _AssetEditorState extends State<AssetEditor> {
  final form = GlobalKey<FormState>();
  late final code = TextEditingController(
    text: '${widget.record?['assetCode'] ?? ''}',
  );
  late final name = TextEditingController(
    text: '${widget.record?['name'] ?? ''}',
  );
  late final category = TextEditingController(
    text: '${widget.record?['category'] ?? ''}',
  );
  late final date = TextEditingController(
    text:
        '${widget.record?['purchaseDate'] ?? DateTime.now().toIso8601String().substring(0, 10)}',
  );
  late final cost = TextEditingController(
    text: '${widget.record?['cost'] ?? ''}',
  );
  late final residual = TextEditingController(
    text: '${widget.record?['residualValue'] ?? 0}',
  );
  late final life = TextEditingController(
    text: '${widget.record?['usefulLife'] ?? 60}',
  );
  late final location = TextEditingController(
    text: '${widget.record?['location'] ?? ''}',
  );
  late final serial = TextEditingController(
    text: '${widget.record?['serialNumber'] ?? ''}',
  );
  late String account = '${widget.record?['paymentAccount'] ?? 'Bank'}';
  @override
  void dispose() {
    for (final c in [
      code,
      name,
      category,
      date,
      cost,
      residual,
      life,
      location,
      serial,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? requiredText(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Required.' : null;
  String? amount(String? value) {
    final text = value?.trim() ?? '', number = double.tryParse(text);
    return number == null ||
            number < 0 ||
            !AppValidators.decimalPattern.hasMatch(text)
        ? 'Use a nonnegative amount with up to two decimals.'
        : null;
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title: Text(
            widget.record == null ? 'Add asset draft' : 'Edit asset draft'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: PopupFormFields(
                children: [
                  ValidatedTextField(
                    controller: code,
                    kind: AppInputKind.reference,
                    decoration: const InputDecoration(labelText: 'Asset code'),
                    validator: requiredText,
                  ),
                  ValidatedTextField(
                    controller: name,
                    kind: AppInputKind.name,
                    required: true,
                    decoration: const InputDecoration(labelText: 'Asset name'),
                    validator: requiredText,
                  ),
                  CategoryFormField(
                      controller: category, kind: CategoryKind.asset),
                  CalendarFormField(
                    controller: date,
                    decoration:
                        const InputDecoration(labelText: 'Purchase date'),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      return AppValidators.datePattern.hasMatch(t) &&
                              DateTime.tryParse(t) != null
                          ? null
                          : 'Use YYYY-MM-DD.';
                    },
                  ),
                  ValidatedTextField(
                    required: true,
                    controller: cost,
                    kind: AppInputKind.money,
                    decoration: const InputDecoration(labelText: 'Cost'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final e = amount(v);
                      return e ??
                          (double.parse(v!.trim()) <= 0
                              ? 'Cost must be greater than zero.'
                              : null);
                    },
                  ),
                  ValidatedTextField(
                    required: true,
                    controller: residual,
                    kind: AppInputKind.money,
                    decoration:
                        const InputDecoration(labelText: 'Residual value'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: amount,
                  ),
                  ValidatedTextField(
                    controller: life,
                    required: true,
                    kind: AppInputKind.integer,
                    decoration: const InputDecoration(
                      labelText: 'Useful life (months)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      return n == null || n < 1 || n > 1200
                          ? 'Enter 1 to 1200 months.'
                          : null;
                    },
                  ),
                  PaymentMethodDropdown(
                    value: account,
                    decoration: const InputDecoration(labelText: 'Paid from'),
                    onChanged: (v) => account = v ?? 'Bank',
                  ),
                  ValidatedTextField(
                    controller: location,
                    kind: AppInputKind.text,
                    decoration: const InputDecoration(
                      labelText: 'Location (optional)',
                    ),
                  ),
                  ValidatedTextField(
                    controller: serial,
                    kind: AppInputKind.reference,
                    decoration: const InputDecoration(
                      labelText: 'Serial number (optional)',
                    ),
                  ),
                ],
              ),
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
              Navigator.pop(context, <String, Object?>{
                'assetCode': code.text.trim(),
                'name': name.text.trim(),
                'category': category.text.trim(),
                'purchaseDate': date.text.trim(),
                'cost': double.parse(cost.text.trim()),
                'usefulLife': int.parse(life.text.trim()),
                'residualValue': double.parse(residual.text.trim()),
                'depreciationMethod': 'STRAIGHT_LINE',
                'paymentAccount': account,
                'location': location.text.trim(),
                'assignedEmployeeId': '',
                'serialNumber': serial.text.trim(),
                'acquisitionType': 'COMPANY_PURCHASE',
              });
            },
            child: const Text('Save draft'),
          ),
        ],
      );
}

class AssetDepreciationEditor extends StatefulWidget {
  const AssetDepreciationEditor({super.key});
  @override
  State<AssetDepreciationEditor> createState() =>
      _AssetDepreciationEditorState();
}

class _AssetDepreciationEditorState extends State<AssetDepreciationEditor> {
  final form = GlobalKey<FormState>();
  final date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  @override
  void dispose() {
    date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title: const Text('Post monthly depreciation'),
        content: Form(
          key: form,
          child: CalendarFormField(
            controller: date,
            decoration: const InputDecoration(labelText: 'Posting date'),
            validator: (v) {
              final t = v?.trim() ?? '';
              return AppValidators.datePattern.hasMatch(t) &&
                      DateTime.tryParse(t) != null
                  ? null
                  : 'Use YYYY-MM-DD.';
            },
          ),
        ),
        actions: [
          LoadingButton.text(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          LoadingButton(
            onPressed: () {
              if (AppFormValidation.validate(form.currentState!)) {
                Navigator.pop(context, <String, Object?>{
                  'lastDepreciationDate': date.text.trim(),
                });
              }
            },
            child: const Text('Post depreciation'),
          ),
        ],
      );
}

class AssetDisposalEditor extends StatefulWidget {
  const AssetDisposalEditor({super.key, required this.bookValue});
  final Object? bookValue;
  @override
  State<AssetDisposalEditor> createState() => _AssetDisposalEditorState();
}

class _AssetDisposalEditorState extends State<AssetDisposalEditor> {
  final form = GlobalKey<FormState>();
  String account = 'Bank';
  final date = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final proceeds = TextEditingController(text: '0');
  final reason = TextEditingController();
  @override
  void dispose() {
    date.dispose();
    proceeds.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title: const Text('Dispose asset'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: form,
            child: PopupFormFields(
              children: [
                Text('Current net book value: ${widget.bookValue}'),
                CalendarFormField(
                  controller: date,
                  decoration: const InputDecoration(labelText: 'Disposal date'),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    return AppValidators.datePattern.hasMatch(t) &&
                            DateTime.tryParse(t) != null
                        ? null
                        : 'Use YYYY-MM-DD.';
                  },
                ),
                ValidatedTextField(
                  required: true,
                  controller: proceeds,
                  kind: AppInputKind.money,
                  decoration: const InputDecoration(labelText: 'Sale proceeds'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '', n = double.tryParse(t);
                    return n == null ||
                            n < 0 ||
                            !AppValidators.decimalPattern.hasMatch(t)
                        ? 'Enter a nonnegative amount.'
                        : null;
                  },
                ),
                PaymentMethodDropdown(
                  value: account,
                  decoration:
                      const InputDecoration(labelText: 'Proceeds account'),
                  onChanged: (v) => account = v ?? 'Bank',
                ),
                ValidatedTextField(
                  controller: reason,
                  kind: AppInputKind.text,
                  maxLength: 500,
                  decoration:
                      const InputDecoration(labelText: 'Disposal reason'),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Enter a reason.' : null,
                ),
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
              Navigator.pop(context, <String, Object?>{
                'disposalDate': date.text.trim(),
                'disposalProceeds': double.parse(proceeds.text.trim()),
                'disposalAccount': account,
                'disposalReason': reason.text.trim(),
              });
            },
            child: const Text('Post disposal'),
          ),
        ],
      );
}
