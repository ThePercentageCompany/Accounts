// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'office_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$OfficeState {

 OfficeData get data; bool get busy; String? get error;
/// Create a copy of OfficeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OfficeStateCopyWith<OfficeState> get copyWith => _$OfficeStateCopyWithImpl<OfficeState>(this as OfficeState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OfficeState&&(identical(other.data, data) || other.data == data)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,data,busy,error);

@override
String toString() {
  return 'OfficeState(data: $data, busy: $busy, error: $error)';
}


}

/// @nodoc
abstract mixin class $OfficeStateCopyWith<$Res>  {
  factory $OfficeStateCopyWith(OfficeState value, $Res Function(OfficeState) _then) = _$OfficeStateCopyWithImpl;
@useResult
$Res call({
 OfficeData data, bool busy, String? error
});


$OfficeDataCopyWith<$Res> get data;

}
/// @nodoc
class _$OfficeStateCopyWithImpl<$Res>
    implements $OfficeStateCopyWith<$Res> {
  _$OfficeStateCopyWithImpl(this._self, this._then);

  final OfficeState _self;
  final $Res Function(OfficeState) _then;

/// Create a copy of OfficeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? busy = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as OfficeData,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of OfficeState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OfficeDataCopyWith<$Res> get data {
  
  return $OfficeDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [OfficeState].
extension OfficeStatePatterns on OfficeState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OfficeState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OfficeState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OfficeState value)  $default,){
final _that = this;
switch (_that) {
case _OfficeState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OfficeState value)?  $default,){
final _that = this;
switch (_that) {
case _OfficeState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( OfficeData data,  bool busy,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OfficeState() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( OfficeData data,  bool busy,  String? error)  $default,) {final _that = this;
switch (_that) {
case _OfficeState():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( OfficeData data,  bool busy,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _OfficeState() when $default != null:
return $default(_that.data,_that.busy,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _OfficeState implements OfficeState {
  const _OfficeState({this.data = const OfficeData(), this.busy = false, this.error});
  

@override@JsonKey() final  OfficeData data;
@override@JsonKey() final  bool busy;
@override final  String? error;

/// Create a copy of OfficeState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OfficeStateCopyWith<_OfficeState> get copyWith => __$OfficeStateCopyWithImpl<_OfficeState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OfficeState&&(identical(other.data, data) || other.data == data)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,data,busy,error);

@override
String toString() {
  return 'OfficeState(data: $data, busy: $busy, error: $error)';
}


}

/// @nodoc
abstract mixin class _$OfficeStateCopyWith<$Res> implements $OfficeStateCopyWith<$Res> {
  factory _$OfficeStateCopyWith(_OfficeState value, $Res Function(_OfficeState) _then) = __$OfficeStateCopyWithImpl;
@override @useResult
$Res call({
 OfficeData data, bool busy, String? error
});


@override $OfficeDataCopyWith<$Res> get data;

}
/// @nodoc
class __$OfficeStateCopyWithImpl<$Res>
    implements _$OfficeStateCopyWith<$Res> {
  __$OfficeStateCopyWithImpl(this._self, this._then);

  final _OfficeState _self;
  final $Res Function(_OfficeState) _then;

/// Create a copy of OfficeState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? busy = null,Object? error = freezed,}) {
  return _then(_OfficeState(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as OfficeData,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of OfficeState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OfficeDataCopyWith<$Res> get data {
  
  return $OfficeDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
