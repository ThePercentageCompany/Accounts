// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'office_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OfficeData _$OfficeDataFromJson(Map<String, dynamic> json) => _OfficeData(
  employees:
      (json['employees'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
  attendance:
      (json['attendance'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
  payroll:
      (json['payroll'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
  entries:
      (json['entries'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
);

Map<String, dynamic> _$OfficeDataToJson(_OfficeData instance) =>
    <String, dynamic>{
      'employees': instance.employees,
      'attendance': instance.attendance,
      'payroll': instance.payroll,
      'entries': instance.entries,
    };
