// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accounting_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ShareholderModel _$ShareholderModelFromJson(
  Map<String, dynamic> json,
) => _ShareholderModel(
  id: json['id'] as String,
  name: json['name'] as String,
  ownershipPercentage: (json['ownershipPercentage'] as num?)?.toDouble() ?? 0.0,
  agreedCapital: (json['agreedCapital'] as num?)?.toDouble() ?? 0.0,
  cashInvested: (json['cashInvested'] as num?)?.toDouble() ?? 0.0,
  assetContributions: (json['assetContributions'] as num?)?.toDouble() ?? 0.0,
  totalInvested: (json['totalInvested'] as num?)?.toDouble() ?? 0.0,
  outstandingCapital: (json['outstandingCapital'] as num?)?.toDouble() ?? 0.0,
  loanBalance: (json['loanBalance'] as num?)?.toDouble() ?? 0.0,
  status: json['status'] as String? ?? 'active',
  notes: json['notes'] as String? ?? '',
  version: (json['version'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ShareholderModelToJson(_ShareholderModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'ownershipPercentage': instance.ownershipPercentage,
      'agreedCapital': instance.agreedCapital,
      'cashInvested': instance.cashInvested,
      'assetContributions': instance.assetContributions,
      'totalInvested': instance.totalInvested,
      'outstandingCapital': instance.outstandingCapital,
      'loanBalance': instance.loanBalance,
      'status': instance.status,
      'notes': instance.notes,
      'version': instance.version,
    };

_CapitalTransactionModel _$CapitalTransactionModelFromJson(
  Map<String, dynamic> json,
) => _CapitalTransactionModel(
  id: json['id'] as String,
  shareholderId: json['shareholderId'] as String,
  shareholderName: json['shareholderName'] as String? ?? '',
  date: json['date'] as String,
  transactionType: json['transactionType'] as String? ?? 'capitalContribution',
  contributionType: json['contributionType'] as String? ?? 'bank',
  amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
  amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
  assetId: json['assetId'] as String?,
  bankAccountId: json['bankAccountId'] as String? ?? 'Bank',
  reference: json['reference'] as String? ?? '',
  notes: json['notes'] as String? ?? '',
  status: json['status'] as String? ?? 'posted',
  journalId: json['journalId'] as String? ?? '',
  version: (json['version'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CapitalTransactionModelToJson(
  _CapitalTransactionModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'shareholderId': instance.shareholderId,
  'shareholderName': instance.shareholderName,
  'date': instance.date,
  'transactionType': instance.transactionType,
  'contributionType': instance.contributionType,
  'amount': instance.amount,
  'amountCents': instance.amountCents,
  'assetId': instance.assetId,
  'bankAccountId': instance.bankAccountId,
  'reference': instance.reference,
  'notes': instance.notes,
  'status': instance.status,
  'journalId': instance.journalId,
  'version': instance.version,
};

_ShareholderLoanModel _$ShareholderLoanModelFromJson(
  Map<String, dynamic> json,
) => _ShareholderLoanModel(
  id: json['id'] as String,
  shareholderId: json['shareholderId'] as String,
  shareholderName: json['shareholderName'] as String? ?? '',
  date: json['date'] as String,
  type: json['type'] as String? ?? 'loanReceived',
  amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
  amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
  paymentAccount: json['paymentAccount'] as String? ?? 'Bank',
  reference: json['reference'] as String? ?? '',
  notes: json['notes'] as String? ?? '',
  status: json['status'] as String? ?? 'posted',
  journalId: json['journalId'] as String? ?? '',
  version: (json['version'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ShareholderLoanModelToJson(
  _ShareholderLoanModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'shareholderId': instance.shareholderId,
  'shareholderName': instance.shareholderName,
  'date': instance.date,
  'type': instance.type,
  'amount': instance.amount,
  'amountCents': instance.amountCents,
  'paymentAccount': instance.paymentAccount,
  'reference': instance.reference,
  'notes': instance.notes,
  'status': instance.status,
  'journalId': instance.journalId,
  'version': instance.version,
};

_AssetRecordModel _$AssetRecordModelFromJson(Map<String, dynamic> json) =>
    _AssetRecordModel(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String,
      category: json['category'] as String? ?? 'Computers & IT Equipment',
      acquisitionType: json['acquisitionType'] as String? ?? 'companyPurchase',
      purchaseDate: json['purchaseDate'] as String,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      costCents: (json['costCents'] as num?)?.toInt() ?? 0,
      vatAmount: (json['vatAmount'] as num?)?.toDouble() ?? 0.0,
      supplier: json['supplier'] as String? ?? '',
      paymentAccount: json['paymentAccount'] as String? ?? 'Bank',
      shareholderId: json['shareholderId'] as String? ?? '',
      shareholderName: json['shareholderName'] as String? ?? '',
      location: json['location'] as String? ?? 'Main Office',
      assignedEmployeeId: json['assignedEmployeeId'] as String? ?? '',
      assignedEmployeeName: json['assignedEmployeeName'] as String? ?? '',
      serialNumber: json['serialNumber'] as String? ?? '',
      warrantyExpiry: json['warrantyExpiry'] as String? ?? '',
      depreciationMethod:
          json['depreciationMethod'] as String? ?? 'straightLine',
      usefulLifeMonths: (json['usefulLifeMonths'] as num?)?.toInt() ?? 36,
      residualValue: (json['residualValue'] as num?)?.toDouble() ?? 0.0,
      accumulatedDepreciation:
          (json['accumulatedDepreciation'] as num?)?.toDouble() ?? 0.0,
      accumulatedDepreciationCents:
          (json['accumulatedDepreciationCents'] as num?)?.toInt() ?? 0,
      bookValue: (json['bookValue'] as num?)?.toDouble() ?? 0.0,
      bookValueCents: (json['bookValueCents'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
      disposalDate: json['disposalDate'] as String?,
      disposalType: json['disposalType'] as String?,
      salePrice: (json['salePrice'] as num?)?.toDouble(),
      gainLoss: (json['gainLoss'] as num?)?.toDouble(),
      notes: json['notes'] as String? ?? '',
      journalId: json['journalId'] as String? ?? '',
      version: (json['version'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$AssetRecordModelToJson(_AssetRecordModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'name': instance.name,
      'category': instance.category,
      'acquisitionType': instance.acquisitionType,
      'purchaseDate': instance.purchaseDate,
      'cost': instance.cost,
      'costCents': instance.costCents,
      'vatAmount': instance.vatAmount,
      'supplier': instance.supplier,
      'paymentAccount': instance.paymentAccount,
      'shareholderId': instance.shareholderId,
      'shareholderName': instance.shareholderName,
      'location': instance.location,
      'assignedEmployeeId': instance.assignedEmployeeId,
      'assignedEmployeeName': instance.assignedEmployeeName,
      'serialNumber': instance.serialNumber,
      'warrantyExpiry': instance.warrantyExpiry,
      'depreciationMethod': instance.depreciationMethod,
      'usefulLifeMonths': instance.usefulLifeMonths,
      'residualValue': instance.residualValue,
      'accumulatedDepreciation': instance.accumulatedDepreciation,
      'accumulatedDepreciationCents': instance.accumulatedDepreciationCents,
      'bookValue': instance.bookValue,
      'bookValueCents': instance.bookValueCents,
      'status': instance.status,
      'disposalDate': instance.disposalDate,
      'disposalType': instance.disposalType,
      'salePrice': instance.salePrice,
      'gainLoss': instance.gainLoss,
      'notes': instance.notes,
      'journalId': instance.journalId,
      'version': instance.version,
    };

_JournalLineModel _$JournalLineModelFromJson(Map<String, dynamic> json) =>
    _JournalLineModel(
      accountId: json['accountId'] as String,
      accountName: json['accountName'] as String,
      accountGroup: json['accountGroup'] as String,
      debitCents: (json['debitCents'] as num?)?.toInt() ?? 0,
      creditCents: (json['creditCents'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String? ?? '',
      shareholderId: json['shareholderId'] as String?,
      assetId: json['assetId'] as String?,
    );

Map<String, dynamic> _$JournalLineModelToJson(_JournalLineModel instance) =>
    <String, dynamic>{
      'accountId': instance.accountId,
      'accountName': instance.accountName,
      'accountGroup': instance.accountGroup,
      'debitCents': instance.debitCents,
      'creditCents': instance.creditCents,
      'notes': instance.notes,
      'shareholderId': instance.shareholderId,
      'assetId': instance.assetId,
    };

_JournalEntryModel _$JournalEntryModelFromJson(Map<String, dynamic> json) =>
    _JournalEntryModel(
      id: json['id'] as String,
      journalNumber: json['journalNumber'] as String,
      date: json['date'] as String,
      sourceType: json['sourceType'] as String,
      sourceId: json['sourceId'] as String,
      description: json['description'] as String? ?? '',
      lines:
          (json['lines'] as List<dynamic>?)
              ?.map((e) => JournalLineModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      totalDebitCents: (json['totalDebitCents'] as num?)?.toInt() ?? 0,
      totalCreditCents: (json['totalCreditCents'] as num?)?.toInt() ?? 0,
      isBalanced: json['isBalanced'] as bool? ?? true,
      status: json['status'] as String? ?? 'posted',
      version: (json['version'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$JournalEntryModelToJson(_JournalEntryModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'journalNumber': instance.journalNumber,
      'date': instance.date,
      'sourceType': instance.sourceType,
      'sourceId': instance.sourceId,
      'description': instance.description,
      'lines': instance.lines.map((e) => e.toJson()).toList(),
      'totalDebitCents': instance.totalDebitCents,
      'totalCreditCents': instance.totalCreditCents,
      'isBalanced': instance.isBalanced,
      'status': instance.status,
      'version': instance.version,
    };
