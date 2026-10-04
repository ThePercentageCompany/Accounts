import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'saas_api.dart';

/// One durable owner/company queue. Only individually acknowledged operations
/// are removed; an HTTP 200 batch can still contain a failed operation.
class RecordWriteQueue {
  RecordWriteQueue(
    this.api,
    this.preferences,
    String ownerId,
    this.companyId, {
    this.employee = false,
  }) : storageKey = 'saas_records_${ownerId}_$companyId';
  final bool employee;
  final SaasApi api;
  final SharedPreferences preferences;
  final String companyId;
  final String storageKey;
  bool _busy = false;
  String get _rejectedKey => '$storageKey-rejected';
  bool get canDiscardRejected =>
      (preferences.getStringList(_rejectedKey) ?? []).isNotEmpty;
  Future<void> discardRejected() async {
    if (_busy) {
      throw const SaasApiException('BUSY', 'Wait for the pending request.');
    }
    _busy = true;
    try {
      await preferences.reload();
      final rejected = preferences.getStringList(_rejectedKey) ?? [];
      if (rejected.isEmpty) {
        throw const SaasApiException(
          'PENDING',
          'Retry to confirm this change before discarding it.',
        );
      }
      for (final id in rejected) {
        if (!await preferences.remove('${storageKey}_$id')) {
          throw const SaasApiException(
            'LOCAL_STORAGE',
            'Could not discard the rejected change.',
          );
        }
      }
      await preferences.remove(_rejectedKey);
    } finally {
      _busy = false;
    }
  }

  List<Map<String, Object?>> get pending => (preferences
          .getKeys()
          .where((key) => key.startsWith('${storageKey}_'))
          .toList()
        ..sort())
      .map(
        (key) => Map<String, Object?>.from(
          jsonDecode(preferences.getString(key)!) as Map,
        ),
      )
      .toList();
  Future<void> _store(Map<String, Object?> operation) async {
    if (!await preferences.setString(
      '${storageKey}_${operation['operationId']}',
      jsonEncode(operation),
    )) {
      throw const SaasApiException(
        'LOCAL_STORAGE',
        'Cannot save pending changes on this device.',
      );
    }
  }

  Future<void> enqueue(
    String table,
    String action,
    Map<String, Object?> values, {
    String? recordId,
    required int expectedVersion,
  }) async {
    if (_busy) {
      throw const SaasApiException('BUSY', 'Wait for the pending request.');
    }
    _busy = true;
    try {
      await preferences.reload();
      final operations = pending;
      if (operations.isNotEmpty) {
        throw const SaasApiException(
          'PENDING',
          'Retry the pending change before editing another record.',
        );
      }
      await _store({
        'operationId': const Uuid().v4(),
        'table': table,
        'action': action,
        'expectedVersion': expectedVersion,
        if (recordId != null) 'recordId': recordId,
        if (!const [
          'delete',
          'post',
          'issue',
          'send',
          'convert',
          'approve',
          'capitalize',
          'capitalPost',
          'loanPost',
        ].contains(action))
          'values': values,
      });
    } finally {
      _busy = false;
    }
  }

