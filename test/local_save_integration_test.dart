import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpc_invoice/core/network/saas_api.dart';
import 'package:tpc_invoice/core/offline/offline_store.dart';
import 'package:tpc_invoice/features/employees/presentation/cubit/employee_admin_controller.dart';
import 'package:tpc_invoice/features/documents/data/document_upload_queue.dart';

void main() {
  final owner = List.filled(43, 'o').join(),
      company = List.filled(43, 'c').join();
  late SaasApi api;
  late SharedPreferences preferences;
  late List<http.Request> mutations;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    mutations = [];
    api = SaasApi(
        origin: 'https://accounts.thepercentagecompany.com',
        offlineStore: IndexedOfflineStore(newIdbFactoryMemory()),
        offlineAutomatic: false,
        client: MockClient((request) async {
          if (request.method != 'GET') mutations.add(request);
          final path = request.url.path;
          final data = path == '/v1/me'
              ? {
                  'owner': {'ownerId': owner}
                }
              : path.endsWith('/employees')
                  ? request.method == 'GET'
                      ? {'employees': []}
                      : {
                          'employeeId': List.filled(43, 'e').join(),
                          'version': 1
                        }
                  : path.endsWith('/documents')
                      ? {'documentId': List.filled(43, 'd').join()}
                      : path.endsWith('/reports/settings')
                          ? {
                              'version': request.method == 'GET' ? 2 : 3,
                              'accounts': [],
                              'views': []
                            }
                          : {};
          return http.Response(jsonEncode(data), 200,
              headers: {'content-type': 'application/json'});
        }));
    api.useVerifiedWorkspace(company, ownerId: owner);
  });
  tearDown(() {
    api.close();
  });

  test(
      'employee save commits locally and is available to other forms before sync',
      () async {
    final controller =
        EmployeeAdminController(api, preferences, owner, company);
    expect(
        await controller.save(null, {
          'fullName': 'Local employee',
          'expectedVersion': 0,
          'employmentStatus': 'ACTIVE',
          'currency': 'INR'
        }),
        isTrue);
    expect(mutations, isEmpty);
    expect(controller.state.employees.single['fullName'], 'Local employee');
    final references = await api.employees(company);
    expect(
        (references['employees'] as List).single['fullName'], 'Local employee');
    await api.outbox(owner, company).sync();
    expect(mutations, hasLength(1));
    expect(api.outbox(owner, company).pending, isEmpty);
    await controller.close();
  });

  test('multiple attachments save locally without waiting for another upload',
      () async {
    final uploads = DocumentUploadQueue(api, preferences, owner, company);
    await uploads.enqueue(
        name: 'first.pdf',
        mimeType: 'application/pdf',
        section: 'Invoices',
        recordId: List.filled(43, 'i').join(),
        bytes: Uint8List.fromList([1, 2, 3]));
    await uploads.enqueue(
        name: 'second.pdf',
        mimeType: 'application/pdf',
        section: 'Invoices',
        recordId: List.filled(43, 'i').join(),
        bytes: Uint8List.fromList([4, 5, 6]));
    expect(mutations, isEmpty);
    expect(uploads.busy, isFalse);
    expect(uploads.box!.pending, hasLength(2));
    await uploads.box!.sync();
    expect(mutations, hasLength(2));
    expect(uploads.box!.pending, isEmpty);
    uploads.dispose();
  });

  test('report settings commit locally and sync using the saved version',
      () async {
    await api.saveReportSettings(
        company, {'version': 2, 'accounts': [], 'views': []});
    expect(mutations, isEmpty);
    expect(
        api.outbox(owner, company).pending.single['table'], 'ReportSettings');
    final saved = await api.reportSettings(company);
    expect(saved['version'], 2);
    await api.outbox(owner, company).sync();
    expect(mutations, hasLength(1));
    expect(jsonDecode(mutations.single.body)['expectedVersion'], 2);
    expect(api.outbox(owner, company).pending, isEmpty);
  });
}
