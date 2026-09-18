import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/google_session.dart';
import '../../../core/auth/google_workspace_service.dart';
import '../domain/models.dart';

/// The sheet stores a private Drive reference. Image bytes stay in a separate
/// device cache so a sheet refresh cannot erase the displayed logo.
class CompanyLogoStorage {
  CompanyLogoStorage(this.session, this.service);

  final GoogleSession session;
  final GoogleWorkspaceService service;

  String get _cacheKey =>
      'tpc_company_logo_${session.workspace?.spreadsheetId ?? 'local'}_'
      '${session.isEmployee ? session.workspace?.employeeId ?? 'employee' : 'owner'}';

  Future<String> _cachedLogo(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return '';
    try {
      final cached = jsonDecode(raw) as Map;
      return cached['url'] == url ? cached['logo']?.toString() ?? '' : '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _cache(String url, String logo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode({'url': url, 'logo': logo}));
  }

  Future<Company> hydrate(Company company) async {
    final url = company.logoDriveUrl;
    if (url.isEmpty) return company;
    if (companyLogoBytes(company.logo)?.isNotEmpty == true) {
      await _cache(url, company.logo);
      return company;
    }
    final cached = await _cachedLogo(url);
    if (companyLogoBytes(cached)?.isNotEmpty == true) {
      return company.copyWith(logo: cached);
    }
    try {
      final Map<String, dynamic> file;
      if (session.isCodeEmployeeSession) {
        file = await session.downloadEmployeeFile(url);
      } else {
        final token = await session.tryGetToken();
        if (token == null) return company;
        file = await service.downloadDriveFile(token, url);
      }
      final mime = file['mimeType']?.toString().split(';').first ?? '';
      final encoded = file['base64']?.toString() ?? '';
      if (!mime.startsWith('image/') || encoded.isEmpty) return company;
      final logo = 'data:$mime;base64,$encoded';
      if (companyLogoBytes(logo)?.isNotEmpty != true) return company;
      await _cache(url, logo);
      return company.copyWith(logo: logo);
    } catch (_) {
      // Keep the reference on a transient download failure. Saving another
      // company field must not remove an image that could not load offline.
      return company;
    }
  }

  Future<Company> prepareForSave(Company company, Company previous) async {
    if (company.logo.isEmpty) return company;
    final bytes = companyLogoBytes(company.logo);
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('Choose a valid PNG or JPEG company logo.');
    }
    final previousLogo = previous.logo.isNotEmpty
        ? previous.logo
        : await _cachedLogo(previous.logoDriveUrl);
    if (previous.logoDriveUrl.isNotEmpty && previousLogo == company.logo) {
      return company.copyWith(logoDriveUrl: previous.logoDriveUrl);
    }
    final token = await session.tryGetToken();
    final folder = session.workspace?.driveFolderId ?? '';
    if (token == null || folder.isEmpty) {
      throw StateError('Reconnect Google Drive to save the company logo.');
    }
    final mime = company.logo.startsWith('data:')
        ? company.logo.substring(5).split(';').first
        : (bytes.length > 2 && bytes[0] == 255 && bytes[1] == 216
              ? 'image/jpeg'
              : 'image/png');
    if (mime != 'image/png' && mime != 'image/jpeg') {
      throw const FormatException('Choose a PNG or JPEG company logo.');
    }
    final extension = mime == 'image/jpeg' ? 'jpg' : 'png';
    final name = company.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final url = await service.uploadImageFile(
      token,
      folder,
      '${name.isEmpty ? 'company' : name}_logo.$extension',
      bytes,
      mimeType: mime,
      subfolder: 'Assets',
    );
    if (url.isEmpty) {
      throw StateError('The company logo upload did not complete. Please retry.');
    }
    await _cache(url, company.logo);
    return company.copyWith(logoDriveUrl: url);
  }
}
