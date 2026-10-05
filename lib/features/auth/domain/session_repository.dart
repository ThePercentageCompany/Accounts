/// Authentication/workspace operations consumed by the session Bloc.
/// Infrastructure implements this contract; presentation owns no HTTP calls.
abstract interface class SessionRepository {
  set onAccessRevoked(void Function()? callback);
  void Function()? get onAccessRevoked;
  set onEmployeeChanged(void Function(Map<String, dynamic>)? callback);
  void Function(Map<String, dynamic>)? get onEmployeeChanged;
  Future<Map<String, dynamic>> me();
  Future<Map<String, dynamic>> companies();
  Future<Map<String, dynamic>> setup(String companyId);
  Future<Map<String, dynamic>> retrySetup(String companyId);
  Future<Map<String, dynamic>> createCompany(String name, String operationId);
  Future<Map<String, dynamic>> deleteCompany(String companyId);
  Future<Map<String, dynamic>> employeeMe();
  Future<Map<String, dynamic>> employeeLogin(String invite, String code);
  Future<Map<String, dynamic>> employeeLogout();
  Future<Map<String, dynamic>> logout();
  Future<Uri> startSignIn();
  Future<Uri> connectGoogle(String companyId);
  Future<void> clearWorkspace();
  void detachWorkspace();
  void useVerifiedWorkspace(
    String companyId, {
    String? ownerId,
    Map<String, dynamic>? employee,
  });
}
