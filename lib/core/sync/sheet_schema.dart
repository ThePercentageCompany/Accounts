import 'dart:convert';

/// Universal Google Sheets Schema and Column Field Mapping for TPC Accounts & Billing.
/// Ensures every Google Sheet tab has dedicated, clean human-readable column headers and fields
/// with ZERO JSON payload blobs, providing 100% human-readable sheets and robust bidirectional sync.
class SheetSchema {
  static const List<String> allTabs = [
    'Customers',
    'Invoices',
    'Quotations',
    'Finance',
    'Employees',
    'Attendance',
    'Payroll',
    'Shareholders',
    'CapitalTransactions',
    'ShareholderLoans',
    'Assets',
    'Journals',
    'Settings',
    'Invoice Register',
    'Payment Register',
    'Quotation Register',
  ];

  static const List<String> dataTabsToSync = [
    'Customers',
    'Invoices',
    'Quotations',
    'Finance',
    'Employees',
    'Attendance',
    'Payroll',
    'Shareholders',
    'CapitalTransactions',
    'ShareholderLoans',
    'Assets',
    'Journals',
    'Settings',
  ];

  /// Converts a 1-based column index to an Excel / Google Sheets column letter (e.g. 1 -> 'A', 26 -> 'Z', 27 -> 'AA').
  static String getColLetter(int index) {
    if (index <= 0) return 'A';
    String result = '';
    while (index > 0) {
      final rem = (index - 1) % 26;
      result = String.fromCharCode(65 + rem) + result;
      index = (index - 1) ~/ 26;
    }
    return result;
  }

