import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/quotation.dart';
import '../domain/quotation_repository.dart';

class LocalQuotationRepository implements QuotationRepository {
  List<Quotation> _quotations = [];

  @override
  bool get isDemo => true;

  Future<void> _write() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _quotations.map((q) => q.toJson()).toList();
    if (!await prefs.setString('tpc_quotations_v1', jsonEncode(jsonList))) {
      throw StateError('Could not save quotations to this device.');
    }
  }

  @override
  Future<List<Quotation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString('tpc_quotations_v1');
    if (text == null || text.isEmpty) {
      _quotations = [];
    } else {
      try {
        final list = jsonDecode(text) as List<dynamic>;
        _quotations = list
            .map((e) => Quotation.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        _quotations = [];
      }
    }
    return _quotations;
  }

  @override
  Future<Quotation> save(Quotation quotation) async {
    QuotationTotals.of(quotation);
    final updated = quotation.copyWith(version: quotation.version + 1);
    final idx = _quotations.indexWhere((x) => x.id == updated.id);
    if (idx >= 0) {
      _quotations[idx] = updated;
    } else {
      _quotations.add(updated);
    }
    await _write();
    return updated;
  }

  @override
  Future<Quotation> issue(Quotation quotation) async {
    final current = _quotations.firstWhere(
      (x) => x.id == quotation.id,
      orElse: () => quotation,
    );
    if (current.number.isNotEmpty) return current;

    final prefix = quotation.company.prefix.isNotEmpty ? quotation.company.prefix : 'TPC';
    final year = DateTime.now().year;
    final seq = _quotations.where((x) => x.number.isNotEmpty).length + 1;
    final generatedNumber = 'QT-$prefix-$year-${seq.toString().padLeft(6, '0')}';

    final issued = current.copyWith(
      number: generatedNumber,
      status: current.status == 'draft' ? 'sent' : current.status,
      issuedAt: DateTime.now().toUtc().toIso8601String(),
      version: current.version + 1,
    );

    final idx = _quotations.indexWhere((x) => x.id == issued.id);
    if (idx >= 0) {
      _quotations[idx] = issued;
    } else {
      _quotations.add(issued);
    }
    await _write();
    return issued;
  }

  @override
  Future<Quotation> updateStatus(String quotationId, String newStatus) async {
    final idx = _quotations.indexWhere((x) => x.id == quotationId);
    if (idx < 0) throw StateError('Quotation not found.');
    final current = _quotations[idx];
    final updated = current.copyWith(
      status: newStatus,
      version: current.version + 1,
    );
    _quotations[idx] = updated;
    await _write();
    return updated;
  }

  @override
  Future<void> delete(String quotationId) async {
    _quotations.removeWhere((x) => x.id == quotationId);
    await _write();
  }
}
