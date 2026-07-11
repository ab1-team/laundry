import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'icon.dart';

class IconRepository {
  IconRepository(this._api);
  final ApiClient _api;

  /// List icon. Backend pakai `BelongsToTenant` trait untuk auto-filter
  /// per tenant — global scope, jadi tidak perlu kirim tenant_id dari FE.
  Future<List<IconAsset>> listIcons({bool? activeOnly}) async {
    final res = await _api.dio.get('/master/icons', queryParameters: {
      if (activeOnly == true) 'active_only': true,
    });
    final data = (res.data as Map)['data'] as List;
    return data.cast<Map<String, dynamic>>().map(IconAsset.fromJson).toList();
  }

  /// Upload/create icon baru. Backend butuh multipart karena field
  /// `icon` adalah file (lihat IconRequest::rules). Pola sama dengan
  /// tenant logo upload di TenantSettingsRepository.
  Future<IconAsset> createIcon({
    required String name,
    required File iconFile,
    bool isActive = true,
  }) async {
    final form = FormData.fromMap({
      'name': name,
      'is_active': isActive,
      'icon': await MultipartFile.fromFile(
        iconFile.path,
        filename: iconFile.path.split(Platform.pathSeparator).last,
      ),
    });
    final res = await _api.dio.post('/master/icons', data: form);
    return IconAsset.fromJson(
      ((res.data as Map)['data'] as Map<String, dynamic>),
    );
  }

  /// Update icon. [iconFile] opsional — jika null, hanya update metadata.
  /// Backend akan hapus file lama dan ganti dengan yang baru bila ada
  /// upload. PUT dengan multipart bekerja di Laravel + Dio (lihat pola
  /// TenantSettingsRepository::updateTenant yang sama).
  Future<IconAsset> updateIcon(
    int id, {
    String? name,
    bool? isActive,
    File? iconFile,
  }) async {
    late final Response<dynamic> res;
    if (iconFile != null) {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (isActive != null) body['is_active'] = isActive;
      body['icon'] = await MultipartFile.fromFile(
        iconFile.path,
        filename: iconFile.path.split(Platform.pathSeparator).last,
      );
      res = await _api.dio.put('/master/icons/$id', data: FormData.fromMap(body));
    } else {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (isActive != null) body['is_active'] = isActive;
      res = await _api.dio.put('/master/icons/$id', data: body);
    }
    return IconAsset.fromJson(
      ((res.data as Map)['data'] as Map<String, dynamic>),
    );
  }

  Future<void> deleteIcon(int id) async {
    await _api.dio.delete('/master/icons/$id');
  }
}