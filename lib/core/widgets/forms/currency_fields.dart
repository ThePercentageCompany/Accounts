import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'currency_selector.dart';

typedef ExchangeRateLoader = Future<Map<String, dynamic>> Function(
    String currency, String date);

class CurrencyDraft {
  CurrencyDraft(
      {Map<String, dynamic>? record, TextEditingController? currencyController})
      : currency = currencyController ??
            TextEditingController(text: '${record?['currency'] ?? ''}'),
        ownsCurrency = currencyController == null,
        rate = TextEditingController(text: '${record?['exchangeRate'] ?? ''}'),
        base = '${record?['baseCurrency'] ?? ''}',
        date = '${record?['rateDate'] ?? ''}',
        source = '${record?['rateSource'] ?? 'MANUAL'}';
  final TextEditingController currency, rate;
  final bool ownsCurrency;
  String base, date, source;
  Map<String, Object?> get values => {
        'currency': currency.text.trim().toUpperCase(),
        'exchangeRate': double.parse(rate.text.trim()),
        if (base.isNotEmpty) 'baseCurrency': base,
        'rateDate': date,
        'rateSource': source,
      };
  void dispose() {
    if (ownsCurrency) currency.dispose();
    rate.dispose();
  }
}

class CurrencyFields extends StatefulWidget {
  const CurrencyFields(
      {super.key,
      required this.draft,
      required this.transactionDate,
      this.loadRate,
      this.fixedCurrency = false,
      this.month = false});
  final CurrencyDraft draft;
  final TextEditingController transactionDate;
  final ExchangeRateLoader? loadRate;
  final bool fixedCurrency, month;
  @override
  State<CurrencyFields> createState() => _CurrencyFieldsState();
}

class _CurrencyFieldsState extends State<CurrencyFields> {
  Timer? _debounce;
  int _generation = 0;
  bool _loading = false, _applying = false;
  String? _error;
  CurrencyDraft get draft => widget.draft;
  String get date => widget.month
      ? '${widget.transactionDate.text}-01'
      : widget.transactionDate.text;
  @override
  void initState() {
    super.initState();
    draft.currency.addListener(_changed);
    widget.transactionDate.addListener(_changed);
    if (draft.rate.text.isEmpty) scheduleMicrotask(_fetch);
  }

  void _changed() {
    if (_applying) return;
    _generation++;
    _debounce?.cancel();
    draft.rate.clear();
    draft.date = date;
    setState(() {
      _loading = false;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 450), _fetch);
  }

  Future<void> _fetch() async {
    if (!mounted || DateTime.tryParse(date) == null) return;
    final generation = ++_generation;
    if (widget.loadRate == null) {
      if (draft.currency.text.isEmpty) draft.currency.text = 'AED';
      draft.rate.text = '1';
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.loadRate!(
          draft.currency.text.trim().toUpperCase(), date);
      if (!mounted || generation != _generation) return;
      _applying = true;
      draft.currency.text = '${result['currency']}';
      draft.rate.text = (result['exchangeRate'] as num).toStringAsFixed(8);
      draft.base = '${result['baseCurrency']}';
      draft.date = '${result['rateDate']}';
      draft.source = '${result['rateSource']}';
      _applying = false;
    } catch (_) {
      if (mounted && generation == _generation) {
        _error = 'Automatic rate unavailable. Enter your rate manually.';
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    draft.currency.removeListener(_changed);
    widget.transactionDate.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CurrencySelector(
            controller: draft.currency, enabled: !widget.fixedCurrency),
        const SizedBox(height: 12),
        TextFormField(
            controller: draft.rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Exchange rate',
                helperText:
                    '1 ${draft.currency.text} = rate ${draft.base.isEmpty ? 'company currency' : draft.base}. You can edit the automatic rate.',
                helperMaxLines: 3,
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: AppActivityIndicator())
                    : IconButton(
                        tooltip: 'Get automatic rate',
                        onPressed: widget.loadRate == null ? null : _fetch,
                        icon: const Icon(Icons.refresh))),
            onChanged: (_) {
              _debounce?.cancel();
              _generation++;
              setState(() => _loading = false);
              draft.source = 'MANUAL';
              draft.date = date;
            },
            validator: (v) {
              final n = double.tryParse(v ?? '');
              return n != null &&
                      n.isFinite &&
                      n > 0 &&
                      n <= 1e8 &&
                      RegExp(r'^\d+(\.\d{1,8})?$').hasMatch(v ?? '')
                  ? null
                  : 'Enter a positive rate with up to eight decimals.';
            }),
        if (_error != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!)),
        if (draft.date.isNotEmpty)
          Text(
              '${draft.source == 'MANUAL' ? 'Manual rate' : 'Reference rate'} · ${draft.date}'),
      ]);
}
