import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Repository for the `tenants` row the authenticated user belongs to.
/// Calls the existing backend `GET/PUT /api/v1/settings/tenant` endpoint —
/// the row represents the user's own tenant (read + edit).
class TenantSettingsRepository {
  TenantSettingsRepository(this._api);
  final ApiClient _api;

  /// Extract `{success, message, data}` → `data` as Map<String, dynamic>.
  /// Sama helper-nya dengan `WhatsAppRepository._unwrapData`. Kalau backend
  /// mengembalikan body tanpa `data`, lempar ApiException dengan path +
  /// status supaya snackbar UI menampilkan pesan jelas (sebelumnya throw
  /// raw TypeError `Null is not a subtype of Map<String, dynamic>`).
  Map<String, dynamic> _unwrapData(Response<dynamic> res, String endpoint) {
    final body = res.data;
    if (body is! Map) {
      throw ApiException(
        'Response dari $endpoint bukan JSON object',
        statusCode: res.statusCode,
      );
    }
    final data = body['data'];
    if (data is! Map) {
      throw ApiException(
        'Response dari $endpoint tidak punya field "data" '
        '(success=${body['success']}, message=${body['message'] ?? '(none)'})',
        statusCode: res.statusCode,
      );
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> getTenant() async {
    final res = await _api.dio.get('/settings/tenant');
    return _unwrapData(res, 'GET /settings/tenant');
  }

  /// Update tenant settings. If [logoFile] is provided, request is sent as
  /// multipart/form-data so the backend can store the file. Otherwise a
  /// regular JSON PUT is used.
  Future<Map<String, dynamic>> updateTenant(
    Map<String, dynamic> body, {
    File? logoFile,
  }) async {
    final Response<dynamic> res;
    if (logoFile != null) {
      final form = FormData.fromMap({
        ...body,
        'logo': await MultipartFile.fromFile(
          logoFile.path,
          filename: logoFile.path.split(Platform.pathSeparator).last,
        ),
      });
      res = await _api.dio.put('/settings/tenant', data: form);
    } else {
      res = await _api.dio.put('/settings/tenant', data: body);
    }
    return _unwrapData(res, 'PUT /settings/tenant');
  }
}
