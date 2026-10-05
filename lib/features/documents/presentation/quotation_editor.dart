import 'package:tpc_invoice/features/documents/presentation/document_editor.dart';
import 'package:flutter/material.dart';

class QuotationEditor extends StatelessWidget {
  const QuotationEditor({
    super.key,
    required this.customers,
    this.record,
    this.items = const [],
    this.company = const {},
    this.onSave,
  });
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic>? record;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> company;
  final Future<void> Function(Map<String, Object?>)? onSave;
  @override
  Widget build(BuildContext context) => DocumentEditor(
    quotation: true,
    customers: customers,
    record: record,
    items: items,
    company: company,
    onSave: onSave,
  );
}
