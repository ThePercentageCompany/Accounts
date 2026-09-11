import 'dart:convert';

/// Universal Google Sheets Schema and Column Field Mapping for TPC Accounts & Billing.
/// Ensures every Google Sheet tab has dedicated, human-readable column headers and fields
/// instead of raw unformatted JSON strings, while maintaining 100% bidirectional sync fidelity.
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

  /// Returns the human-readable column headers for a specific sheet tab.
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
          'JSON Payload',
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
          'Notes',
          'Payment Terms',
          'Drive PDF Link',
          'Issued At',
          'Version',
          'JSON Payload',
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
          'Notes',
          'Payment Terms',
          'Converted Invoice ID',
          'Drive PDF Link',
          'Issued At',
          'Version',
          'JSON Payload',
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
          'JSON Payload',
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
          'JSON Payload',
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
          'JSON Payload',
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
          'JSON Payload',
        ];

      case 'Shareholders':
        return [
          'Shareholder ID',
          'Shareholder Name',
          'Role / Title',
          'Equity Share %',
          'Invested Capital AED',
          'Investment Date',
          'Email Address',
          'Phone Number',
          'Status',
          'Notes',
          'JSON Payload',
        ];

      case 'CapitalTransactions':
        return [
          'Transaction ID',
          'Transaction Date',
          'Shareholder ID',
          'Shareholder Name',
          'Contribution Type',
          'Capital Amount AED',
          'Asset Name / Details',
          'Destination Account',
          'Status',
          'Reference / Doc #',
          'Notes',
          'JSON Payload',
        ];

      case 'ShareholderLoans':
        return [
          'Loan ID',
          'Loan Date',
          'Shareholder ID',
          'Shareholder Name',
          'Loan Type',
          'Principal Amount AED',
          'Interest Rate %',
          'Repaid Amount AED',
          'Outstanding Balance AED',
          'Due Date',
          'Payment Account',
          'Loan Status',
          'Notes',
          'JSON Payload',
        ];

      case 'Assets':
        return [
          'Asset ID',
          'Asset Name',
          'Asset Category',
          'Purchase Date',
          'Purchase Cost AED',
          'Useful Life (Years)',
          'Salvage Value AED',
          'Depreciation Method',
          'Accumulated Depreciation AED',
          'Net Book Value AED',
          'Location / Status',
          'Notes',
          'JSON Payload',
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
          'JSON Payload',
        ];

      case 'Settings':
        return [
          'Setting Key',
          'Setting Title',
          'Summary / Details',
          'Version',
          'JSON Payload',
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
        return ['ID', 'Data', 'JSON Payload'];
    }
  }

  /// Converts a domain data record into a human-readable list of cell values for Google Sheets.
  static List<dynamic> recordToRow(String tabName, Map<String, dynamic> record) {
    final jsonStr = jsonEncode(record);

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
          jsonStr,
        ];

      case 'Invoices':
        final customerMap = record['customer'] is Map ? record['customer'] as Map : {};
        final customerName = customerMap['name']?.toString() ?? '';
        final customerId = customerMap['id']?.toString() ?? '';

        // Calculate totals
        double subtotal = 0.0;
        final items = record['items'];
        if (items is List) {
          for (final item in items) {
            if (item is Map) {
              final qty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1.0;
              final rate = double.tryParse(item['rate']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
              subtotal += qty * rate;
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
        if (payments is List) {
          for (final p in payments) {
            if (p is Map) {
              final cents = (p['cents'] as num?)?.toDouble() ?? 0.0;
              paidAmount += cents / 100.0;
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
          record['notes']?.toString() ?? '',
          record['terms']?.toString() ?? '',
          record['driveUrl']?.toString() ?? '',
          record['issuedAt']?.toString() ?? '',
          record['version'] ?? 0,
          jsonStr,
        ];

      case 'Quotations':
        final customerMap = record['customer'] is Map ? record['customer'] as Map : {};
        final customerName = customerMap['name']?.toString() ?? '';
        final customerId = customerMap['id']?.toString() ?? '';

        double subtotal = 0.0;
        final items = record['items'];
        if (items is List) {
          for (final item in items) {
            if (item is Map) {
              final qty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1.0;
              final rate = double.tryParse(item['rate']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
              subtotal += qty * rate;
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
          record['notes']?.toString() ?? '',
          record['terms']?.toString() ?? '',
          record['convertedInvoiceId']?.toString() ?? '',
          record['driveUrl']?.toString() ?? '',
          record['issuedAt']?.toString() ?? '',
          record['version'] ?? 0,
          jsonStr,
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
          jsonStr,
        ];

      case 'Employees':
        final basic = double.tryParse(record['basic']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
        final allowances = double.tryParse(record['allowances']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
        final totalSalary = basic + allowances;

        return [
          record['id']?.toString() ?? '',
          record['code']?.toString() ?? '',
          record['name']?.toString() ?? '',
          record['role']?.toString() ?? '',
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
          jsonStr,
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
          jsonStr,
        ];

      case 'Payroll':
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
          record['employeeName']?.toString() ?? '',
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
          jsonStr,
        ];

      case 'Shareholders':
        final invested = double.tryParse(record['investedAmount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
        final shares = double.tryParse(record['sharesPercent']?.toString().replaceAll('%', '') ?? '0') ?? 0.0;

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
          jsonStr,
        ];

      case 'CapitalTransactions':
        final amount = double.tryParse(record['amount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;

        return [
          record['id']?.toString() ?? '',
          record['date']?.toString() ?? '',
          record['shareholderId']?.toString() ?? '',
          record['shareholderName']?.toString() ?? '',
          (record['type']?.toString() ?? 'cash').toUpperCase(),
          amount.toStringAsFixed(2),
          record['assetName']?.toString() ?? '',
          record['account']?.toString() ?? 'Bank',
          (record['status']?.toString() ?? 'completed').toUpperCase(),
          record['reference']?.toString() ?? '',
          record['notes']?.toString() ?? '',
          jsonStr,
        ];

      case 'ShareholderLoans':
        final principal = double.tryParse(record['principalAmount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
        final repaid = double.tryParse(record['repaidAmount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
        final balance = (principal - repaid).clamp(0.0, double.infinity);
        final rate = double.tryParse(record['interestRate']?.toString() ?? '0') ?? 0.0;

        return [
          record['id']?.toString() ?? '',
          record['date']?.toString() ?? '',
          record['shareholderId']?.toString() ?? '',
          record['shareholderName']?.toString() ?? '',
          (record['type']?.toString() ?? 'loan_to_company').toUpperCase(),
          principal.toStringAsFixed(2),
          rate.toStringAsFixed(2),
          repaid.toStringAsFixed(2),
          balance.toStringAsFixed(2),
          record['dueDate']?.toString() ?? '',
          record['account']?.toString() ?? 'Bank',
          (record['status']?.toString() ?? 'active').toUpperCase(),
          record['notes']?.toString() ?? '',
          jsonStr,
        ];

      case 'Assets':
        final costCents = (record['costCents'] as num?)?.toDouble() ?? 0.0;
        final costAed = costCents != 0 ? costCents / 100.0 : (double.tryParse(record['cost']?.toString().replaceAll(',', '') ?? '0') ?? 0.0);
        final salvageCents = (record['salvageValueCents'] as num?)?.toDouble() ?? 0.0;
        final salvageAed = salvageCents != 0 ? salvageCents / 100.0 : (double.tryParse(record['salvageValue']?.toString().replaceAll(',', '') ?? '0') ?? 0.0);
        final accDepCents = (record['accumulatedDepreciationCents'] as num?)?.toDouble() ?? 0.0;
        final accDepAed = accDepCents / 100.0;
        final bookValCents = (record['currentBookValueCents'] as num?)?.toDouble() ?? 0.0;
        final bookValAed = bookValCents != 0 ? bookValCents / 100.0 : (costAed - accDepAed);

        return [
          record['id']?.toString() ?? '',
          record['name']?.toString() ?? '',
          record['category']?.toString() ?? 'Office Equipment',
          record['purchaseDate']?.toString() ?? '',
          costAed.toStringAsFixed(2),
          record['usefulLifeYears']?.toString() ?? '3',
          salvageAed.toStringAsFixed(2),
          record['depreciationMethod']?.toString() ?? 'Straight Line',
          accDepAed.toStringAsFixed(2),
          bookValAed.toStringAsFixed(2),
          record['status']?.toString() ?? 'Active',
          record['notes']?.toString() ?? '',
          jsonStr,
        ];

      case 'Journals':
        final amountCents = (record['amountCents'] as num?)?.toDouble() ?? 0.0;
        final amountAed = amountCents != 0 ? amountCents / 100.0 : (double.tryParse(record['amount']?.toString().replaceAll(',', '') ?? '0') ?? 0.0);

        return [
          record['id']?.toString() ?? '',
          record['date']?.toString() ?? '',
          record['entryNumber']?.toString() ?? record['ref']?.toString() ?? '',
          record['description']?.toString() ?? '',
          (record['type']?.toString() ?? 'general').toUpperCase(),
          record['debitAccount']?.toString() ?? '',
          record['creditAccount']?.toString() ?? '',
          amountAed.toStringAsFixed(2),
          record['notes']?.toString() ?? '',
          jsonStr,
        ];

      case 'Settings':
        final val = record['value'] ?? record;
        final name = val is Map ? (val['name']?.toString() ?? 'Company Settings') : 'Setting';
        final email = val is Map ? (val['email']?.toString() ?? '') : '';
        final phone = val is Map ? (val['phone']?.toString() ?? '') : '';
        final trn = val is Map ? (val['trn']?.toString() ?? '') : '';
        final summary = '$name | $email | $phone | TRN: $trn';

        return [
          record['id']?.toString() ?? 'company',
          name,
          summary,
          record['version'] ?? 0,
          jsonStr,
        ];

      default:
        return [
          record['id']?.toString() ?? '',
          jsonStr,
        ];
    }
  }

  /// Converts a row of cell values from Google Sheets back into a domain Map.
  /// Seamlessly handles:
  /// 1. New multi-column rows with JSON Payload at the end.
  /// 2. Legacy 2-column rows [ID, JSON].
  /// 3. Rows manually typed into Google Sheets where JSON may not be populated.
  static Map<String, dynamic> rowToRecord(String tabName, List<dynamic> row) {
    if (row.isEmpty) return {};

    // Check if the last column or second column contains valid JSON
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

    // Fallback: reconstruct from explicit column cells
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

      case 'Employees':
        if (row.length > 1) record['code'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['name'] = row[2]?.toString() ?? '';
        if (row.length > 3) record['role'] = row[3]?.toString() ?? '';
        if (row.length > 4) record['department'] = row[4]?.toString() ?? '';
        if (row.length > 5) record['joinDate'] = row[5]?.toString() ?? '';
        if (row.length > 6) record['basic'] = row[6]?.toString() ?? '0.00';
        if (row.length > 7) record['allowances'] = row[7]?.toString() ?? '0.00';
        if (row.length > 9) record['phone'] = row[9]?.toString() ?? '';
        if (row.length > 10) record['email'] = row[10]?.toString() ?? '';
        if (row.length > 11) record['status'] = row[11]?.toString().toLowerCase() ?? 'active';
        if (row.length > 12) record['iban'] = row[12]?.toString() ?? '';
        if (row.length > 13) record['notes'] = row[13]?.toString() ?? '';
        break;

      case 'Finance':
        if (row.length > 1) record['date'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['kind'] = row[2]?.toString().toLowerCase() ?? 'expense';
        if (row.length > 3) record['category'] = row[3]?.toString() ?? '';
        if (row.length > 4) record['description'] = row[4]?.toString() ?? '';
        if (row.length > 5) {
          final amt = double.tryParse(row[5]?.toString().replaceAll(',', '') ?? '0') ?? 0.0;
          record['amountCents'] = (amt * 100).round();
        }
        if (row.length > 6) record['vatPercent'] = double.tryParse(row[6]?.toString() ?? '0') ?? 0.0;
        if (row.length > 9) record['status'] = row[9]?.toString().toLowerCase() ?? 'paid';
        if (row.length > 10) record['paidDate'] = row[10]?.toString() ?? '';
        if (row.length > 11) record['dueDate'] = row[11]?.toString() ?? '';
        if (row.length > 12) record['account'] = row[12]?.toString() ?? 'Bank';
        if (row.length > 13) record['supplier'] = row[13]?.toString() ?? '';
        if (row.length > 14) record['invoiceRef'] = row[14]?.toString() ?? '';
        if (row.length > 15) record['notes'] = row[15]?.toString() ?? '';
        break;

      case 'Shareholders':
        if (row.length > 1) record['name'] = row[1]?.toString() ?? '';
        if (row.length > 2) record['role'] = row[2]?.toString() ?? '';
        if (row.length > 3) record['sharesPercent'] = row[3]?.toString() ?? '0';
        if (row.length > 4) record['investedAmount'] = row[4]?.toString() ?? '0';
        if (row.length > 5) record['date'] = row[5]?.toString() ?? '';
        if (row.length > 6) record['email'] = row[6]?.toString() ?? '';
        if (row.length > 7) record['phone'] = row[7]?.toString() ?? '';
        if (row.length > 8) record['status'] = row[8]?.toString().toLowerCase() ?? 'active';
        if (row.length > 9) record['notes'] = row[9]?.toString() ?? '';
        break;

      default:
        break;
    }

    return record;
  }
}
