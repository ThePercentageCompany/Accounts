// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'employee_admin_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EmployeeAdminState {

 List<Map<String, dynamic>> get employees; bool get busy; bool get hasPending; bool get canDiscardRejected; bool get refreshing; bool get offline; String? get error; String? get refreshError;
/// Create a copy of EmployeeAdminState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EmployeeAdminStateCopyWith<EmployeeAdminState> get copyWith => _$EmployeeAdminStateCopyWithImpl<EmployeeAdminState>(this as EmployeeAdminState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EmployeeAdminState&&const DeepCollectionEquality().equals(other.employees, employees)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.hasPending, hasPending) || other.hasPending == hasPending)&&(identical(other.canDiscardRejected, canDiscardRejected) || other.canDiscardRejected == canDiscardRejected)&&(identical(other.refreshing, refreshing) || other.refreshing == refreshing)&&(identical(other.offline, offline) || other.offline == offline)&&(identical(other.error, error) || other.error == error)&&(identical(other.refreshError, refreshError) || other.refreshError == refreshError));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(employees),busy,hasPending,canDiscardRejected,refreshing,offline,error,refreshError);

@override
String toString() {
  return 'EmployeeAdminState(employees: $employees, busy: $busy, hasPending: $hasPending, canDiscardRejected: $canDiscardRejected, refreshing: $refreshing, offline: $offline, error: $error, refreshError: $refreshError)';
}


}

