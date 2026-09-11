import 'package:freezed_annotation/freezed_annotation.dart';

part 'accounting_models.freezed.dart';
part 'accounting_models.g.dart';

@freezed
abstract class ShareholderModel with _$ShareholderModel {
  const factory ShareholderModel({
    required String id,
    required String name,
    @Default(0.0) double ownershipPercentage,
    @Default(0.0) double agreedCapital,
    @Default(0.0) double cashInvested,
    @Default(0.0) double assetContributions,
    @Default(0.0) double totalInvested,
    @Default(0.0) double outstandingCapital,
    @Default(0.0) double loanBalance,
    @Default('active') String status,
    @Default('') String notes,
    @Default(0) int version,
  }) = _ShareholderModel;

  factory ShareholderModel.fromJson(Map<String, dynamic> json) => _$ShareholderModelFromJson(json);
}

@freezed
abstract class CapitalTransactionModel with _$CapitalTransactionModel {
  const factory CapitalTransactionModel({
    required String id,
    required String shareholderId,
    @Default('') String shareholderName,
    required String date,
    @Default('capitalContribution') String transactionType, // capitalContribution, additionalCapital, capitalWithdrawal, equityAdjustment
    @Default('bank') String contributionType, // cash, bank, asset, other
    @Default(0.0) double amount,
    @Default(0) int amountCents,
    String? assetId,
    @Default('Bank') String bankAccountId, // Bank, Cash
    @Default('') String reference,
    @Default('') String notes,
    @Default('posted') String status, // posted, void, draft
    @Default('') String journalId,
    @Default(0) int version,
  }) = _CapitalTransactionModel;

  factory CapitalTransactionModel.fromJson(Map<String, dynamic> json) => _$CapitalTransactionModelFromJson(json);
}

@freezed
abstract class ShareholderLoanModel with _$ShareholderLoanModel {
  const factory ShareholderLoanModel({
    required String id,
    required String shareholderId,
    @Default('') String shareholderName,
    required String date,
    @Default('loanReceived') String type, // loanReceived, loanRepayment, loanAdjustment
    @Default(0.0) double amount,
    @Default(0) int amountCents,
    @Default('Bank') String paymentAccount, // Bank, Cash
    @Default('') String reference,
    @Default('') String notes,
    @Default('posted') String status,
    @Default('') String journalId,
    @Default(0) int version,
  }) = _ShareholderLoanModel;

  factory ShareholderLoanModel.fromJson(Map<String, dynamic> json) => _$ShareholderLoanModelFromJson(json);
}

@freezed
abstract class AssetRecordModel with _$AssetRecordModel {
  const factory AssetRecordModel({
    required String id,
    @Default('') String code,
    required String name,
    @Default('Computers & IT Equipment') String category,
    @Default('companyPurchase') String acquisitionType, // companyPurchase, shareholderContribution, openingBalance
    required String purchaseDate,
    @Default(0.0) double cost,
    @Default(0) int costCents,
    @Default(0.0) double vatAmount,
    @Default('') String supplier,
    @Default('Bank') String paymentAccount,
    @Default('') String shareholderId,
    @Default('') String shareholderName,
    @Default('Main Office') String location,
    @Default('') String assignedEmployeeId,
    @Default('') String assignedEmployeeName,
    @Default('') String serialNumber,
    @Default('') String warrantyExpiry,
    @Default('straightLine') String depreciationMethod,
    @Default(36) int usefulLifeMonths,
    @Default(0.0) double residualValue,
    @Default(0.0) double accumulatedDepreciation,
    @Default(0) int accumulatedDepreciationCents,
    @Default(0.0) double bookValue,
    @Default(0) int bookValueCents,
    @Default('active') String status, // active, maintenance, damaged, lost, sold, disposed
    String? disposalDate,
    String? disposalType,
    double? salePrice,
    double? gainLoss,
    @Default('') String notes,
    @Default('') String journalId,
    @Default(0) int version,
  }) = _AssetRecordModel;

  factory AssetRecordModel.fromJson(Map<String, dynamic> json) => _$AssetRecordModelFromJson(json);
}

@freezed
abstract class JournalLineModel with _$JournalLineModel {
  const factory JournalLineModel({
    required String accountId,
    required String accountName,
    required String accountGroup, // Asset, Liability, Equity, Income, Expense
    @Default(0) int debitCents,
    @Default(0) int creditCents,
    @Default('') String notes,
    String? shareholderId,
    String? assetId,
  }) = _JournalLineModel;

  factory JournalLineModel.fromJson(Map<String, dynamic> json) => _$JournalLineModelFromJson(json);
}

@freezed
abstract class JournalEntryModel with _$JournalEntryModel {
  const factory JournalEntryModel({
    required String id,
    required String journalNumber,
    required String date,
    required String sourceType, // capital, asset_purchase, asset_contribution, depreciation, shareholder_loan, invoice, customer_payment, expense, payroll
    required String sourceId,
    @Default('') String description,
    @Default([]) List<JournalLineModel> lines,
    @Default(0) int totalDebitCents,
    @Default(0) int totalCreditCents,
    @Default(true) bool isBalanced,
    @Default('posted') String status,
    @Default(0) int version,
  }) = _JournalEntryModel;

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) => _$JournalEntryModelFromJson(json);
}
