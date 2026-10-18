String documentEndpointSection(String value) {
  final key = value.replaceAll(RegExp(r'[\s_-]'), '').toLowerCase();
  return const {
        'invoice': 'Invoices',
        'invoices': 'Invoices',
        'quotation': 'Quotations',
        'quotations': 'Quotations',
        'creditnote': 'CreditNotes',
        'creditnotes': 'CreditNotes',
        'receipt': 'Receipts',
        'receipts': 'Receipts',
        'payslip': 'Payroll',
        'payslips': 'Payroll',
        'payroll': 'Payroll',
      }[key] ??
      (throw ArgumentError.value(
          value, 'section', 'Unsupported document template'));
}
