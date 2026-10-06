import 'package:flutter/material.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/widgets/appearance_selector.dart';
import 'package:tpc_invoice/features/documents/data/html_document_design.dart';
import 'package:tpc_invoice/features/documents/presentation/html_document_design_editor.dart';

class SystemSettingsPanel extends StatelessWidget {
  const SystemSettingsPanel({
    super.key,
    required this.api,
    required this.companyId,
  });
  final SaasApi api;
  final String companyId;

  void editDesign(BuildContext context, String section) {
    showDialog<void>(
      context: context,
      builder: (_) => HtmlDocumentDesignEditor(
        store: HtmlDocumentDesignStore('${api.origin}|$companyId|$section'),
        preview: (source) async {
          final records =
              (await api.records(companyId, section, force: true))['records']
                  as List;
          if (records.isEmpty) {
            throw const SaasApiException(
              'NO_PREVIEW_RECORD',
              'Save an invoice or quotation first to preview its design. You can save the design now.',
            );
          }
          return savedRecordHtml(
            api,
            companyId,
            section,
            records.first['recordId'],
            source,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Card(
      child: ExpansionTile(
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        initiallyExpanded: true,
        leading: const Icon(Icons.settings_outlined),
        title: const Text('System settings'),
        subtitle: const Text('Appearance and document designs'),
        children: [
          const ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text('Appearance'),
            subtitle: Text('Light, dark or system theme'),
            trailing: AppearanceSelector(),
          ),
          for (final section in const ['Invoices', 'Quotations'])
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(
                section == 'Invoices' ? 'Invoice design' : 'Quotation design',
              ),
              subtitle: const Text(
                'Edit, import, preview and update HTML / CSS',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => editDesign(context, section),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Designs and appearance are saved on this device. Company details and logo are managed below. Preview uses the first saved document.',
            ),
          ),
        ],
      ),
    ),
  );
}
