import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/widgets/app_spacing.dart';
import 'package:tpc_invoice/core/widgets/loading.dart';
import 'package:tpc_invoice/features/documents/data/document_upload_queue.dart';
import 'package:tpc_invoice/features/documents/presentation/record_documents_view.dart';

/// Both views derive from the saved payroll, never disconnected manual rows.
class PayrollSupportView extends StatefulWidget {
  const PayrollSupportView(
      {super.key,
      required this.api,
      required this.companyId,
      required this.employee,
      required this.slips,
      this.uploads,
      this.active = true});
  final SaasApi api;
  final String companyId;
  final bool employee, slips, active;
  final DocumentUploadQueue? uploads;
  @override
  State<PayrollSupportView> createState() => _PayrollSupportViewState();
}

class _PayrollSupportViewState extends State<PayrollSupportView> {
  List<Map<String, dynamic>> _rows = [];
  Map<String, String> _names = {};
  bool _busy = false;
  String? _error;
  int _generation = 0;
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PayrollSupportView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.api != oldWidget.api ||
        widget.companyId != oldWidget.companyId ||
        widget.employee != oldWidget.employee) {
      _generation++;
      _busy = false;
      _rows = [];
      _names = {};
      _load();
    } else if ((!oldWidget.active && widget.active) ||
        oldWidget.slips != widget.slips) {
      _load();
    }
  }

  Future<void> _load() async {
    if (_busy || !widget.active) return;
    final generation = _generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.records(widget.companyId, 'Payroll',
          employee: widget.employee, force: true);
      final names = <String, String>{};
      if (!widget.employee) {
        final employees = await widget.api.employees(widget.companyId);
        for (final row in employees['employees'] as List? ?? []) {
          names['${row['recordId']}'] = '${row['fullName']}';
        }
      }
      if (!mounted || generation != _generation) return;
      final rows = (result['records'] as List? ?? [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      rows.sort((a, b) => '${b['month']}'.compareTo('${a['month']}'));
      setState(() {
        _rows = rows;
        _names = names;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e is SaasApiException
            ? e.message
            : 'Could not load payroll. Please retry.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _name(Map<String, dynamic> row) =>
      _names['${row['employeeId']}'] ??
      (widget.employee ? 'Your payroll' : 'Employee ${row['employeeId']}');
  @override
  Widget build(BuildContext context) {
    final rows = _rows
        .where((r) =>
            (!widget.slips || ['APPROVED', 'PAID'].contains(r['status'])) &&
            '${_name(r)} ${r['month']} ${r['status']}'
                .toLowerCase()
                .contains(_search.text.trim().toLowerCase()))
        .toList();
    final money = NumberFormat('#,##0.00');
    String amount(dynamic value) => money.format(num.tryParse('$value') ?? 0);
    return RefreshIndicator.noSpinner(
        onRefresh: _load,
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.page(context),
            children: [
              Row(children: [
                Expanded(
                    child: Text(widget.slips ? 'Payslips' : 'Payroll details',
                        style: Theme.of(context).textTheme.headlineSmall)),
                IconButton(
                    tooltip: 'Refresh payroll',
                    onPressed: _busy ? null : _load,
                    icon: const Icon(Icons.refresh))
              ]),
              Text(widget.slips
                  ? 'Open or create a payslip from approved or paid payroll.'
                  : 'Salary breakdowns calculated and saved with each payroll record.'),
              const SizedBox(height: 16),
              TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'Search employee, month or status',
                      prefixIcon: Icon(Icons.search))),
              const SizedBox(height: 16),
              if (_busy) const Center(child: AppActivityIndicator()),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_error!)),
              if (!_busy && _error == null && rows.isEmpty)
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_search.text.isNotEmpty
                        ? 'No matching payroll records.'
                        : widget.slips
                            ? 'Approve a payroll record to make its payslip available.'
                            : 'Create payroll to see its salary breakdown here.')),
              for (final row in rows)
                Card(
                    child: ExpansionTile(
                  key: PageStorageKey((widget.slips, row['recordId'])),
                  title: Text('${_name(row)} · ${row['month']}'),
                  subtitle: Text(
                      '${row['status']} · Net salary ${amount(row['netSalary'])}'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final field in const {
                      'basicSalary': 'Basic salary',
                      'allowances': 'Allowances',
                      'overtimeAmount': 'Overtime',
                      'bonus': 'Bonus',
                      'grossSalary': 'Gross salary',
                      'deductions': 'Deductions',
                      'netSalary': 'Net salary'
                    }.entries)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Expanded(child: Text(field.value)),
                            const SizedBox(width: 16),
                            Text(amount(row[field.key])),
                          ])),
                    if (row['status'] == 'PAID')
                      Text(
                          'Paid ${row['paidDate']} · ${row['paymentAccount']}'),
                    if (['APPROVED', 'PAID'].contains(row['status'])) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Open payslip documents'),
                          onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => RecordDocumentsView(
                                  api: widget.api,
                                  companyId: widget.companyId,
                                  section: 'Payroll',
                                  record: row,
                                  employee: widget.employee,
                                  uploads: widget.employee
                                      ? null
                                      : widget.uploads))),
                    ],
                  ],
                )),
            ]));
  }
}
