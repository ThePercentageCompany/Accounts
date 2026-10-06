import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:tpc_invoice/core/offline/durable_value.dart';
import 'package:tpc_invoice/core/offline/offline_store.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';

const defaultHtmlDocumentDesign = '''<style>
@page { size: A4; margin: 18mm; }
body { font: 14px Arial, sans-serif; color: #202124; margin: 32px; }
header { display:flex; justify-content:space-between; border-bottom:2px solid #1677ff; padding-bottom:20px; }
h1 { margin:0; font-size:28px; } h2 { font-size:18px; }
.details { display:flex; justify-content:space-between; margin:28px 0; }
table { border-collapse:collapse; width:100%; }
th, td { padding:12px; border-bottom:1px solid #ddd; text-align:right; }
th:first-child, td:first-child { text-align:left; }
th { background:#f4f6f8; } .totals { margin:24px 0 24px auto; width:300px; }
footer { border-top:1px solid #ddd; margin-top:32px; padding-top:16px; }
</style>
<header><div><h2>{{company.name}}</h2>{{company.address}}<br>TRN: {{company.trn}}<br>{{company.email}}</div>
<div><h1>{{title}}</h1>{{record.number}}<br>{{record.status}}</div></header>
<div class="details"><div><b>Bill to</b><h2>{{customer.name}}</h2>{{customer.address}}<br>TRN: {{customer.trn}}</div>
<div>Issue date: {{record.issueDate}}<br>Due / valid until: {{endDate}}<br>Currency: {{record.currency}}</div></div>
<table><thead><tr><th>Description</th><th>Quantity</th><th>Unit price</th><th>Discount</th><th>VAT %</th><th>Amount</th></tr></thead><tbody>{{items}}</tbody></table>
<div class="totals">Subtotal: {{record.subtotal}}<br>Discount: {{record.discount}}<br>VAT: {{record.taxAmount}}<h2>Total: {{record.currency}} {{record.total}}</h2></div>
<footer><b>Notes</b><p>{{record.notes}}</p><b>Terms</b><p>{{record.paymentTerms}}</p></footer>''';

class HtmlDocumentDesignStore {
  HtmlDocumentDesignStore(this.scope);
  final String scope;
  String get key => 'html-document-design-v1:${Uri.encodeComponent(scope)}';
  DurableValue? _durable;
  Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      _durable = DurableValue(
          createOfflineStore(), 'document-design:$scope', key, prefs);
      await _durable!.load(migrateLegacy: jsonEncode);
      return _durable!.value == null
          ? defaultHtmlDocumentDesign
          : jsonDecode(_durable!.value!) as String;
    }
    return prefs.getString(key) ?? defaultHtmlDocumentDesign;
  }

  Future<void> save(String source) async {
    validateHtmlDocumentDesign(source);
    if (kIsWeb && _durable == null) await load();
    final saved = _durable != null
        ? await _durable!.put(jsonEncode(source))
        : await (await SharedPreferences.getInstance()).setString(key, source);
    if (!saved) {
      throw StateError('The design could not be saved on this device.');
    }
  }
}

void validateHtmlDocumentDesign(String source) {
  if (source.trim().isEmpty || utf8.encode(source).length > 100000) {
    throw const FormatException('Use a non-empty HTML design up to 100 KB.');
  }
  final matches = RegExp(r'\{\{([^{}]+)\}\}').allMatches(source);
  for (final match in matches) {
    final token = match[1]!.trim();
    if (!const ['title', 'endDate', 'items'].contains(token) &&
        !RegExp(
          r'^(company|customer|record)\.[a-zA-Z][a-zA-Z0-9]*$',
        ).hasMatch(token)) {
      throw FormatException('Unknown placeholder: {{$token}}');
    }
  }
  if (!source.contains('{{items}}') || !source.contains('{{record.total}}')) {
    throw const FormatException(
      'Include {{items}} and {{record.total}} in the design.',
    );
  }
}

String renderHtmlDocument({
  required String source,
  required String section,
  required Map<String, dynamic> record,
  required Map<String, dynamic> company,
  required Map<String, dynamic> customer,
  required List<Map<String, dynamic>> items,
}) {
  validateHtmlDocumentDesign(source);
  String escape(Object? value) => const HtmlEscape().convert('${value ?? ''}');
  String money(Object? value) =>
      escape(value is num ? value.toStringAsFixed(2) : value);
  final rows = items
      .map(
        (item) => '<tr><td>${escape(item['description'])}</td>'
            '<td>${escape(item['quantity'])}</td><td>${money(item['unitPrice'])}</td>'
            '<td>${money(item['discount'])}</td><td>${escape(item['taxRate'])}</td>'
            '<td>${money(item['lineTotal'])}</td></tr>',
      )
      .join();
  final content = source.replaceAllMapped(RegExp(r'\{\{([^{}]+)\}\}'), (match) {
    final token = match[1]!.trim();
    if (token == 'items') return rows;
    if (token == 'title') {
      return section == 'Invoices' ? 'INVOICE' : 'QUOTATION';
    }
    if (token == 'endDate') {
      return escape(record[section == 'Invoices' ? 'dueDate' : 'validUntil']);
    }
    final parts = token.split('.');
    final data = {
      'record': record,
      'company': company,
      'customer': customer,
    }[parts[0]]!;
    return money(data[parts[1]]);
  });
  // Designs are exported, never executed inside the signed-in application.
  // Block scripts, network requests, forms and embedded pages in the browser export.
  return '<!doctype html><html><head><meta charset="utf-8">'
      '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'; img-src data:; font-src data:; base-uri \'none\'; form-action \'none\'">'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<title>${escape(record['number'] ?? section)}</title></head><body>$content</body></html>';
}

Future<String> savedRecordHtml(
  SaasApi api,
  String companyId,
  String section,
  String recordId,
  String source,
) async {
  if (!const ['Invoices', 'Quotations'].contains(section)) {
    throw ArgumentError('Unsupported document');
  }
  Future<List<Map<String, dynamic>>> rows(String table) async =>
      ((await api.records(companyId, table, force: true))['records'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  Map<String, dynamic> find(List<Map<String, dynamic>> data, String id) =>
      data.firstWhere(
        (r) => r['recordId'] == id,
        orElse: () => throw const SaasApiException(
          'RECORD_UNAVAILABLE',
          'A document record is unavailable. Refresh and retry.',
        ),
      );
  final record = find(await rows(section), recordId);
  final company = find(await rows('CompanyProfile'), 'company');
  final customer = find(await rows('Customers'), record['customerId']);
  final invoice = section == 'Invoices';
  final items = (await rows(invoice ? 'InvoiceItems' : 'QuotationItems'))
      .where((r) => r[invoice ? 'invoiceId' : 'quotationId'] == recordId)
      .toList()
    ..sort(
      (a, b) => (a['lineNumber'] as num).compareTo(b['lineNumber'] as num),
    );
  final latest = find(await rows(section), recordId);
  final latestCompany = find(await rows('CompanyProfile'), 'company');
  if (record['recordVersion'] != latest['recordVersion'] ||
      company['recordVersion'] != latestCompany['recordVersion']) {
    throw const SaasApiException(
      'VERSION_CONFLICT',
      'Document changed. Export again.',
    );
  }
  return renderHtmlDocument(
    source: source,
    section: section,
    record: record,
    company: company,
    customer: customer,
    items: items,
  );
}
