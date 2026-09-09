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

      _scheduleBackgroundSync();

      return {
        'employees': employees,
        'attendance': attendance,
        'payroll': payroll,
        'entries': entries,
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

    if (action == 'officeUploadDocument') {
      final token = await session.tryGetToken();
      if (token == null) {
        throw StateError('Document upload to Google Drive requires an active internet connection.');
      }
      final bytes = base64Decode(d['base64'] as String);
      final fileName = d['name'] as String;
      final link = await _service.uploadPdfFile(token, _driveFolderId, fileName, bytes);
      return {'url': link};
    }

    throw StateError('Unknown action: $action');
  }
}
