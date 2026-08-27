import '../../../core/network/api_client.dart';
import 'service.dart';
import 'service_category.dart';

class MasterRepository {
  MasterRepository(this._api);
  final ApiClient _api;

  // ==================
  // Service Categories
  // ==================

  Future<List<ServiceCategory>> listCategories({bool? activeOnly}) async {
    final res = await _api.dio.get('/master/service-categories', queryParameters: {
      if (activeOnly == true) 'active_only': true,
    });
    final data = (res.data as Map)['data'] as List;
    return data.cast<Map<String, dynamic>>().map(ServiceCategory.fromJson).toList();
  }

  Future<ServiceCategory> createCategory({required String name, int? iconId, int sortOrder = 0, bool isActive = true}) async {
    final res = await _api.dio.post('/master/service-categories', data: {
      'name': name,
      'icon_id': iconId,
      'sort_order': sortOrder,
      'is_active': isActive,
    });
    return ServiceCategory.fromJson(((res.data as Map)['data'] as Map<String, dynamic>));
  }

  Future<ServiceCategory> updateCategory(int id, {String? name, int? iconId, bool clearIcon = false, int? sortOrder, bool? isActive}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    // Selalu kirim icon_id kalau caller sebut — termasuk null eksplisit
    // lewat flag `clearIcon` (untuk unset). Backend rule `nullable`
    // mengizinkan null; kalau field tidak dikirim sama sekali, Eloquent
    // tidak update kolom.
    //
    // Catatan: versi sebelumnya menggunakan heuristik "kirim null kalau
    // field lain semua null" yang membuat `updateCategory(id, name:'X',
    // iconId: null)` diam-diam TIDAK mengirim icon_id, padahal intent
    // user bisa saja ingin mengubah nama sekaligus menghapus icon.
    // Caller sekarang harus pakai `clearIcon: true` untuk unset
    // (konsisten dengan createService yang mengirim key icon_id apa
    // adanya).
    if (iconId != null || clearIcon) {
      body['icon_id'] = iconId;
    }
    if (sortOrder != null) body['sort_order'] = sortOrder;
    if (isActive != null) body['is_active'] = isActive;
    final res = await _api.dio.put('/master/service-categories/$id', data: body);
    return ServiceCategory.fromJson(((res.data as Map)['data'] as Map<String, dynamic>));
  }

  Future<void> deleteCategory(int id) async {
    await _api.dio.delete('/master/service-categories/$id');
  }

  // ========
  // Services
  // ========

  Future<List<Service>> listServices({int? categoryId, String? search, bool? activeOnly}) async {
    final res = await _api.dio.get('/master/services', queryParameters: {
      if (categoryId != null) 'category_id': categoryId,
      if (search?.isNotEmpty == true) 'search': search,
      if (activeOnly == true) 'active_only': true,
    });
    final data = (res.data as Map)['data'] as List;
    return data.cast<Map<String, dynamic>>().map(Service.fromJson).toList();
  }

  Future<Service> createService({
    required int categoryId,
    required String name,
    required double price,
    required String unit,
    int? iconId,
    int durationHours = 24,
    bool isActive = true,
  }) async {
    final res = await _api.dio.post('/master/services', data: {
      'category_id': categoryId,
      'icon_id': iconId,
      'name': name,
      'price': price,
      'unit': unit,
      'duration_hours': durationHours,
      'is_active': isActive,
    });
    return Service.fromJson(((res.data as Map)['data'] as Map<String, dynamic>));
  }

  Future<Service> updateService(int id, {
    int? categoryId,
    int? iconId,
    bool clearIcon = false,
    String? name,
    double? price,
    String? unit,
    int? durationHours,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (categoryId != null) body['category_id'] = categoryId;
    // Lihat updateCategory — gunakan flag `clearIcon` eksplisit untuk
    // unset, bukan heuristik yang bisa di-bypass.
    if (iconId != null || clearIcon) {
      body['icon_id'] = iconId;
    }
    if (name != null) body['name'] = name;
    if (price != null) body['price'] = price;
    if (unit != null) body['unit'] = unit;
    if (durationHours != null) body['duration_hours'] = durationHours;
    if (isActive != null) body['is_active'] = isActive;
    final res = await _api.dio.put('/master/services/$id', data: body);
    return Service.fromJson(((res.data as Map)['data'] as Map<String, dynamic>));
  }

  Future<void> deleteService(int id) async {
    await _api.dio.delete('/master/services/$id');
  }
}
