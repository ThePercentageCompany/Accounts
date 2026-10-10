import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Public currency metadata only. Transaction rates use the authenticated API.
class CurrencySelector extends StatefulWidget {
  const CurrencySelector(
      {super.key,
      required this.controller,
      this.label = 'Transaction currency',
      this.optional = false,
      this.enabled = true});
  final TextEditingController controller;
  final String label;
  final bool optional, enabled;
  @override
  State<CurrencySelector> createState() => _CurrencySelectorState();
}

class _CurrencySelectorState extends State<CurrencySelector> {
  static Map<String, String> _catalog = {
    'AED': 'United Arab Emirates Dirham',
    'INR': 'Indian Rupee',
    'GBP': 'British Pound',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'SAR': 'Saudi Riyal',
    'CAD': 'Canadian Dollar',
    'AUD': 'Australian Dollar',
  };
  static Future<void>? _request;
  static Future<void> _load() async {
    final response = await http
        .get(Uri.parse('https://api.frankfurter.dev/v2/currencies'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Currency list unavailable');
    }
    final rows = jsonDecode(response.body) as List;
    final catalog = <String, String>{};
    for (final row in rows) {
      final code = row['iso_code'];
      final name = row['name'];
      if (code is String &&
          RegExp(r'^[A-Z]{3}$').hasMatch(code) &&
          name is String) {
        catalog[code] = name;
      }
    }
    if (catalog.isEmpty) throw StateError('Empty currency list');
    _catalog = catalog;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      await (_request ??= _load());
      if (mounted) setState(() {});
    } catch (_) {
      // Common currencies and the saved currency remain available offline.
      _request = null;
    }
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (context, value, _) {
            final selected = value.text.trim().toUpperCase();
            final options = {
              ..._catalog,
              if (selected.isNotEmpty && !_catalog.containsKey(selected))
                selected: selected
            };
            final codes = options.keys.toList()..sort();
            return DropdownButtonFormField<String>(
              key: ValueKey(selected),
              initialValue: selected.isEmpty ? null : selected,
              isExpanded: true,
              decoration: InputDecoration(labelText: widget.label),
              hint: Text(
                  widget.optional ? 'Use company currency' : 'Select currency'),
              items: [
                if (widget.optional)
                  const DropdownMenuItem(
                      value: '', child: Text('Use company currency')),
                for (final code in codes)
                  DropdownMenuItem(
                      value: code,
                      child: Text('$code — ${options[code]}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: widget.enabled
                  ? (code) => widget.controller.text = code ?? ''
                  : null,
              validator: (code) =>
                  !widget.optional && (code == null || code.isEmpty)
                      ? 'Select a currency.'
                      : null,
            );
          });
}
