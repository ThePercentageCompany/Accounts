// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'office_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OfficeData {

 List<Map<String, dynamic>> get employees; List<Map<String, dynamic>> get attendance; List<Map<String, dynamic>> get payroll; List<Map<String, dynamic>> get entries;
/// Create a copy of OfficeData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OfficeDataCopyWith<OfficeData> get copyWith => _$OfficeDataCopyWithImpl<OfficeData>(this as OfficeData, _$identity);

  /// Serializes this OfficeData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OfficeData&&const DeepCollectionEquality().equals(other.employees, employees)&&const DeepCollectionEquality().equals(other.attendance, attendance)&&const DeepCollectionEquality().equals(other.payroll, payroll)&&const DeepCollectionEquality().equals(other.entries, entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(employees),const DeepCollectionEquality().hash(attendance),const DeepCollectionEquality().hash(payroll),const DeepCollectionEquality().hash(entries));

@override
String toString() {
  return 'OfficeData(employees: $employees, attendance: $attendance, payroll: $payroll, entries: $entries)';
}


}

/// @nodoc
abstract mixin class $OfficeDataCopyWith<$Res>  {
  factory $OfficeDataCopyWith(OfficeData value, $Res Function(OfficeData) _then) = _$OfficeDataCopyWithImpl;
@useResult
$Res call({
 List<Map<String, dynamic>> employees, List<Map<String, dynamic>> attendance, List<Map<String, dynamic>> payroll, List<Map<String, dynamic>> entries
});




}
/// @nodoc
class _$OfficeDataCopyWithImpl<$Res>
    implements $OfficeDataCopyWith<$Res> {
  _$OfficeDataCopyWithImpl(this._self, this._then);

  final OfficeData _self;
  final $Res Function(OfficeData) _then;

/// Create a copy of OfficeData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? employees = null,Object? attendance = null,Object? payroll = null,Object? entries = null,}) {
  return _then(_self.copyWith(
employees: null == employees ? _self.employees : employees // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,attendance: null == attendance ? _self.attendance : attendance // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,payroll: null == payroll ? _self.payroll : payroll // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}

}


/// Adds pattern-matching-related methods to [OfficeData].
extension OfficeDataPatterns on OfficeData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OfficeData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OfficeData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OfficeData value)  $default,){
final _that = this;
switch (_that) {
case _OfficeData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OfficeData value)?  $default,){
final _that = this;
switch (_that) {
case _OfficeData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Map<String, dynamic>> employees,  List<Map<String, dynamic>> attendance,  List<Map<String, dynamic>> payroll,  List<Map<String, dynamic>> entries)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OfficeData() when $default != null:
return $default(_that.employees,_that.attendance,_that.payroll,_that.entries);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Map<String, dynamic>> employees,  List<Map<String, dynamic>> attendance,  List<Map<String, dynamic>> payroll,  List<Map<String, dynamic>> entries)  $default,) {final _that = this;
switch (_that) {
case _OfficeData():
return $default(_that.employees,_that.attendance,_that.payroll,_that.entries);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Map<String, dynamic>> employees,  List<Map<String, dynamic>> attendance,  List<Map<String, dynamic>> payroll,  List<Map<String, dynamic>> entries)?  $default,) {final _that = this;
switch (_that) {
case _OfficeData() when $default != null:
return $default(_that.employees,_that.attendance,_that.payroll,_that.entries);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OfficeData implements OfficeData {
  const _OfficeData({final  List<Map<String, dynamic>> employees = const [], final  List<Map<String, dynamic>> attendance = const [], final  List<Map<String, dynamic>> payroll = const [], final  List<Map<String, dynamic>> entries = const []}): _employees = employees,_attendance = attendance,_payroll = payroll,_entries = entries;
  factory _OfficeData.fromJson(Map<String, dynamic> json) => _$OfficeDataFromJson(json);

 final  List<Map<String, dynamic>> _employees;
@override@JsonKey() List<Map<String, dynamic>> get employees {
  if (_employees is EqualUnmodifiableListView) return _employees;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_employees);
}

 final  List<Map<String, dynamic>> _attendance;
@override@JsonKey() List<Map<String, dynamic>> get attendance {
  if (_attendance is EqualUnmodifiableListView) return _attendance;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attendance);
}

 final  List<Map<String, dynamic>> _payroll;
@override@JsonKey() List<Map<String, dynamic>> get payroll {
  if (_payroll is EqualUnmodifiableListView) return _payroll;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_payroll);
}

 final  List<Map<String, dynamic>> _entries;
@override@JsonKey() List<Map<String, dynamic>> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}


/// Create a copy of OfficeData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OfficeDataCopyWith<_OfficeData> get copyWith => __$OfficeDataCopyWithImpl<_OfficeData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OfficeDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OfficeData&&const DeepCollectionEquality().equals(other._employees, _employees)&&const DeepCollectionEquality().equals(other._attendance, _attendance)&&const DeepCollectionEquality().equals(other._payroll, _payroll)&&const DeepCollectionEquality().equals(other._entries, _entries));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_employees),const DeepCollectionEquality().hash(_attendance),const DeepCollectionEquality().hash(_payroll),const DeepCollectionEquality().hash(_entries));

@override
String toString() {
  return 'OfficeData(employees: $employees, attendance: $attendance, payroll: $payroll, entries: $entries)';
}


}

/// @nodoc
abstract mixin class _$OfficeDataCopyWith<$Res> implements $OfficeDataCopyWith<$Res> {
  factory _$OfficeDataCopyWith(_OfficeData value, $Res Function(_OfficeData) _then) = __$OfficeDataCopyWithImpl;
@override @useResult
$Res call({
 List<Map<String, dynamic>> employees, List<Map<String, dynamic>> attendance, List<Map<String, dynamic>> payroll, List<Map<String, dynamic>> entries
});




}
/// @nodoc
class __$OfficeDataCopyWithImpl<$Res>
    implements _$OfficeDataCopyWith<$Res> {
  __$OfficeDataCopyWithImpl(this._self, this._then);

  final _OfficeData _self;
  final $Res Function(_OfficeData) _then;

/// Create a copy of OfficeData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? employees = null,Object? attendance = null,Object? payroll = null,Object? entries = null,}) {
  return _then(_OfficeData(
employees: null == employees ? _self._employees : employees // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,attendance: null == attendance ? _self._attendance : attendance // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,payroll: null == payroll ? _self._payroll : payroll // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<Map<String, dynamic>>,
  ));
}


}

// dart format on
