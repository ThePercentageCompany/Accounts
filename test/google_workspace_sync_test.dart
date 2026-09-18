import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpc_invoice/core/auth/google_workspace_service.dart';
import 'package:tpc_invoice/core/sync/sheet_schema.dart';

http.Response jsonResponse(Object value, [int status = 200]) =>
    http.Response(jsonEncode(value), status, headers: {'content-type': 'application/json'});

http.Response? schemaResponse(http.Request request) {
  if (request.url.queryParameters['fields'] == 'sheets.properties') {
    return jsonResponse({'sheets': [
      for (final tab in SheetSchema.allTabs) {'properties': {'title': tab}},
    ]});
  }
  final ranges = request.url.queryParametersAll['ranges'];
  if (ranges != null && ranges.every((range) => range.endsWith('!1:1'))) {
    return jsonResponse({'valueRanges': [
      for (final tab in SheetSchema.allTabs) {'values': [SheetSchema.getHeaders(tab)]},
    ]});
  }
  return null;
}

void main() {
  test('batch sync reads every schema column including columns after Z', () async {
    final service = GoogleWorkspaceService(client: MockClient((request) async {
      final schema = schemaResponse(request);
      if (schema != null) return schema;
      final ranges = request.url.queryParametersAll['ranges']!;
      expect(ranges, ["'Employees'!A2:AA", "'Payroll'!A2:Y", "'Assets'!A2:X"]);
      final employees = List<dynamic>.filled(SheetSchema.getHeaders('Employees').length, '');
      employees[0] = 'employee-1'; employees[26] = 'Owner Admin';
      return jsonResponse({'valueRanges': [
        {'values': [employees]}, {}, {},
      ]});
    }));
    final result = await service.readAllTabsBatch('token', 'sheet', ['Employees', 'Payroll', 'Assets']);
    expect(result['Employees']!.single['updatedBy'], 'Owner Admin');
    expect(result['Payroll'], isEmpty);
    expect(result['Assets'], isEmpty);
  });

  test('failed batch read and incomplete response never masquerade as empty data', () async {
    for (final response in [jsonResponse({'error': {'message': 'Permission denied'}}, 403), jsonResponse({'valueRanges': []})]) {
      final service = GoogleWorkspaceService(client: MockClient((request) async => schemaResponse(request) ?? response));
      await expectLater(service.readAllTabsBatch('token', 'sheet', ['Settings']), throwsStateError);
    }
  });

  test('single-tab read surfaces server errors without clearing data', () async {
    final service = GoogleWorkspaceService(client: MockClient((_) async => jsonResponse({'error': {'message': 'Quota exceeded'}}, 429)));
    await expectLater(service.readTabRecords('token', 'sheet', 'Finance'), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('429'))));
  });

  test('failed ID lookup never writes over row 2', () async {
    final requests = <http.Request>[];
    final service = GoogleWorkspaceService(client: MockClient((request) async {
      requests.add(request);
      return jsonResponse({'error': {'message': 'Expired token'}}, 401);
    }));
    await expectLater(service.upsertTabRecord('token', 'sheet', 'Customers', 'c1', {'id': 'c1', 'name': 'Client'}), throwsStateError);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
  });

  test('new records append atomically and keep identifiers and text literal', () async {
    final service = GoogleWorkspaceService(client: MockClient((request) async {
      final schema = schemaResponse(request);
      if (schema != null) return schema;
      if (request.method == 'GET') return jsonResponse({'values': [['another-customer']]});
      expect(request.method, 'POST');
      expect(request.url.path, endsWith(':append'));
      expect(request.url.queryParameters['valueInputOption'], 'RAW');
      expect(request.url.queryParameters['insertDataOption'], 'INSERT_ROWS');
      final row = (jsonDecode(request.body)['values'] as List).single as List;
      expect(row[0], '0012');
      expect(row[1], '=Client');
      return jsonResponse({});
    }));
    await service.upsertTabRecord('token', 'sheet', 'Customers', '0012', {'id': '0012', 'name': '=Client'});
  });

  test('delete targets one sheet row without clearing or rewriting the table', () async {
    final methods = <String>[];
    final service = GoogleWorkspaceService(client: MockClient((request) async {
      methods.add(request.method);
      if (request.url.queryParameters['fields'] == 'sheets.properties') {
        return jsonResponse({'sheets': [{'properties': {'title': 'Employees', 'sheetId': 9}}]});
      }
      if (request.method == 'GET') return jsonResponse({'values': [['keep'], ['remove'], ['keep-too']]});
      expect(request.url.path, endsWith(':batchUpdate'));
      final range = jsonDecode(request.body)['requests'][0]['deleteDimension']['range'];
      expect(range, {'sheetId': 9, 'dimension': 'ROWS', 'startIndex': 2, 'endIndex': 3});
      return jsonResponse({});
    }));
    await service.deleteTabRecord('token', 'sheet', 'Employees', 'remove');
    expect(methods, ['GET', 'GET', 'POST']);
  });

  test('schema mismatch fails before existing columns can be relabelled', () async {
    final requests = <http.Request>[];
    final service = GoogleWorkspaceService(client: MockClient((request) async {
      requests.add(request);
      if (request.url.queryParameters.containsKey('fields')) return jsonResponse({'sheets': [{'properties': {'title': 'Customers'}}]});
      return jsonResponse({'valueRanges': [{'values': [['Customer Name', 'Customer ID']]}]});
    }));
    await expectLater(service.ensureAllTabsExist('token', 'sheet'), throwsA(isA<StateError>().having((e) => e.message, 'message', contains('original order'))));
    expect(requests.every((request) => request.method == 'GET'), isTrue);
  });

  test('schema migration expands narrow sheets before writing column AA', () async {
    var resized = false;
    final service = GoogleWorkspaceService(client: MockClient((request) async {
      if (request.url.queryParameters['fields'] == 'sheets.properties') {
        return jsonResponse({'sheets': [
          for (final tab in SheetSchema.allTabs) {'properties': {
            'title': tab, 'sheetId': SheetSchema.allTabs.indexOf(tab),
            'gridProperties': {'columnCount': 26},
          }},
        ]});
      }
      if (request.method == 'GET') {
        return jsonResponse({'valueRanges': [
          for (final tab in SheetSchema.allTabs) {'values': [SheetSchema.getHeaders(tab).take(26).toList()]},
        ]});
      }
      if (request.url.path.endsWith('/values:batchUpdate')) {
        expect(resized, isTrue);
        expect(jsonDecode(request.body)['data'][0]['range'], "'Employees'!A1:AA1");
      } else {
        final properties = jsonDecode(request.body)['requests'][0]['updateSheetProperties']['properties'];
        expect(properties['gridProperties']['columnCount'], 27);
        resized = true;
      }
      return jsonResponse({});
    }));
    await service.ensureAllTabsExist('token', 'sheet');
    expect(resized, isTrue);
  });

  test('Drive upload preserves exact binary data and returns confirmed link', () async {
    final bytes = Uint8List.fromList([0, 255, 128, 13, 10, 37, 80, 68, 70]);
    final service = GoogleWorkspaceService(client: MockClient((request) async {
      if (request.method == 'GET') return jsonResponse({'files': [
        for (final folder in GoogleWorkspaceService.standardSubfolders) {'id': 'folder-$folder', 'name': folder},
      ]});
      expect(request.url.path, '/upload/drive/v3/files');
      expect(request.headers['authorization'], 'Bearer token');
      expect(request.bodyBytes, containsAllInOrder(bytes));
      expect(utf8.decode(request.bodyBytes, allowMalformed: true), contains('folder-Assets'));
      return jsonResponse({'id': 'image-1'}, 201);
    }));
    expect(await service.uploadImageFile('token', 'binary-root', 'logo.png', bytes), 'https://drive.google.com/file/d/image-1/view');
  });

  test('Drive failure is visible and cannot be reported as upload success', () async {
    final service = GoogleWorkspaceService(client: MockClient((request) async {
      if (request.method == 'GET') return jsonResponse({'files': [
        for (final folder in GoogleWorkspaceService.standardSubfolders) {'id': 'folder-$folder', 'name': folder},
      ]});
      return jsonResponse({'error': {'message': 'Storage quota exceeded'}}, 403);
    }));
    await expectLater(service.uploadImageFile('token', 'failed-root', 'logo.png', Uint8List.fromList([1])),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Storage quota exceeded'))));
  });

  test('private image download uses authenticated media instead of HTML view URL', () async {
    final bytes = Uint8List.fromList([137, 80, 78, 71]);
    final service = GoogleWorkspaceService(client: MockClient((request) async {
      expect(request.url.toString(), 'https://www.googleapis.com/drive/v3/files/image-1?alt=media');
      expect(request.headers['authorization'], 'Bearer private-token');
      return http.Response.bytes(bytes, 200, headers: {'content-type': 'image/png'});
    }));
    final result = await service.downloadDriveFile('private-token', 'https://drive.google.com/file/d/image-1/view');
    expect(base64Decode(result['base64'] as String), bytes);
    expect(result['mimeType'], 'image/png');
    await expectLater(service.downloadDriveFile('token', 'https://other.example/file/d/image-1/view'), throwsStateError);
  });
}
