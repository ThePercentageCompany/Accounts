import 'dart:typed_data';

Future<void> downloadFilePlatform(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
}) {
  throw UnsupportedError(
      'File downloads are currently available in the web app.');
}
