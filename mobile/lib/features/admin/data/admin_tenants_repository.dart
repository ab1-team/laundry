import '../../../core/network/api_client.dart';

/// Repository for the Super-Admin tenant management endpoints.
/// Backend: /api/v1/admin/tenants* — protected by `role:super_admin`.
class AdminTenantsRepository {
  AdminTenantsRepository(this._api);
  final ApiClient _api;

  /// GET /admin/tenants?search=&status=&page=
  /// Returns: { data: Tenant[], meta: { current_page, last_page, total, ... } }
  Future<({List<Map<String, dynamic>> items, int currentPage, int lastPage, int total})>
      list({String? search, String? status, int page = 1}) async {
    final res = await _api.dio.get('/admin/tenants', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
      'page': page,
    });
    final data = (res.data as Map)['data'] as List;
    final meta = (res.data as Map)['meta'] as Map?;
    return (
      items: data.cast<Map<String, dynamic>>(),
      currentPage: (meta?['current_page'] as int?) ?? 1,
      lastPage: (meta?['last_page'] as int?) ?? 1,
      total: (meta?['total'] as int?) ?? data.length,
    );
  }

  Future<Map<String, dynamic>> show(int id) async {
    final res = await _api.dio.get('/admin/tenants/$id');
    return ((res.data as Map)['data'] as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> create({
    required String name,
    required String slug,
    String? phone,
    String? address,
    String? city,
    required String ownerName,
    required String ownerEmail,
    required String ownerPassword,
  }) async {
    final res = await _api.dio.post('/admin/tenants', data: {
      'name': name,
      'slug': slug,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (address != null && address.isNotEmpty) 'address': address,
      if (city != null && city.isNotEmpty) 'city': city,
      'owner_name': ownerName,
      'owner_email': ownerEmail,
      'owner_password': ownerPassword,
    });
    return ((res.data as Map)['data'] as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> activate(int id) async {
    final res = await _api.dio.patch('/admin/tenants/$id/activate');
    return ((res.data as Map)['data'] as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> suspend(int id, {String? reason}) async {
    final res = await _api.dio.patch('/admin/tenants/$id/suspend', data: {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return ((res.data as Map)['data'] as Map).cast<String, dynamic>();
  }
}
