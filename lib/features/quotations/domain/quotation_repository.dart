import 'dart:typed_data';
import 'quotation.dart';

abstract interface class QuotationRepository {
  bool get isDemo;
  Future<List<Quotation>> load();
  Future<Quotation> save(Quotation quotation);
  Future<Quotation> issue(Quotation quotation);
  Future<Quotation> updateStatus(String quotationId, String newStatus);
  Future<void> delete(String quotationId);
  Future<String> archive(Quotation quotation, Uint8List bytes);
}
