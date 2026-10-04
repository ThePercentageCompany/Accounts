import 'dart:typed_data';

import 'package:tpc_invoice/core/utils/file_download_stub.dart'
    if (dart.library.js_interop) 'package:tpc_invoice/core/utils/file_download_web.dart';

/// Saves an export using the platform's native download mechanism.
Future<void> downloadFile(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
}) {
  return downloadFilePlatform(bytes, filename: filename, mimeType: mimeType);
}
