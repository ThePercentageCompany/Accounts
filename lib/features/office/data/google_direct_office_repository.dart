import 'dart:convert';
import '../../../core/auth/google_session.dart';
import '../../../core/auth/google_workspace_service.dart';
import '../../../core/sync/sync_manager.dart';
import '../../billing/domain/models.dart';
import '../../billing/domain/totals.dart';
import '../domain/office_repository.dart';
import '../domain/office_rules.dart';

class GoogleDirectOfficeRepository implements OfficeRepository {
  final GoogleSession session;
  final GoogleWorkspaceService _service = GoogleWorkspaceService();
  final SyncManager _sync = SyncManager.instance;

  GoogleDirectOfficeRepository(this.session);

  @override
  bool get isDemo => false;

  String get _spreadsheetId {
    final id = session.workspace?.spreadsheetId;
    if (id == null || id.isEmpty) {
      throw StateError('No Google Spreadsheet linked. Complete onboarding first.');
    }
    return id;
  }

  String get _driveFolderId => session.workspace?.driveFolderId ?? '';

  void _scheduleBackgroundSync() {
    Future.microtask(() async {
      try {
        final token = await session.tryGetToken();
        if (token != null) {
          await _sync.triggerBackgroundSync(token: token, spreadsheetId: _spreadsheetId);
        }
      } catch (_) {}
    });
  }

  @override
  Future<Map<String, dynamic>> command(String action, [Map<String, dynamic>? payload]) async {
    final spreadsheetId = _spreadsheetId;
    final d = Map<String, dynamic>.from(payload ?? {});

    if (action == 'officeLoad') {
      final employees = await _sync.loadCachedRecords(spreadsheetId, 'Employees');
      final attendance = await _sync.loadCachedRecords(spreadsheetId, 'Attendance');
      final payroll = await _sync.loadCachedRecords(spreadsheetId, 'Payroll');
      final entries = await _sync.loadCachedRecords(spreadsheetId, 'Finance');
      final shareholders = await _sync.loadCachedRecords(spreadsheetId, 'Shareholders');
      final capitalTransactions = await _sync.loadCachedRecords(spreadsheetId, 'CapitalTransactions');
      final shareholderLoans = await _sync.loadCachedRecords(spreadsheetId, 'ShareholderLoans');
      final assets = await _sync.loadCachedRecords(spreadsheetId, 'Assets');
      final journals = await _sync.loadCachedRecords(spreadsheetId, 'Journals');

      _scheduleBackgroundSync();

      return {
        'employees': employees,
        'attendance': attendance,
        'payroll': payroll,
        'entries': entries,
        'shareholders': shareholders,
        'capitalTransactions': capitalTransactions,
        'shareholderLoans': shareholderLoans,
        'assets': assets,
        'journals': journals,
      };
    }

    if (action == 'employeeSave') {
      final employees = await _sync.loadCachedRecords(spreadsheetId, 'Employees');
      final id = d['id'] as String;
      final old = employees.where((x) => x['id'] == id).firstOrNull;
      if (old != null && (old['version'] ?? 0) != (d['version'] ?? 0)) {
        throw StateError('Record changed. Refresh and reopen.');
      }
      if (employees.any((e) => e['id'] != id && e['code'] == d['code'])) {
        throw StateError('Employee code already exists.');
      }
      scaled(d['basic'].toString(), 2);
      scaled(d['allowances'].toString(), 2);

      final record = {
        ...d,
        'documents': old?['documents'] ?? [],
        'version': ((d['version'] as int?) ?? 0) + 1,
      };
      await _sync.upsertCachedRecord(spreadsheetId, 'Employees', id, record);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'Employees',
        recordId: id,
        action: 'upsert',
        data: record,
      );
      _scheduleBackgroundSync();
      return record;
    }

