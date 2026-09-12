import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/google_session.dart';
import '../../../core/auth/google_workspace_service.dart';
import '../../../core/sync/sync_manager.dart';
import '../../billing/domain/models.dart';
import '../../billing/domain/totals.dart';
import '../domain/office_repository.dart';
import '../domain/office_rules.dart';

/// Unified offline-first + auto-cloud-sync office repository.
///
/// Replaces both [LocalOfficeRepository] and [GoogleDirectOfficeRepository].
/// Every command writes to local storage immediately via SyncManager.upsertCachedRecord
/// (which internally calls mirrorTabRecordToLocalStorage), then conditionally
/// enqueues a cloud sync operation when a Google Sheets workspace is connected.
class HybridOfficeRepository implements OfficeRepository {
  final GoogleSession session;
  final GoogleWorkspaceService _service = GoogleWorkspaceService();
  final SyncManager _sync = SyncManager.instance;

  HybridOfficeRepository(this.session);

  @override
  bool get isDemo => !_hasCloudWorkspace;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get _hasCloudWorkspace {
    final id = session.workspace?.spreadsheetId;
    return id != null && id.isNotEmpty && id != 'local_demo_workspace';
  }

  String get _spreadsheetId =>
      _hasCloudWorkspace ? session.workspace!.spreadsheetId : 'local_demo_workspace';

  String get _driveFolderId => session.workspace?.driveFolderId ?? '';

  void _scheduleBackgroundSync() {
    if (!_hasCloudWorkspace) return;
    Future.microtask(() async {
      try {
        final token = await session.tryGetToken();
        if (token != null) {
          await _sync.triggerBackgroundSync(
            token: token,
            spreadsheetId: _spreadsheetId,
          );
        }
      } catch (_) {}
    });
  }

  Future<void> _upsert(String tab, String id, Map<String, dynamic> data) async {
    await _sync.upsertCachedRecord(_spreadsheetId, tab, id, data);
    if (_hasCloudWorkspace) {
      await _sync.enqueueOperation(
        spreadsheetId: _spreadsheetId,
        tabName: tab,
        recordId: id,
        action: 'upsert',
        data: data,
      );
    }
  }

  Future<void> _delete(String tab, String id) async {
    await _sync.deleteCachedRecord(_spreadsheetId, tab, id);
    if (_hasCloudWorkspace) {
      await _sync.enqueueOperation(
        spreadsheetId: _spreadsheetId,
        tabName: tab,
        recordId: id,
        action: 'delete',
        data: {},
      );
    }
  }

