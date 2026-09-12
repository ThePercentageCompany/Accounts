import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../billing/domain/models.dart';
import '../../billing/presentation/billing_cubit.dart';
import '../domain/quotation.dart';
import '../domain/quotation_repository.dart';

class QuotationState {
  final List<Quotation> quotations;
  final bool busy;
  final String? error;

  const QuotationState({
    this.quotations = const [],
    this.busy = false,
    this.error,
  });

  QuotationState copyWith({
    List<Quotation>? quotations,
    bool? busy,
    String? error,
  }) {
    return QuotationState(
      quotations: quotations ?? this.quotations,
      busy: busy ?? this.busy,
      error: error,
    );
  }
}

class QuotationCubit extends Cubit<QuotationState> {
  final QuotationRepository repository;

  QuotationCubit(this.repository) : super(const QuotationState());

  Future<void> refresh() => _run(() async {});

  Future<bool> run(Future<void> Function() action) => _run(action);

  Future<bool> _run(Future<void> Function() action) async {
    if (state.busy) return false;
    emit(state.copyWith(busy: true, error: null));
    try {
      await action();
      final data = await repository.load();
      emit(QuotationState(quotations: data));
      return true;
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }

  Future<bool> save(Quotation quotation) async {
    return _run(() async {
      await repository.save(quotation);
    });
  }

  Future<Quotation?> issue(Quotation quotation) async {
    Quotation? result;
    final ok = await _run(() async {
      result = await repository.issue(quotation);
    });
    return ok ? result : null;
  }

  Future<String> archive(Quotation quotation, Uint8List bytes) async {
    try {
      final link = await repository.archive(quotation, bytes);
      final data = await repository.load();
      emit(QuotationState(quotations: data));
      return link;
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return '';
    }
  }

  Future<bool> updateStatus(String id, String status) async {
    return _run(() async {
      await repository.updateStatus(id, status);
    });
  }

  Future<bool> delete(String id) async {
    return _run(() async {
      await repository.delete(id);
    });
  }

  Future<Invoice?> convertToInvoice(Quotation quotation, BillingCubit billingCubit) async {
    try {
      emit(state.copyWith(busy: true, error: null));
      final invId = 'inv_${DateTime.now().millisecondsSinceEpoch}';
      final invoice = Invoice(
        id: invId,
        date: DateTime.now().toString().substring(0, 10),
        dueDate: quotation.validUntil.isNotEmpty ? quotation.validUntil : '',
        customer: quotation.customer,
        company: quotation.company,
        items: quotation.items,
        discount: quotation.discount,
        taxRate: quotation.taxRate,
        notes: quotation.notes,
        terms: quotation.terms,
        status: 'draft',
      );

      final createdInvoice = await billingCubit.repository.saveDraft(invoice);
      await billingCubit.refresh();

      final updatedQuote = quotation.copyWith(
        status: 'converted',
        convertedInvoiceId: createdInvoice.id,
      );
      await repository.save(updatedQuote);

      final updatedList = await repository.load();
      emit(QuotationState(quotations: updatedList));
      return createdInvoice;
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
      return null;
    }
  }
}
