import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

Future<void> downloadFilePlatform(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
}) async {
  final path = await FilePicker.platform
      .saveFile(dialogTitle: 'Save file', fileName: filename, bytes: bytes);
  if (path != null && !Platform.isAndroid && !Platform.isIOS) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
}
