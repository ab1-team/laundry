import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

/// Repository for the `tenants` row the authenticated user belongs to.
/// Calls the existing backend `GET/PUT /api/v1/settings/tenant` endpoint —
/// the row represents the user's own tenant (read + edit).
class TenantSettingsRepository {
  TenantSettingsRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> getTenant() async {
    final res = await _api.dio.get('/settings/tenant');
    return (res.data as Map)['data'] as Map<String, dynamic>;
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
    return (res.data as Map)['data'] as Map<String, dynamic>;
  }
}