  /// Stores attachment URLs as individual newline-delimited Drive links.  This
  /// keeps Sheets readable while preserving enough information to rebuild the
  /// in-app attachment list after a refresh.
  static String attachmentLinks(Map<String, dynamic> record) {
    final docs = record['documents'];
    if (docs is! List) return '';
    return docs
        .whereType<Map>()
        .map((doc) => doc['url']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .join('\n');
  }

  static List<Map<String, dynamic>> attachmentsFromCell(dynamic value) {
    final urls = (value?.toString() ?? '')
        .split(RegExp(r'[\n,]'))
        .map((url) => url.trim())
        .where((url) => url.startsWith('http://') || url.startsWith('https://'))
        .toList();
    return [
      for (var i = 0; i < urls.length; i++)
        {'id': 'drive_$i', 'name': 'Attachment ${i + 1}', 'url': urls[i]},
    ];
  }

  /// Returns the human-readable column headers for a specific sheet tab (without JSON Payload).
  static List<String> getHeaders(String tabName) {
    switch (tabName) {
      case 'Customers':
        return [
          'Customer ID',
          'Customer Name',
          'Email Address',
          'Phone Number',
          'TRN / Tax Number',
          'Company Address',
          'Version',
        ];

      case 'Invoices':
        return [
          'Invoice ID',
          'Invoice Number',
          'Issue Date',
          'Due Date',
          'Customer Name',
          'Customer ID',
          'Status',
          'Tax Rate %',
          'Discount AED',
          'Subtotal AED',
          'Tax Amount AED',
          'Total Amount AED',
          'Paid Amount AED',
          'Balance Due AED',
          'Items Summary',
          'Payment Details',
          'Notes',
          'Payment Terms',
          'Drive PDF Link',
          'Issued At',
          'Version',
        ];

      case 'Quotations':
        return [
          'Quotation ID',
          'Quotation Number',
          'Issue Date',
          'Valid Until',
          'Customer Name',
          'Customer ID',
          'Status',
          'Tax Rate %',
          'Discount AED',
          'Subtotal AED',
          'Tax Amount AED',
          'Total Amount AED',
          'Items Summary',
          'Notes',
          'Payment Terms',
          'Converted Invoice ID',
          'Drive PDF Link',
          'Issued At',
          'Version',
        ];

      case 'Finance':
        return [
          'Entry ID',
          'Date',
          'Transaction Kind',
          'Category',
          'Description',
          'Amount AED',
          'VAT %',
          'VAT Amount AED',
          'Total Amount AED',
          'Payment Status',
          'Paid Date',
          'Due Date',
          'Account / Method',
          'Supplier / Payee',
          'Reference / Doc #',
          'Notes',
          'Version',
          'Attachment Drive Links',
        ];

      case 'Employees':
        return [
          'Employee ID',
          'Employee Code',
          'Full Name',
          'Role / Designation',
          'Department',
          'Join Date',
          'Basic Salary AED',
          'Allowances AED',
          'Total Monthly Salary AED',
          'Phone Number',
          'Email Address',
          'Employment Status',
          'IBAN / Bank Account',
          'Notes',
          'Version',
          'Attachment Drive Links',
          'Address',
          'Bank Name',
          'Emirates ID',
          'Passport Number',
          'Visa Expiry',
          'Last Employment Date',
        ];

      case 'Attendance':
        return [
          'Attendance ID',
          'Date',
          'Employee ID',
          'Employee Name',
          'Attendance Status',
          'Overtime Hours',
          'Notes',
          'Version',
        ];

      case 'Payroll':
        return [
          'Payroll ID',
          'Payroll Month',
          'Employee ID',
          'Employee Name',
          'Basic Salary AED',
          'Allowances AED',
          'Overtime Amount AED',
          'Bonus AED',
          'Deductions AED',
          'Gross Salary AED',
          'Net Salary AED',
          'Payment Status',
          'Paid Date',
          'Payment Account',
          'Version',
          'Drive Payslip Link',
          'Unpaid Absence Deduction AED',
          'Salary Daily Divisor',
          'Base Paid Days',
          'Scheduled Working Days',
          'Marked Working Days',
          'Unpaid Days',
          'Overtime Rate AED',
          'Adjustment Note',
          'Payment Reference',
        ];

      case 'Shareholders':
        return [
          'Shareholder ID',
          'Shareholder Name',
          'Role / Title',
          'Equity Share %',
          'Agreed Capital AED',
          'Investment Date',
          'Email Address',
          'Phone Number',
          'Status',
          'Notes',
          'Version',
        ];

      case 'CapitalTransactions':
        return [
          'Transaction ID',
          'Transaction Date',
          'Shareholder ID',
          'Shareholder Name',
          'Transaction Type',
          'Contribution Method',
          'Capital Amount AED',
          'Asset Name / Details',
          'Destination Account',
          'Status',
          'Reference / Doc #',
          'Notes',
          'Version',
        ];

      case 'ShareholderLoans':
        return [
          'Loan ID',
          'Loan Date',
          'Shareholder ID',
          'Shareholder Name',
          'Loan Action / Type',
          'Principal Amount AED',
          'Interest Rate %',
          'Repaid Amount AED',
          'Outstanding Balance AED',
          'Due Date',
          'Payment Account',
          'Loan Status',
          'Reference / Doc #',
          'Notes',
          'Version',
        ];

      case 'Assets':
        return [
          'Asset ID',
          'Asset Name',
          'Asset Category',
          'Purchase Date',
          'Purchase Cost AED',
          'Useful Life (Years)',
          'Residual Value AED',
          'Depreciation Method',
          'Accumulated Depreciation AED',
          'Net Book Value AED',
          'Status',
          'Notes',
          'Version',
          'Last Depreciation Month',
          'Asset Code',
          'Acquisition Type',
          'Payment Account',
          'Shareholder ID',
          'Shareholder Name',
          'Location',
          'Assigned Employee ID',
          'Assigned Employee Name',
          'Serial Number',
          'Acquisition Journal ID',
        ];

      case 'Journals':
        return [
          'Journal ID',
          'Entry Date',
          'Entry Number / Ref',
          'Description',
          'Transaction Type',
          'Debit Account',
          'Credit Account',
          'Amount AED',
          'Notes',
          'Version',
          'Source Type',
          'Source ID',
          'Total Debit AED',
          'Total Credit AED',
          'Balanced',
          'Status',
          'Journal Lines (Account ID | Name | Group | Debit AED | Credit AED)',
        ];

      case 'Settings':
        return [
          'Setting Key',
          'Company Name',
          'Email Address',
          'Phone Number',
          'TRN / Tax Number',
          'Invoice Prefix',
          'Company Address',
          'Bank Name',
          'Account Holder',
          'Account Number',
          'IBAN',
          'Default Payment Terms',
          'Default Notes',
          'Version',
          'Company Logo Drive Link',
        ];

      case 'Invoice Register':
        return [
          'ID',
          'Number',
          'Date',
          'Due Date',
          'Customer',
          'Status',
          'Subtotal AED',
          'Tax AED',
          'Total AED',
          'Paid AED',
          'Balance AED',
          'PDF Link',
        ];

      case 'Payment Register':
        return [
          'Payment ID',
          'Invoice #',
          'Date',
          'Amount AED',
          'Account',
          'Reference',
          'Customer',
        ];

      case 'Quotation Register':
        return [
          'ID',
          'Number',
          'Date',
          'Valid Until',
          'Customer',
          'Status',
          'Total AED',
          'Converted Invoice #',
          'PDF Link',
        ];

      default:
        return ['ID', 'Data'];
    }
  }

  /// Converts a domain data record into a clean, human-readable list of scalar cell values for Google Sheets (NO JSON blobs).
  static List<dynamic> recordToRow(String tabName, Map<String, dynamic> record) {
    switch (tabName) {
      case 'Customers':
        return [
          record['id']?.toString() ?? '',
          record['name']?.toString() ?? '',
          record['email']?.toString() ?? '',
          record['phone']?.toString() ?? '',
          record['trn']?.toString() ?? '',
          record['address']?.toString() ?? '',
          record['version'] ?? 0,
        ];

      case 'Invoices':
        final customerMap = record['customer'] is Map ? record['customer'] as Map : {};
        final customerName = customerMap['name']?.toString() ?? '';
        final customerId = customerMap['id']?.toString() ?? '';

        // Calculate totals
        double subtotal = 0.0;
        final items = record['items'];
        final itemsStrList = <String>[];
        if (items is List) {
          for (final item in items) {
            if (item is Map) {
              final qty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1.0;
              final rate = double.tryParse(item['rate']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
              subtotal += qty * rate;
              final desc = item['description']?.toString() ?? '';
              final quantityText = qty.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
              // Persist the calculated line amount in the readable Sheets
              // summary. It remains derived from quantity and rate in the
              // app, so the stored total cannot become inconsistent.
              final amount = qty * rate;
              itemsStrList.add(
                '${quantityText}x $desc @ ${rate.toStringAsFixed(2)} = ${amount.toStringAsFixed(2)}',
              );
            }
          }
        }
        final discount = double.tryParse(record['discount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
        final discountedSubtotal = (subtotal - discount).clamp(0.0, double.infinity);
        final taxRate = double.tryParse(record['taxRate']?.toString().replaceAll('%', '') ?? '0') ?? 0.0;
        final taxAmount = (discountedSubtotal * taxRate) / 100.0;
        final totalAmount = discountedSubtotal + taxAmount;

        double paidAmount = 0.0;
        final payments = record['payments'];
        final paymentsStrList = <String>[];
        if (payments is List) {
          for (final p in payments) {
            if (p is Map) {
              final cents = (p['cents'] as num?)?.toDouble() ?? 0.0;
              final aed = cents / 100.0;
              paidAmount += aed;
              final paymentId = p['id']?.toString() ?? '';
              final dt = p['date']?.toString() ?? '';
              final acc = p['account']?.toString() ?? 'Bank';
              final reference = p['reference']?.toString() ?? '';
              // Dedicated fields within a readable cell retain the payment's
              // stable ID, amount, date, account, and reference on reload.
              paymentsStrList.add('$paymentId | ${aed.toStringAsFixed(2)} | $dt | $acc | $reference');
            }
          }
        }
        final balanceDue = (totalAmount - paidAmount).clamp(0.0, double.infinity);

        return [
          record['id']?.toString() ?? '',
          record['number']?.toString() ?? '',
          record['date']?.toString() ?? '',
          record['dueDate']?.toString() ?? '',
          customerName,
          customerId,
          (record['status']?.toString() ?? 'draft').toUpperCase(),
          taxRate.toStringAsFixed(2),
          discount.toStringAsFixed(2),
          subtotal.toStringAsFixed(2),
          taxAmount.toStringAsFixed(2),
          totalAmount.toStringAsFixed(2),
          paidAmount.toStringAsFixed(2),
          balanceDue.toStringAsFixed(2),
          itemsStrList.join(' | '),
          paymentsStrList.join(' || '),
          record['notes']?.toString() ?? '',
          record['terms']?.toString() ?? '',
          record['driveUrl']?.toString() ?? '',
          record['issuedAt']?.toString() ?? '',
          record['version'] ?? 0,
        ];

      case 'Quotations':
        final customerMap = record['customer'] is Map ? record['customer'] as Map : {};
        final customerName = customerMap['name']?.toString() ?? '';
        final customerId = customerMap['id']?.toString() ?? '';

        double subtotal = 0.0;
        final items = record['items'];
        final itemsStrList = <String>[];
        if (items is List) {
          for (final item in items) {
            if (item is Map) {
              final qty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1.0;
              final rate = double.tryParse(item['rate']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
              subtotal += qty * rate;
              final desc = item['description']?.toString() ?? '';
              final quantityText = qty.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
              itemsStrList.add('${quantityText}x $desc @ ${rate.toStringAsFixed(2)}');
            }
          }
        }
        final discount = double.tryParse(record['discount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
        final discountedSubtotal = (subtotal - discount).clamp(0.0, double.infinity);
        final taxRate = double.tryParse(record['taxRate']?.toString().replaceAll('%', '') ?? '0') ?? 0.0;
        final taxAmount = (discountedSubtotal * taxRate) / 100.0;
        final totalAmount = discountedSubtotal + taxAmount;

        return [
          record['id']?.toString() ?? '',
          record['number']?.toString() ?? '',
          record['date']?.toString() ?? '',
          record['validUntil']?.toString() ?? '',
          customerName,
          customerId,
          (record['status']?.toString() ?? 'draft').toUpperCase(),
          taxRate.toStringAsFixed(2),
          discount.toStringAsFixed(2),
          subtotal.toStringAsFixed(2),
          taxAmount.toStringAsFixed(2),
          totalAmount.toStringAsFixed(2),
          itemsStrList.join(' | '),
          record['notes']?.toString() ?? '',
          record['terms']?.toString() ?? '',
          record['convertedInvoiceId']?.toString() ?? '',
          record['driveUrl']?.toString() ?? '',
          record['issuedAt']?.toString() ?? '',
          record['version'] ?? 0,
        ];

      case 'Finance':
        final amountCents = (record['amountCents'] as num?)?.toDouble() ?? 0.0;
        final amountAed = amountCents != 0 ? amountCents / 100.0 : (double.tryParse(record['amount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0);
        final vatPercent = (record['vatPercent'] as num?)?.toDouble() ?? (double.tryParse(record['vatPercent']?.toString() ?? '0') ?? 0.0);
        final vatCents = (record['vatCents'] as num?)?.toDouble() ?? 0.0;
        final vatAed = vatCents != 0 ? vatCents / 100.0 : ((amountAed * vatPercent) / 100.0);
        final totalAed = amountAed + vatAed;

        return [
          record['id']?.toString() ?? '',
          record['date']?.toString() ?? '',
          (record['kind']?.toString() ?? 'expense').toUpperCase(),
          record['category']?.toString() ?? '',
          record['description']?.toString() ?? '',
          amountAed.toStringAsFixed(2),
          vatPercent.toStringAsFixed(1),
          vatAed.toStringAsFixed(2),
          totalAed.toStringAsFixed(2),
          (record['status']?.toString() ?? 'paid').toUpperCase(),
          record['paidDate']?.toString() ?? '',
          record['dueDate']?.toString() ?? '',
          record['account']?.toString() ?? 'Bank',
          record['supplier']?.toString() ?? record['payee']?.toString() ?? '',
          record['invoiceRef']?.toString() ?? record['reference']?.toString() ?? '',
          record['notes']?.toString() ?? '',
          record['version'] ?? 0,
          attachmentLinks(record),
        ];

      case 'Employees':
        final basic = double.tryParse(record['basic']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
        final allowances = double.tryParse(record['allowances']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
        final totalSalary = basic + allowances;

        return [
          record['id']?.toString() ?? '',
          record['code']?.toString() ?? '',
          record['name']?.toString() ?? '',
          record['title']?.toString() ?? record['role']?.toString() ?? '',
          record['department']?.toString() ?? '',
          record['joinDate']?.toString() ?? '',
          basic.toStringAsFixed(2),
          allowances.toStringAsFixed(2),
          totalSalary.toStringAsFixed(2),
          record['phone']?.toString() ?? '',
          record['email']?.toString() ?? '',
          (record['status']?.toString() ?? 'active').toUpperCase(),
          record['iban']?.toString() ?? '',
          record['notes']?.toString() ?? '',
          record['version'] ?? 0,
          attachmentLinks(record),
          record['address']?.toString() ?? '',
          record['bank']?.toString() ?? '',
          record['emiratesId']?.toString() ?? '',
          record['passport']?.toString() ?? '',
          record['visaExpiry']?.toString() ?? '',
          record['endDate']?.toString() ?? '',
        ];

      case 'Attendance':
        return [
          record['id']?.toString() ?? '',
          record['date']?.toString() ?? '',
          record['employeeId']?.toString() ?? '',
          record['employeeName']?.toString() ?? '',
          (record['status']?.toString() ?? 'present').toUpperCase(),
          record['overtimeHours']?.toString() ?? '0',
          record['notes']?.toString() ?? '',
          record['version'] ?? 0,
        ];

      case 'Payroll':
        final employeeMap = record['employee'] is Map ? record['employee'] as Map : const <dynamic, dynamic>{};
        final basicCents = (record['basicCents'] as num?)?.toDouble() ?? 0.0;
        final basicAed = basicCents != 0 ? basicCents / 100.0 : (double.tryParse(record['basic']?.toString() ?? '0') ?? 0.0);
        final allowancesCents = (record['allowancesCents'] as num?)?.toDouble() ?? 0.0;
        final allowancesAed = allowancesCents != 0 ? allowancesCents / 100.0 : (double.tryParse(record['allowances']?.toString() ?? '0') ?? 0.0);
        final overtimeCents = (record['overtimeCents'] as num?)?.toDouble() ?? 0.0;
        final overtimeAed = overtimeCents / 100.0;
        final bonusCents = (record['bonusCents'] as num?)?.toDouble() ?? 0.0;
        final bonusAed = bonusCents / 100.0;
        final deductionsCents = (record['deductionsCents'] as num?)?.toDouble() ?? 0.0;
        final deductionsAed = deductionsCents / 100.0;
        final grossCents = (record['grossCents'] as num?)?.toDouble() ?? 0.0;
        final grossAed = grossCents != 0 ? grossCents / 100.0 : (basicAed + allowancesAed + overtimeAed + bonusAed);
        final netCents = (record['netCents'] as num?)?.toDouble() ?? 0.0;
        final netAed = netCents != 0 ? netCents / 100.0 : (grossAed - deductionsAed);

        return [
          record['id']?.toString() ?? '',
          record['month']?.toString() ?? '',
          record['employeeId']?.toString() ?? '',
          record['employeeName']?.toString() ?? employeeMap['name']?.toString() ?? '',
          basicAed.toStringAsFixed(2),
          allowancesAed.toStringAsFixed(2),
          overtimeAed.toStringAsFixed(2),
          bonusAed.toStringAsFixed(2),
          deductionsAed.toStringAsFixed(2),
          grossAed.toStringAsFixed(2),
          netAed.toStringAsFixed(2),
          (record['status']?.toString() ?? 'draft').toUpperCase(),
          record['paidDate']?.toString() ?? '',
          record['account']?.toString() ?? 'Bank',
          record['version'] ?? 0,
          record['driveUrl']?.toString() ?? '',
          // Kept at the end so existing Payroll columns retain their stable
          // positions in already-provisioned workspaces.
          (((record['absenceCents'] as num?)?.toDouble() ?? 0.0) / 100.0).toStringAsFixed(2),
          record['divisor']?.toString() ?? '',
          record['baseDays']?.toString() ?? '',
          record['scheduledDays']?.toString() ?? '',
          record['markedDays']?.toString() ?? '',
          record['absentDays']?.toString() ?? '',
          record['overtimeRate']?.toString() ?? '',
          record['adjustmentNote']?.toString() ?? '',
          record['reference']?.toString() ?? '',
        ];

      case 'Shareholders':
        final invested = double.tryParse(
              (record['agreedCapital'] ?? record['investedAmount'] ?? record['amount'])?.toString().replaceAll(',', '') ?? '0',
            ) ??
            0.0;
        final shares = double.tryParse(
              (record['ownershipPercentage'] ?? record['sharesPercent'] ?? record['equityPercent'])?.toString().replaceAll('%', '') ?? '0',
            ) ??
            0.0;

        return [
          record['id']?.toString() ?? '',
          record['name']?.toString() ?? '',
          record['role']?.toString() ?? 'Partner & Shareholder',
          shares.toStringAsFixed(2),
          invested.toStringAsFixed(2),
          record['date']?.toString() ?? '',
          record['email']?.toString() ?? '',
          record['phone']?.toString() ?? '',
          (record['status']?.toString() ?? 'active').toUpperCase(),
          record['notes']?.toString() ?? '',
          record['version'] ?? 0,
        ];

      case 'CapitalTransactions':
        final amtCents = (record['amountCents'] as num?)?.toDouble() ?? 0.0;
        final amount = amtCents != 0
            ? amtCents / 100.0
            : (double.tryParse(record['amount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0);
        final tType = (record['transactionType'] ?? record['type'] ?? 'capitalContribution').toString();
        final cType = (record['contributionType'] ?? record['method'] ?? 'bank').toString();
        final account = (record['bankAccountId'] ?? record['account'] ?? (cType == 'cash' ? 'Cash' : 'Bank')).toString();

        return [
          record['id']?.toString() ?? '',
          record['date']?.toString() ?? '',
          record['shareholderId']?.toString() ?? '',
          record['shareholderName']?.toString() ?? '',
          tType.toUpperCase(),
          cType.toUpperCase(),
          amount.toStringAsFixed(2),
          record['assetName']?.toString() ?? '',
          account,
          (record['status']?.toString() ?? 'posted').toUpperCase(),
          record['reference']?.toString() ?? '',
          record['notes']?.toString() ?? '',
          record['version'] ?? 0,
        ];

      case 'ShareholderLoans':
        final amtCents = (record['amountCents'] as num?)?.toDouble() ?? 0.0;
        final rawAmt = amtCents != 0
            ? amtCents / 100.0
            : (double.tryParse(record['amount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0);
        final principal = rawAmt != 0
            ? rawAmt
            : (double.tryParse(record['principalAmount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0);
        final repaid = double.tryParse(record['repaidAmount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
        final balance = (principal - repaid).clamp(0.0, double.infinity);
        final rate = double.tryParse(record['interestRate']?.toString() ?? '0') ?? 0.0;
        final type = (record['type'] ?? 'loanReceived').toString();
        final acc = (record['paymentAccount'] ?? record['account'] ?? 'Bank').toString();

        return [
          record['id']?.toString() ?? '',
          record['date']?.toString() ?? '',
          record['shareholderId']?.toString() ?? '',
          record['shareholderName']?.toString() ?? '',
          type.toUpperCase(),
          principal.toStringAsFixed(2),
          rate.toStringAsFixed(2),
          repaid.toStringAsFixed(2),
          balance.toStringAsFixed(2),
          record['dueDate']?.toString() ?? '',
          acc,
          (record['status']?.toString() ?? 'posted').toUpperCase(),
          record['reference']?.toString() ?? '',
          record['notes']?.toString() ?? '',
          record['version'] ?? 0,
        ];

      case 'Assets':
        final costCents = (record['costCents'] as num?)?.toDouble() ?? 0.0;
        final costAed = costCents != 0 ? costCents / 100.0 : (double.tryParse(record['cost']?.toString().replaceAll(',', '') ?? '0') ?? 0.0);
        final residualCents = ((record['residualValueCents'] ?? record['salvageValueCents']) as num?)?.toDouble() ?? 0.0;
        final residualAed = residualCents != 0
            ? residualCents / 100.0
            : (double.tryParse((record['residualValue'] ?? record['salvageValue'])?.toString().replaceAll(',', '') ?? '0') ?? 0.0);
        final accDepCents = (record['accumulatedDepreciationCents'] as num?)?.toDouble() ?? 0.0;
        final accDepAed = accDepCents / 100.0;
        final bookValCents = ((record['bookValueCents'] ?? record['currentBookValueCents']) as num?)?.toDouble() ?? 0.0;
        final bookValAed = bookValCents != 0 ? bookValCents / 100.0 : (costAed - accDepAed);

        return [
          record['id']?.toString() ?? '',
          record['name']?.toString() ?? '',
          record['category']?.toString() ?? 'Office Equipment',
          record['purchaseDate']?.toString() ?? '',
          costAed.toStringAsFixed(2),
          (double.tryParse(record['usefulLifeYears']?.toString() ?? '') ??
                  (((record['usefulLifeMonths'] as num?)?.toDouble() ?? 36.0) / 12.0))
              .toStringAsFixed(2),
          residualAed.toStringAsFixed(2),
          record['depreciationMethod']?.toString() ?? 'Straight Line',
          accDepAed.toStringAsFixed(2),
          bookValAed.toStringAsFixed(2),
          record['status']?.toString() ?? 'Active',
          record['notes']?.toString() ?? '',
          record['version'] ?? 0,
          record['lastDepreciationMonth']?.toString() ?? '',
          record['code']?.toString() ?? '',
          record['acquisitionType']?.toString() ?? 'companyPurchase',
          record['paymentAccount']?.toString() ?? 'Bank',
          record['shareholderId']?.toString() ?? '',
          record['shareholderName']?.toString() ?? '',
          record['location']?.toString() ?? '',
          record['assignedEmployeeId']?.toString() ?? '',
          record['assignedEmployeeName']?.toString() ?? '',
          record['serialNumber']?.toString() ?? '',
          record['journalId']?.toString() ?? '',
        ];

      case 'Journals':
        final lines = (record['lines'] as List? ?? const []).whereType<Map>();
        final totalDebitCents = (record['totalDebitCents'] as num?)?.toInt() ??
            lines.fold<int>(0, (sum, line) => sum + ((line['debitCents'] as num?)?.toInt() ?? 0));
        final totalCreditCents = (record['totalCreditCents'] as num?)?.toInt() ??
            lines.fold<int>(0, (sum, line) => sum + ((line['creditCents'] as num?)?.toInt() ?? 0));
        final lineText = lines.map((line) {
          final debit = ((line['debitCents'] as num?)?.toDouble() ?? 0) / 100.0;
          final credit = ((line['creditCents'] as num?)?.toDouble() ?? 0) / 100.0;
          return '${line['accountId'] ?? ''} | ${line['accountName'] ?? ''} | ${line['accountGroup'] ?? ''} | ${debit.toStringAsFixed(2)} | ${credit.toStringAsFixed(2)}';
        }).join('\n');

        return [
          record['id']?.toString() ?? '',
          record['date']?.toString() ?? '',
          record['journalNumber']?.toString() ?? record['entryNumber']?.toString() ?? record['ref']?.toString() ?? '',
          record['description']?.toString() ?? '',
          (record['sourceType']?.toString() ?? record['type']?.toString() ?? 'general').toUpperCase(),
          '',
          '',
          (totalDebitCents / 100.0).toStringAsFixed(2),
          record['notes']?.toString() ?? '',
          record['version'] ?? 0,
          record['sourceType']?.toString() ?? record['type']?.toString() ?? 'general',
          record['sourceId']?.toString() ?? '',
          (totalDebitCents / 100.0).toStringAsFixed(2),
          (totalCreditCents / 100.0).toStringAsFixed(2),
          (record['isBalanced'] == true || totalDebitCents == totalCreditCents).toString(),
          record['status']?.toString() ?? 'posted',
          lineText,
        ];

      case 'Settings':
        final val = record['value'] ?? record;
        final map = val is Map ? Map<String, dynamic>.from(val) : <String, dynamic>{};
        final key = record['id']?.toString() ?? 'company';
        final name = map['name']?.toString() ?? (key == 'company' ? 'The Percentage FZ LLC' : key);
        final email = map['email']?.toString() ?? '';
        final phone = map['phone']?.toString() ?? '';
        final trn = map['trn']?.toString() ?? '';
        final prefix = map['prefix']?.toString() ?? 'TPC';
        final address = map['address']?.toString() ?? '';
        final bank = map['bank']?.toString() ?? '';
        final accountHolder = map['accountHolder']?.toString() ?? '';
        final accountNumber = map['accountNumber']?.toString() ?? '';
        final iban = map['iban']?.toString() ?? '';
        final terms = map['terms']?.toString() ?? '';
        final notes = map['notes']?.toString() ?? '';
        final version = map['version'] ?? record['version'] ?? 0;

        return [
          key,
          name,
          email,
          phone,
          trn,
          prefix,
          address,
          bank,
          accountHolder,
          accountNumber,
          iban,
          terms,
          notes,
          version,
          map['logoDriveUrl']?.toString() ?? '',
        ];

      default:
        return [
          record['id']?.toString() ?? '',
          record['data']?.toString() ?? '',
        ];
    }
  }

  /// Converts a row of cell values from Google Sheets back into a domain Map.
  /// Seamlessly reconstructs structured entities directly from dedicated columns.
  static Map<String, dynamic> rowToRecord(String tabName, List<dynamic> row) {
    if (row.isEmpty) return {};

    // Check if any legacy cell contains JSON for backwards compatibility
    for (int i = row.length - 1; i >= 1; i--) {
      final cellStr = row[i]?.toString().trim() ?? '';
      if (cellStr.startsWith('{') && cellStr.endsWith('}')) {
        try {
          final parsed = jsonDecode(cellStr);
          if (parsed is Map) {
            return Map<String, dynamic>.from(parsed);
          }
        } catch (_) {}
      }
    }

    // Direct reconstruction from dedicated column cells
    final id = row.isNotEmpty ? row[0]?.toString().trim() ?? '' : '';
    final record = <String, dynamic>{'id': id};

    switch (tabName) {
      case 'Customers':
        if (row.length > 1) record['name'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['email'] = row[2]?.toString() ?? '';
        if (row.length > 3) record['phone'] = row[3]?.toString() ?? '';
        if (row.length > 4) record['trn'] = row[4]?.toString() ?? '';
        if (row.length > 5) record['address'] = row[5]?.toString() ?? '';
        if (row.length > 6) record['version'] = int.tryParse(row[6]?.toString() ?? '0') ?? 0;
        break;

      case 'Invoices':
        if (row.length > 1) record['number'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['date'] = row[2]?.toString() ?? '';
        if (row.length > 3) record['dueDate'] = row[3]?.toString() ?? '';
        final custName = row.length > 4 ? row[4]?.toString() ?? '' : '';
        final custId = row.length > 5 ? row[5]?.toString() ?? '' : '';
        record['customer'] = {'id': custId, 'name': custName, 'email': '', 'phone': '', 'address': '', 'trn': ''};
        record['company'] = defaultCompanyMap();
        if (row.length > 6) record['status'] = row[6]?.toString().toLowerCase() ?? 'draft';
        if (row.length > 7) record['taxRate'] = row[7]?.toString() ?? '0';
        if (row.length > 8) record['discount'] = row[8]?.toString() ?? '0.00';

        // New rows include the line amount (e.g. "1x Item Name @ 500.00 =
        // 500.00"). The amount part is optional for existing Sheets rows.
        final itemsList = <Map<String, dynamic>>[];
        if (row.length > 14 && row[14]?.toString().isNotEmpty == true) {
          final itemsRaw = row[14].toString().split(' | ');
          for (final raw in itemsRaw) {
            final match = RegExp(
              r'^(\d+(?:\.\d+)?)\s*x\s*(.*?)\s*@\s*(\d+(?:\.\d+)?)(?:\s*=\s*\d+(?:\.\d+)?)?$',
              dotAll: true,
            ).firstMatch(raw.trim());
            if (match != null) {
              itemsList.add({
                'quantity': match.group(1) ?? '1',
                'description': match.group(2) ?? '',
                'rate': match.group(3) ?? '0.00',
              });
            } else if (raw.trim().isNotEmpty) {
              itemsList.add({
                'quantity': '1',
                'description': raw.trim(),
                'rate': '0.00',
              });
            }
          }
        }
        record['items'] = itemsList;

        final paymentsList = <Map<String, dynamic>>[];
        if (row.length > 15 && row[15]?.toString().isNotEmpty == true) {
          for (final raw in row[15].toString().split(' || ')) {
            final fields = raw.split(' | ').map((value) => value.trim()).toList();
            // Current structured readable format: ID | AED amount | date | account | reference.
            if (fields.length >= 4) {
              final aed = double.tryParse(fields[1].replaceAll('AED', '').trim());
              if (aed != null && aed > 0) {
                paymentsList.add({
                  'id': fields[0].isEmpty ? 'payment_${id}_${paymentsList.length}' : fields[0],
                  'cents': (aed * 100).round(),
                  'date': fields[2],
                  'account': fields[3].isEmpty ? 'Bank' : fields[3],
                  'reference': fields.length > 4 ? fields.sublist(4).join(' | ') : '',
                });
              }
              continue;
            }
            // Legacy format: "125.00 AED on 2026-09-13 via Bank".
            final legacy = RegExp(r'^(\d+(?:\.\d+)?)\s*AED\s*on\s*(\d{4}-\d{2}-\d{2})\s*via\s*(.+)$').firstMatch(raw.trim());
            if (legacy != null) {
              final aed = double.tryParse(legacy.group(1) ?? '');
              if (aed != null && aed > 0) {
                paymentsList.add({
                  'id': 'payment_${id}_${paymentsList.length}',
                  'cents': (aed * 100).round(),
                  'date': legacy.group(2) ?? '',
                  'account': legacy.group(3) ?? 'Bank',
                  'reference': '',
                });
              }
            }
          }
        }
        record['payments'] = paymentsList;

        if (row.length > 16) record['notes'] = row[16]?.toString() ?? '';
        if (row.length > 17) record['terms'] = row[17]?.toString() ?? '';
        if (row.length > 18) record['driveUrl'] = row[18]?.toString() ?? '';
        if (row.length > 19) record['issuedAt'] = row[19]?.toString() ?? '';
        if (row.length > 20) record['version'] = int.tryParse(row[20]?.toString() ?? '0') ?? 0;
        break;

      case 'Quotations':
        if (row.length > 1) record['number'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['date'] = row[2]?.toString() ?? '';
        if (row.length > 3) record['validUntil'] = row[3]?.toString() ?? '';
        final qCustName = row.length > 4 ? row[4]?.toString() ?? '' : '';
        final qCustId = row.length > 5 ? row[5]?.toString() ?? '' : '';
        record['customer'] = {'id': qCustId, 'name': qCustName, 'email': '', 'phone': '', 'address': '', 'trn': ''};
        record['company'] = defaultCompanyMap();
        if (row.length > 6) record['status'] = row[6]?.toString().toLowerCase() ?? 'draft';
        if (row.length > 7) record['taxRate'] = row[7]?.toString() ?? '0';
        if (row.length > 8) record['discount'] = row[8]?.toString() ?? '0.00';

        final qItemsList = <Map<String, dynamic>>[];
        if (row.length > 12 && row[12]?.toString().isNotEmpty == true) {
          final itemsRaw = row[12].toString().split(' | ');
          for (final raw in itemsRaw) {
            final match = RegExp(r'^(\d+(?:\.\d+)?)\s*x\s*(.*?)\s*@\s*(\d+(?:\.\d+)?)$', dotAll: true).firstMatch(raw.trim());
            if (match != null) {
              qItemsList.add({
                'quantity': match.group(1) ?? '1',
                'description': match.group(2) ?? '',
                'rate': match.group(3) ?? '0.00',
              });
            } else if (raw.trim().isNotEmpty) {
              qItemsList.add({
                'quantity': '1',
                'description': raw.trim(),
                'rate': '0.00',
              });
            }
          }
        }
        record['items'] = qItemsList;

        if (row.length > 13) record['notes'] = row[13]?.toString() ?? '';
        if (row.length > 14) record['terms'] = row[14]?.toString() ?? '';
        if (row.length > 15) record['convertedInvoiceId'] = row[15]?.toString() ?? '';
        if (row.length > 16) record['driveUrl'] = row[16]?.toString() ?? '';
        if (row.length > 17) record['issuedAt'] = row[17]?.toString() ?? '';
        if (row.length > 18) record['version'] = int.tryParse(row[18]?.toString() ?? '0') ?? 0;
        break;

      case 'Finance':
        if (row.length > 1) record['date'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['kind'] = row[2]?.toString().toLowerCase() ?? 'expense';
        if (row.length > 3) record['category'] = row[3]?.toString() ?? '';
        if (row.length > 4) record['description'] = row[4]?.toString() ?? '';
        if (row.length > 5) {
          final amt = double.tryParse(row[5]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['amountCents'] = (amt * 100).round();
          record['amount'] = amt.toStringAsFixed(2);
        }
        if (row.length > 6) record['vatPercent'] = double.tryParse(row[6]?.toString() ?? '0') ?? 0.0;
        if (row.length > 7) {
          final vatAmt = double.tryParse(row[7]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['vatCents'] = (vatAmt * 100).round();
        }
        if (row.length > 9) record['status'] = row[9]?.toString().toLowerCase() ?? 'paid';
        if (row.length > 10) record['paidDate'] = row[10]?.toString() ?? '';
        if (row.length > 11) record['dueDate'] = row[11]?.toString() ?? '';
        if (row.length > 12) record['account'] = row[12]?.toString() ?? 'Bank';
        if (row.length > 13) {
          record['supplier'] = row[13]?.toString() ?? '';
          record['payee'] = row[13]?.toString() ?? '';
        }
        if (row.length > 14) {
          record['invoiceRef'] = row[14]?.toString() ?? '';
          record['reference'] = row[14]?.toString() ?? '';
        }
        if (row.length > 15) record['notes'] = row[15]?.toString() ?? '';
        if (row.length > 16) record['version'] = int.tryParse(row[16]?.toString() ?? '0') ?? 0;
        if (row.length > 17) record['documents'] = attachmentsFromCell(row[17]);
        break;

      case 'Employees':
        if (row.length > 1) record['code'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['name'] = row[2]?.toString() ?? '';
        if (row.length > 3) {
          record['title'] = row[3]?.toString() ?? '';
          record['role'] = record['title']; // compatibility with earlier rows
        }
        if (row.length > 4) record['department'] = row[4]?.toString() ?? '';
        if (row.length > 5) record['joinDate'] = row[5]?.toString() ?? '';
        if (row.length > 6) record['basic'] = row[6]?.toString() ?? '0.00';
        if (row.length > 7) record['allowances'] = row[7]?.toString() ?? '0.00';
        if (row.length > 9) record['phone'] = row[9]?.toString() ?? '';
        if (row.length > 10) record['email'] = row[10]?.toString() ?? '';
        if (row.length > 11) record['status'] = row[11]?.toString().toLowerCase() ?? 'active';
        if (row.length > 12) record['iban'] = row[12]?.toString() ?? '';
        if (row.length > 13) record['notes'] = row[13]?.toString() ?? '';
        if (row.length > 14) record['version'] = int.tryParse(row[14]?.toString() ?? '0') ?? 0;
        if (row.length > 15) record['documents'] = attachmentsFromCell(row[15]);
        if (row.length > 16) record['address'] = row[16]?.toString() ?? '';
        if (row.length > 17) record['bank'] = row[17]?.toString() ?? '';
        if (row.length > 18) record['emiratesId'] = row[18]?.toString() ?? '';
        if (row.length > 19) record['passport'] = row[19]?.toString() ?? '';
        if (row.length > 20) record['visaExpiry'] = row[20]?.toString() ?? '';
        if (row.length > 21) record['endDate'] = row[21]?.toString() ?? '';
        break;

      case 'Attendance':
        if (row.length > 1) record['date'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['employeeId'] = row[2]?.toString() ?? '';
        if (row.length > 3) record['employeeName'] = row[3]?.toString() ?? '';
        if (row.length > 4) record['status'] = row[4]?.toString().toLowerCase() ?? 'present';
        if (row.length > 5) record['overtimeHours'] = row[5]?.toString() ?? '0';
        if (row.length > 6) record['notes'] = row[6]?.toString() ?? '';
        if (row.length > 7) record['version'] = int.tryParse(row[7]?.toString() ?? '0') ?? 0;
        break;

      case 'Payroll':
        if (row.length > 1) record['month'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['employeeId'] = row[2]?.toString() ?? '';
        if (row.length > 3) record['employeeName'] = row[3]?.toString() ?? '';
        if (row.length > 4) {
          final b = double.tryParse(row[4]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['basicCents'] = (b * 100).round();
          record['basic'] = b.toStringAsFixed(2);
        }
        if (row.length > 5) {
          final a = double.tryParse(row[5]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['allowancesCents'] = (a * 100).round();
          record['allowances'] = a.toStringAsFixed(2);
        }
        if (row.length > 6) {
          final ot = double.tryParse(row[6]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['overtimeCents'] = (ot * 100).round();
        }
        if (row.length > 7) {
          final bn = double.tryParse(row[7]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['bonusCents'] = (bn * 100).round();
        }
        if (row.length > 8) {
          final d = double.tryParse(row[8]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['deductionsCents'] = (d * 100).round();
        }
        if (row.length > 9) {
          final g = double.tryParse(row[9]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['grossCents'] = (g * 100).round();
        }
        if (row.length > 10) {
          final n = double.tryParse(row[10]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['netCents'] = (n * 100).round();
        }
        if (row.length > 11) record['status'] = row[11]?.toString().toLowerCase() ?? 'draft';
        if (row.length > 12) record['paidDate'] = row[12]?.toString() ?? '';
        if (row.length > 13) record['account'] = row[13]?.toString() ?? 'Bank';
        if (row.length > 14) record['version'] = int.tryParse(row[14]?.toString() ?? '0') ?? 0;
        if (row.length > 15) record['driveUrl'] = row[15]?.toString() ?? '';
        if (row.length > 16) {
          final absence = double.tryParse(row[16]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['absenceCents'] = (absence * 100).round();
        }
        if (row.length > 17) record['divisor'] = row[17]?.toString() ?? '';
        if (row.length > 18) record['baseDays'] = row[18]?.toString() ?? '';
        if (row.length > 19) record['scheduledDays'] = row[19]?.toString() ?? '';
        if (row.length > 20) record['markedDays'] = int.tryParse(row[20]?.toString() ?? '') ?? 0;
        if (row.length > 21) record['absentDays'] = double.tryParse(row[21]?.toString() ?? '') ?? 0.0;
        if (row.length > 22) record['overtimeRate'] = row[22]?.toString() ?? '';
        if (row.length > 23) record['adjustmentNote'] = row[23]?.toString() ?? '';
        if (row.length > 24) record['reference'] = row[24]?.toString() ?? '';
        // Legacy rows only have one Deductions column. Treat it as the
        // complete deduction when an absence breakdown is unavailable.
        final totalDeductions = (record['deductionsCents'] as num?)?.toInt() ?? 0;
        final absenceDeduction = (record['absenceCents'] as num?)?.toInt() ?? 0;
        record['deductionCents'] = (totalDeductions - absenceDeduction).clamp(0, totalDeductions);
        if (record['grossCents'] == null) {
          record['grossCents'] =
              ((record['basicCents'] as num?)?.toInt() ?? 0) +
              ((record['allowancesCents'] as num?)?.toInt() ?? 0) +
              ((record['overtimeCents'] as num?)?.toInt() ?? 0) +
              ((record['bonusCents'] as num?)?.toInt() ?? 0);
        }
        record['employee'] = {'id': record['employeeId'], 'name': record['employeeName']};
        break;

      case 'Shareholders':
        if (row.length > 1) record['name'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['role'] = row[2]?.toString() ?? 'Partner & Shareholder';
        if (row.length > 3) {
          final pct = double.tryParse(row[3]?.toString().replaceAll('%', '') ?? '0') ?? 0.0;
          record['ownershipPercentage'] = pct;
          record['sharesPercent'] = pct.toStringAsFixed(2);
        }
        if (row.length > 4) {
          final cap = double.tryParse(row[4]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['agreedCapital'] = cap;
          record['investedAmount'] = cap.toStringAsFixed(2);
        }
        if (row.length > 5) record['date'] = row[5]?.toString() ?? '';
        if (row.length > 6) record['email'] = row[6]?.toString() ?? '';
        if (row.length > 7) record['phone'] = row[7]?.toString() ?? '';
        if (row.length > 8) record['status'] = row[8]?.toString().toLowerCase() ?? 'active';
        if (row.length > 9) record['notes'] = row[9]?.toString() ?? '';
        if (row.length > 10) record['version'] = int.tryParse(row[10]?.toString() ?? '0') ?? 0;
        break;

      case 'CapitalTransactions':
        if (row.length > 1) record['date'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['shareholderId'] = row[2]?.toString() ?? '';
        if (row.length > 3) record['shareholderName'] = row[3]?.toString() ?? '';
        if (row.length > 4) {
          final t = row[4]?.toString().toLowerCase() ?? 'capitalcontribution';
          record['transactionType'] = t == 'capital_withdrawal' || t == 'capitalwithdrawal'
              ? 'capitalWithdrawal'
              : (t == 'additional_capital' || t == 'additionalcapital'
                  ? 'additionalCapital'
                  : 'capitalContribution');
          record['type'] = record['transactionType'];
        }
        if (row.length > 5) {
          record['contributionType'] = row[5]?.toString().toLowerCase() ?? 'bank';
        }
        if (row.length > 6) {
          final amt = double.tryParse(row[6]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['amount'] = amt.toStringAsFixed(2);
          record['amountCents'] = (amt * 100).round();
        }
        if (row.length > 7) record['assetName'] = row[7]?.toString() ?? '';
        if (row.length > 8) {
          record['bankAccountId'] = row[8]?.toString() ?? 'Bank';
          record['account'] = record['bankAccountId'];
        }
        if (row.length > 9) record['status'] = row[9]?.toString().toLowerCase() ?? 'posted';
        if (row.length > 10) record['reference'] = row[10]?.toString() ?? '';
        if (row.length > 11) record['notes'] = row[11]?.toString() ?? '';
        if (row.length > 12) record['version'] = int.tryParse(row[12]?.toString() ?? '0') ?? 0;
        break;

      case 'ShareholderLoans':
        if (row.length > 1) record['date'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['shareholderId'] = row[2]?.toString() ?? '';
        if (row.length > 3) record['shareholderName'] = row[3]?.toString() ?? '';
        if (row.length > 4) {
          final t = row[4]?.toString().toLowerCase() ?? 'loanreceived';
          record['type'] = t == 'loan_repayment' || t == 'loanrepayment'
              ? 'loanRepayment'
              : 'loanReceived';
        }
        if (row.length > 5) {
          final p = double.tryParse(row[5]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['principalAmount'] = p.toStringAsFixed(2);
          record['amount'] = p.toStringAsFixed(2);
          record['amountCents'] = (p * 100).round();
        }
        if (row.length > 6) record['interestRate'] = row[6]?.toString() ?? '0';
        if (row.length > 7) record['repaidAmount'] = row[7]?.toString() ?? '0.00';
        if (row.length > 9) record['dueDate'] = row[9]?.toString() ?? '';
        if (row.length > 10) {
          record['paymentAccount'] = row[10]?.toString() ?? 'Bank';
          record['account'] = record['paymentAccount'];
        }
        if (row.length > 11) record['status'] = row[11]?.toString().toLowerCase() ?? 'posted';
        if (row.length > 12) record['reference'] = row[12]?.toString() ?? '';
        if (row.length > 13) record['notes'] = row[13]?.toString() ?? '';
        if (row.length > 14) record['version'] = int.tryParse(row[14]?.toString() ?? '0') ?? 0;
        break;

      case 'Assets':
        if (row.length > 1) record['name'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['category'] = row[2]?.toString() ?? 'Office Equipment';
        if (row.length > 3) record['purchaseDate'] = row[3]?.toString() ?? '';
        if (row.length > 4) {
          final c = double.tryParse(row[4]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['costCents'] = (c * 100).round();
          record['cost'] = c.toStringAsFixed(2);
        }
        if (row.length > 5) {
          record['usefulLifeYears'] = row[5]?.toString() ?? '3';
          final years = double.tryParse(record['usefulLifeYears'] ?? '3') ?? 3.0;
          record['usefulLifeMonths'] = (years * 12).round();
        }
        if (row.length > 6) {
          final s = double.tryParse(row[6]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['residualValueCents'] = (s * 100).round();
          record['residualValue'] = s.toStringAsFixed(2);
          // Keep legacy aliases for any existing presentation code.
          record['salvageValueCents'] = record['residualValueCents'];
          record['salvageValue'] = record['residualValue'];
        }
        if (row.length > 7) record['depreciationMethod'] = row[7]?.toString() ?? 'Straight Line';
        if (row.length > 8) {
          final ad = double.tryParse(row[8]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['accumulatedDepreciationCents'] = (ad * 100).round();
          record['accumulatedDepreciation'] = ad.toStringAsFixed(2);
        }
        if (row.length > 9) {
          final bv = double.tryParse(row[9]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['currentBookValueCents'] = (bv * 100).round();
          record['bookValueCents'] = record['currentBookValueCents'];
          record['bookValue'] = bv.toStringAsFixed(2);
        }
        if (row.length > 10) record['status'] = row[10]?.toString() ?? 'Active';
        if (row.length > 11) record['notes'] = row[11]?.toString() ?? '';
        if (row.length > 12) record['version'] = int.tryParse(row[12]?.toString() ?? '0') ?? 0;
        if (row.length > 13) record['lastDepreciationMonth'] = row[13]?.toString() ?? '';
        // These appended columns preserve the complete fixed-asset register
        // on Sheets without shifting legacy rows.
        record['code'] = row.length > 14 && row[14]?.toString().trim().isNotEmpty == true
            ? row[14].toString().trim()
            : id;
        if (row.length > 15) record['acquisitionType'] = row[15]?.toString() ?? 'companyPurchase';
        if (row.length > 16) record['paymentAccount'] = row[16]?.toString() ?? 'Bank';
        if (row.length > 17) record['shareholderId'] = row[17]?.toString() ?? '';
        if (row.length > 18) record['shareholderName'] = row[18]?.toString() ?? '';
        if (row.length > 19) record['location'] = row[19]?.toString() ?? '';
        if (row.length > 20) record['assignedEmployeeId'] = row[20]?.toString() ?? '';
        if (row.length > 21) record['assignedEmployeeName'] = row[21]?.toString() ?? '';
        if (row.length > 22) record['serialNumber'] = row[22]?.toString() ?? '';
        if (row.length > 23) record['journalId'] = row[23]?.toString() ?? '';
        break;

      case 'Journals':
        if (row.length > 1) record['date'] = row[1]?.toString() ?? '';
        if (row.length > 2) {
          record['entryNumber'] = row[2]?.toString() ?? '';
          record['ref'] = row[2]?.toString() ?? '';
        }
        if (row.length > 3) record['description'] = row[3]?.toString() ?? '';
        if (row.length > 4) record['type'] = row[4]?.toString().toLowerCase() ?? 'general';
        if (row.length > 5) record['debitAccount'] = row[5]?.toString() ?? '';
        if (row.length > 6) record['creditAccount'] = row[6]?.toString() ?? '';
        if (row.length > 7) {
          final a = double.tryParse(row[7]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['amountCents'] = (a * 100).round();
          record['amount'] = a.toStringAsFixed(2);
        }
        if (row.length > 8) record['notes'] = row[8]?.toString() ?? '';
        if (row.length > 9) record['version'] = int.tryParse(row[9]?.toString() ?? '0') ?? 0;
        if (row.length > 10) record['sourceType'] = row[10]?.toString() ?? record['type'] ?? 'general';
        if (row.length > 11) record['sourceId'] = row[11]?.toString() ?? '';
        if (row.length > 12) record['totalDebitCents'] = ((double.tryParse(row[12]?.toString().replaceAll(',', '') ?? '0') ?? 0) * 100).round();
        if (row.length > 13) record['totalCreditCents'] = ((double.tryParse(row[13]?.toString().replaceAll(',', '') ?? '0') ?? 0) * 100).round();
        if (row.length > 14) record['isBalanced'] = row[14]?.toString().toLowerCase() == 'true';
        if (row.length > 15) record['status'] = row[15]?.toString().toLowerCase() ?? 'posted';
        final lines = <Map<String, dynamic>>[];
        if (row.length > 16 && row[16]?.toString().trim().isNotEmpty == true) {
          for (final rawLine in row[16].toString().split('\n')) {
            final fields = rawLine.split(' | ').map((field) => field.trim()).toList();
            if (fields.length < 5) continue;
            final debit = double.tryParse(fields[3].replaceAll(',', '')) ?? 0;
            final credit = double.tryParse(fields[4].replaceAll(',', '')) ?? 0;
            lines.add({
              'accountId': fields[0], 'accountName': fields[1], 'accountGroup': fields[2],
              'debitCents': (debit * 100).round(), 'creditCents': (credit * 100).round(),
            });
          }
        }
        record['lines'] = lines;
        record['journalNumber'] = record['entryNumber'] ?? record['ref'] ?? '';
        if (lines.isNotEmpty) {
          record['totalDebitCents'] = lines.fold<int>(0, (sum, line) => sum + (line['debitCents'] as int));
          record['totalCreditCents'] = lines.fold<int>(0, (sum, line) => sum + (line['creditCents'] as int));
          record['isBalanced'] = record['totalDebitCents'] == record['totalCreditCents'];
        }
        break;

      case 'Settings':
        final key = row.isNotEmpty ? row[0]?.toString().trim() ?? 'company' : 'company';
        final valueMap = <String, dynamic>{};
        if (row.length > 1) valueMap['name'] = row[1]?.toString() ?? '';
        if (row.length > 2) valueMap['email'] = row[2]?.toString() ?? '';
        if (row.length > 3) valueMap['phone'] = row[3]?.toString() ?? '';
        if (row.length > 4) valueMap['trn'] = row[4]?.toString() ?? '';
        if (row.length > 5) valueMap['prefix'] = row[5]?.toString() ?? 'TPC';
        if (row.length > 6) valueMap['address'] = row[6]?.toString() ?? '';
        if (row.length > 7) valueMap['bank'] = row[7]?.toString() ?? '';
        if (row.length > 8) valueMap['accountHolder'] = row[8]?.toString() ?? '';
        if (row.length > 9) valueMap['accountNumber'] = row[9]?.toString() ?? '';
        if (row.length > 10) valueMap['iban'] = row[10]?.toString() ?? '';
        if (row.length > 11) valueMap['terms'] = row[11]?.toString() ?? '';
        if (row.length > 12) valueMap['notes'] = row[12]?.toString() ?? '';
        if (row.length > 13) valueMap['version'] = int.tryParse(row[13]?.toString() ?? '0') ?? 0;
        if (row.length > 14) valueMap['logoDriveUrl'] = row[14]?.toString() ?? '';
        return {'id': key, 'value': valueMap};

      default:
        break;
    }

    return record;
  }

  /// Default company information map for invoices & quotations deserialization
  static Map<String, dynamic> defaultCompanyMap() => {
    'name': 'The Percentage FZ LLC',
    'address': 'Dubai U.A.E',
    'phone': '+971 56 331 9030',
    'email': 'thepercentagecompany1@gmail.com',
    'trn': '',
    'prefix': 'TPC',
    'bank': 'Mashreq Bank',
    'accountHolder': 'The Percentage FZ LLC',
    'accountNumber': '019102062841',
    'iban': '',
    'terms': 'Due on Receipt',
    'notes': 'Thanks for your business.',
    'logo': '',
    'shareholders': <Map<String, dynamic>>[],
    'version': 0,
  };
}
