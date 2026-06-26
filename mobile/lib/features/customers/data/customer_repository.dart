import '../../../core/network/api_client.dart';
import 'customer.dart';

class CustomerRepository {
  CustomerRepository(this._api);
  final ApiClient _api;

  Future<List<Customer>> list({String? search}) async {
    final res = await _api.dio.get('/customers', queryParameters: {
      if (search?.isNotEmpty == true) 'search': search,
    });
    final data = (res.data as Map)['data'] as List;
    return data.cast<Map<String, dynamic>>().map(Customer.fromJson).toList();
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
    return Customer.fromJson(((res.data as Map)['data'] as Map<String, dynamic>));
  }

  Future<void> delete(int id) async {
    await _api.dio.delete('/customers/$id');
  }
}
