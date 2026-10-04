import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/utils/file_download.dart';
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:tpc_invoice/features/documents/data/html_document_design.dart';

class HtmlDocumentDesignEditor extends StatefulWidget {
  const HtmlDocumentDesignEditor({
    super.key,
    required this.store,
    required this.preview,
  });
  final HtmlDocumentDesignStore store;
  final Future<String> Function(String) preview;
  @override
  State<HtmlDocumentDesignEditor> createState() =>
      _HtmlDocumentDesignEditorState();
}

class _HtmlDocumentDesignEditorState extends State<HtmlDocumentDesignEditor> {
  final source = TextEditingController();
  bool busy = true;
  String? message;
  @override
  void initState() {
    super.initState();
    run(() async {
      source.text = await widget.store.load();
    });
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    source.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
    title: const Text('Custom HTML design'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 850,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const Text(
              'Edit HTML and CSS. Saved separately for invoices and quotations in this workspace on this browser/device. Export a backup to use elsewhere. Designs change presentation only.',
            ),
            const SelectableText(
              'Placeholders: {{title}}, {{endDate}}, {{items}}, {{company.name}}, {{company.address}}, {{company.trn}}, {{customer.name}}, {{record.number}}, {{record.currency}}, {{record.subtotal}}, {{record.discount}}, {{record.taxAmount}}, {{record.total}}, {{record.notes}}, {{record.paymentTerms}}',
            ),
            TextField(
              controller: source,
              enabled: !busy,
              minLines: 12,
              maxLines: 20,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'HTML / CSS source',
                alignLabelWithHint: true,
              ),
            ),
            if (busy) const CupertinoActivityIndicator(),
            if (message != null)
              Semantics(liveRegion: true, child: Text(message!)),
            const Text(
              'Preview downloads an HTML file. Open it in your browser, then use Print → Save as PDF. Scripts and external resources are blocked; inline CSS and embedded data images are supported.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy
            ? null
            : () => run(() async {
                final picked = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['html', 'htm'],
                  withData: true,
                );
                if (picked == null) return;
                final bytes = picked.files.single.bytes;
                if (bytes == null || bytes.length > 100000) {
                  throw const FormatException(
                    'Choose an HTML file up to 100 KB.',
                  );
                }
                final imported = utf8.decode(bytes);
                validateHtmlDocumentDesign(imported);
                source.text = imported;
              }),
        child: const Text('Import HTML'),
      ),
      TextButton(
        onPressed: busy ? null : () => source.text = defaultHtmlDocumentDesign,
        child: const Text('Reset source'),
      ),
      TextButton(
        onPressed: busy
            ? null
            : () => run(() async {
                validateHtmlDocumentDesign(source.text);
                await downloadFile(
                  Uint8List.fromList(utf8.encode(source.text)),
                  filename: 'document-design.html',
                  mimeType: 'text/html',
                );
              }),
        child: const Text('Export design'),
      ),
      TextButton(
        onPressed: busy
            ? null
            : () => run(() async {
                final html = await widget.preview(source.text);
                await downloadFile(
                  Uint8List.fromList(utf8.encode(html)),
                  filename: 'document-preview.html',
                  mimeType: 'text/html',
                );
              }),
        child: const Text('Preview HTML'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () => run(() async {
                await widget.store.save(source.text);
                if (mounted) {
                  setState(() => message = 'Design saved on this device.');
                }
              }),
        child: const Text('Save design'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
