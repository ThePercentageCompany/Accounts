import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/offline/durable_value.dart';

/// Persist the exact upload before sending it; uncertain responses reuse it.
class DocumentUploadQueue extends ChangeNotifier {
  DocumentUploadQueue(
    this.api,
    this.preferences,
    String ownerId,
    this.companyId,
  )   : storageKey = 'saas_document_${ownerId}_$companyId',
        ownerId = ownerId;
  final String ownerId;
  late final DurableValue? _durable = api.offlineEnabled
      ? DurableValue(
          api.offlineStore,
          api.outbox(ownerId, companyId).scope,
          storageKey,
          preferences,
        )
      : null;
  Future<void> _reload() async {
    await preferences.reload();
    await _durable?.load();
  }

  Future<void> initialize() async {
    await _reload();
    notifyListeners();
  }

  Future<bool> _save(String value) =>
      _durable?.put(value) ?? preferences.setString(storageKey, value);
  Future<bool> _remove() =>
      _durable?.remove() ?? preferences.remove(storageKey);
  final SaasApi api;
  final SharedPreferences preferences;
  final String companyId, storageKey;
  bool busy = false;
  Map<String, dynamic>? get pending {
    final value =
        _durable != null ? _durable.value : preferences.getString(storageKey);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  Future<void> enqueue({
    required String name,
    required String mimeType,
    required String section,
    required String recordId,
    required Uint8List bytes,
  }) async {
    if (busy) throw const SaasApiException('BUSY', 'Wait for the upload.');
    busy = true;
    try {
      await _reload();
      if (api.offlineEnabled) await api.verifySyncIdentity(ownerId, companyId);
      if (pending != null) {
        throw const SaasApiException(
          'PENDING',
          'Retry the pending upload first.',
        );
      }
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        throw const SaasApiException(
          'DOCUMENT_SIZE',
          'Choose a file between 1 byte and 5 MiB.',
        );
      }
      if (!await _save(
        jsonEncode({
          'operationId': const Uuid().v4(),
          'name': name,
          'mimeType': mimeType,
          'section': section,
          'recordId': recordId,
          'data': base64Encode(bytes),
        }),
      )) {
        throw const SaasApiException(
          'LOCAL_STORAGE',
          'Could not retain this file for retry. Upload was not started.',
        );
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> flush() async {
    if (busy) throw const SaasApiException('BUSY', 'Wait for the upload.');
    busy = true;
    notifyListeners();
    try {
      await _reload();
      final item = pending;
      if (item == null) return;
      if (api.offlineEnabled) await api.verifySyncIdentity(ownerId, companyId);
      final result = await api.upload(
        companyId,
        operationId: item['operationId'],
        name: item['name'],
        mimeType: item['mimeType'],
        relatedSection: item['section'],
        relatedRecordId: item['recordId'],
        bytes: base64Decode(item['data']),
      );
      if (result['documentId'] is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(result['documentId'])) {
        throw const SaasApiException(
          'INVALID_RESPONSE',
          'Upload is not confirmed. Retry the pending upload.',
        );
      }
      if (!await _remove()) {
        throw const SaasApiException(
          'LOCAL_STORAGE',
          'Uploaded. Retry to confirm local progress.',
        );
      }
    } on SaasApiException catch (e) {
      // These validations occur before the backend reserves a document write.
      if (const [
        'DOCUMENT_SIZE',
        'DOCUMENT_TYPE',
        'INVALID_DOCUMENT',
      ].contains(e.code)) {
        await _remove();
      }
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
