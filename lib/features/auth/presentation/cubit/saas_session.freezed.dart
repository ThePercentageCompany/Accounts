// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'saas_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionState {

 Map<String, dynamic>? get owner; Map<String, dynamic>? get employee; Map<String, dynamic>? get company; List<Map<String, dynamic>> get companies; bool get busy; String? get error; String? get pendingCompanyName;
/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionStateCopyWith<SessionState> get copyWith => _$SessionStateCopyWithImpl<SessionState>(this as SessionState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionState&&const DeepCollectionEquality().equals(other.owner, owner)&&const DeepCollectionEquality().equals(other.employee, employee)&&const DeepCollectionEquality().equals(other.company, company)&&const DeepCollectionEquality().equals(other.companies, companies)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error)&&(identical(other.pendingCompanyName, pendingCompanyName) || other.pendingCompanyName == pendingCompanyName));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(owner),const DeepCollectionEquality().hash(employee),const DeepCollectionEquality().hash(company),const DeepCollectionEquality().hash(companies),busy,error,pendingCompanyName);

@override
String toString() {
  return 'SessionState(owner: $owner, employee: $employee, company: $company, companies: $companies, busy: $busy, error: $error, pendingCompanyName: $pendingCompanyName)';
}


}

/// @nodoc
abstract mixin class $SessionStateCopyWith<$Res>  {
  factory $SessionStateCopyWith(SessionState value, $Res Function(SessionState) _then) = _$SessionStateCopyWithImpl;
@useResult
$Res call({
 Map<String, dynamic>? owner, Map<String, dynamic>? employee, Map<String, dynamic>? company, List<Map<String, dynamic>> companies, bool busy, String? error, String? pendingCompanyName
});




}
/// @nodoc
class _$SessionStateCopyWithImpl<$Res>
    implements $SessionStateCopyWith<$Res> {
  _$SessionStateCopyWithImpl(this._self, this._then);

  final SessionState _self;
  final $Res Function(SessionState) _then;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? owner = freezed,Object? employee = freezed,Object? company = freezed,Object? companies = null,Object? busy = null,Object? error = freezed,Object? pendingCompanyName = freezed,}) {
  return _then(_self.copyWith(
owner: freezed == owner ? _self.owner : owner // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,employee: freezed == employee ? _self.employee : employee // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,company: freezed == company ? _self.company : company // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,companies: null == companies ? _self.companies : companies // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,pendingCompanyName: freezed == pendingCompanyName ? _self.pendingCompanyName : pendingCompanyName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionState].
extension SessionStatePatterns on SessionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionState value)  $default,){
final _that = this;
switch (_that) {
case _SessionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionState value)?  $default,){
final _that = this;
switch (_that) {
case _SessionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, dynamic>? owner,  Map<String, dynamic>? employee,  Map<String, dynamic>? company,  List<Map<String, dynamic>> companies,  bool busy,  String? error,  String? pendingCompanyName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionState() when $default != null:
return $default(_that.owner,_that.employee,_that.company,_that.companies,_that.busy,_that.error,_that.pendingCompanyName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, dynamic>? owner,  Map<String, dynamic>? employee,  Map<String, dynamic>? company,  List<Map<String, dynamic>> companies,  bool busy,  String? error,  String? pendingCompanyName)  $default,) {final _that = this;
switch (_that) {
case _SessionState():
return $default(_that.owner,_that.employee,_that.company,_that.companies,_that.busy,_that.error,_that.pendingCompanyName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, dynamic>? owner,  Map<String, dynamic>? employee,  Map<String, dynamic>? company,  List<Map<String, dynamic>> companies,  bool busy,  String? error,  String? pendingCompanyName)?  $default,) {final _that = this;
switch (_that) {
case _SessionState() when $default != null:
return $default(_that.owner,_that.employee,_that.company,_that.companies,_that.busy,_that.error,_that.pendingCompanyName);case _:
  return null;

}
}

}

/// @nodoc


class _SessionState implements SessionState {
  const _SessionState({final  Map<String, dynamic>? owner, final  Map<String, dynamic>? employee, final  Map<String, dynamic>? company, final  List<Map<String, dynamic>> companies = const [], this.busy = false, this.error, this.pendingCompanyName}): _owner = owner,_employee = employee,_company = company,_companies = companies;
  

 final  Map<String, dynamic>? _owner;
@override Map<String, dynamic>? get owner {
  final value = _owner;
  if (value == null) return null;
  if (_owner is EqualUnmodifiableMapView) return _owner;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _employee;
@override Map<String, dynamic>? get employee {
  final value = _employee;
  if (value == null) return null;
  if (_employee is EqualUnmodifiableMapView) return _employee;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _company;
@override Map<String, dynamic>? get company {
  final value = _company;
  if (value == null) return null;
  if (_company is EqualUnmodifiableMapView) return _company;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  List<Map<String, dynamic>> _companies;
@override@JsonKey() List<Map<String, dynamic>> get companies {
  if (_companies is EqualUnmodifiableListView) return _companies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_companies);
}

@override@JsonKey() final  bool busy;
@override final  String? error;
@override final  String? pendingCompanyName;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionStateCopyWith<_SessionState> get copyWith => __$SessionStateCopyWithImpl<_SessionState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionState&&const DeepCollectionEquality().equals(other._owner, _owner)&&const DeepCollectionEquality().equals(other._employee, _employee)&&const DeepCollectionEquality().equals(other._company, _company)&&const DeepCollectionEquality().equals(other._companies, _companies)&&(identical(other.busy, busy) || other.busy == busy)&&(identical(other.error, error) || other.error == error)&&(identical(other.pendingCompanyName, pendingCompanyName) || other.pendingCompanyName == pendingCompanyName));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_owner),const DeepCollectionEquality().hash(_employee),const DeepCollectionEquality().hash(_company),const DeepCollectionEquality().hash(_companies),busy,error,pendingCompanyName);

@override
String toString() {
  return 'SessionState(owner: $owner, employee: $employee, company: $company, companies: $companies, busy: $busy, error: $error, pendingCompanyName: $pendingCompanyName)';
}


}

/// @nodoc
abstract mixin class _$SessionStateCopyWith<$Res> implements $SessionStateCopyWith<$Res> {
  factory _$SessionStateCopyWith(_SessionState value, $Res Function(_SessionState) _then) = __$SessionStateCopyWithImpl;
@override @useResult
$Res call({
 Map<String, dynamic>? owner, Map<String, dynamic>? employee, Map<String, dynamic>? company, List<Map<String, dynamic>> companies, bool busy, String? error, String? pendingCompanyName
});




}
/// @nodoc
class __$SessionStateCopyWithImpl<$Res>
    implements _$SessionStateCopyWith<$Res> {
  __$SessionStateCopyWithImpl(this._self, this._then);

  final _SessionState _self;
  final $Res Function(_SessionState) _then;

/// Create a copy of SessionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? owner = freezed,Object? employee = freezed,Object? company = freezed,Object? companies = null,Object? busy = null,Object? error = freezed,Object? pendingCompanyName = freezed,}) {
  return _then(_SessionState(
owner: freezed == owner ? _self._owner : owner // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,employee: freezed == employee ? _self._employee : employee // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,company: freezed == company ? _self._company : company // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,companies: null == companies ? _self._companies : companies // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,busy: null == busy ? _self.busy : busy // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,pendingCompanyName: freezed == pendingCompanyName ? _self.pendingCompanyName : pendingCompanyName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
