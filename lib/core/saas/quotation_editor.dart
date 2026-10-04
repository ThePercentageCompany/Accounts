import 'document_editor.dart';
import 'package:flutter/material.dart';

class QuotationEditor extends StatelessWidget {
  const QuotationEditor({
    super.key,
    required this.customers,
    this.record,
    this.items = const [],
    this.company = const {},
  });
  final List<Map<String, dynamic>> customers;
  final Map<String, dynamic>? record;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> company;
  @override
  Widget build(BuildContext context) => DocumentEditor(
        quotation: true,
        customers: customers,
        record: record,
        items: items,
        company: company,
      );
}
