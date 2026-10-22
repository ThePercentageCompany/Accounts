/// Shared invalidation rules for server writes and local provisional changes.
/// Financial effects still depend on posting status in the report projection.
class WorkspaceDependencies {
  static bool financial(Iterable<String> tables) => tables.any(
    (table) => !const [
      'Customers',
      'Projects',
      'Employees',
      'CompanyProfile',
      'Tasks',
      'TaskComments',
      'TaskActivity',
    ].contains(table),
  );

  static Set<String> affected(Iterable<String> tables) {
    final changed = tables.toSet(), result = {...tables};
    if (changed.contains('Tasks')) result.add('TaskActivity');
    if (financial(changed)) result.addAll(['Journals', 'JournalLines']);
    if (changed.any(['Invoices', 'InvoiceItems', 'Receipts'].contains)) {
      result.addAll([
        'Invoices',
        'InvoiceItems',
        'Receipts',
        'ReceiptAllocations',
        'CreditNotes',
        'CreditNoteItems',
      ]);
    }
    if (changed.any(['Quotations', 'QuotationItems'].contains)) {
      result.addAll([
        'Quotations',
        'QuotationItems',
        'Invoices',
        'InvoiceItems',
      ]);
    }
    if (changed.contains('Payroll')) {
      result.addAll(['PayrollItems', 'Payslips']);
    }
    if (changed.contains('CapitalTransactions')) {
      result.addAll(['CapitalAccounts', 'ShareholderEquity', 'Shareholders']);
    }
    return result;
  }

  static bool localAffects(String source, String resource) {
    final changed = Uri.parse(source).path;
    final path = Uri.parse(resource).path;
    // Reload notifications carry the records collection with no table name.
    if (changed.isEmpty || changed.endsWith('/records/')) return true;
    final table = changed.endsWith('/employees')
        ? 'Employees'
        : changed.split('/').last;
    if (path.endsWith('/overview')) return true;
    if (path.contains('/reports/')) return financial([table]);
    if (path.contains('/tasks')) {
      return const [
        'Tasks',
        'TaskComments',
        'TaskActivity',
        'Employees',
        'Projects',
      ].contains(table);
    }
    if (table == 'Documents' && path.contains('/documents')) return true;
    if (table == 'Employees' && path.endsWith('/employees')) return true;
    return affected([table]).contains(path.split('/').last);
  }
}
