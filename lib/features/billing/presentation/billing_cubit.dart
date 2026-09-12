import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../domain/billing_repository.dart';
import '../domain/models.dart';
part 'billing_cubit.freezed.dart';

@freezed
abstract class BillingState with _$BillingState {
  const factory BillingState({@Default(BillingData()) BillingData data,
    @Default(false) bool busy, String? error}) = _BillingState;
}
class BillingCubit extends Cubit<BillingState> {
  final BillingRepository repository;
  BillingCubit(this.repository) : super(const BillingState());

  Future<void> refresh() => run(() async {});

  Future<bool> run(Future<void> Function() action) async {
    emit(state.copyWith(busy: true, error: null));
    try {
      await action();
      final data = await repository.load();
      emit(BillingState(data: data));
      return true;
    } catch (e) {
      emit(state.copyWith(busy: false, error: e.toString()));
      return false;
    }
  }

  Future<bool> saveCustomer(Customer customer) async {
    return run(() => repository.saveCustomer(customer));
  }

  Future<bool> deleteCustomer(String customerId) async {
    return run(() => repository.deleteCustomer(customerId));
  }

  Future<Invoice?> saveDraft(Invoice invoice) async {
    Invoice? result;
    final ok = await run(() async {
      result = await repository.saveDraft(invoice);
    });
    return ok ? result : null;
  }

  Future<bool> deleteDraft(String invoiceId) async {
    return run(() => repository.deleteDraft(invoiceId));
  }

  Future<Invoice?> issueInvoice(Invoice invoice) async {
    Invoice? result;
    final ok = await run(() async {
      result = await repository.issue(invoice);
    });
    return ok ? result : null;
  }

  Future<Invoice?> recordPayment(Invoice invoice, Payment payment) async {
    Invoice? result;
    final ok = await run(() async {
      result = await repository.pay(invoice, payment);
    });
    return ok ? result : null;
  }

  Future<Invoice?> voidInvoice(Invoice invoice) async {
    Invoice? result;
    final ok = await run(() async {
      result = await repository.voidInvoice(invoice);
    });
    return ok ? result : null;
  }
}
