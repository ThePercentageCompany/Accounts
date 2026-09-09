import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../domain/office_repository.dart';
part 'office_cubit.freezed.dart';
@freezed
abstract class OfficeState with _$OfficeState {
 const factory OfficeState({@Default(OfficeData()) OfficeData data,@Default(false) bool busy,String? error})=_OfficeState;
}
class OfficeCubit extends Cubit<OfficeState> {
 final OfficeRepository repository;OfficeCubit(this.repository):super(const OfficeState());
 Future<bool> run([String? action,Map<String,dynamic>? payload])async {
  if(state.busy)return false;emit(state.copyWith(busy:true,error:null));
  try{if(action!=null)await repository.command(action,payload);final data=OfficeData.fromJson(await repository.command('officeLoad'));emit(OfficeState(data:data));return true;}
  catch(e){emit(state.copyWith(busy:false,error:e.toString()));return false;}
 }
}
