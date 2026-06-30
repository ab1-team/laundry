import '../../../core/network/api_client.dart';
import 'customer.dart';

class CustomerRepository {
  CustomerRepository(this._api);
  final ApiClient _api;

  Future<List<Customer>> list({String? search}) async {
    final res = await _api.dio.get('/customers', queryParameters: {
      if (search?.isNotEmpty == true) 'search': search,
    });
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Customer.fromJson)
        .toList();
  }

  Future<Customer> create({
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final res = await _api.dio.post('/customers', data: {
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
    });
    final body = res.data;
    if (body is! Map || body['data'] is! Map<String, dynamic>) {
      // API balikin error (422 validasi / 500) — `data` field gak ada atau bukan Map.
      final msg = body is Map ? body['message']?.toString() : null;
      throw Exception(msg ?? 'Response server tidak valid (bukan Map)');
    }
    return Customer.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _api.dio.delete('/customers/$id');
  }
}
