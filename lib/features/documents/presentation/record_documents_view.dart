import 'package:tpc_invoice/core/utils/report_print.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:tpc_invoice/features/documents/data/html_document_design.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tpc_invoice/core/widgets/forms/mobile_components.dart';
import 'package:tpc_invoice/core/utils/file_download.dart';
import 'package:tpc_invoice/features/documents/data/document_upload_queue.dart';
import 'package:tpc_invoice/features/accounting/data/record_write_queue.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/features/documents/data/shared_record_pdf.dart';

const documentSections = [
  'Tasks',
  'CompanyProfile',
  'Invoices',
  'CreditNotes',
  'Receipts',
  'Quotations',
  'Income',
  'Expenses',
  'Employees',
  'Payroll',
  'Payslips',
  'Assets',
];

class RecordDocumentsView extends StatefulWidget {
  const RecordDocumentsView({
    super.key,
    required this.api,
    required this.companyId,
    required this.section,
    required this.record,
    this.employee = false,
    this.uploads,
    this.writes,
  });
  final SaasApi api;
  final String companyId, section;
  final Map<String, dynamic> record;
  final bool employee;
  final DocumentUploadQueue? uploads;
  final RecordWriteQueue? writes;
  @override
  State<RecordDocumentsView> createState() => _RecordDocumentsViewState();
}

class _RecordDocumentsViewState extends State<RecordDocumentsView> {
  List<Map<String, dynamic>> documents = [];
  bool busy = false;
  bool _hasLoaded = false;
  bool _reading = false;
  int _lastLocalCount = 0;
  String get _recordId =>
      '${widget.uploads?.box?.data['ids'][widget.record['recordId']] ?? widget.record['recordId']}';
  List<Map<String, dynamic>> get _localDocuments =>
      widget.uploads?.box?.pending
          .where((op) =>
              op['table'] == 'Documents' &&
              (op['values'] as Map)['section'] == widget.section &&
              (op['values'] as Map)['relatedRecordId'] ==
                  (widget.uploads?.box?.data['ids']
                          [widget.record['recordId']] ??
                      widget.record['recordId']))
          .map((op) => <String, dynamic>{
                ...Map<String, dynamic>.from(op['values'] as Map),
                'documentId': op['localId'],
                '_localData': (op['values'] as Map)['data']
              })
          .toList() ??
      [];
  void _localChanged() {
    if (mounted) {
      final count = _localDocuments.length;
      final acknowledged = count < _lastLocalCount;
      _lastLocalCount = count;
      setState(() {});
      if (acknowledged) _load().ignore();
    }
  }

  String? error;
  Uint8List? image;
  String? imageName;
  bool get logo => widget.section == 'CompanyProfile';
  Future<void> _exportHtml() => _run(() async {
        final html = await savedRecordHtml(
          widget.api,
          widget.companyId,
          widget.section,
          _recordId,
          employee: widget.employee,
        );
        await downloadFile(
          Uint8List.fromList(utf8.encode(html)),
          filename: '${widget.section}-${widget.record['recordId']}.html',
          mimeType: 'text/html',
        );
      });
  @override
  void initState() {
    super.initState();
    widget.uploads?.box?.addListener(_localChanged);
    _load();
  }