    if (action == 'attendanceSave') {
      final employeeId = d['employeeId'] as String;
      final date = d['date'].toString();
      final id = '${employeeId}_$date';

      final employees = await _sync.loadCachedRecords(spreadsheetId, 'Employees');
      final employee = employees.where((x) => x['id'] == employeeId).firstOrNull;
      if (employee == null) throw StateError('Employee not found.');

      if (date.compareTo(employee['joinDate']) < 0 ||
          (employee['endDate'] != '' && date.compareTo(employee['endDate']) > 0)) {
        throw StateError('Date outside employment.');
      }
      if (scaled(d['overtimeHours'].toString(), 2) > 2400) {
        throw StateError('Overtime exceeds 24 hours.');
      }

      final payroll = await _sync.loadCachedRecords(spreadsheetId, 'Payroll');
      if (payroll.any((p) =>
          p['employee']?['id'] == employeeId &&
          p['month'] == date.substring(0, 7) &&
          p['status'] != 'draft')) {
        throw StateError('Attendance is locked by approved payroll.');
      }

      final attendance = await _sync.loadCachedRecords(spreadsheetId, 'Attendance');
      final old = attendance.where((x) => x['id'] == id).firstOrNull;
      if (old != null && (old['version'] ?? 0) != (d['version'] ?? 0)) {
        throw StateError('Record changed. Refresh and reopen.');
      }

      final record = {
        ...d,
        'id': id,
        'version': ((d['version'] as int?) ?? 0) + 1,
      };
      await _sync.upsertCachedRecord(spreadsheetId, 'Attendance', id, record);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'Attendance',
        recordId: id,
        action: 'upsert',
        data: record,
      );
      _scheduleBackgroundSync();
      return record;
    }

    if (action == 'payrollGenerate') {
      final employeeId = d['employeeId'] as String;
      final month = d['month'] as String;
      final id = '${employeeId}_$month';

      final employees = await _sync.loadCachedRecords(spreadsheetId, 'Employees');
      final employee = employees.where((x) => x['id'] == employeeId).firstOrNull;
      if (employee == null) throw StateError('Employee not found.');

      final attendance = await _sync.loadCachedRecords(spreadsheetId, 'Attendance');
      final rows = attendance
          .where((a) => a['employeeId'] == employeeId && a['date'].toString().startsWith(month))
          .toList()
        ..sort((a, b) => a['date'].toString().compareTo(b['date']));

      final settings = await _sync.loadCachedRecords(spreadsheetId, 'Settings');
      Company company = const Company();
      for (final s in settings) {
        if (s['id'] == 'company') {
          final val = s['value'] ?? s;
          if (val is Map) company = Company.fromJson(Map<String, dynamic>.from(val));
        }
      }

      final payroll = await _sync.loadCachedRecords(spreadsheetId, 'Payroll');
      final old = payroll.where((x) => x['id'] == id).firstOrNull;
      if (old != null && old['status'] != 'draft') {
        throw StateError('Payroll already approved.');
      }

      final record = {
        ...d,
        'id': id,
        'employee': employee,
        'attendanceSnapshot': rows,
        'company': company.toJson(),
        ...calculatePayroll(employee, rows, d),
        'status': 'draft',
        'version': ((d['version'] as int?) ?? 0) + 1,
        'paidDate': '',
        'account': 'Bank',
        'driveUrl': '',
        'archivedVersion': 0,
        'reference': '',
      };
      await _sync.upsertCachedRecord(spreadsheetId, 'Payroll', id, record);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'Payroll',
        recordId: id,
        action: 'upsert',
        data: record,
      );
      _scheduleBackgroundSync();
      return record;
    }

    if (action == 'payrollApprove' || action == 'payrollPay') {
      final id = d['id'] as String;
      final payroll = await _sync.loadCachedRecords(spreadsheetId, 'Payroll');
      final record = payroll.where((x) => x['id'] == id).firstOrNull;
      if (record == null) throw StateError('Payroll record not found.');

      if (action == 'payrollPay' && record['status'] == 'paid') return record;
      if (action == 'payrollApprove' && record['status'] != 'draft') return record;

      if ((record['version'] ?? 0) != (d['version'] ?? 0)) {
        throw StateError('Record changed. Refresh and reopen.');
      }

      final updated = Map<String, dynamic>.from(record);
      if (action == 'payrollApprove') {
        if (record['missingDays'] != 0) {
          throw StateError('Marked scheduled days must match expected days.');
        }
        updated['status'] = 'approved';
      } else {
        if (record['status'] != 'approved') throw StateError('Approve payroll first.');
        updated['status'] = 'paid';
        updated['paidDate'] = d['paidDate'] ?? '';
        updated['account'] = d['account'] ?? 'Bank';
        updated['reference'] = d['reference'] ?? '';
      }
      updated['version'] = ((record['version'] as int?) ?? 0) + 1;

      await _sync.upsertCachedRecord(spreadsheetId, 'Payroll', id, updated);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'Payroll',
        recordId: id,
        action: 'upsert',
        data: updated,
      );
      _scheduleBackgroundSync();
      return updated;
    }

    if (action == 'financeSave') {
      final id = d['id'] as String;
      final entries = await _sync.loadCachedRecords(spreadsheetId, 'Finance');
      final old = entries.where((x) => x['id'] == id).firstOrNull;
      if (old != null && old['status'] != 'unpaid') {
        throw StateError('Posted entries are locked.');
      }
      final amount = scaled(d['amount'].toString(), 2);
      if (amount <= 0) throw StateError('Amount must exceed zero.');

      final record = {
        ...d,
        'amountCents': amount,
        'status': d['kind'] == 'income' ? 'paid' : d['status'],
        'documents': old?['documents'] ?? [],
        'version': ((d['version'] as int?) ?? 0) + 1,
      };
      await _sync.upsertCachedRecord(spreadsheetId, 'Finance', id, record);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'Finance',
        recordId: id,
        action: 'upsert',
        data: record,
      );
      _scheduleBackgroundSync();
      return record;
    }

    if (action == 'financePay' || action == 'financeVoid') {
      final id = d['id'] as String;
      final entries = await _sync.loadCachedRecords(spreadsheetId, 'Finance');
      final record = entries.where((x) => x['id'] == id).firstOrNull;
      if (record == null) throw StateError('Finance record not found.');

      final targetStatus = action == 'financePay' ? 'paid' : 'void';
      if (record['status'] == targetStatus) return record;

      if ((record['version'] ?? 0) != (d['version'] ?? 0)) {
        throw StateError('Record changed. Refresh and reopen.');
      }
      if (record['status'] != 'unpaid') throw StateError('Only unpaid bills can change.');

      final updated = Map<String, dynamic>.from(record)
        ..addAll({
          'status': targetStatus,
          'paidDate': d['paidDate'] ?? '',
          'account': d['account'] ?? record['account'],
          'version': ((record['version'] as int?) ?? 0) + 1,
        });

      await _sync.upsertCachedRecord(spreadsheetId, 'Finance', id, updated);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'Finance',
        recordId: id,
        action: 'upsert',
        data: updated,
      );
      _scheduleBackgroundSync();
      return updated;
    }

    if (action == 'shareholderSave') {
      final id = d['id'] as String? ?? 'SHR_${DateTime.now().millisecondsSinceEpoch}';
      final shareholders = await _sync.loadCachedRecords(spreadsheetId, 'Shareholders');
      final old = shareholders.where((x) => x['id'] == id).firstOrNull;
      final pct = (d['ownershipPercentage'] ?? d['sharesPercent'] as num?)?.toDouble() ??
          double.tryParse((d['ownershipPercentage'] ?? d['sharesPercent'] ?? '0').toString()) ??
          0.0;
      final agreed = (d['agreedCapital'] ?? d['investedAmount'] as num?)?.toDouble() ??
          double.tryParse((d['agreedCapital'] ?? d['investedAmount'] ?? '0').toString()) ??
          0.0;

      final record = {
        ...d,
        'id': id,
        'ownershipPercentage': pct,
        'sharesPercent': pct.toStringAsFixed(2),
        'agreedCapital': agreed,
        'investedAmount': agreed.toStringAsFixed(2),
        'version': ((d['version'] as int?) ?? (old?['version'] ?? 0)) + 1,
      };
      await _sync.upsertCachedRecord(spreadsheetId, 'Shareholders', id, record);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'Shareholders',
        recordId: id,
        action: 'upsert',
        data: record,
      );
      _scheduleBackgroundSync();
      return record;
    }

    if (action == 'shareholderDelete') {
      final id = d['id'] as String;
      await _sync.deleteCachedRecord(spreadsheetId, 'Shareholders', id);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'Shareholders',
        recordId: id,
        action: 'delete',
        data: {},
      );
      _scheduleBackgroundSync();
      return {'id': id};
    }

    if (action == 'capitalTransactionSave') {
      final id = d['id'] as String? ?? 'CAP_${DateTime.now().millisecondsSinceEpoch}';
      final amountCents = scaled(d['amount'].toString(), 2);
      final journal = createCapitalJournal(
        transactionId: id,
        shareholderName: d['shareholderName'] ?? 'Shareholder',
        date: d['date'] ?? DateTime.now().toIso8601String().substring(0, 10),
        transactionType: d['transactionType'] ?? 'capitalContribution',
        contributionType: d['contributionType'] ?? 'bank',
        amountCents: amountCents,
        assetName: d['assetName'],
        accountName: d['bankAccountId'] ?? 'Bank Account',
      );
      await _sync.upsertCachedRecord(spreadsheetId, 'Journals', journal['id'] as String, journal);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'Journals',
        recordId: journal['id'] as String,
        action: 'upsert',
        data: journal,
      );

      final record = {
        ...d,
        'id': id,
        'amountCents': amountCents,
        'amount': (amountCents / 100.0).toStringAsFixed(2),
        'journalId': journal['id'],
        'version': ((d['version'] as int?) ?? 0) + 1,
      };
      await _sync.upsertCachedRecord(spreadsheetId, 'CapitalTransactions', id, record);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'CapitalTransactions',
        recordId: id,
        action: 'upsert',
        data: record,
      );
      _scheduleBackgroundSync();
      return record;
    }

    if (action == 'capitalTransactionDelete') {
      final id = d['id'] as String;
      final tx = (await _sync.loadCachedRecords(spreadsheetId, 'CapitalTransactions'))
          .where((x) => x['id'] == id)
          .firstOrNull;
      if (tx != null && tx['journalId'] != null) {
        await _sync.deleteCachedRecord(spreadsheetId, 'Journals', tx['journalId'] as String);
        await _sync.enqueueOperation(
          spreadsheetId: spreadsheetId,
          tabName: 'Journals',
          recordId: tx['journalId'] as String,
          action: 'delete',
          data: {},
        );
      }
      await _sync.deleteCachedRecord(spreadsheetId, 'CapitalTransactions', id);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'CapitalTransactions',
        recordId: id,
        action: 'delete',
        data: {},
      );
      _scheduleBackgroundSync();
      return {'id': id};
    }

    if (action == 'shareholderLoanSave') {
      final id = d['id'] as String? ?? 'LOAN_${DateTime.now().millisecondsSinceEpoch}';
      final amountCents = scaled(d['amount'].toString(), 2);
      final journal = createShareholderLoanJournal(
        loanId: id,
        shareholderName: d['shareholderName'] ?? 'Shareholder',
        date: d['date'] ?? DateTime.now().toIso8601String().substring(0, 10),
        type: d['type'] ?? 'loanReceived',
        amountCents: amountCents,
        paymentAccount: d['paymentAccount'] ?? 'Bank',
      );
      await _sync.upsertCachedRecord(spreadsheetId, 'Journals', journal['id'] as String, journal);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'Journals',
        recordId: journal['id'] as String,
        action: 'upsert',
        data: journal,
      );

      final record = {
        ...d,
        'id': id,
        'amountCents': amountCents,
        'amount': (amountCents / 100.0).toStringAsFixed(2),
        'principalAmount': (amountCents / 100.0).toStringAsFixed(2),
        'journalId': journal['id'],
        'version': ((d['version'] as int?) ?? 0) + 1,
      };
      await _sync.upsertCachedRecord(spreadsheetId, 'ShareholderLoans', id, record);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'ShareholderLoans',
        recordId: id,
        action: 'upsert',
        data: record,
      );
      _scheduleBackgroundSync();
      return record;
    }

    if (action == 'shareholderLoanDelete') {
      final id = d['id'] as String;
      final loan = (await _sync.loadCachedRecords(spreadsheetId, 'ShareholderLoans'))
          .where((x) => x['id'] == id)
          .firstOrNull;
      if (loan != null && loan['journalId'] != null) {
        await _sync.deleteCachedRecord(spreadsheetId, 'Journals', loan['journalId'] as String);
        await _sync.enqueueOperation(
          spreadsheetId: spreadsheetId,
          tabName: 'Journals',
          recordId: loan['journalId'] as String,
          action: 'delete',
          data: {},
        );
      }
      await _sync.deleteCachedRecord(spreadsheetId, 'ShareholderLoans', id);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'ShareholderLoans',
        recordId: id,
        action: 'delete',
        data: {},
      );
      _scheduleBackgroundSync();
      return {'id': id};
    }

    if (action == 'assetSave') {
      final id = d['id'] as String? ?? 'AST_${DateTime.now().millisecondsSinceEpoch}';
      final costCents = scaled(d['cost'].toString(), 2);
      final accDepCents = (d['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0;
      final bookValueCents = (costCents - accDepCents).clamp(0, costCents);

      final assets = await _sync.loadCachedRecords(spreadsheetId, 'Assets');
      final old = assets.where((x) => x['id'] == id).firstOrNull;
      if (old == null) {
        final journal = createAssetPurchaseJournal(
          assetId: id,
          assetName: d['name'] ?? 'Asset',
          category: d['category'] ?? 'Fixed Assets',
          date: d['purchaseDate'] ?? DateTime.now().toIso8601String().substring(0, 10),
          acquisitionType: d['acquisitionType'] ?? 'companyPurchase',
          costCents: costCents,
          paymentAccount: d['paymentAccount'] ?? 'Bank',
          shareholderName: d['shareholderName'],
        );
        await _sync.upsertCachedRecord(spreadsheetId, 'Journals', journal['id'] as String, journal);
        await _sync.enqueueOperation(
          spreadsheetId: spreadsheetId,
          tabName: 'Journals',
          recordId: journal['id'] as String,
          action: 'upsert',
          data: journal,
        );
      }

      final record = {
        ...d,
        'id': id,
        'costCents': costCents,
        'cost': (costCents / 100.0).toStringAsFixed(2),
        'accumulatedDepreciationCents': accDepCents,
        'bookValueCents': bookValueCents,
        'version': ((d['version'] as int?) ?? (old?['version'] ?? 0)) + 1,
      };
      await _sync.upsertCachedRecord(spreadsheetId, 'Assets', id, record);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'Assets',
        recordId: id,
        action: 'upsert',
        data: record,
      );
      _scheduleBackgroundSync();
      return record;
    }

    if (action == 'assetDelete') {
      final id = d['id'] as String;
      await _sync.deleteCachedRecord(spreadsheetId, 'Assets', id);
      await _sync.enqueueOperation(
        spreadsheetId: spreadsheetId,
        tabName: 'Assets',
        recordId: id,
        action: 'delete',
        data: {},
      );
      _scheduleBackgroundSync();
      return {'id': id};
    }

    if (action == 'runDepreciation') {
      final assets = await _sync.loadCachedRecords(spreadsheetId, 'Assets');
      final today = DateTime.now().toIso8601String().substring(0, 10);
      var count = 0;

      for (final a in assets) {
        if (a['status'] == 'active') {
          final cost = (a['costCents'] as num?)?.toInt() ?? 0;
          final residual = scaled((a['residualValue'] ?? 0).toString(), 2);
          final months = (a['usefulLifeMonths'] as num?)?.toInt() ?? 36;
          final currentAccDep = (a['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0;
          final depCalc = calculateDepreciation(costCents: cost, residualValueCents: residual, usefulLifeMonths: months);
          final monthlyDep = depCalc['monthlyCents'] ?? 0;

          if (monthlyDep > 0 && currentAccDep < (cost - residual)) {
            final newAccDep = (currentAccDep + monthlyDep).clamp(0, cost - residual);
            final newBookVal = (cost - newAccDep).clamp(0, cost);
            final jrn = createDepreciationJournal(
              assetId: a['id'] as String,
              assetName: a['name'] as String? ?? 'Asset',
              date: today,
              depreciationCents: monthlyDep,
            );
            await _sync.upsertCachedRecord(spreadsheetId, 'Journals', jrn['id'] as String, jrn);

            final updated = {
              ...a,
              'accumulatedDepreciationCents': newAccDep,
              'accumulatedDepreciation': newAccDep / 100.0,
              'bookValueCents': newBookVal,
              'bookValue': newBookVal / 100.0,
              'version': ((a['version'] as int?) ?? 0) + 1,
            };
            await _sync.upsertCachedRecord(spreadsheetId, 'Assets', a['id'] as String, updated);
            count++;
          }
        }
      }
      _scheduleBackgroundSync();
      return {'status': 'success', 'depreciatedCount': count};
    }

    if (action == 'payrollArchive') {
      final token = await session.tryGetToken();
      if (token == null) {
        throw StateError('Archiving to Google Drive requires an active internet connection.');
      }
      final id = d['id'] as String;
      final bytes = base64Decode(d['pdf'] as String);
      final fileName = 'Payslip_$id.pdf';
      final link = await _service.uploadPdfFile(token, _driveFolderId, fileName, bytes, subfolder: 'Payroll');

      if (link.isNotEmpty) {
        final payroll = await _sync.loadCachedRecords(spreadsheetId, 'Payroll');
        final current = payroll.where((x) => x['id'] == id).firstOrNull;
        if (current != null) {
          final updated = {
            ...current,
            'driveUrl': link,
            'archivedVersion': current['version'] ?? 0,
          };
          await _sync.upsertCachedRecord(spreadsheetId, 'Payroll', id, updated);
          await _sync.enqueueOperation(
            spreadsheetId: spreadsheetId,
            tabName: 'Payroll',
            recordId: id,
            action: 'upsert',
            data: updated,
          );
          _scheduleBackgroundSync();
        }
      }
      return {'url': link};
    }

    if (action == 'reportArchive') {
      final token = await session.tryGetToken();
      if (token == null) {
        throw StateError('Archiving to Google Drive requires an active internet connection.');
      }
      final month = d['month'] as String? ?? DateTime.now().toIso8601String().substring(0, 7);
      final bytes = base64Decode(d['pdf'] as String);
      final fileName = 'Financial_Report_$month.pdf';
      final link = await _service.uploadPdfFile(token, _driveFolderId, fileName, bytes, subfolder: 'Reports');
      return {'url': link};
    }

    if (action == 'officeUploadDocument') {
      final token = await session.tryGetToken();
      if (token == null) {
        throw StateError('Document upload to Google Drive requires an active internet connection.');
      }
      final bytes = base64Decode(d['base64'] as String);
      final fileName = d['name'] as String;
      final mimeType = d['type'] as String? ?? 'application/octet-stream';
      final category = d['category'] as String?;
      final targetSubfolder = GoogleWorkspaceService.detectSubfolder(
        fileName: fileName,
        mimeType: mimeType,
        category: category,
      );
      final link = await _service.uploadDriveFile(
        token,
        _driveFolderId,
        fileName,
        bytes,
        mimeType: mimeType,
        subfolder: targetSubfolder,
      );
      return {'url': link};
    }

    throw StateError('Unknown action: $action');
  }
}
