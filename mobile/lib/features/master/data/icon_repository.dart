import '../../../core/network/api_client.dart';
import 'icon.dart';

/// Icon adalah global asset yang di-manage oleh super_admin via panel
/// `/admin/icons` (web). Mobile butuh list saja — untuk picker di
/// form Kategori & Layanan. Tidak ada create/update/delete dari FE.
class IconRepository {
  IconRepository(this._api);
  final ApiClient _api;

  /// List icon aktif (default `active_only=true` di mobile karena
  /// picker hanya butuh icon yang boleh dipilih). Backend return semua
  /// icon tanpa filter tenant karena tabel icons sudah global.
  Future<List<IconAsset>> listIcons({bool activeOnly = true}) async {
    final res = await _api.dio.get('/master/icons', queryParameters: {
      if (activeOnly) 'active_only': true,
    });
    final data = (res.data as Map)['data'] as List;
    return data.cast<Map<String, dynamic>>().map(IconAsset.fromJson).toList();
  }
}