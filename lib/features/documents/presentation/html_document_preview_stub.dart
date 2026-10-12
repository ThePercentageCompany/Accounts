import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/utils/file_download.dart';

class HtmlDocumentPreview extends StatelessWidget {
  const HtmlDocumentPreview({super.key, required this.html});
  final String html;
  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton.icon(
          icon: const Icon(Icons.preview_outlined),
          label: const Text('Open HTML design preview'),
          onPressed: () => downloadFile(Uint8List.fromList(utf8.encode(html)),
              filename: 'document-preview.html', mimeType: 'text/html'),
        ),
      );
}