/// @nodoc
abstract mixin class $EmployeeAdminStateCopyWith<$Res>  {
  factory $EmployeeAdminStateCopyWith(EmployeeAdminState value, $Res Function(EmployeeAdminState) _then) = _$EmployeeAdminStateCopyWithImpl;
@useResult
$Res call({
 List<Map<String, dynamic>> employees, bool busy, bool hasPending, bool canDiscardRejected, bool refreshing, bool offline, String? error, String? refreshError
});




}
/// @nodoc
class _$EmployeeAdminStateCopyWithImpl<$Res>
    implements $EmployeeAdminStateCopyWith<$Res> {
  _$EmployeeAdminStateCopyWithImpl(this._self, this._then);

  final EmployeeAdminState _self;
  final $Res Function(EmployeeAdminState) _then;

/// Create a copy of EmployeeAdminState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? employees = null,Object? busy = null,Object? hasPending = null,Object? canDiscardRejected = null,Object? refreshing = null,Object? offline = null,Object? error = freezed,Object? refreshError = freezed,}) {
  return _then(_self.copyWith(
employees: null == employees ? _self.employees : employees // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,hasPending: null == hasPending ? _self.hasPending : hasPending // ignore: cast_nullable_to_non_nullable
as bool,canDiscardRejected: null == canDiscardRejected ? _self.canDiscardRejected : canDiscardRejected // ignore: cast_nullable_to_non_nullable
as bool,refreshing: null == refreshing ? _self.refreshing : refreshing // ignore: cast_nullable_to_non_nullable
as bool,offline: null == offline ? _self.offline : offline // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,refreshError: freezed == refreshError ? _self.refreshError : refreshError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EmployeeAdminState].
extension EmployeeAdminStatePatterns on EmployeeAdminState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EmployeeAdminState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EmployeeAdminState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EmployeeAdminState value)  $default,){
final _that = this;
switch (_that) {
case _EmployeeAdminState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EmployeeAdminState value)?  $default,){
final _that = this;
switch (_that) {
case _EmployeeAdminState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Map<String, dynamic>> employees,  bool busy,  bool hasPending,  bool canDiscardRejected,  bool refreshing,  bool offline,  String? error,  String? refreshError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EmployeeAdminState() when $default != null:
return $default(_that.employees,_that.busy,_that.hasPending,_that.canDiscardRejected,_that.refreshing,_that.offline,_that.error,_that.refreshError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Map<String, dynamic>> employees,  bool busy,  bool hasPending,  bool canDiscardRejected,  bool refreshing,  bool offline,  String? error,  String? refreshError)  $default,) {final _that = this;
switch (_that) {
case _EmployeeAdminState():
return $default(_that.employees,_that.busy,_that.hasPending,_that.canDiscardRejected,_that.refreshing,_that.offline,_that.error,_that.refreshError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Map<String, dynamic>> employees,  bool busy,  bool hasPending,  bool canDiscardRejected,  bool refreshing,  bool offline,  String? error,  String? refreshError)?  $default,) {final _that = this;
switch (_that) {
case _EmployeeAdminState() when $default != null:
return $default(_that.employees,_that.busy,_that.hasPending,_that.canDiscardRejected,_that.refreshing,_that.offline,_that.error,_that.refreshError);case _:
  return null;

}
}

}

/// @nodoc


class _EmployeeAdminState implements EmployeeAdminState {
  const _EmployeeAdminState({final  List<Map<String, dynamic>> employees = const [], this.busy = false, this.hasPending = false, this.canDiscardRejected = false, this.refreshing = false, this.offline = false, this.error, this.refreshError}): _employees = employees;
  

 final  List<Map<String, dynamic>> _employees;
@override@JsonKey() List<Map<String, dynamic>> get employees {
  if (_employees is EqualUnmodifiableListView) return _employees;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_employees);
}

@override@JsonKey() final  bool busy;
@override@JsonKey() final  bool hasPending;
@override@JsonKey() final  bool canDiscardRejected;
@override@JsonKey() final  bool refreshing;
@override@JsonKey() final  bool offline;
@override final  String? error;
@override final  String? refreshError;

/// Create a copy of EmployeeAdminState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EmployeeAdminStateCopyWith<_EmployeeAdminState> get copyWith => __$EmployeeAdminStateCopyWithImpl<_EmployeeAdminState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EmployeeAdminState&&const DeepCollectionEquality().equals(other._employees, _employees)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.hasPending, hasPending) || other.hasPending == hasPending)&&(identical(other.canDiscardRejected, canDiscardRejected) || other.canDiscardRejected == canDiscardRejected)&&(identical(other.refreshing, refreshing) || other.refreshing == refreshing)&&(identical(other.offline, offline) || other.offline == offline)&&(identical(other.error, error) || other.error == error)&&(identical(other.refreshError, refreshError) || other.refreshError == refreshError));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_employees),busy,hasPending,canDiscardRejected,refreshing,offline,error,refreshError);

@override
String toString() {
  return 'EmployeeAdminState(employees: $employees, busy: $busy, hasPending: $hasPending, canDiscardRejected: $canDiscardRejected, refreshing: $refreshing, offline: $offline, error: $error, refreshError: $refreshError)';
}


}

/// @nodoc
abstract mixin class _$EmployeeAdminStateCopyWith<$Res> implements $EmployeeAdminStateCopyWith<$Res> {
  factory _$EmployeeAdminStateCopyWith(_EmployeeAdminState value, $Res Function(_EmployeeAdminState) _then) = __$EmployeeAdminStateCopyWithImpl;
@override @useResult
$Res call({
 List<Map<String, dynamic>> employees, bool busy, bool hasPending, bool canDiscardRejected, bool refreshing, bool offline, String? error, String? refreshError
});




}
/// @nodoc
class __$EmployeeAdminStateCopyWithImpl<$Res>
    implements _$EmployeeAdminStateCopyWith<$Res> {
  __$EmployeeAdminStateCopyWithImpl(this._self, this._then);

  final _EmployeeAdminState _self;
  final $Res Function(_EmployeeAdminState) _then;

/// Create a copy of EmployeeAdminState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? employees = null,Object? busy = null,Object? hasPending = null,Object? canDiscardRejected = null,Object? refreshing = null,Object? offline = null,Object? error = freezed,Object? refreshError = freezed,}) {
  return _then(_EmployeeAdminState(
employees: null == employees ? _self._employees : employees // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,hasPending: null == hasPending ? _self.hasPending : hasPending // ignore: cast_nullable_to_non_nullable
as bool,canDiscardRejected: null == canDiscardRejected ? _self.canDiscardRejected : canDiscardRejected // ignore: cast_nullable_to_non_nullable
as bool,refreshing: null == refreshing ? _self.refreshing : refreshing // ignore: cast_nullable_to_non_nullable
as bool,offline: null == offline ? _self.offline : offline // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,refreshError: freezed == refreshError ? _self.refreshError : refreshError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
