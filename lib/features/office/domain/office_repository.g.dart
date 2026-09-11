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
  shareholders:
      (json['shareholders'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
  capitalTransactions:
      (json['capitalTransactions'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
  shareholderLoans:
      (json['shareholderLoans'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
  assets:
      (json['assets'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      const [],
  journals:
      (json['journals'] as List<dynamic>?)
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
      'shareholders': instance.shareholders,
      'capitalTransactions': instance.capitalTransactions,
      'shareholderLoans': instance.shareholderLoans,
      'assets': instance.assets,
      'journals': instance.journals,
    };
