import '../../../core/network/api_client.dart';
import 'order_model.dart';

class OrderRepository {
  OrderRepository(this._api);
  final ApiClient _api;

  Future<List<OrderModel>> list({
    String? status,
    String? search,
    String? group, // 'active' | 'history'
    bool unpaid = false,
  }) async {
    final res = await _api.dio.get('/orders', queryParameters: {
      if (status != null) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      if (group != null) 'group': group,
      if (unpaid) 'unpaid': 1,
    });
    final data = (res.data as Map)['data'] as List;
    return data.cast<Map<String, dynamic>>().map(OrderModel.fromJson).toList();
  }

  Future<OrderModel> show(int id) async {
    final res = await _api.dio.get('/orders/$id');
    final data = (res.data as Map)['data'] as Map<String, dynamic>;
    return OrderModel.fromJson(data);
  }

  Future<OrderModel> create({
    required int customerId,
    required List<({int serviceId, double qty})> items,
    String? notes,
    double discount = 0,
  }) async {
    final res = await _api.dio.post('/orders', data: {
      'customer_id': customerId,
      'notes': notes,
      'discount': discount,
      'items': items.map((i) => {'service_id': i.serviceId, 'qty': i.qty}).toList(),
    });
    return OrderModel.fromJson((res.data as Map)['data'] as Map<String, dynamic>);
  }

  Future<OrderModel> updateStatus(int id, String status, {String? note, String? cancelReason}) async {
    final res = await _api.dio.patch('/orders/$id/status', data: {
      'status': status,
      if (note != null) 'note': note,
      if (cancelReason != null) 'cancel_reason': cancelReason,
    });
    return OrderModel.fromJson((res.data as Map)['data'] as Map<String, dynamic>);
  }

  /// Record a payment for [orderId]. Backend enforces the remaining
  /// balance (POST /orders/{id}/payments will 422 if amount > sisa).
  /// Returns the raw payment payload from `data`.
  Future<Map<String, dynamic>> recordPayment(
    int orderId, {
    required double amount,
    required String method,
    String? note,
  }) async {
    final res = await _api.dio.post('/orders/$orderId/payments', data: {
      'amount': amount,
      'method': method,
      if (note != null) 'note': note,
    });
    return (res.data as Map)['data'] as Map<String, dynamic>;
  }
}