  Future<void> flush() async {
    if (_busy) {
      throw const SaasApiException('BUSY', 'Wait for the pending request.');
    }
    _busy = true;
    try {
      await preferences.reload();
      var operations = pending;
      if (operations.isEmpty) return;
      final batch = operations.take(20).toList();
      late final Map<String, dynamic> response;
      try {
        response = await api.sync(companyId, batch, employee: employee);
      } on SaasApiException catch (error) {
        // INVALID_RECORD at batch validation occurs before any write starts.
        if (error.status == 400 &&
            error.code == 'INVALID_RECORD' &&
            batch.length == 1 &&
            _isDraftCreation(batch.single)) {
          await _removeRejectedDraft(batch.single['operationId'] as String);
        }
        rethrow;
      }
      final results = response['results'];
      if (results is! List || results.length != batch.length) {
        throw const SaasApiException(
          'INVALID_RESPONSE',
          'Cannot confirm this change. Retry with the same request.',
        );
      }
      // Validate all identities before acknowledging any result.
      for (var i = 0; i < results.length; i++) {
        if (results[i] is! Map ||
            results[i]['operationId'] != batch[i]['operationId'] ||
            !const [
              'APPLIED',
              'FAILED',
              'NOT_ATTEMPTED',
            ].contains(results[i]['status'])) {
          throw const SaasApiException(
            'INVALID_RESPONSE',
            'Cannot confirm the result. Pending changes are retained.',
          );
        }
      }
      final applied = results
          .where((r) => r['status'] == 'APPLIED')
          .map((r) => r['operationId'])
          .toSet();
      operations =
          operations.where((r) => !applied.contains(r['operationId'])).toList();
      for (final id in applied) {
        if (!await preferences.remove('${storageKey}_$id')) {
          throw const SaasApiException(
            'LOCAL_STORAGE',
            'Saved online. Retry to confirm local progress.',
          );
        }
      }
      final failed = results.where((r) => r['status'] == 'FAILED').firstOrNull;
      if (failed != null) {
        final error = failed['error'] as Map;
        if (const [
          'VERSION_CONFLICT',
          'INVALID_RECORD',
          'INVALID_DOCUMENT_ITEMS',
          'INVALID_INVOICE_LINE',
          'INVALID_INVOICE',
          'INVOICE_DERIVED_FIELD',
          'INVALID_COMPANY_PROFILE',
          'COMPANY_CURRENCY_LOCKED',
          'DOCUMENT_REFERENCE_INVALID',
          'CASH_TOTAL_MISMATCH',
          'CASH_ENTRY_LINKED',
          'INVALID_PAYMENT_ACCOUNT',
          'INVALID_PAYMENT',
          'INVALID_REVERSAL',
          'REVERSAL_NOT_AVAILABLE',
          'INVOICE_EMPTY',
          'INVOICE_TOTAL_MISMATCH',
          'INVALID_INVOICE_PREFIX',
          'INVOICE_SEQUENCE_EXHAUSTED',
          'INVALID_INVOICE_VOID',
          'INVOICE_VOID_NOT_AVAILABLE',
          'INVOICE_LEDGER_MISMATCH',
          'INVALID_RECEIPT',
          'RECEIPT_LOCKED',
          'RECEIPT_CUSTOMER_INVALID',
          'RECEIPT_CUSTOMER_MISMATCH',
          'RECEIPT_CURRENCY_MISMATCH',
          'INVOICE_NOT_PAYABLE',
          'INVOICE_BALANCE_INVALID',
          'RECEIPT_OVERPAYMENT',
          'RECEIPT_SEQUENCE_EXHAUSTED',
          'INVALID_QUOTATION',
          'INVALID_QUOTATION_LINE',
          'QUOTATION_LOCKED',
          'QUOTATION_EMPTY',
          'QUOTATION_TOTAL_MISMATCH',
          'QUOTATION_DERIVED_FIELD',
          'INVALID_QUOTATION_PREFIX',
          'QUOTATION_SEQUENCE_EXHAUSTED',
          'QUOTATION_NOT_CONVERTIBLE',
          'INVALID_PAYROLL',
          'PAYROLL_LOCKED',
          'PAYROLL_EMPLOYEE_INVALID',
          'PAYROLL_DERIVED_FIELD',
          'PAYROLL_DUPLICATE',
          'PAYROLL_TOTAL_MISMATCH',
          'PAYROLL_NOT_PAYABLE',
          'PAYROLL_NOT_REVERSIBLE',
          'INVALID_ASSET',
          'ASSET_LOCKED',
          'ASSET_DERIVED_FIELD',
          'ASSET_CODE_DUPLICATE',
          'ASSET_NOT_CAPITALIZABLE',
          'ASSET_NOT_DEPRECIABLE',
          'ASSET_DEPRECIATION_DUPLICATE',
          'ASSET_FULLY_DEPRECIATED',
          'ASSET_NOT_DISPOSABLE',
          'ASSET_BOOK_VALUE_INVALID',
          'INVALID_SHAREHOLDER',
          'INVALID_CAPITAL_TRANSACTION',
          'CAPITAL_LOCKED',
          'CAPITAL_DERIVED_FIELD',
          'CAPITAL_REFERENCE_DUPLICATE',
          'CAPITAL_NOT_POSTABLE',
          'INVALID_SHAREHOLDER_LOAN',
          'SHAREHOLDER_LOAN_LOCKED',
          'SHAREHOLDER_LOAN_DERIVED_FIELD',
          'SHAREHOLDER_LOAN_NOT_POSTABLE',
          'SHAREHOLDER_LOAN_NOT_REPAYABLE',
          'RECEIPT_NOT_REVERSIBLE',
          'PAYMENT_NOT_AVAILABLE',
          'INVALID_PAYMENT_DATE',
          'PERIOD_CLOSED',
          'INVALID_CASH_ENTRY',
          'INVALID_MONEY',
          'INVALID_FINANCIAL_PERIOD',
          'PERIOD_METADATA',
          'PERIOD_OVERLAP',
          'PERIOD_LOCKED',
          'PERIOD_HAS_JOURNALS',
          'PERIOD_HAS_DRAFTS',
        ].contains(error['code'])) {
          final operation = batch.firstWhere(
            (op) => op['operationId'] == failed['operationId'],
          );
          if (_isDraftCreation(operation)) {
            await _removeRejectedDraft(failed['operationId'] as String);
          } else {
            await preferences.setStringList(_rejectedKey, [
              failed['operationId'] as String,
            ]);
          }
        }
        throw SaasApiException(
          error['code'] as String,
          error['message'] as String,
        );
      }
      await preferences.remove(_rejectedKey);
      if (operations.isNotEmpty) {
        throw const SaasApiException(
          'PENDING',
          'Some changes are still pending. Retry to continue.',
        );
      }
    } finally {
      _busy = false;
    }
  }

  bool _isDraftCreation(Map<String, Object?> operation) =>
      operation['action'] == 'create' &&
      const ['Invoices', 'Quotations'].contains(operation['table']);

  Future<void> _removeRejectedDraft(String id) async {
    if (!await preferences.remove('${storageKey}_$id')) {
      throw const SaasApiException(
        'LOCAL_STORAGE',
        'Could not clear the rejected draft. Retry.',
      );
    }
    await preferences.remove(_rejectedKey);
  }
}
