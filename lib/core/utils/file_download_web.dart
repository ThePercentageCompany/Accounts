// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadFilePlatform(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
}) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], mimeType));
  final anchor = html.AnchorElement(href: url)..download = filename;
  anchor.click();
  html.Url.revokeObjectUrl(url);
}
