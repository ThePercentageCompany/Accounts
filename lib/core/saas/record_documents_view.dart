import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../utils/file_download.dart';
import 'document_upload_queue.dart';
import 'record_write_queue.dart';
import 'saas_api.dart';
import 'shared_record_pdf.dart';

const documentSections = [
  'CompanyProfile',
  'Invoices',
  'Receipts',
  'Quotations',
  'Expenses',
  'Employees',
  'Payroll',
  'Payslips',
  'Assets'
];

class RecordDocumentsView extends StatefulWidget {
  const RecordDocumentsView(
      {super.key,
      required this.api,
      required this.companyId,
      required this.section,
      required this.record,
      this.employee = false,
      this.uploads,
      this.writes});
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
  String? error;
  Uint8List? image;
  String? imageName;
  bool get logo => widget.section == 'CompanyProfile';
  @override
  void initState() {
    super.initState();
    _load();
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
        setState(() => error = e is SaasApiException
            ? e.message
            : 'Could not complete this action. Retry when connected.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _read() async {
    final result = await widget.api.documents(
        widget.companyId, widget.section, widget.record['recordId'],
        employee: widget.employee);
    if (mounted) {
      setState(() => documents = (result['documents'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList());
    }
  }

  Future<void> _load() => _run(() async {
        setState(() => documents = []);
        await _read();
      });
  Future<void> _upload() => _run(() async {
        final picked = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions:
                logo ? ['png', 'jpg', 'jpeg'] : ['pdf', 'png', 'jpg', 'jpeg'],
            withData: true);
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
              'DOCUMENT_TYPE', 'Choose a PNG, JPEG or PDF file.');
        }
        await widget.uploads!.enqueue(
            name: file.name,
            mimeType: mime,
            section: widget.section,
            recordId: widget.record['recordId'],
            bytes: file.bytes!);
        await widget.uploads!.flush();
        await _read();
      });
  Future<void> _generate() => _run(() async {
        final bytes = await sharedRecordPdf(widget.api, widget.companyId,
            widget.section, widget.record['recordId']);
        await widget.uploads!.enqueue(
            name: '${widget.section}-${widget.record['recordId']}.pdf',
            mimeType: 'application/pdf',
            section: widget.section,
            recordId: widget.record['recordId'],
            bytes: bytes);
        await widget.uploads!.flush();
        await _read();
      });
  Future<void> _open(Map<String, dynamic> doc) => _run(() async {
        final bytes = await widget.api.document(
            widget.companyId, doc['documentId'],
            employee: widget.employee);
        if ('${doc['mimeType']}'.startsWith('image/')) {
          if (mounted) {
            setState(() {
              image = bytes;
              imageName = doc['name'];
            });
          }
        } else {
          await downloadFile(bytes,
              filename: doc['name'], mimeType: doc['mimeType']);
        }
      });
  Future<void> _useLogo(String id) => _run(() async {
        // Read the current version; the durable update still detects concurrent edits.
        final data =
            await widget.api.records(widget.companyId, 'CompanyProfile');
        final profile = (data['records'] as List).single;
        await widget.writes!.enqueue(
            'CompanyProfile', 'update', {'logoDocumentId': id},
            recordId: 'company',
            expectedVersion: int.parse('${profile['recordVersion']}'));
        await widget.writes!.flush();
        if (mounted) Navigator.pop(context);
      });
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(logo ? 'Company logo' : 'Record documents'),
        content: SizedBox(
            width: 560,
            height: 440,
            child: Column(children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null) Text(error!),
              if (widget.uploads != null)
                Wrap(spacing: 8, children: [
                  if (const [
                    'Invoices',
                    'Quotations',
                    'Receipts',
                    'Payroll',
                    'Assets'
                  ].contains(widget.section))
                    TextButton.icon(
                        onPressed: busy ||
                                widget.uploads!.pending != null ||
                                widget.writes?.pending.isNotEmpty == true
                            ? null
                            : _generate,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Create and attach PDF')),
                  TextButton.icon(
                      onPressed: busy ||
                              widget.uploads!.pending != null ||
                              widget.writes?.pending.isNotEmpty == true
                          ? null
                          : _upload,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload file (max 5 MiB)')),
                  if (widget.uploads!.pending != null)
                    TextButton(
                        onPressed: busy
                            ? null
                            : () => _run(() async {
                                  await widget.uploads!.flush();
                                  await _read();
                                }),
                        child: const Text('Retry pending upload')),
                ]),
              if (!busy && documents.isEmpty)
                const Text('No documents attached.'),
              Expanded(
                  child: ListView(children: [
                for (final doc in documents)
                  ListTile(
                      title: Text('${doc['name']}'),
                      subtitle: Text(
                          '${doc['mimeType']} · ${doc['byteLength']} bytes'),
                      onTap: busy ? null : () => _open(doc),
                      trailing: logo && widget.writes != null
                          ? TextButton(
                              onPressed:
                                  busy || widget.writes!.pending.isNotEmpty
                                      ? null
                                      : () => _useLogo(doc['documentId']),
                              child: const Text('Use as logo'))
                          : const Icon(Icons.download)),
                if (image != null)
                  Image.memory(image!,
                      semanticLabel: imageName,
                      height: 200,
                      errorBuilder: (_, _, _) =>
                          const Text('Image could not be displayed.')),
              ])),
            ])),
        actions: [
          if (logo &&
              widget.writes != null &&
              '${widget.record['logoDocumentId'] ?? ''}'.isNotEmpty)
            TextButton(
                onPressed: busy || widget.writes!.pending.isNotEmpty
                    ? null
                    : () => _useLogo(''),
                child: const Text('Remove logo')),
          TextButton(
              onPressed: busy ? null : _load, child: const Text('Refresh')),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      );
}

class PrivateCompanyLogo extends StatefulWidget {
  const PrivateCompanyLogo(
      {super.key,
      required this.api,
      required this.companyId,
      required this.documentId,
      this.employee = false});
  final SaasApi api;
  final String companyId, documentId;
  final bool employee;
  @override
  State<PrivateCompanyLogo> createState() => _PrivateCompanyLogoState();
}

class _PrivateCompanyLogoState extends State<PrivateCompanyLogo> {
  late final content = widget.api
      .document(widget.companyId, widget.documentId, employee: widget.employee);
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
      future: content,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Logo unavailable. Refresh to retry.');
        }
        if (!snapshot.hasData) {
          return const SizedBox(
              height: 40, child: Center(child: CircularProgressIndicator()));
        }
        return Image.memory(snapshot.data!,
            height: 100,
            semanticLabel: 'Company logo',
            errorBuilder: (_, _, _) =>
                const Text('Logo could not be displayed.'));
      });
}
