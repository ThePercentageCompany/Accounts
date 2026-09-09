import '../../../core/google_api.dart';
import '../domain/office_repository.dart';
class GoogleOfficeRepository implements OfficeRepository {
  final GoogleApi api;GoogleOfficeRepository(this.api);
  @override bool get isDemo=>false;
  @override Future<Map<String,dynamic>> command(String action,[Map<String,dynamic>? data])=>api.command(action,data);
}
