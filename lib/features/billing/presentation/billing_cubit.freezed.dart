// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'billing_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BillingState {

 BillingData get data; bool get busy; String? get error;
/// Create a copy of BillingState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BillingStateCopyWith<BillingState> get copyWith => _$BillingStateCopyWithImpl<BillingState>(this as BillingState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BillingState&&(identical(other.data, data) || other.data == data)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,data,busy,error);

@override
String toString() {
  return 'BillingState(data: $data, busy: $busy, error: $error)';
}


}

/// @nodoc
abstract mixin class $BillingStateCopyWith<$Res>  {
  factory $BillingStateCopyWith(BillingState value, $Res Function(BillingState) _then) = _$BillingStateCopyWithImpl;
@useResult
$Res call({
 BillingData data, bool busy, String? error
});


$BillingDataCopyWith<$Res> get data;

}
/// @nodoc
class _$BillingStateCopyWithImpl<$Res>
    implements $BillingStateCopyWith<$Res> {
  _$BillingStateCopyWithImpl(this._self, this._then);

  final BillingState _self;
  final $Res Function(BillingState) _then;

/// Create a copy of BillingState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? busy = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as BillingData,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of BillingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BillingDataCopyWith<$Res> get data {
  
  return $BillingDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [BillingState].
extension BillingStatePatterns on BillingState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BillingState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BillingState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BillingState value)  $default,){
final _that = this;
switch (_that) {
case _BillingState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BillingState value)?  $default,){
final _that = this;
switch (_that) {
case _BillingState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BillingData data,  bool busy,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BillingState() when $default != null:
return $default(_that.data,_that.busy,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BillingData data,  bool busy,  String? error)  $default,) {final _that = this;
switch (_that) {
case _BillingState():
return $default(_that.data,_that.busy,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BillingData data,  bool busy,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _BillingState() when $default != null:
return $default(_that.data,_that.busy,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _BillingState implements BillingState {
  const _BillingState({this.data = const BillingData(), this.busy = false, this.error});
  

@override@JsonKey() final  BillingData data;
@override@JsonKey() final  bool busy;
@override final  String? error;

/// Create a copy of BillingState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BillingStateCopyWith<_BillingState> get copyWith => __$BillingStateCopyWithImpl<_BillingState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BillingState&&(identical(other.data, data) || other.data == data)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,data,busy,error);

@override
String toString() {
  return 'BillingState(data: $data, busy: $busy, error: $error)';
}


}

/// @nodoc
abstract mixin class _$BillingStateCopyWith<$Res> implements $BillingStateCopyWith<$Res> {
  factory _$BillingStateCopyWith(_BillingState value, $Res Function(_BillingState) _then) = __$BillingStateCopyWithImpl;
@override @useResult
$Res call({
 BillingData data, bool busy, String? error
});


@override $BillingDataCopyWith<$Res> get data;

}
/// @nodoc
class __$BillingStateCopyWithImpl<$Res>
    implements _$BillingStateCopyWith<$Res> {
  __$BillingStateCopyWithImpl(this._self, this._then);

  final _BillingState _self;
  final $Res Function(_BillingState) _then;

/// Create a copy of BillingState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? busy = null,Object? error = freezed,}) {
  return _then(_BillingState(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as BillingData,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of BillingState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BillingDataCopyWith<$Res> get data {
  
  return $BillingDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