  // ---------------------------------------------------------------------------
  // OfficeRepository interface
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>> command(String action, [Map<String, dynamic>? payload]) async {
    final sid = _spreadsheetId;
    final d = Map<String, dynamic>.from(payload ?? {});

    // ── officeLoad ────────────────────────────────────────────────────────────
    if (action == 'officeLoad') {
      // Seed cache from legacy local storage if needed
      await _seedCacheFromLocalStorage(sid);

      final employees = await _sync.loadCachedRecords(sid, 'Employees');
      final attendance = await _sync.loadCachedRecords(sid, 'Attendance');
      final payroll = await _sync.loadCachedRecords(sid, 'Payroll');
      final entries = await _sync.loadCachedRecords(sid, 'Finance');
      final shareholders = await _sync.loadCachedRecords(sid, 'Shareholders');
      final capitalTransactions = await _sync.loadCachedRecords(sid, 'CapitalTransactions');
      final shareholderLoans = await _sync.loadCachedRecords(sid, 'ShareholderLoans');
      final assets = await _sync.loadCachedRecords(sid, 'Assets');
      final journals = await _sync.loadCachedRecords(sid, 'Journals');

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

    // ── employeeSave ─────────────────────────────────────────────────────────
    if (action == 'employeeSave') {
      final employees = await _sync.loadCachedRecords(sid, 'Employees');
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
      await _upsert('Employees', id, record);
      _scheduleBackgroundSync();
      return record;
    }

    // ── attendanceSave ────────────────────────────────────────────────────────
    if (action == 'attendanceSave') {
      final employeeId = d['employeeId'] as String;
      final date = d['date'].toString();
      final id = '${employeeId}_$date';

      final employees = await _sync.loadCachedRecords(sid, 'Employees');
      final employee = employees.where((x) => x['id'] == employeeId).firstOrNull;
      if (employee == null) throw StateError('Employee not found.');

      if (date.compareTo(employee['joinDate']) < 0 ||
          (employee['endDate'] != '' && date.compareTo(employee['endDate']) > 0)) {
        throw StateError('Date outside employment.');
      }
      if (scaled(d['overtimeHours'].toString(), 2) > 2400) {
        throw StateError('Overtime exceeds 24 hours.');
      }

      final payroll = await _sync.loadCachedRecords(sid, 'Payroll');
      if (payroll.any((p) =>
          p['employee']?['id'] == employeeId &&
          p['month'] == date.substring(0, 7) &&
          p['status'] != 'draft')) {
        throw StateError('Attendance is locked by approved payroll.');
      }

      final attendance = await _sync.loadCachedRecords(sid, 'Attendance');
      final old = attendance.where((x) => x['id'] == id).firstOrNull;
      if (old != null && (old['version'] ?? 0) != (d['version'] ?? 0)) {
        throw StateError('Record changed. Refresh and reopen.');
      }

      final record = {...d, 'id': id, 'version': ((d['version'] as int?) ?? 0) + 1};
      await _upsert('Attendance', id, record);
      _scheduleBackgroundSync();
      return record;
    }

    // ── payrollGenerate ───────────────────────────────────────────────────────
    if (action == 'payrollGenerate') {
      final employeeId = d['employeeId'] as String;
      final month = d['month'] as String;
      final id = '${employeeId}_$month';

      final employees = await _sync.loadCachedRecords(sid, 'Employees');
      final employee = employees.where((x) => x['id'] == employeeId).firstOrNull;
      if (employee == null) throw StateError('Employee not found.');

      final attendance = await _sync.loadCachedRecords(sid, 'Attendance');
      final rows = attendance
          .where((a) => a['employeeId'] == employeeId && a['date'].toString().startsWith(month))
          .toList()
        ..sort((a, b) => a['date'].toString().compareTo(b['date']));

      final settings = await _sync.loadCachedRecords(sid, 'Settings');
      Company company = const Company();
      for (final s in settings) {
        if (s['id'] == 'company') {
          final val = s['value'] ?? s;
          if (val is Map) company = Company.fromJson(Map<String, dynamic>.from(val));
        }
      }

      final payroll = await _sync.loadCachedRecords(sid, 'Payroll');
      final old = payroll.where((x) => x['id'] == id).firstOrNull;
      if (old != null && old['status'] != 'draft') throw StateError('Payroll already approved.');

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
      await _upsert('Payroll', id, record);
      _scheduleBackgroundSync();
      return record;
    }

    // ── payrollApprove / payrollPay ───────────────────────────────────────────
    if (action == 'payrollApprove' || action == 'payrollPay') {
      final id = d['id'] as String;
      final payroll = await _sync.loadCachedRecords(sid, 'Payroll');
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

      await _upsert('Payroll', id, updated);
      _scheduleBackgroundSync();
      return updated;
    }

    // ── financeSave ───────────────────────────────────────────────────────────
    if (action == 'financeSave') {
      final id = d['id'] as String;
      final entries = await _sync.loadCachedRecords(sid, 'Finance');
      final old = entries.where((x) => x['id'] == id).firstOrNull;
      if (old != null && old['status'] != 'unpaid') throw StateError('Posted entries are locked.');

      final amount = scaled(d['amount'].toString(), 2);
      if (amount <= 0) throw StateError('Amount must exceed zero.');

      final record = {
        ...d,
        'amountCents': amount,
        'status': (d['kind'] == 'income' || d['kind'] == 'capital') ? 'paid' : d['status'],
        'documents': old?['documents'] ?? [],
        'version': ((d['version'] as int?) ?? 0) + 1,
      };
      await _upsert('Finance', id, record);
      _scheduleBackgroundSync();
      return record;
    }

    // ── financePay / financeVoid ──────────────────────────────────────────────
    if (action == 'financePay' || action == 'financeVoid') {
      final id = d['id'] as String;
      final entries = await _sync.loadCachedRecords(sid, 'Finance');
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

      await _upsert('Finance', id, updated);
      _scheduleBackgroundSync();
      return updated;
    }

    // ── shareholderSave ───────────────────────────────────────────────────────
    if (action == 'shareholderSave') {
      final id = d['id'] as String? ?? 'SHR_${DateTime.now().millisecondsSinceEpoch}';
      final shareholders = await _sync.loadCachedRecords(sid, 'Shareholders');
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
      await _upsert('Shareholders', id, record);
      _scheduleBackgroundSync();
      return record;
    }

    // ── shareholderDelete ─────────────────────────────────────────────────────
    if (action == 'shareholderDelete') {
      final id = d['id'] as String;
      await _delete('Shareholders', id);
      _scheduleBackgroundSync();
      return {'id': id};
    }

    // ── capitalTransactionSave ────────────────────────────────────────────────
    if (action == 'capitalTransactionSave') {
      final id = d['id'] as String? ?? 'CAP_${DateTime.now().millisecondsSinceEpoch}';
      final amountCents = scaled(d['amount'].toString(), 2);
      if (amountCents <= 0) throw StateError('Contribution amount must be greater than zero.');

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
      await _upsert('Journals', journal['id'] as String, journal);

      final record = {
        ...d,
        'id': id,
        'amountCents': amountCents,
        'amount': (amountCents / 100.0).toStringAsFixed(2),
        'journalId': journal['id'],
        'version': ((d['version'] as int?) ?? 0) + 1,
      };
      await _upsert('CapitalTransactions', id, record);
      _scheduleBackgroundSync();
      return record;
    }

    // ── capitalTransactionDelete ──────────────────────────────────────────────
    if (action == 'capitalTransactionDelete') {
      final id = d['id'] as String;
      final txs = await _sync.loadCachedRecords(sid, 'CapitalTransactions');
      final tx = txs.where((x) => x['id'] == id).firstOrNull;
      if (tx != null && tx['journalId'] != null) {
        await _delete('Journals', tx['journalId'] as String);
      }
      await _delete('CapitalTransactions', id);
      _scheduleBackgroundSync();
      return {'id': id};
    }

    // ── shareholderLoanSave ───────────────────────────────────────────────────
    if (action == 'shareholderLoanSave') {
      final id = d['id'] as String? ?? 'LOAN_${DateTime.now().millisecondsSinceEpoch}';
      final amountCents = scaled(d['amount'].toString(), 2);
      if (amountCents <= 0) throw StateError('Loan amount must be greater than zero.');

      final journal = createShareholderLoanJournal(
        loanId: id,
        shareholderName: d['shareholderName'] ?? 'Shareholder',
        date: d['date'] ?? DateTime.now().toIso8601String().substring(0, 10),
        type: d['type'] ?? 'loanReceived',
        amountCents: amountCents,
        paymentAccount: d['paymentAccount'] ?? 'Bank',
      );
      await _upsert('Journals', journal['id'] as String, journal);

      final record = {
        ...d,
        'id': id,
        'amountCents': amountCents,
        'amount': (amountCents / 100.0).toStringAsFixed(2),
        'principalAmount': (amountCents / 100.0).toStringAsFixed(2),
        'journalId': journal['id'],
        'version': ((d['version'] as int?) ?? 0) + 1,
      };
      await _upsert('ShareholderLoans', id, record);
      _scheduleBackgroundSync();
      return record;
    }

    // ── shareholderLoanDelete ─────────────────────────────────────────────────
    if (action == 'shareholderLoanDelete') {
      final id = d['id'] as String;
      final loans = await _sync.loadCachedRecords(sid, 'ShareholderLoans');
      final loan = loans.where((x) => x['id'] == id).firstOrNull;
      if (loan != null && loan['journalId'] != null) {
        await _delete('Journals', loan['journalId'] as String);
      }
      await _delete('ShareholderLoans', id);
      _scheduleBackgroundSync();
      return {'id': id};
    }

    // ── assetSave ─────────────────────────────────────────────────────────────
    if (action == 'assetSave') {
      final id = d['id'] as String? ?? 'AST_${DateTime.now().millisecondsSinceEpoch}';
      final costCents = scaled(d['cost'].toString(), 2);
      final accDepCents = (d['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0;
      final bookValueCents = (costCents - accDepCents).clamp(0, costCents);

      final assets = await _sync.loadCachedRecords(sid, 'Assets');
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
        await _upsert('Journals', journal['id'] as String, journal);
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
      await _upsert('Assets', id, record);
      _scheduleBackgroundSync();
      return record;
    }

    // ── assetDelete ───────────────────────────────────────────────────────────
    if (action == 'assetDelete') {
      final id = d['id'] as String;
      await _delete('Assets', id);
      _scheduleBackgroundSync();
      return {'id': id};
    }

    // ── runDepreciation ───────────────────────────────────────────────────────
    if (action == 'runDepreciation') {
      final assets = await _sync.loadCachedRecords(sid, 'Assets');
      final today = DateTime.now().toIso8601String().substring(0, 10);
      var count = 0;

      for (final a in assets) {
        if (a['status'] == 'active') {
          final cost = (a['costCents'] as num?)?.toInt() ?? 0;
          final residual = scaled((a['residualValue'] ?? 0).toString(), 2);
          final months = (a['usefulLifeMonths'] as num?)?.toInt() ?? 36;
          final currentAccDep = (a['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0;
          final depCalc = calculateDepreciation(
              costCents: cost, residualValueCents: residual, usefulLifeMonths: months);
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
            await _upsert('Journals', jrn['id'] as String, jrn);
            final updated = {
              ...a,
              'accumulatedDepreciationCents': newAccDep,
              'accumulatedDepreciation': newAccDep / 100.0,
              'bookValueCents': newBookVal,
              'bookValue': newBookVal / 100.0,
              'version': ((a['version'] as int?) ?? 0) + 1,
            };
            await _upsert('Assets', a['id'] as String, updated);
            count++;
          }
        }
      }
      _scheduleBackgroundSync();
      return {'status': 'success', 'depreciatedCount': count};
    }

    // ── payrollArchive ────────────────────────────────────────────────────────
    if (action == 'payrollArchive') {
      if (!_hasCloudWorkspace) {
        throw StateError('Archiving to Google Drive requires a connected Google workspace.');
      }
      final token = await session.tryGetToken();
      if (token == null) {
        throw StateError('Archiving to Google Drive requires an active internet connection.');
      }
      final id = d['id'] as String;
      final bytes = base64Decode(d['pdf'] as String);
      final fileName = 'Payslip_$id.pdf';
      final link = await _service.uploadPdfFile(
          token, _driveFolderId, fileName, bytes, subfolder: 'Payroll');

      if (link.isNotEmpty) {
        final payroll = await _sync.loadCachedRecords(sid, 'Payroll');
        final current = payroll.where((x) => x['id'] == id).firstOrNull;
        if (current != null) {
          final updated = {
            ...current,
            'driveUrl': link,
            'archivedVersion': current['version'] ?? 0,
          };
          await _upsert('Payroll', id, updated);
          _scheduleBackgroundSync();
        }
      }
      return {'url': link};
    }

    // ── reportArchive ─────────────────────────────────────────────────────────
    if (action == 'reportArchive') {
      if (!_hasCloudWorkspace) {
        throw StateError('Archiving to Google Drive requires a connected Google workspace.');
      }
      final token = await session.tryGetToken();
      if (token == null) {
        throw StateError('Archiving to Google Drive requires an active internet connection.');
      }
      final month = d['month'] as String? ?? DateTime.now().toIso8601String().substring(0, 7);
      final bytes = base64Decode(d['pdf'] as String);
      final fileName = 'Financial_Report_$month.pdf';
      final link = await _service.uploadPdfFile(
          token, _driveFolderId, fileName, bytes, subfolder: 'Reports');
      return {'url': link};
    }

    // ── officeUploadDocument ──────────────────────────────────────────────────
    if (action == 'officeUploadDocument') {
      if (!_hasCloudWorkspace) {
        throw StateError('Document upload to Google Drive requires a connected Google workspace.');
      }
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

    throw StateError('Unknown office action: $action');
  }

  // ---------------------------------------------------------------------------
  // Cold-start cache seeder
  // ---------------------------------------------------------------------------

  /// Seeds the SyncManager tab caches from the legacy `tpc_office_demo_v2`
  /// local storage key on first load so existing offline data is preserved.
  Future<void> _seedCacheFromLocalStorage(String spreadsheetId) async {
    try {
      final employees = await _sync.loadCachedRecords(spreadsheetId, 'Employees');
      final entries = await _sync.loadCachedRecords(spreadsheetId, 'Finance');
      // Only seed if we have nothing — avoids overwriting fresh cloud data
      if (employees.isNotEmpty || entries.isNotEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('tpc_office_demo_v2');
      if (raw == null || raw.isEmpty) return;

      final officeMap = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final tabMap = {
        'employees': 'Employees',
        'attendance': 'Attendance',
        'payroll': 'Payroll',
        'entries': 'Finance',
        'shareholders': 'Shareholders',
        'capitalTransactions': 'CapitalTransactions',
        'shareholderLoans': 'ShareholderLoans',
        'assets': 'Assets',
        'journals': 'Journals',
      };

      for (final entry in tabMap.entries) {
        final list = (officeMap[entry.key] as List? ?? [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        if (list.isNotEmpty) {
          await _sync.saveCachedRecords(spreadsheetId, entry.value, list);
        }
      }
    } catch (_) {}
  }
}
