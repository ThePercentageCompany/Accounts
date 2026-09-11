// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'accounting_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ShareholderModel {

 String get id; String get name; double get ownershipPercentage; double get agreedCapital; double get cashInvested; double get assetContributions; double get totalInvested; double get outstandingCapital; double get loanBalance; String get status; String get notes; int get version;
/// Create a copy of ShareholderModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShareholderModelCopyWith<ShareholderModel> get copyWith => _$ShareholderModelCopyWithImpl<ShareholderModel>(this as ShareholderModel, _$identity);

  /// Serializes this ShareholderModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShareholderModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.ownershipPercentage, ownershipPercentage) || other.ownershipPercentage == ownershipPercentage)&&(identical(other.agreedCapital, agreedCapital) || other.agreedCapital == agreedCapital)&&(identical(other.cashInvested, cashInvested) || other.cashInvested == cashInvested)&&(identical(other.assetContributions, assetContributions) || other.assetContributions == assetContributions)&&(identical(other.totalInvested, totalInvested) || other.totalInvested == totalInvested)&&(identical(other.outstandingCapital, outstandingCapital) || other.outstandingCapital == outstandingCapital)&&(identical(other.loanBalance, loanBalance) || other.loanBalance == loanBalance)&&(identical(other.status, status) || other.status == status)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,ownershipPercentage,agreedCapital,cashInvested,assetContributions,totalInvested,outstandingCapital,loanBalance,status,notes,version);

@override
String toString() {
  return 'ShareholderModel(id: $id, name: $name, ownershipPercentage: $ownershipPercentage, agreedCapital: $agreedCapital, cashInvested: $cashInvested, assetContributions: $assetContributions, totalInvested: $totalInvested, outstandingCapital: $outstandingCapital, loanBalance: $loanBalance, status: $status, notes: $notes, version: $version)';
}


}

