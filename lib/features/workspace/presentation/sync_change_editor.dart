import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/offline/offline_store.dart';
import 'package:tpc_invoice/core/widgets/forms/currency_selector.dart';

/// Edit the saved form values without exposing queue IDs or transport payloads.
class SyncChangeEditor extends StatefulWidget {
  const SyncChangeEditor(
      {super.key,
      required this.values,
      required this.section,
      this.references = const {}});
  final Map<String, Object?> values;
  final String section;
  final Map<String, List<Map<String, dynamic>>> references;
  @override
  State<SyncChangeEditor> createState() => _SyncChangeEditorState();
}

class _SyncChangeEditorState extends State<SyncChangeEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> _values = copyJson(widget.values);
  final _controllers = <TextEditingController>[];
  String _label(String key) => key
      .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}')
      .replaceAll('_', ' ');
  late final List<Widget> _fields = _buildFields(_values);
  List<Widget> _buildFields(Map<String, dynamic> values) {
    final fields = <Widget>[];
    for (final entry in values.entries) {
      final key = entry.key, value = entry.value;
      final references = widget.references[key];
      if (references != null && references.isNotEmpty) {
        final ids = references.map((r) => '${r['recordId']}').toSet();
        fields.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: ids.contains(value) ? value as String : null,
                decoration: InputDecoration(
                    labelText: _label(key.replaceFirst('Id', ''))),
                items: [
                  for (final r in references)
                    DropdownMenuItem(
                        value: '${r['recordId']}',
                        child: Text(
                            '${r['name'] ?? r['fullName'] ?? r['title'] ?? r['number'] ?? 'Record'}',
                            overflow: TextOverflow.ellipsis))
                ],
                onChanged: (v) => values[key] = v,
                validator: (v) =>
                    v == null ? 'Select a valid reference.' : null)));
        continue;
      }
      if (key == 'data' ||
          key == 'expectedVersion' ||
          key.endsWith('Id') ||
          key == 'rateSource' ||
          key == 'baseCurrency') {
        continue;
      }
      if (value is Map) {
        final nested = Map<String, dynamic>.from(value);
        values[key] = nested;
        fields.addAll(_buildFields(nested));
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          if (value[i] is Map) {
            final nested = Map<String, dynamic>.from(value[i] as Map);
            value[i] = nested;
            fields.add(Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('${_label(key)} ${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600))));
            fields.addAll(_buildFields(nested));
          }
        }
      } else if (value is bool) {
        fields.add(FormField<bool>(
            initialValue: value,
            builder: (state) => CheckboxListTile(
                title: Text(_label(key)),
                value: state.value,
                onChanged: (v) {
                  state.didChange(v);
                  values[key] = v;
                })));
      } else {
        final controller = TextEditingController(text: '${value ?? ''}');
        _controllers.add(controller);
        if (key == 'currency' || key == 'preferredCurrency') {
          controller.addListener(() => values[key] = controller.text);
          fields.add(
              CurrencySelector(controller: controller, label: _label(key)));
          continue;
        }
        fields.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(labelText: _label(key)),
              keyboardType: value is num
                  ? const TextInputType.numberWithOptions(
                      decimal: true, signed: true)
                  : TextInputType.text,
              validator: (v) =>
                  value is num && (num.tryParse(v ?? '')?.isFinite != true)
                      ? 'Enter a valid number.'
                      : null,
              onSaved: (v) {
                values[key] = value is num ? num.parse(v!) : v!.trim();
                if (key == 'exchangeRate' && values[key] != value) {
                  values['rateSource'] = 'MANUAL';
                }
              },
            )));
      }
    }
    return fields;
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text('Edit ${widget.section} change'),
          content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                  child: Form(
                      key: _form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _fields.isEmpty
                              ? [
                                  const Text(
                                      'This action has no editable fields. Retry it after resolving the reported issue.')
                                ]
                              : _fields)))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  _form.currentState!.save();
                  Navigator.pop(context, Map<String, Object?>.from(_values));
                },
                child: const Text('Save correction'))
          ]);
}
