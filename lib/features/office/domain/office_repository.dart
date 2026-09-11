import 'package:freezed_annotation/freezed_annotation.dart';
part 'office_repository.freezed.dart';
part 'office_repository.g.dart';
@freezed
abstract class OfficeData with _$OfficeData {
  const factory OfficeData({
    @Default([]) List<Map<String,dynamic>> employees,
    @Default([]) List<Map<String,dynamic>> attendance,
    @Default([]) List<Map<String,dynamic>> payroll,
    @Default([]) List<Map<String,dynamic>> entries,
    @Default([]) List<Map<String,dynamic>> shareholders,
    @Default([]) List<Map<String,dynamic>> capitalTransactions,
    @Default([]) List<Map<String,dynamic>> shareholderLoans,
    @Default([]) List<Map<String,dynamic>> assets,
    @Default([]) List<Map<String,dynamic>> journals,
  }) = _OfficeData;
  factory OfficeData.fromJson(Map<String,dynamic> json)=>_$OfficeDataFromJson(json);
}
abstract interface class OfficeRepository {
  bool get isDemo;
  Future<Map<String,dynamic>> command(String action,[Map<String,dynamic>? data]);
}