/// @nodoc
abstract mixin class $ShareholderModelCopyWith<$Res>  {
  factory $ShareholderModelCopyWith(ShareholderModel value, $Res Function(ShareholderModel) _then) = _$ShareholderModelCopyWithImpl;
@useResult
$Res call({
 String id, String name, double ownershipPercentage, double agreedCapital, double cashInvested, double assetContributions, double totalInvested, double outstandingCapital, double loanBalance, String status, String notes, int version
});




}
/// @nodoc
class _$ShareholderModelCopyWithImpl<$Res>
    implements $ShareholderModelCopyWith<$Res> {
  _$ShareholderModelCopyWithImpl(this._self, this._then);

  final ShareholderModel _self;
  final $Res Function(ShareholderModel) _then;

/// Create a copy of ShareholderModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? ownershipPercentage = null,Object? agreedCapital = null,Object? cashInvested = null,Object? assetContributions = null,Object? totalInvested = null,Object? outstandingCapital = null,Object? loanBalance = null,Object? status = null,Object? notes = null,Object? version = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ownershipPercentage: null == ownershipPercentage ? _self.ownershipPercentage : ownershipPercentage // ignore: cast_nullable_to_non_nullable
as double,agreedCapital: null == agreedCapital ? _self.agreedCapital : agreedCapital // ignore: cast_nullable_to_non_nullable
as double,cashInvested: null == cashInvested ? _self.cashInvested : cashInvested // ignore: cast_nullable_to_non_nullable
as double,assetContributions: null == assetContributions ? _self.assetContributions : assetContributions // ignore: cast_nullable_to_non_nullable
as double,totalInvested: null == totalInvested ? _self.totalInvested : totalInvested // ignore: cast_nullable_to_non_nullable
as double,outstandingCapital: null == outstandingCapital ? _self.outstandingCapital : outstandingCapital // ignore: cast_nullable_to_non_nullable
as double,loanBalance: null == loanBalance ? _self.loanBalance : loanBalance // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ShareholderModel].
extension ShareholderModelPatterns on ShareholderModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShareholderModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShareholderModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShareholderModel value)  $default,){
final _that = this;
switch (_that) {
case _ShareholderModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShareholderModel value)?  $default,){
final _that = this;
switch (_that) {
case _ShareholderModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  double ownershipPercentage,  double agreedCapital,  double cashInvested,  double assetContributions,  double totalInvested,  double outstandingCapital,  double loanBalance,  String status,  String notes,  int version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShareholderModel() when $default != null:
return $default(_that.id,_that.name,_that.ownershipPercentage,_that.agreedCapital,_that.cashInvested,_that.assetContributions,_that.totalInvested,_that.outstandingCapital,_that.loanBalance,_that.status,_that.notes,_that.version);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  double ownershipPercentage,  double agreedCapital,  double cashInvested,  double assetContributions,  double totalInvested,  double outstandingCapital,  double loanBalance,  String status,  String notes,  int version)  $default,) {final _that = this;
switch (_that) {
case _ShareholderModel():
return $default(_that.id,_that.name,_that.ownershipPercentage,_that.agreedCapital,_that.cashInvested,_that.assetContributions,_that.totalInvested,_that.outstandingCapital,_that.loanBalance,_that.status,_that.notes,_that.version);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  double ownershipPercentage,  double agreedCapital,  double cashInvested,  double assetContributions,  double totalInvested,  double outstandingCapital,  double loanBalance,  String status,  String notes,  int version)?  $default,) {final _that = this;
switch (_that) {
case _ShareholderModel() when $default != null:
return $default(_that.id,_that.name,_that.ownershipPercentage,_that.agreedCapital,_that.cashInvested,_that.assetContributions,_that.totalInvested,_that.outstandingCapital,_that.loanBalance,_that.status,_that.notes,_that.version);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ShareholderModel implements ShareholderModel {
  const _ShareholderModel({required this.id, required this.name, this.ownershipPercentage = 0.0, this.agreedCapital = 0.0, this.cashInvested = 0.0, this.assetContributions = 0.0, this.totalInvested = 0.0, this.outstandingCapital = 0.0, this.loanBalance = 0.0, this.status = 'active', this.notes = '', this.version = 0});
  factory _ShareholderModel.fromJson(Map<String, dynamic> json) => _$ShareholderModelFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  double ownershipPercentage;
@override@JsonKey() final  double agreedCapital;
@override@JsonKey() final  double cashInvested;
@override@JsonKey() final  double assetContributions;
@override@JsonKey() final  double totalInvested;
@override@JsonKey() final  double outstandingCapital;
@override@JsonKey() final  double loanBalance;
@override@JsonKey() final  String status;
@override@JsonKey() final  String notes;
@override@JsonKey() final  int version;

/// Create a copy of ShareholderModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShareholderModelCopyWith<_ShareholderModel> get copyWith => __$ShareholderModelCopyWithImpl<_ShareholderModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShareholderModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShareholderModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.ownershipPercentage, ownershipPercentage) || other.ownershipPercentage == ownershipPercentage)&&(identical(other.agreedCapital, agreedCapital) || other.agreedCapital == agreedCapital)&&(identical(other.cashInvested, cashInvested) || other.cashInvested == cashInvested)&&(identical(other.assetContributions, assetContributions) || other.assetContributions == assetContributions)&&(identical(other.totalInvested, totalInvested) || other.totalInvested == totalInvested)&&(identical(other.outstandingCapital, outstandingCapital) || other.outstandingCapital == outstandingCapital)&&(identical(other.loanBalance, loanBalance) || other.loanBalance == loanBalance)&&(identical(other.status, status) || other.status == status)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,ownershipPercentage,agreedCapital,cashInvested,assetContributions,totalInvested,outstandingCapital,loanBalance,status,notes,version);

@override
String toString() {
  return 'ShareholderModel(id: $id, name: $name, ownershipPercentage: $ownershipPercentage, agreedCapital: $agreedCapital, cashInvested: $cashInvested, assetContributions: $assetContributions, totalInvested: $totalInvested, outstandingCapital: $outstandingCapital, loanBalance: $loanBalance, status: $status, notes: $notes, version: $version)';
}


}

/// @nodoc
abstract mixin class _$ShareholderModelCopyWith<$Res> implements $ShareholderModelCopyWith<$Res> {
  factory _$ShareholderModelCopyWith(_ShareholderModel value, $Res Function(_ShareholderModel) _then) = __$ShareholderModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, double ownershipPercentage, double agreedCapital, double cashInvested, double assetContributions, double totalInvested, double outstandingCapital, double loanBalance, String status, String notes, int version
});




}
/// @nodoc
class __$ShareholderModelCopyWithImpl<$Res>
    implements _$ShareholderModelCopyWith<$Res> {
  __$ShareholderModelCopyWithImpl(this._self, this._then);

  final _ShareholderModel _self;
  final $Res Function(_ShareholderModel) _then;

/// Create a copy of ShareholderModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? ownershipPercentage = null,Object? agreedCapital = null,Object? cashInvested = null,Object? assetContributions = null,Object? totalInvested = null,Object? outstandingCapital = null,Object? loanBalance = null,Object? status = null,Object? notes = null,Object? version = null,}) {
  return _then(_ShareholderModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,ownershipPercentage: null == ownershipPercentage ? _self.ownershipPercentage : ownershipPercentage // ignore: cast_nullable_to_non_nullable
as double,agreedCapital: null == agreedCapital ? _self.agreedCapital : agreedCapital // ignore: cast_nullable_to_non_nullable
as double,cashInvested: null == cashInvested ? _self.cashInvested : cashInvested // ignore: cast_nullable_to_non_nullable
as double,assetContributions: null == assetContributions ? _self.assetContributions : assetContributions // ignore: cast_nullable_to_non_nullable
as double,totalInvested: null == totalInvested ? _self.totalInvested : totalInvested // ignore: cast_nullable_to_non_nullable
as double,outstandingCapital: null == outstandingCapital ? _self.outstandingCapital : outstandingCapital // ignore: cast_nullable_to_non_nullable
as double,loanBalance: null == loanBalance ? _self.loanBalance : loanBalance // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$CapitalTransactionModel {

 String get id; String get shareholderId; String get shareholderName; String get date; String get transactionType;// capitalContribution, additionalCapital, capitalWithdrawal, equityAdjustment
 String get contributionType;// cash, bank, asset, other
 double get amount; int get amountCents; String? get assetId; String get bankAccountId;// Bank, Cash
 String get reference; String get notes; String get status;// posted, void, draft
 String get journalId; int get version;
/// Create a copy of CapitalTransactionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CapitalTransactionModelCopyWith<CapitalTransactionModel> get copyWith => _$CapitalTransactionModelCopyWithImpl<CapitalTransactionModel>(this as CapitalTransactionModel, _$identity);

  /// Serializes this CapitalTransactionModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CapitalTransactionModel&&(identical(other.id, id) || other.id == id)&&(identical(other.shareholderId, shareholderId) || other.shareholderId == shareholderId)&&(identical(other.shareholderName, shareholderName) || other.shareholderName == shareholderName)&&(identical(other.date, date) || other.date == date)&&(identical(other.transactionType, transactionType) || other.transactionType == transactionType)&&(identical(other.contributionType, contributionType) || other.contributionType == contributionType)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.assetId, assetId) || other.assetId == assetId)&&(identical(other.bankAccountId, bankAccountId) || other.bankAccountId == bankAccountId)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.status, status) || other.status == status)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,shareholderId,shareholderName,date,transactionType,contributionType,amount,amountCents,assetId,bankAccountId,reference,notes,status,journalId,version);

@override
String toString() {
  return 'CapitalTransactionModel(id: $id, shareholderId: $shareholderId, shareholderName: $shareholderName, date: $date, transactionType: $transactionType, contributionType: $contributionType, amount: $amount, amountCents: $amountCents, assetId: $assetId, bankAccountId: $bankAccountId, reference: $reference, notes: $notes, status: $status, journalId: $journalId, version: $version)';
}


}

/// @nodoc
abstract mixin class $CapitalTransactionModelCopyWith<$Res>  {
  factory $CapitalTransactionModelCopyWith(CapitalTransactionModel value, $Res Function(CapitalTransactionModel) _then) = _$CapitalTransactionModelCopyWithImpl;
@useResult
$Res call({
 String id, String shareholderId, String shareholderName, String date, String transactionType, String contributionType, double amount, int amountCents, String? assetId, String bankAccountId, String reference, String notes, String status, String journalId, int version
});




}
/// @nodoc
class _$CapitalTransactionModelCopyWithImpl<$Res>
    implements $CapitalTransactionModelCopyWith<$Res> {
  _$CapitalTransactionModelCopyWithImpl(this._self, this._then);

  final CapitalTransactionModel _self;
  final $Res Function(CapitalTransactionModel) _then;

/// Create a copy of CapitalTransactionModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? shareholderId = null,Object? shareholderName = null,Object? date = null,Object? transactionType = null,Object? contributionType = null,Object? amount = null,Object? amountCents = null,Object? assetId = freezed,Object? bankAccountId = null,Object? reference = null,Object? notes = null,Object? status = null,Object? journalId = null,Object? version = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,shareholderId: null == shareholderId ? _self.shareholderId : shareholderId // ignore: cast_nullable_to_non_nullable
as String,shareholderName: null == shareholderName ? _self.shareholderName : shareholderName // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,transactionType: null == transactionType ? _self.transactionType : transactionType // ignore: cast_nullable_to_non_nullable
as String,contributionType: null == contributionType ? _self.contributionType : contributionType // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,assetId: freezed == assetId ? _self.assetId : assetId // ignore: cast_nullable_to_non_nullable
as String?,bankAccountId: null == bankAccountId ? _self.bankAccountId : bankAccountId // ignore: cast_nullable_to_non_nullable
as String,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,journalId: null == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CapitalTransactionModel].
extension CapitalTransactionModelPatterns on CapitalTransactionModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CapitalTransactionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CapitalTransactionModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CapitalTransactionModel value)  $default,){
final _that = this;
switch (_that) {
case _CapitalTransactionModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CapitalTransactionModel value)?  $default,){
final _that = this;
switch (_that) {
case _CapitalTransactionModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String shareholderId,  String shareholderName,  String date,  String transactionType,  String contributionType,  double amount,  int amountCents,  String? assetId,  String bankAccountId,  String reference,  String notes,  String status,  String journalId,  int version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CapitalTransactionModel() when $default != null:
return $default(_that.id,_that.shareholderId,_that.shareholderName,_that.date,_that.transactionType,_that.contributionType,_that.amount,_that.amountCents,_that.assetId,_that.bankAccountId,_that.reference,_that.notes,_that.status,_that.journalId,_that.version);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String shareholderId,  String shareholderName,  String date,  String transactionType,  String contributionType,  double amount,  int amountCents,  String? assetId,  String bankAccountId,  String reference,  String notes,  String status,  String journalId,  int version)  $default,) {final _that = this;
switch (_that) {
case _CapitalTransactionModel():
return $default(_that.id,_that.shareholderId,_that.shareholderName,_that.date,_that.transactionType,_that.contributionType,_that.amount,_that.amountCents,_that.assetId,_that.bankAccountId,_that.reference,_that.notes,_that.status,_that.journalId,_that.version);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String shareholderId,  String shareholderName,  String date,  String transactionType,  String contributionType,  double amount,  int amountCents,  String? assetId,  String bankAccountId,  String reference,  String notes,  String status,  String journalId,  int version)?  $default,) {final _that = this;
switch (_that) {
case _CapitalTransactionModel() when $default != null:
return $default(_that.id,_that.shareholderId,_that.shareholderName,_that.date,_that.transactionType,_that.contributionType,_that.amount,_that.amountCents,_that.assetId,_that.bankAccountId,_that.reference,_that.notes,_that.status,_that.journalId,_that.version);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CapitalTransactionModel implements CapitalTransactionModel {
  const _CapitalTransactionModel({required this.id, required this.shareholderId, this.shareholderName = '', required this.date, this.transactionType = 'capitalContribution', this.contributionType = 'bank', this.amount = 0.0, this.amountCents = 0, this.assetId, this.bankAccountId = 'Bank', this.reference = '', this.notes = '', this.status = 'posted', this.journalId = '', this.version = 0});
  factory _CapitalTransactionModel.fromJson(Map<String, dynamic> json) => _$CapitalTransactionModelFromJson(json);

@override final  String id;
@override final  String shareholderId;
@override@JsonKey() final  String shareholderName;
@override final  String date;
@override@JsonKey() final  String transactionType;
// capitalContribution, additionalCapital, capitalWithdrawal, equityAdjustment
@override@JsonKey() final  String contributionType;
// cash, bank, asset, other
@override@JsonKey() final  double amount;
@override@JsonKey() final  int amountCents;
@override final  String? assetId;
@override@JsonKey() final  String bankAccountId;
// Bank, Cash
@override@JsonKey() final  String reference;
@override@JsonKey() final  String notes;
@override@JsonKey() final  String status;
// posted, void, draft
@override@JsonKey() final  String journalId;
@override@JsonKey() final  int version;

/// Create a copy of CapitalTransactionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CapitalTransactionModelCopyWith<_CapitalTransactionModel> get copyWith => __$CapitalTransactionModelCopyWithImpl<_CapitalTransactionModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CapitalTransactionModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CapitalTransactionModel&&(identical(other.id, id) || other.id == id)&&(identical(other.shareholderId, shareholderId) || other.shareholderId == shareholderId)&&(identical(other.shareholderName, shareholderName) || other.shareholderName == shareholderName)&&(identical(other.date, date) || other.date == date)&&(identical(other.transactionType, transactionType) || other.transactionType == transactionType)&&(identical(other.contributionType, contributionType) || other.contributionType == contributionType)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.assetId, assetId) || other.assetId == assetId)&&(identical(other.bankAccountId, bankAccountId) || other.bankAccountId == bankAccountId)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.status, status) || other.status == status)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,shareholderId,shareholderName,date,transactionType,contributionType,amount,amountCents,assetId,bankAccountId,reference,notes,status,journalId,version);

@override
String toString() {
  return 'CapitalTransactionModel(id: $id, shareholderId: $shareholderId, shareholderName: $shareholderName, date: $date, transactionType: $transactionType, contributionType: $contributionType, amount: $amount, amountCents: $amountCents, assetId: $assetId, bankAccountId: $bankAccountId, reference: $reference, notes: $notes, status: $status, journalId: $journalId, version: $version)';
}


}

/// @nodoc
abstract mixin class _$CapitalTransactionModelCopyWith<$Res> implements $CapitalTransactionModelCopyWith<$Res> {
  factory _$CapitalTransactionModelCopyWith(_CapitalTransactionModel value, $Res Function(_CapitalTransactionModel) _then) = __$CapitalTransactionModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String shareholderId, String shareholderName, String date, String transactionType, String contributionType, double amount, int amountCents, String? assetId, String bankAccountId, String reference, String notes, String status, String journalId, int version
});




}
/// @nodoc
class __$CapitalTransactionModelCopyWithImpl<$Res>
    implements _$CapitalTransactionModelCopyWith<$Res> {
  __$CapitalTransactionModelCopyWithImpl(this._self, this._then);

  final _CapitalTransactionModel _self;
  final $Res Function(_CapitalTransactionModel) _then;

/// Create a copy of CapitalTransactionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? shareholderId = null,Object? shareholderName = null,Object? date = null,Object? transactionType = null,Object? contributionType = null,Object? amount = null,Object? amountCents = null,Object? assetId = freezed,Object? bankAccountId = null,Object? reference = null,Object? notes = null,Object? status = null,Object? journalId = null,Object? version = null,}) {
  return _then(_CapitalTransactionModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,shareholderId: null == shareholderId ? _self.shareholderId : shareholderId // ignore: cast_nullable_to_non_nullable
as String,shareholderName: null == shareholderName ? _self.shareholderName : shareholderName // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,transactionType: null == transactionType ? _self.transactionType : transactionType // ignore: cast_nullable_to_non_nullable
as String,contributionType: null == contributionType ? _self.contributionType : contributionType // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,assetId: freezed == assetId ? _self.assetId : assetId // ignore: cast_nullable_to_non_nullable
as String?,bankAccountId: null == bankAccountId ? _self.bankAccountId : bankAccountId // ignore: cast_nullable_to_non_nullable
as String,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,journalId: null == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ShareholderLoanModel {

 String get id; String get shareholderId; String get shareholderName; String get date; String get type;// loanReceived, loanRepayment, loanAdjustment
 double get amount; int get amountCents; String get paymentAccount;// Bank, Cash
 String get reference; String get notes; String get status; String get journalId; int get version;
/// Create a copy of ShareholderLoanModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShareholderLoanModelCopyWith<ShareholderLoanModel> get copyWith => _$ShareholderLoanModelCopyWithImpl<ShareholderLoanModel>(this as ShareholderLoanModel, _$identity);

  /// Serializes this ShareholderLoanModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShareholderLoanModel&&(identical(other.id, id) || other.id == id)&&(identical(other.shareholderId, shareholderId) || other.shareholderId == shareholderId)&&(identical(other.shareholderName, shareholderName) || other.shareholderName == shareholderName)&&(identical(other.date, date) || other.date == date)&&(identical(other.type, type) || other.type == type)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.paymentAccount, paymentAccount) || other.paymentAccount == paymentAccount)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.status, status) || other.status == status)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,shareholderId,shareholderName,date,type,amount,amountCents,paymentAccount,reference,notes,status,journalId,version);

@override
String toString() {
  return 'ShareholderLoanModel(id: $id, shareholderId: $shareholderId, shareholderName: $shareholderName, date: $date, type: $type, amount: $amount, amountCents: $amountCents, paymentAccount: $paymentAccount, reference: $reference, notes: $notes, status: $status, journalId: $journalId, version: $version)';
}


}

/// @nodoc
abstract mixin class $ShareholderLoanModelCopyWith<$Res>  {
  factory $ShareholderLoanModelCopyWith(ShareholderLoanModel value, $Res Function(ShareholderLoanModel) _then) = _$ShareholderLoanModelCopyWithImpl;
@useResult
$Res call({
 String id, String shareholderId, String shareholderName, String date, String type, double amount, int amountCents, String paymentAccount, String reference, String notes, String status, String journalId, int version
});




}
/// @nodoc
class _$ShareholderLoanModelCopyWithImpl<$Res>
    implements $ShareholderLoanModelCopyWith<$Res> {
  _$ShareholderLoanModelCopyWithImpl(this._self, this._then);

  final ShareholderLoanModel _self;
  final $Res Function(ShareholderLoanModel) _then;

/// Create a copy of ShareholderLoanModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? shareholderId = null,Object? shareholderName = null,Object? date = null,Object? type = null,Object? amount = null,Object? amountCents = null,Object? paymentAccount = null,Object? reference = null,Object? notes = null,Object? status = null,Object? journalId = null,Object? version = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,shareholderId: null == shareholderId ? _self.shareholderId : shareholderId // ignore: cast_nullable_to_non_nullable
as String,shareholderName: null == shareholderName ? _self.shareholderName : shareholderName // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,paymentAccount: null == paymentAccount ? _self.paymentAccount : paymentAccount // ignore: cast_nullable_to_non_nullable
as String,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,journalId: null == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ShareholderLoanModel].
extension ShareholderLoanModelPatterns on ShareholderLoanModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShareholderLoanModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShareholderLoanModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShareholderLoanModel value)  $default,){
final _that = this;
switch (_that) {
case _ShareholderLoanModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShareholderLoanModel value)?  $default,){
final _that = this;
switch (_that) {
case _ShareholderLoanModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String shareholderId,  String shareholderName,  String date,  String type,  double amount,  int amountCents,  String paymentAccount,  String reference,  String notes,  String status,  String journalId,  int version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShareholderLoanModel() when $default != null:
return $default(_that.id,_that.shareholderId,_that.shareholderName,_that.date,_that.type,_that.amount,_that.amountCents,_that.paymentAccount,_that.reference,_that.notes,_that.status,_that.journalId,_that.version);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String shareholderId,  String shareholderName,  String date,  String type,  double amount,  int amountCents,  String paymentAccount,  String reference,  String notes,  String status,  String journalId,  int version)  $default,) {final _that = this;
switch (_that) {
case _ShareholderLoanModel():
return $default(_that.id,_that.shareholderId,_that.shareholderName,_that.date,_that.type,_that.amount,_that.amountCents,_that.paymentAccount,_that.reference,_that.notes,_that.status,_that.journalId,_that.version);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String shareholderId,  String shareholderName,  String date,  String type,  double amount,  int amountCents,  String paymentAccount,  String reference,  String notes,  String status,  String journalId,  int version)?  $default,) {final _that = this;
switch (_that) {
case _ShareholderLoanModel() when $default != null:
return $default(_that.id,_that.shareholderId,_that.shareholderName,_that.date,_that.type,_that.amount,_that.amountCents,_that.paymentAccount,_that.reference,_that.notes,_that.status,_that.journalId,_that.version);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ShareholderLoanModel implements ShareholderLoanModel {
  const _ShareholderLoanModel({required this.id, required this.shareholderId, this.shareholderName = '', required this.date, this.type = 'loanReceived', this.amount = 0.0, this.amountCents = 0, this.paymentAccount = 'Bank', this.reference = '', this.notes = '', this.status = 'posted', this.journalId = '', this.version = 0});
  factory _ShareholderLoanModel.fromJson(Map<String, dynamic> json) => _$ShareholderLoanModelFromJson(json);

@override final  String id;
@override final  String shareholderId;
@override@JsonKey() final  String shareholderName;
@override final  String date;
@override@JsonKey() final  String type;
// loanReceived, loanRepayment, loanAdjustment
@override@JsonKey() final  double amount;
@override@JsonKey() final  int amountCents;
@override@JsonKey() final  String paymentAccount;
// Bank, Cash
@override@JsonKey() final  String reference;
@override@JsonKey() final  String notes;
@override@JsonKey() final  String status;
@override@JsonKey() final  String journalId;
@override@JsonKey() final  int version;

/// Create a copy of ShareholderLoanModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShareholderLoanModelCopyWith<_ShareholderLoanModel> get copyWith => __$ShareholderLoanModelCopyWithImpl<_ShareholderLoanModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShareholderLoanModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShareholderLoanModel&&(identical(other.id, id) || other.id == id)&&(identical(other.shareholderId, shareholderId) || other.shareholderId == shareholderId)&&(identical(other.shareholderName, shareholderName) || other.shareholderName == shareholderName)&&(identical(other.date, date) || other.date == date)&&(identical(other.type, type) || other.type == type)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.paymentAccount, paymentAccount) || other.paymentAccount == paymentAccount)&&(identical(other.reference, reference) || other.reference == reference)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.status, status) || other.status == status)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,shareholderId,shareholderName,date,type,amount,amountCents,paymentAccount,reference,notes,status,journalId,version);

@override
String toString() {
  return 'ShareholderLoanModel(id: $id, shareholderId: $shareholderId, shareholderName: $shareholderName, date: $date, type: $type, amount: $amount, amountCents: $amountCents, paymentAccount: $paymentAccount, reference: $reference, notes: $notes, status: $status, journalId: $journalId, version: $version)';
}


}

/// @nodoc
abstract mixin class _$ShareholderLoanModelCopyWith<$Res> implements $ShareholderLoanModelCopyWith<$Res> {
  factory _$ShareholderLoanModelCopyWith(_ShareholderLoanModel value, $Res Function(_ShareholderLoanModel) _then) = __$ShareholderLoanModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String shareholderId, String shareholderName, String date, String type, double amount, int amountCents, String paymentAccount, String reference, String notes, String status, String journalId, int version
});




}
/// @nodoc
class __$ShareholderLoanModelCopyWithImpl<$Res>
    implements _$ShareholderLoanModelCopyWith<$Res> {
  __$ShareholderLoanModelCopyWithImpl(this._self, this._then);

  final _ShareholderLoanModel _self;
  final $Res Function(_ShareholderLoanModel) _then;

/// Create a copy of ShareholderLoanModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? shareholderId = null,Object? shareholderName = null,Object? date = null,Object? type = null,Object? amount = null,Object? amountCents = null,Object? paymentAccount = null,Object? reference = null,Object? notes = null,Object? status = null,Object? journalId = null,Object? version = null,}) {
  return _then(_ShareholderLoanModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,shareholderId: null == shareholderId ? _self.shareholderId : shareholderId // ignore: cast_nullable_to_non_nullable
as String,shareholderName: null == shareholderName ? _self.shareholderName : shareholderName // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,paymentAccount: null == paymentAccount ? _self.paymentAccount : paymentAccount // ignore: cast_nullable_to_non_nullable
as String,reference: null == reference ? _self.reference : reference // ignore: cast_nullable_to_non_nullable
as String,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,journalId: null == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$AssetRecordModel {

 String get id; String get code; String get name; String get category; String get acquisitionType;// companyPurchase, shareholderContribution, openingBalance
 String get purchaseDate; double get cost; int get costCents; double get vatAmount; String get supplier; String get paymentAccount; String get shareholderId; String get shareholderName; String get location; String get assignedEmployeeId; String get assignedEmployeeName; String get serialNumber; String get warrantyExpiry; String get depreciationMethod; int get usefulLifeMonths; double get residualValue; double get accumulatedDepreciation; int get accumulatedDepreciationCents; double get bookValue; int get bookValueCents; String get status;// active, maintenance, damaged, lost, sold, disposed
 String? get disposalDate; String? get disposalType; double? get salePrice; double? get gainLoss; String get notes; String get journalId; int get version;
/// Create a copy of AssetRecordModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssetRecordModelCopyWith<AssetRecordModel> get copyWith => _$AssetRecordModelCopyWithImpl<AssetRecordModel>(this as AssetRecordModel, _$identity);

  /// Serializes this AssetRecordModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssetRecordModel&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.acquisitionType, acquisitionType) || other.acquisitionType == acquisitionType)&&(identical(other.purchaseDate, purchaseDate) || other.purchaseDate == purchaseDate)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.costCents, costCents) || other.costCents == costCents)&&(identical(other.vatAmount, vatAmount) || other.vatAmount == vatAmount)&&(identical(other.supplier, supplier) || other.supplier == supplier)&&(identical(other.paymentAccount, paymentAccount) || other.paymentAccount == paymentAccount)&&(identical(other.shareholderId, shareholderId) || other.shareholderId == shareholderId)&&(identical(other.shareholderName, shareholderName) || other.shareholderName == shareholderName)&&(identical(other.location, location) || other.location == location)&&(identical(other.assignedEmployeeId, assignedEmployeeId) || other.assignedEmployeeId == assignedEmployeeId)&&(identical(other.assignedEmployeeName, assignedEmployeeName) || other.assignedEmployeeName == assignedEmployeeName)&&(identical(other.serialNumber, serialNumber) || other.serialNumber == serialNumber)&&(identical(other.warrantyExpiry, warrantyExpiry) || other.warrantyExpiry == warrantyExpiry)&&(identical(other.depreciationMethod, depreciationMethod) || other.depreciationMethod == depreciationMethod)&&(identical(other.usefulLifeMonths, usefulLifeMonths) || other.usefulLifeMonths == usefulLifeMonths)&&(identical(other.residualValue, residualValue) || other.residualValue == residualValue)&&(identical(other.accumulatedDepreciation, accumulatedDepreciation) || other.accumulatedDepreciation == accumulatedDepreciation)&&(identical(other.accumulatedDepreciationCents, accumulatedDepreciationCents) || other.accumulatedDepreciationCents == accumulatedDepreciationCents)&&(identical(other.bookValue, bookValue) || other.bookValue == bookValue)&&(identical(other.bookValueCents, bookValueCents) || other.bookValueCents == bookValueCents)&&(identical(other.status, status) || other.status == status)&&(identical(other.disposalDate, disposalDate) || other.disposalDate == disposalDate)&&(identical(other.disposalType, disposalType) || other.disposalType == disposalType)&&(identical(other.salePrice, salePrice) || other.salePrice == salePrice)&&(identical(other.gainLoss, gainLoss) || other.gainLoss == gainLoss)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,code,name,category,acquisitionType,purchaseDate,cost,costCents,vatAmount,supplier,paymentAccount,shareholderId,shareholderName,location,assignedEmployeeId,assignedEmployeeName,serialNumber,warrantyExpiry,depreciationMethod,usefulLifeMonths,residualValue,accumulatedDepreciation,accumulatedDepreciationCents,bookValue,bookValueCents,status,disposalDate,disposalType,salePrice,gainLoss,notes,journalId,version]);

@override
String toString() {
  return 'AssetRecordModel(id: $id, code: $code, name: $name, category: $category, acquisitionType: $acquisitionType, purchaseDate: $purchaseDate, cost: $cost, costCents: $costCents, vatAmount: $vatAmount, supplier: $supplier, paymentAccount: $paymentAccount, shareholderId: $shareholderId, shareholderName: $shareholderName, location: $location, assignedEmployeeId: $assignedEmployeeId, assignedEmployeeName: $assignedEmployeeName, serialNumber: $serialNumber, warrantyExpiry: $warrantyExpiry, depreciationMethod: $depreciationMethod, usefulLifeMonths: $usefulLifeMonths, residualValue: $residualValue, accumulatedDepreciation: $accumulatedDepreciation, accumulatedDepreciationCents: $accumulatedDepreciationCents, bookValue: $bookValue, bookValueCents: $bookValueCents, status: $status, disposalDate: $disposalDate, disposalType: $disposalType, salePrice: $salePrice, gainLoss: $gainLoss, notes: $notes, journalId: $journalId, version: $version)';
}


}

/// @nodoc
abstract mixin class $AssetRecordModelCopyWith<$Res>  {
  factory $AssetRecordModelCopyWith(AssetRecordModel value, $Res Function(AssetRecordModel) _then) = _$AssetRecordModelCopyWithImpl;
@useResult
$Res call({
 String id, String code, String name, String category, String acquisitionType, String purchaseDate, double cost, int costCents, double vatAmount, String supplier, String paymentAccount, String shareholderId, String shareholderName, String location, String assignedEmployeeId, String assignedEmployeeName, String serialNumber, String warrantyExpiry, String depreciationMethod, int usefulLifeMonths, double residualValue, double accumulatedDepreciation, int accumulatedDepreciationCents, double bookValue, int bookValueCents, String status, String? disposalDate, String? disposalType, double? salePrice, double? gainLoss, String notes, String journalId, int version
});




}
/// @nodoc
class _$AssetRecordModelCopyWithImpl<$Res>
    implements $AssetRecordModelCopyWith<$Res> {
  _$AssetRecordModelCopyWithImpl(this._self, this._then);

  final AssetRecordModel _self;
  final $Res Function(AssetRecordModel) _then;

/// Create a copy of AssetRecordModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? code = null,Object? name = null,Object? category = null,Object? acquisitionType = null,Object? purchaseDate = null,Object? cost = null,Object? costCents = null,Object? vatAmount = null,Object? supplier = null,Object? paymentAccount = null,Object? shareholderId = null,Object? shareholderName = null,Object? location = null,Object? assignedEmployeeId = null,Object? assignedEmployeeName = null,Object? serialNumber = null,Object? warrantyExpiry = null,Object? depreciationMethod = null,Object? usefulLifeMonths = null,Object? residualValue = null,Object? accumulatedDepreciation = null,Object? accumulatedDepreciationCents = null,Object? bookValue = null,Object? bookValueCents = null,Object? status = null,Object? disposalDate = freezed,Object? disposalType = freezed,Object? salePrice = freezed,Object? gainLoss = freezed,Object? notes = null,Object? journalId = null,Object? version = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,acquisitionType: null == acquisitionType ? _self.acquisitionType : acquisitionType // ignore: cast_nullable_to_non_nullable
as String,purchaseDate: null == purchaseDate ? _self.purchaseDate : purchaseDate // ignore: cast_nullable_to_non_nullable
as String,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double,costCents: null == costCents ? _self.costCents : costCents // ignore: cast_nullable_to_non_nullable
as int,vatAmount: null == vatAmount ? _self.vatAmount : vatAmount // ignore: cast_nullable_to_non_nullable
as double,supplier: null == supplier ? _self.supplier : supplier // ignore: cast_nullable_to_non_nullable
as String,paymentAccount: null == paymentAccount ? _self.paymentAccount : paymentAccount // ignore: cast_nullable_to_non_nullable
as String,shareholderId: null == shareholderId ? _self.shareholderId : shareholderId // ignore: cast_nullable_to_non_nullable
as String,shareholderName: null == shareholderName ? _self.shareholderName : shareholderName // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,assignedEmployeeId: null == assignedEmployeeId ? _self.assignedEmployeeId : assignedEmployeeId // ignore: cast_nullable_to_non_nullable
as String,assignedEmployeeName: null == assignedEmployeeName ? _self.assignedEmployeeName : assignedEmployeeName // ignore: cast_nullable_to_non_nullable
as String,serialNumber: null == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as String,warrantyExpiry: null == warrantyExpiry ? _self.warrantyExpiry : warrantyExpiry // ignore: cast_nullable_to_non_nullable
as String,depreciationMethod: null == depreciationMethod ? _self.depreciationMethod : depreciationMethod // ignore: cast_nullable_to_non_nullable
as String,usefulLifeMonths: null == usefulLifeMonths ? _self.usefulLifeMonths : usefulLifeMonths // ignore: cast_nullable_to_non_nullable
as int,residualValue: null == residualValue ? _self.residualValue : residualValue // ignore: cast_nullable_to_non_nullable
as double,accumulatedDepreciation: null == accumulatedDepreciation ? _self.accumulatedDepreciation : accumulatedDepreciation // ignore: cast_nullable_to_non_nullable
as double,accumulatedDepreciationCents: null == accumulatedDepreciationCents ? _self.accumulatedDepreciationCents : accumulatedDepreciationCents // ignore: cast_nullable_to_non_nullable
as int,bookValue: null == bookValue ? _self.bookValue : bookValue // ignore: cast_nullable_to_non_nullable
as double,bookValueCents: null == bookValueCents ? _self.bookValueCents : bookValueCents // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,disposalDate: freezed == disposalDate ? _self.disposalDate : disposalDate // ignore: cast_nullable_to_non_nullable
as String?,disposalType: freezed == disposalType ? _self.disposalType : disposalType // ignore: cast_nullable_to_non_nullable
as String?,salePrice: freezed == salePrice ? _self.salePrice : salePrice // ignore: cast_nullable_to_non_nullable
as double?,gainLoss: freezed == gainLoss ? _self.gainLoss : gainLoss // ignore: cast_nullable_to_non_nullable
as double?,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,journalId: null == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AssetRecordModel].
extension AssetRecordModelPatterns on AssetRecordModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssetRecordModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssetRecordModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssetRecordModel value)  $default,){
final _that = this;
switch (_that) {
case _AssetRecordModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssetRecordModel value)?  $default,){
final _that = this;
switch (_that) {
case _AssetRecordModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String code,  String name,  String category,  String acquisitionType,  String purchaseDate,  double cost,  int costCents,  double vatAmount,  String supplier,  String paymentAccount,  String shareholderId,  String shareholderName,  String location,  String assignedEmployeeId,  String assignedEmployeeName,  String serialNumber,  String warrantyExpiry,  String depreciationMethod,  int usefulLifeMonths,  double residualValue,  double accumulatedDepreciation,  int accumulatedDepreciationCents,  double bookValue,  int bookValueCents,  String status,  String? disposalDate,  String? disposalType,  double? salePrice,  double? gainLoss,  String notes,  String journalId,  int version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssetRecordModel() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.category,_that.acquisitionType,_that.purchaseDate,_that.cost,_that.costCents,_that.vatAmount,_that.supplier,_that.paymentAccount,_that.shareholderId,_that.shareholderName,_that.location,_that.assignedEmployeeId,_that.assignedEmployeeName,_that.serialNumber,_that.warrantyExpiry,_that.depreciationMethod,_that.usefulLifeMonths,_that.residualValue,_that.accumulatedDepreciation,_that.accumulatedDepreciationCents,_that.bookValue,_that.bookValueCents,_that.status,_that.disposalDate,_that.disposalType,_that.salePrice,_that.gainLoss,_that.notes,_that.journalId,_that.version);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String code,  String name,  String category,  String acquisitionType,  String purchaseDate,  double cost,  int costCents,  double vatAmount,  String supplier,  String paymentAccount,  String shareholderId,  String shareholderName,  String location,  String assignedEmployeeId,  String assignedEmployeeName,  String serialNumber,  String warrantyExpiry,  String depreciationMethod,  int usefulLifeMonths,  double residualValue,  double accumulatedDepreciation,  int accumulatedDepreciationCents,  double bookValue,  int bookValueCents,  String status,  String? disposalDate,  String? disposalType,  double? salePrice,  double? gainLoss,  String notes,  String journalId,  int version)  $default,) {final _that = this;
switch (_that) {
case _AssetRecordModel():
return $default(_that.id,_that.code,_that.name,_that.category,_that.acquisitionType,_that.purchaseDate,_that.cost,_that.costCents,_that.vatAmount,_that.supplier,_that.paymentAccount,_that.shareholderId,_that.shareholderName,_that.location,_that.assignedEmployeeId,_that.assignedEmployeeName,_that.serialNumber,_that.warrantyExpiry,_that.depreciationMethod,_that.usefulLifeMonths,_that.residualValue,_that.accumulatedDepreciation,_that.accumulatedDepreciationCents,_that.bookValue,_that.bookValueCents,_that.status,_that.disposalDate,_that.disposalType,_that.salePrice,_that.gainLoss,_that.notes,_that.journalId,_that.version);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String code,  String name,  String category,  String acquisitionType,  String purchaseDate,  double cost,  int costCents,  double vatAmount,  String supplier,  String paymentAccount,  String shareholderId,  String shareholderName,  String location,  String assignedEmployeeId,  String assignedEmployeeName,  String serialNumber,  String warrantyExpiry,  String depreciationMethod,  int usefulLifeMonths,  double residualValue,  double accumulatedDepreciation,  int accumulatedDepreciationCents,  double bookValue,  int bookValueCents,  String status,  String? disposalDate,  String? disposalType,  double? salePrice,  double? gainLoss,  String notes,  String journalId,  int version)?  $default,) {final _that = this;
switch (_that) {
case _AssetRecordModel() when $default != null:
return $default(_that.id,_that.code,_that.name,_that.category,_that.acquisitionType,_that.purchaseDate,_that.cost,_that.costCents,_that.vatAmount,_that.supplier,_that.paymentAccount,_that.shareholderId,_that.shareholderName,_that.location,_that.assignedEmployeeId,_that.assignedEmployeeName,_that.serialNumber,_that.warrantyExpiry,_that.depreciationMethod,_that.usefulLifeMonths,_that.residualValue,_that.accumulatedDepreciation,_that.accumulatedDepreciationCents,_that.bookValue,_that.bookValueCents,_that.status,_that.disposalDate,_that.disposalType,_that.salePrice,_that.gainLoss,_that.notes,_that.journalId,_that.version);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AssetRecordModel implements AssetRecordModel {
  const _AssetRecordModel({required this.id, this.code = '', required this.name, this.category = 'Computers & IT Equipment', this.acquisitionType = 'companyPurchase', required this.purchaseDate, this.cost = 0.0, this.costCents = 0, this.vatAmount = 0.0, this.supplier = '', this.paymentAccount = 'Bank', this.shareholderId = '', this.shareholderName = '', this.location = 'Main Office', this.assignedEmployeeId = '', this.assignedEmployeeName = '', this.serialNumber = '', this.warrantyExpiry = '', this.depreciationMethod = 'straightLine', this.usefulLifeMonths = 36, this.residualValue = 0.0, this.accumulatedDepreciation = 0.0, this.accumulatedDepreciationCents = 0, this.bookValue = 0.0, this.bookValueCents = 0, this.status = 'active', this.disposalDate, this.disposalType, this.salePrice, this.gainLoss, this.notes = '', this.journalId = '', this.version = 0});
  factory _AssetRecordModel.fromJson(Map<String, dynamic> json) => _$AssetRecordModelFromJson(json);

@override final  String id;
@override@JsonKey() final  String code;
@override final  String name;
@override@JsonKey() final  String category;
@override@JsonKey() final  String acquisitionType;
// companyPurchase, shareholderContribution, openingBalance
@override final  String purchaseDate;
@override@JsonKey() final  double cost;
@override@JsonKey() final  int costCents;
@override@JsonKey() final  double vatAmount;
@override@JsonKey() final  String supplier;
@override@JsonKey() final  String paymentAccount;
@override@JsonKey() final  String shareholderId;
@override@JsonKey() final  String shareholderName;
@override@JsonKey() final  String location;
@override@JsonKey() final  String assignedEmployeeId;
@override@JsonKey() final  String assignedEmployeeName;
@override@JsonKey() final  String serialNumber;
@override@JsonKey() final  String warrantyExpiry;
@override@JsonKey() final  String depreciationMethod;
@override@JsonKey() final  int usefulLifeMonths;
@override@JsonKey() final  double residualValue;
@override@JsonKey() final  double accumulatedDepreciation;
@override@JsonKey() final  int accumulatedDepreciationCents;
@override@JsonKey() final  double bookValue;
@override@JsonKey() final  int bookValueCents;
@override@JsonKey() final  String status;
// active, maintenance, damaged, lost, sold, disposed
@override final  String? disposalDate;
@override final  String? disposalType;
@override final  double? salePrice;
@override final  double? gainLoss;
@override@JsonKey() final  String notes;
@override@JsonKey() final  String journalId;
@override@JsonKey() final  int version;

/// Create a copy of AssetRecordModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssetRecordModelCopyWith<_AssetRecordModel> get copyWith => __$AssetRecordModelCopyWithImpl<_AssetRecordModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssetRecordModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssetRecordModel&&(identical(other.id, id) || other.id == id)&&(identical(other.code, code) || other.code == code)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.acquisitionType, acquisitionType) || other.acquisitionType == acquisitionType)&&(identical(other.purchaseDate, purchaseDate) || other.purchaseDate == purchaseDate)&&(identical(other.cost, cost) || other.cost == cost)&&(identical(other.costCents, costCents) || other.costCents == costCents)&&(identical(other.vatAmount, vatAmount) || other.vatAmount == vatAmount)&&(identical(other.supplier, supplier) || other.supplier == supplier)&&(identical(other.paymentAccount, paymentAccount) || other.paymentAccount == paymentAccount)&&(identical(other.shareholderId, shareholderId) || other.shareholderId == shareholderId)&&(identical(other.shareholderName, shareholderName) || other.shareholderName == shareholderName)&&(identical(other.location, location) || other.location == location)&&(identical(other.assignedEmployeeId, assignedEmployeeId) || other.assignedEmployeeId == assignedEmployeeId)&&(identical(other.assignedEmployeeName, assignedEmployeeName) || other.assignedEmployeeName == assignedEmployeeName)&&(identical(other.serialNumber, serialNumber) || other.serialNumber == serialNumber)&&(identical(other.warrantyExpiry, warrantyExpiry) || other.warrantyExpiry == warrantyExpiry)&&(identical(other.depreciationMethod, depreciationMethod) || other.depreciationMethod == depreciationMethod)&&(identical(other.usefulLifeMonths, usefulLifeMonths) || other.usefulLifeMonths == usefulLifeMonths)&&(identical(other.residualValue, residualValue) || other.residualValue == residualValue)&&(identical(other.accumulatedDepreciation, accumulatedDepreciation) || other.accumulatedDepreciation == accumulatedDepreciation)&&(identical(other.accumulatedDepreciationCents, accumulatedDepreciationCents) || other.accumulatedDepreciationCents == accumulatedDepreciationCents)&&(identical(other.bookValue, bookValue) || other.bookValue == bookValue)&&(identical(other.bookValueCents, bookValueCents) || other.bookValueCents == bookValueCents)&&(identical(other.status, status) || other.status == status)&&(identical(other.disposalDate, disposalDate) || other.disposalDate == disposalDate)&&(identical(other.disposalType, disposalType) || other.disposalType == disposalType)&&(identical(other.salePrice, salePrice) || other.salePrice == salePrice)&&(identical(other.gainLoss, gainLoss) || other.gainLoss == gainLoss)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.journalId, journalId) || other.journalId == journalId)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,code,name,category,acquisitionType,purchaseDate,cost,costCents,vatAmount,supplier,paymentAccount,shareholderId,shareholderName,location,assignedEmployeeId,assignedEmployeeName,serialNumber,warrantyExpiry,depreciationMethod,usefulLifeMonths,residualValue,accumulatedDepreciation,accumulatedDepreciationCents,bookValue,bookValueCents,status,disposalDate,disposalType,salePrice,gainLoss,notes,journalId,version]);

@override
String toString() {
  return 'AssetRecordModel(id: $id, code: $code, name: $name, category: $category, acquisitionType: $acquisitionType, purchaseDate: $purchaseDate, cost: $cost, costCents: $costCents, vatAmount: $vatAmount, supplier: $supplier, paymentAccount: $paymentAccount, shareholderId: $shareholderId, shareholderName: $shareholderName, location: $location, assignedEmployeeId: $assignedEmployeeId, assignedEmployeeName: $assignedEmployeeName, serialNumber: $serialNumber, warrantyExpiry: $warrantyExpiry, depreciationMethod: $depreciationMethod, usefulLifeMonths: $usefulLifeMonths, residualValue: $residualValue, accumulatedDepreciation: $accumulatedDepreciation, accumulatedDepreciationCents: $accumulatedDepreciationCents, bookValue: $bookValue, bookValueCents: $bookValueCents, status: $status, disposalDate: $disposalDate, disposalType: $disposalType, salePrice: $salePrice, gainLoss: $gainLoss, notes: $notes, journalId: $journalId, version: $version)';
}


}

/// @nodoc
abstract mixin class _$AssetRecordModelCopyWith<$Res> implements $AssetRecordModelCopyWith<$Res> {
  factory _$AssetRecordModelCopyWith(_AssetRecordModel value, $Res Function(_AssetRecordModel) _then) = __$AssetRecordModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String code, String name, String category, String acquisitionType, String purchaseDate, double cost, int costCents, double vatAmount, String supplier, String paymentAccount, String shareholderId, String shareholderName, String location, String assignedEmployeeId, String assignedEmployeeName, String serialNumber, String warrantyExpiry, String depreciationMethod, int usefulLifeMonths, double residualValue, double accumulatedDepreciation, int accumulatedDepreciationCents, double bookValue, int bookValueCents, String status, String? disposalDate, String? disposalType, double? salePrice, double? gainLoss, String notes, String journalId, int version
});




}
/// @nodoc
class __$AssetRecordModelCopyWithImpl<$Res>
    implements _$AssetRecordModelCopyWith<$Res> {
  __$AssetRecordModelCopyWithImpl(this._self, this._then);

  final _AssetRecordModel _self;
  final $Res Function(_AssetRecordModel) _then;

/// Create a copy of AssetRecordModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? code = null,Object? name = null,Object? category = null,Object? acquisitionType = null,Object? purchaseDate = null,Object? cost = null,Object? costCents = null,Object? vatAmount = null,Object? supplier = null,Object? paymentAccount = null,Object? shareholderId = null,Object? shareholderName = null,Object? location = null,Object? assignedEmployeeId = null,Object? assignedEmployeeName = null,Object? serialNumber = null,Object? warrantyExpiry = null,Object? depreciationMethod = null,Object? usefulLifeMonths = null,Object? residualValue = null,Object? accumulatedDepreciation = null,Object? accumulatedDepreciationCents = null,Object? bookValue = null,Object? bookValueCents = null,Object? status = null,Object? disposalDate = freezed,Object? disposalType = freezed,Object? salePrice = freezed,Object? gainLoss = freezed,Object? notes = null,Object? journalId = null,Object? version = null,}) {
  return _then(_AssetRecordModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,acquisitionType: null == acquisitionType ? _self.acquisitionType : acquisitionType // ignore: cast_nullable_to_non_nullable
as String,purchaseDate: null == purchaseDate ? _self.purchaseDate : purchaseDate // ignore: cast_nullable_to_non_nullable
as String,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as double,costCents: null == costCents ? _self.costCents : costCents // ignore: cast_nullable_to_non_nullable
as int,vatAmount: null == vatAmount ? _self.vatAmount : vatAmount // ignore: cast_nullable_to_non_nullable
as double,supplier: null == supplier ? _self.supplier : supplier // ignore: cast_nullable_to_non_nullable
as String,paymentAccount: null == paymentAccount ? _self.paymentAccount : paymentAccount // ignore: cast_nullable_to_non_nullable
as String,shareholderId: null == shareholderId ? _self.shareholderId : shareholderId // ignore: cast_nullable_to_non_nullable
as String,shareholderName: null == shareholderName ? _self.shareholderName : shareholderName // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,assignedEmployeeId: null == assignedEmployeeId ? _self.assignedEmployeeId : assignedEmployeeId // ignore: cast_nullable_to_non_nullable
as String,assignedEmployeeName: null == assignedEmployeeName ? _self.assignedEmployeeName : assignedEmployeeName // ignore: cast_nullable_to_non_nullable
as String,serialNumber: null == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as String,warrantyExpiry: null == warrantyExpiry ? _self.warrantyExpiry : warrantyExpiry // ignore: cast_nullable_to_non_nullable
as String,depreciationMethod: null == depreciationMethod ? _self.depreciationMethod : depreciationMethod // ignore: cast_nullable_to_non_nullable
as String,usefulLifeMonths: null == usefulLifeMonths ? _self.usefulLifeMonths : usefulLifeMonths // ignore: cast_nullable_to_non_nullable
as int,residualValue: null == residualValue ? _self.residualValue : residualValue // ignore: cast_nullable_to_non_nullable
as double,accumulatedDepreciation: null == accumulatedDepreciation ? _self.accumulatedDepreciation : accumulatedDepreciation // ignore: cast_nullable_to_non_nullable
as double,accumulatedDepreciationCents: null == accumulatedDepreciationCents ? _self.accumulatedDepreciationCents : accumulatedDepreciationCents // ignore: cast_nullable_to_non_nullable
as int,bookValue: null == bookValue ? _self.bookValue : bookValue // ignore: cast_nullable_to_non_nullable
as double,bookValueCents: null == bookValueCents ? _self.bookValueCents : bookValueCents // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,disposalDate: freezed == disposalDate ? _self.disposalDate : disposalDate // ignore: cast_nullable_to_non_nullable
as String?,disposalType: freezed == disposalType ? _self.disposalType : disposalType // ignore: cast_nullable_to_non_nullable
as String?,salePrice: freezed == salePrice ? _self.salePrice : salePrice // ignore: cast_nullable_to_non_nullable
as double?,gainLoss: freezed == gainLoss ? _self.gainLoss : gainLoss // ignore: cast_nullable_to_non_nullable
as double?,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,journalId: null == journalId ? _self.journalId : journalId // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$JournalLineModel {

 String get accountId; String get accountName; String get accountGroup;// Asset, Liability, Equity, Income, Expense
 int get debitCents; int get creditCents; String get notes; String? get shareholderId; String? get assetId;
/// Create a copy of JournalLineModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JournalLineModelCopyWith<JournalLineModel> get copyWith => _$JournalLineModelCopyWithImpl<JournalLineModel>(this as JournalLineModel, _$identity);

  /// Serializes this JournalLineModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalLineModel&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.accountName, accountName) || other.accountName == accountName)&&(identical(other.accountGroup, accountGroup) || other.accountGroup == accountGroup)&&(identical(other.debitCents, debitCents) || other.debitCents == debitCents)&&(identical(other.creditCents, creditCents) || other.creditCents == creditCents)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.shareholderId, shareholderId) || other.shareholderId == shareholderId)&&(identical(other.assetId, assetId) || other.assetId == assetId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountId,accountName,accountGroup,debitCents,creditCents,notes,shareholderId,assetId);

@override
String toString() {
  return 'JournalLineModel(accountId: $accountId, accountName: $accountName, accountGroup: $accountGroup, debitCents: $debitCents, creditCents: $creditCents, notes: $notes, shareholderId: $shareholderId, assetId: $assetId)';
}


}

/// @nodoc
abstract mixin class $JournalLineModelCopyWith<$Res>  {
  factory $JournalLineModelCopyWith(JournalLineModel value, $Res Function(JournalLineModel) _then) = _$JournalLineModelCopyWithImpl;
@useResult
$Res call({
 String accountId, String accountName, String accountGroup, int debitCents, int creditCents, String notes, String? shareholderId, String? assetId
});




}
/// @nodoc
class _$JournalLineModelCopyWithImpl<$Res>
    implements $JournalLineModelCopyWith<$Res> {
  _$JournalLineModelCopyWithImpl(this._self, this._then);

  final JournalLineModel _self;
  final $Res Function(JournalLineModel) _then;

/// Create a copy of JournalLineModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accountId = null,Object? accountName = null,Object? accountGroup = null,Object? debitCents = null,Object? creditCents = null,Object? notes = null,Object? shareholderId = freezed,Object? assetId = freezed,}) {
  return _then(_self.copyWith(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,accountName: null == accountName ? _self.accountName : accountName // ignore: cast_nullable_to_non_nullable
as String,accountGroup: null == accountGroup ? _self.accountGroup : accountGroup // ignore: cast_nullable_to_non_nullable
as String,debitCents: null == debitCents ? _self.debitCents : debitCents // ignore: cast_nullable_to_non_nullable
as int,creditCents: null == creditCents ? _self.creditCents : creditCents // ignore: cast_nullable_to_non_nullable
as int,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,shareholderId: freezed == shareholderId ? _self.shareholderId : shareholderId // ignore: cast_nullable_to_non_nullable
as String?,assetId: freezed == assetId ? _self.assetId : assetId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [JournalLineModel].
extension JournalLineModelPatterns on JournalLineModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JournalLineModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JournalLineModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JournalLineModel value)  $default,){
final _that = this;
switch (_that) {
case _JournalLineModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JournalLineModel value)?  $default,){
final _that = this;
switch (_that) {
case _JournalLineModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accountId,  String accountName,  String accountGroup,  int debitCents,  int creditCents,  String notes,  String? shareholderId,  String? assetId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JournalLineModel() when $default != null:
return $default(_that.accountId,_that.accountName,_that.accountGroup,_that.debitCents,_that.creditCents,_that.notes,_that.shareholderId,_that.assetId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accountId,  String accountName,  String accountGroup,  int debitCents,  int creditCents,  String notes,  String? shareholderId,  String? assetId)  $default,) {final _that = this;
switch (_that) {
case _JournalLineModel():
return $default(_that.accountId,_that.accountName,_that.accountGroup,_that.debitCents,_that.creditCents,_that.notes,_that.shareholderId,_that.assetId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accountId,  String accountName,  String accountGroup,  int debitCents,  int creditCents,  String notes,  String? shareholderId,  String? assetId)?  $default,) {final _that = this;
switch (_that) {
case _JournalLineModel() when $default != null:
return $default(_that.accountId,_that.accountName,_that.accountGroup,_that.debitCents,_that.creditCents,_that.notes,_that.shareholderId,_that.assetId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _JournalLineModel implements JournalLineModel {
  const _JournalLineModel({required this.accountId, required this.accountName, required this.accountGroup, this.debitCents = 0, this.creditCents = 0, this.notes = '', this.shareholderId, this.assetId});
  factory _JournalLineModel.fromJson(Map<String, dynamic> json) => _$JournalLineModelFromJson(json);

@override final  String accountId;
@override final  String accountName;
@override final  String accountGroup;
// Asset, Liability, Equity, Income, Expense
@override@JsonKey() final  int debitCents;
@override@JsonKey() final  int creditCents;
@override@JsonKey() final  String notes;
@override final  String? shareholderId;
@override final  String? assetId;

/// Create a copy of JournalLineModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JournalLineModelCopyWith<_JournalLineModel> get copyWith => __$JournalLineModelCopyWithImpl<_JournalLineModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JournalLineModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JournalLineModel&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.accountName, accountName) || other.accountName == accountName)&&(identical(other.accountGroup, accountGroup) || other.accountGroup == accountGroup)&&(identical(other.debitCents, debitCents) || other.debitCents == debitCents)&&(identical(other.creditCents, creditCents) || other.creditCents == creditCents)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.shareholderId, shareholderId) || other.shareholderId == shareholderId)&&(identical(other.assetId, assetId) || other.assetId == assetId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountId,accountName,accountGroup,debitCents,creditCents,notes,shareholderId,assetId);

@override
String toString() {
  return 'JournalLineModel(accountId: $accountId, accountName: $accountName, accountGroup: $accountGroup, debitCents: $debitCents, creditCents: $creditCents, notes: $notes, shareholderId: $shareholderId, assetId: $assetId)';
}


}

/// @nodoc
abstract mixin class _$JournalLineModelCopyWith<$Res> implements $JournalLineModelCopyWith<$Res> {
  factory _$JournalLineModelCopyWith(_JournalLineModel value, $Res Function(_JournalLineModel) _then) = __$JournalLineModelCopyWithImpl;
@override @useResult
$Res call({
 String accountId, String accountName, String accountGroup, int debitCents, int creditCents, String notes, String? shareholderId, String? assetId
});




}
/// @nodoc
class __$JournalLineModelCopyWithImpl<$Res>
    implements _$JournalLineModelCopyWith<$Res> {
  __$JournalLineModelCopyWithImpl(this._self, this._then);

  final _JournalLineModel _self;
  final $Res Function(_JournalLineModel) _then;

/// Create a copy of JournalLineModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accountId = null,Object? accountName = null,Object? accountGroup = null,Object? debitCents = null,Object? creditCents = null,Object? notes = null,Object? shareholderId = freezed,Object? assetId = freezed,}) {
  return _then(_JournalLineModel(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,accountName: null == accountName ? _self.accountName : accountName // ignore: cast_nullable_to_non_nullable
as String,accountGroup: null == accountGroup ? _self.accountGroup : accountGroup // ignore: cast_nullable_to_non_nullable
as String,debitCents: null == debitCents ? _self.debitCents : debitCents // ignore: cast_nullable_to_non_nullable
as int,creditCents: null == creditCents ? _self.creditCents : creditCents // ignore: cast_nullable_to_non_nullable
as int,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,shareholderId: freezed == shareholderId ? _self.shareholderId : shareholderId // ignore: cast_nullable_to_non_nullable
as String?,assetId: freezed == assetId ? _self.assetId : assetId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$JournalEntryModel {

 String get id; String get journalNumber; String get date; String get sourceType;// capital, asset_purchase, asset_contribution, depreciation, shareholder_loan, invoice, customer_payment, expense, payroll
 String get sourceId; String get description; List<JournalLineModel> get lines; int get totalDebitCents; int get totalCreditCents; bool get isBalanced; String get status; int get version;
/// Create a copy of JournalEntryModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JournalEntryModelCopyWith<JournalEntryModel> get copyWith => _$JournalEntryModelCopyWithImpl<JournalEntryModel>(this as JournalEntryModel, _$identity);

  /// Serializes this JournalEntryModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JournalEntryModel&&(identical(other.id, id) || other.id == id)&&(identical(other.journalNumber, journalNumber) || other.journalNumber == journalNumber)&&(identical(other.date, date) || other.date == date)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.lines, lines)&&(identical(other.totalDebitCents, totalDebitCents) || other.totalDebitCents == totalDebitCents)&&(identical(other.totalCreditCents, totalCreditCents) || other.totalCreditCents == totalCreditCents)&&(identical(other.isBalanced, isBalanced) || other.isBalanced == isBalanced)&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,journalNumber,date,sourceType,sourceId,description,const DeepCollectionEquality().hash(lines),totalDebitCents,totalCreditCents,isBalanced,status,version);

@override
String toString() {
  return 'JournalEntryModel(id: $id, journalNumber: $journalNumber, date: $date, sourceType: $sourceType, sourceId: $sourceId, description: $description, lines: $lines, totalDebitCents: $totalDebitCents, totalCreditCents: $totalCreditCents, isBalanced: $isBalanced, status: $status, version: $version)';
}


}

/// @nodoc
abstract mixin class $JournalEntryModelCopyWith<$Res>  {
  factory $JournalEntryModelCopyWith(JournalEntryModel value, $Res Function(JournalEntryModel) _then) = _$JournalEntryModelCopyWithImpl;
@useResult
$Res call({
 String id, String journalNumber, String date, String sourceType, String sourceId, String description, List<JournalLineModel> lines, int totalDebitCents, int totalCreditCents, bool isBalanced, String status, int version
});




}
/// @nodoc
class _$JournalEntryModelCopyWithImpl<$Res>
    implements $JournalEntryModelCopyWith<$Res> {
  _$JournalEntryModelCopyWithImpl(this._self, this._then);

  final JournalEntryModel _self;
  final $Res Function(JournalEntryModel) _then;

/// Create a copy of JournalEntryModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? journalNumber = null,Object? date = null,Object? sourceType = null,Object? sourceId = null,Object? description = null,Object? lines = null,Object? totalDebitCents = null,Object? totalCreditCents = null,Object? isBalanced = null,Object? status = null,Object? version = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,journalNumber: null == journalNumber ? _self.journalNumber : journalNumber // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as String,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self.lines : lines // ignore: cast_nullable_to_non_nullable
as List<JournalLineModel>,totalDebitCents: null == totalDebitCents ? _self.totalDebitCents : totalDebitCents // ignore: cast_nullable_to_non_nullable
as int,totalCreditCents: null == totalCreditCents ? _self.totalCreditCents : totalCreditCents // ignore: cast_nullable_to_non_nullable
as int,isBalanced: null == isBalanced ? _self.isBalanced : isBalanced // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [JournalEntryModel].
extension JournalEntryModelPatterns on JournalEntryModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JournalEntryModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JournalEntryModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JournalEntryModel value)  $default,){
final _that = this;
switch (_that) {
case _JournalEntryModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JournalEntryModel value)?  $default,){
final _that = this;
switch (_that) {
case _JournalEntryModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String journalNumber,  String date,  String sourceType,  String sourceId,  String description,  List<JournalLineModel> lines,  int totalDebitCents,  int totalCreditCents,  bool isBalanced,  String status,  int version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JournalEntryModel() when $default != null:
return $default(_that.id,_that.journalNumber,_that.date,_that.sourceType,_that.sourceId,_that.description,_that.lines,_that.totalDebitCents,_that.totalCreditCents,_that.isBalanced,_that.status,_that.version);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String journalNumber,  String date,  String sourceType,  String sourceId,  String description,  List<JournalLineModel> lines,  int totalDebitCents,  int totalCreditCents,  bool isBalanced,  String status,  int version)  $default,) {final _that = this;
switch (_that) {
case _JournalEntryModel():
return $default(_that.id,_that.journalNumber,_that.date,_that.sourceType,_that.sourceId,_that.description,_that.lines,_that.totalDebitCents,_that.totalCreditCents,_that.isBalanced,_that.status,_that.version);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String journalNumber,  String date,  String sourceType,  String sourceId,  String description,  List<JournalLineModel> lines,  int totalDebitCents,  int totalCreditCents,  bool isBalanced,  String status,  int version)?  $default,) {final _that = this;
switch (_that) {
case _JournalEntryModel() when $default != null:
return $default(_that.id,_that.journalNumber,_that.date,_that.sourceType,_that.sourceId,_that.description,_that.lines,_that.totalDebitCents,_that.totalCreditCents,_that.isBalanced,_that.status,_that.version);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _JournalEntryModel implements JournalEntryModel {
  const _JournalEntryModel({required this.id, required this.journalNumber, required this.date, required this.sourceType, required this.sourceId, this.description = '', final  List<JournalLineModel> lines = const [], this.totalDebitCents = 0, this.totalCreditCents = 0, this.isBalanced = true, this.status = 'posted', this.version = 0}): _lines = lines;
  factory _JournalEntryModel.fromJson(Map<String, dynamic> json) => _$JournalEntryModelFromJson(json);

@override final  String id;
@override final  String journalNumber;
@override final  String date;
@override final  String sourceType;
// capital, asset_purchase, asset_contribution, depreciation, shareholder_loan, invoice, customer_payment, expense, payroll
@override final  String sourceId;
@override@JsonKey() final  String description;
 final  List<JournalLineModel> _lines;
@override@JsonKey() List<JournalLineModel> get lines {
  if (_lines is EqualUnmodifiableListView) return _lines;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lines);
}

@override@JsonKey() final  int totalDebitCents;
@override@JsonKey() final  int totalCreditCents;
@override@JsonKey() final  bool isBalanced;
@override@JsonKey() final  String status;
@override@JsonKey() final  int version;

/// Create a copy of JournalEntryModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JournalEntryModelCopyWith<_JournalEntryModel> get copyWith => __$JournalEntryModelCopyWithImpl<_JournalEntryModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JournalEntryModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JournalEntryModel&&(identical(other.id, id) || other.id == id)&&(identical(other.journalNumber, journalNumber) || other.journalNumber == journalNumber)&&(identical(other.date, date) || other.date == date)&&(identical(other.sourceType, sourceType) || other.sourceType == sourceType)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._lines, _lines)&&(identical(other.totalDebitCents, totalDebitCents) || other.totalDebitCents == totalDebitCents)&&(identical(other.totalCreditCents, totalCreditCents) || other.totalCreditCents == totalCreditCents)&&(identical(other.isBalanced, isBalanced) || other.isBalanced == isBalanced)&&(identical(other.status, status) || other.status == status)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,journalNumber,date,sourceType,sourceId,description,const DeepCollectionEquality().hash(_lines),totalDebitCents,totalCreditCents,isBalanced,status,version);

@override
String toString() {
  return 'JournalEntryModel(id: $id, journalNumber: $journalNumber, date: $date, sourceType: $sourceType, sourceId: $sourceId, description: $description, lines: $lines, totalDebitCents: $totalDebitCents, totalCreditCents: $totalCreditCents, isBalanced: $isBalanced, status: $status, version: $version)';
}


}

/// @nodoc
abstract mixin class _$JournalEntryModelCopyWith<$Res> implements $JournalEntryModelCopyWith<$Res> {
  factory _$JournalEntryModelCopyWith(_JournalEntryModel value, $Res Function(_JournalEntryModel) _then) = __$JournalEntryModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String journalNumber, String date, String sourceType, String sourceId, String description, List<JournalLineModel> lines, int totalDebitCents, int totalCreditCents, bool isBalanced, String status, int version
});




}
/// @nodoc
class __$JournalEntryModelCopyWithImpl<$Res>
    implements _$JournalEntryModelCopyWith<$Res> {
  __$JournalEntryModelCopyWithImpl(this._self, this._then);

  final _JournalEntryModel _self;
  final $Res Function(_JournalEntryModel) _then;

/// Create a copy of JournalEntryModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? journalNumber = null,Object? date = null,Object? sourceType = null,Object? sourceId = null,Object? description = null,Object? lines = null,Object? totalDebitCents = null,Object? totalCreditCents = null,Object? isBalanced = null,Object? status = null,Object? version = null,}) {
  return _then(_JournalEntryModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,journalNumber: null == journalNumber ? _self.journalNumber : journalNumber // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,sourceType: null == sourceType ? _self.sourceType : sourceType // ignore: cast_nullable_to_non_nullable
as String,sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,lines: null == lines ? _self._lines : lines // ignore: cast_nullable_to_non_nullable
as List<JournalLineModel>,totalDebitCents: null == totalDebitCents ? _self.totalDebitCents : totalDebitCents // ignore: cast_nullable_to_non_nullable
as int,totalCreditCents: null == totalCreditCents ? _self.totalCreditCents : totalCreditCents // ignore: cast_nullable_to_non_nullable
as int,isBalanced: null == isBalanced ? _self.isBalanced : isBalanced // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