  @override
  void dispose() {
    widget.uploads?.box?.removeListener(_localChanged);
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
      image = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is SaasApiException
              ? e.message
              : 'Could not complete this action. Retry when connected.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _read() async {
    final result = await widget.api.documents(
      widget.companyId,
      widget.section,
      _recordId,
      employee: widget.employee,
      force: true,
    );
    if (mounted) {
      setState(() {
        _hasLoaded = true;
        documents = (result['documents'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    }
  }

  Future<void> _load() async {
    if (_reading) return;
    setState(() => _reading = true);
    try {
      if (!_recordId.startsWith('local_')) await _read();
    } catch (e) {
      if (mounted && documents.isEmpty && _localDocuments.isEmpty) {
        setState(() => error =
            'Previously opened documents remain available when connected.');
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Delete ${doc['name']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.api.deleteDocument(widget.companyId, doc['documentId'],
          employee: widget.employee);
      await _read();
    });
  }

  Future<void> _upload() => _run(() async {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions:
              logo ? ['png', 'jpg', 'jpeg'] : ['pdf', 'png', 'jpg', 'jpeg'],
          withData: true,
        );
        if (picked == null) return;
        final file = picked.files.single;
        final mime = switch (file.extension?.toLowerCase()) {
          'png' => 'image/png',
          'jpg' || 'jpeg' => 'image/jpeg',
          'pdf' => 'application/pdf',
          _ => '',
        };
        if (file.bytes == null || mime.isEmpty) {
          throw const SaasApiException(
            'DOCUMENT_TYPE',
            'Choose a PNG, JPEG or PDF file.',
          );
        }
        await widget.uploads!.enqueue(
          name: file.name,
          mimeType: mime,
          section: widget.section,
          recordId: _recordId,
          bytes: file.bytes!,
        );
        await widget.uploads!.syncInBackground();
        if (widget.api.offlineEnabled) {
          unawaited(_read().catchError((Object _) {}));
        } else {
          await _read();
        }
      });
  Future<Uint8List> _pdfBytes() async {
    return sharedRecordPdf(
      widget.api,
      widget.companyId,
      widget.section,
      _recordId,
      employee: widget.employee,
    );
  }

  Future<void> _downloadPdf() => _run(() async {
        await downloadFile(await _pdfBytes(),
            filename: '${widget.section}-$_recordId.pdf',
            mimeType: 'application/pdf');
      });
  Future<void> _printDesign() => _run(() async {
        final html = await savedRecordHtml(
            widget.api, widget.companyId, widget.section, _recordId,
            employee: widget.employee);
        await printReport(html);
      });
  Future<void> _generate() => _run(() async {
        final bytes = await _pdfBytes();
        await widget.uploads!.enqueue(
          name: '${widget.section}-${widget.record['recordId']}.pdf',
          mimeType: 'application/pdf',
          section: widget.section,
          recordId: _recordId,
          bytes: bytes,
        );
        await widget.uploads!.syncInBackground();
        if (widget.api.offlineEnabled) {
          unawaited(_read().catchError((Object _) {}));
        } else {
          await _read();
        }
      });
  Future<void> _open(Map<String, dynamic> doc) => _run(() async {
        final bytes = doc['_localData'] != null
            ? base64Decode(doc['_localData'])
            : await widget.api.document(
                widget.companyId,
                doc['documentId'],
                employee: widget.employee,
              );
        if ('${doc['mimeType']}'.startsWith('image/')) {
          if (mounted) {
            setState(() {
              image = bytes;
              imageName = doc['name'];
            });
          }
        } else {
          await downloadFile(
            bytes,
            filename: doc['name'],
            mimeType: doc['mimeType'],
          );
        }
      });
  Future<void> _useLogo(String id) => _run(() async {
        // Read the current version; the durable update still detects concurrent edits.
        final data =
            await widget.api.records(widget.companyId, 'CompanyProfile');
        final profile = (data['records'] as List).single;
        await widget.writes!.enqueue(
          'CompanyProfile',
          'update',
          {'logoDocumentId': id},
          recordId: 'company',
          expectedVersion: int.parse('${profile['recordVersion']}'),
        );
        await widget.writes!.syncInBackground();
        if (mounted) Navigator.pop(context);
      });
  @override
  Widget build(BuildContext context) => AdaptiveFormDialog(
        title: Text(logo ? 'Company logo' : 'Record documents'),
        content: SizedBox(
          width: 560,
          height: 440,
          child: Column(
            children: [
              SizedBox(
                height: 28,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: busy && _hasLoaded
                      ? const AppActivityIndicator(radius: 8)
                      : null,
                ),
              ),
              if (error != null) Text(error!),
              if (htmlDocumentSections.contains(widget.section))
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    LoadingButton.textIcon(
                      onPressed: busy ? null : _downloadPdf,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download PDF'),
                    ),
                    if (kIsWeb)
                      LoadingButton.textIcon(
                        onPressed: busy ? null : _printDesign,
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Print company design'),
                      )
                  ],
                ),
              if (widget.section == 'Assets')
                Align(
                  alignment: Alignment.centerRight,
                  child: LoadingButton.textIcon(
                    onPressed: busy ? null : _downloadPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Download PDF'),
                  ),
                ),
              if (!widget.employee &&
                  htmlDocumentSections.contains(widget.section))
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<String>(
                    tooltip: 'Export custom HTML',
                    enabled: !busy,
                    icon: const Icon(Icons.code),
                    onSelected: (_) => _exportHtml(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'export',
                        child: Text('Export custom HTML'),
                      ),
                    ],
                  ),
                ),
              if (widget.uploads != null)
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (const [
                      'Invoices',
                      'Quotations',
                      'CreditNotes',
                      'Receipts',
                      'Payroll',
                      'Assets',
                    ].contains(widget.section))
                      LoadingButton.textIcon(
                        onPressed: busy ? null : _generate,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Create and attach PDF'),
                      ),
                    LoadingButton.icon(
                      onPressed: busy ? null : _upload,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload document'),
                    ),
                  ],
                ),
              if (htmlDocumentSections.contains(widget.section))
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(kIsWeb
                        ? 'PDFs are generated on this device. Print company design uses the saved HTML layout.'
                        : 'PDFs are generated on this device.')),
              if (!busy && documents.isEmpty && _localDocuments.isEmpty)
                const Text('No documents attached.'),
              Expanded(
                child: _reading && !_hasLoaded && _localDocuments.isEmpty
                    ? const CenteredLoading(label: 'Loading documents')
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        children: [
                          for (final doc in [...documents, ..._localDocuments])
                            Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text('${doc['name']}'),
                                  subtitle: Text(
                                    '${doc['mimeType']} · ${doc['byteLength']} bytes',
                                  ),
                                  onTap: busy ? null : () => _open(doc),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (doc['canDelete'] == true ||
                                            (!widget.employee &&
                                                doc['_localData'] == null))
                                          IconButton(
                                            tooltip: 'Delete document',
                                            onPressed: busy
                                                ? null
                                                : () => _deleteDocument(doc),
                                            icon: const Icon(
                                                Icons.delete_outline),
                                          ),
                                        logo && widget.writes != null
                                            ? LoadingButton.text(
                                                onPressed: busy
                                                    ? null
                                                    : () => _useLogo(
                                                        doc['documentId']),
                                                child:
                                                    const Text('Use as logo'),
                                              )
                                            : const Icon(Icons.download),
                                      ]),
                                )),
                          if (image != null)
                            Image.memory(
                              image!,
                              semanticLabel: imageName,
                              height: 200,
                              errorBuilder: (_, _, _) =>
                                  const Text('Image could not be displayed.'),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        actions: [
          if (logo &&
              widget.writes != null &&
              '${widget.record['logoDocumentId'] ?? ''}'.isNotEmpty)
            LoadingButton.text(
              onPressed: busy ? null : () => _useLogo(''),
              child: const Text('Remove logo'),
            ),
          LoadingButton.text(
            onPressed: busy ? null : _load,
            child: const Text('Refresh'),
          ),
          LoadingButton.text(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
}

class PrivateCompanyLogo extends StatefulWidget {
  const PrivateCompanyLogo({
    super.key,
    required this.api,
    required this.companyId,
    required this.documentId,
    this.employee = false,
  });
  final SaasApi api;
  final String companyId, documentId;
  final bool employee;
  @override
  State<PrivateCompanyLogo> createState() => _PrivateCompanyLogoState();
}

class _PrivateCompanyLogoState extends State<PrivateCompanyLogo> {
  late final content = widget.api.document(
    widget.companyId,
    widget.documentId,
    employee: widget.employee,
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: content,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Logo unavailable. Refresh to retry.');
          }
          if (!snapshot.hasData) {
            return const SizedBox(height: 40, child: CenteredLoading());
          }
          return Image.memory(
            snapshot.data!,
            height: 100,
            semanticLabel: 'Company logo',
            errorBuilder: (_, _, _) =>
                const Text('Logo could not be displayed.'),
          );
        },
      );
}
