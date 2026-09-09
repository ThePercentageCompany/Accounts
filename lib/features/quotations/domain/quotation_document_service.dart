import 'dart:typed_data';
import 'quotation.dart';

abstract interface class QuotationDocumentService {
  Future<Uint8List> render(Quotation quotation);
}
