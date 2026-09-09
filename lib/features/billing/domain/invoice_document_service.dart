import 'dart:typed_data';
import 'models.dart';
abstract interface class InvoiceDocumentService {
  Future<Uint8List> render(Invoice invoice, {Payment? receipt});
}
