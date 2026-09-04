import '../../../helpers/secure_storage_test_channel.dart';
import 'package:laundry/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/features/orders/data/order_model.dart';
import 'package:laundry/features/orders/data/order_repository.dart';

import '../../../helpers/test_dio_adapter.dart';

void main() {
  late final SecureStorageTestChannel secureStorage;
  setUpAll(() {
    secureStorage = SecureStorageTestChannel();
    secureStorage.install();
  });

  late ApiClient apiClient;
  late OrderRepository repository;
  late Map<String, dynamic> query;
  late Object? data;
  late String path;
  late String method;

  setUp(() {
    secureStorage.values.clear();
    apiClient = ApiClient.instance;
    final adapter = TestDioAdapter((options) async => jsonResponse(null));
    apiClient.dio.httpClientAdapter = adapter;
    repository = OrderRepository(apiClient);
    query = {};
    data = null;
    path = '';
    method = '';
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      query = options.queryParameters.cast<String, dynamic>();
      data = options.data;
      path = options.path;
      method = options.method;
      return jsonResponse({'data': [orderJson]});
    });
  });

  test('list applies active/history, search and unpaid filters', () async {
    await repository.list(group: 'active', status: null, search: '', unpaid: true);
    expect(query, {'group': 'active', 'unpaid': 1});
    await repository.list(status: 'masuk', search: 'Budi');
    expect(query, {'status': 'masuk', 'search': 'Budi'});
  });

  test('show parses nested order with decimal strings', () async {
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      path = options.path;
      return jsonResponse({'data': orderJson});
    });
    final order = await repository.show(12);
    expect(path, '/orders/12');
    expect(order.ticketNumber, 'T-1');
    expect(order.customerName, 'Budi');
    expect(order.total, 7000);
    expect(order.remaining, 2000);
    expect(order.items.single.subtotal, 14000);
    expect(order.statusLogs.single.changedByName, 'Operator');
    expect(order.cashier, isNull);
  });

  test('show parses cashier when present', () async {
    final withCashier = Map<String, dynamic>.from(orderJson)..['cashier'] = 'Kasir A';
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      return jsonResponse({'data': withCashier});
    });
    final order = await repository.show(12);
    expect(order.cashier, 'Kasir A');
  });

  test('OrderModel.fromJson parses cashier null and present directly', () {
    final base = Map<String, dynamic>.from(orderJson);
    final withoutCashier = Map<String, dynamic>.from(base);
    final withCashier = Map<String, dynamic>.from(base)..['cashier'] = 'Operator 1';
    final parsedNull = OrderModel.fromJson(withoutCashier);
    final parsedPresent = OrderModel.fromJson(withCashier);
    expect(parsedNull.cashier, isNull);
    expect(parsedPresent.cashier, 'Operator 1');
  });

  test('create sends item records', () async {
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      data = options.data;
      return jsonResponse({'data': orderJson});
    });
    await repository.create(
      customerId: 3,
      items: const [(serviceId: 8, qty: 2.5)],
      notes: 'fast',
      discount: 500,
    );
    expect(data, {
      'customer_id': 3,
      'notes': 'fast',
      'discount': 500.0,
      'items': [{'service_id': 8, 'qty': 2.5}],
    });
  });

  test('updateStatus posts status and cancellation reason', () async {
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      method = options.method;
      path = options.path;
      data = options.data;
      return jsonResponse({'data': orderJson});
    });
    await repository.updateStatus(12, 'dibatalkan', cancelReason: 'duplicate');
    expect('$method $path', 'PATCH /orders/12/status');
    expect(data, {'status': 'dibatalkan', 'cancel_reason': 'duplicate'});
  });

  test('recordPayment unwraps payment payload', () async {
    Object? paymentData;
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      paymentData = options.data;
      return jsonResponse({
        'data': {'id': 4, 'amount': '5000'},
      });
    });
    final payment = await repository.recordPayment(12, amount: 5000, method: 'cash', note: 'dp');
    expect(payment, {'id': 4, 'amount': '5000'});
    expect(paymentData, {'amount': 5000.0, 'method': 'cash', 'note': 'dp'});
  });
}

const orderJson = <String, dynamic>{
  'id': 12,
  'ticket_number': 'T-1',
  'customer_id': 3,
  'customer': {'name': 'Budi', 'phone': '+62'},
  'status': 'dicuci',
  'subtotal': '15000',
  'discount': '1000',
  'total': '7000',
  'total_paid': '5000',
  'remaining': '2000',
  'created_at': '2026-07-16T10:00:00.000Z',
  'items': [{
    'id': 20,
    'service_id': 8,
    'service_name': 'Cuci',
    'unit': 'kg',
    'price': '7000',
    'qty': '2',
    'subtotal': '14000',
  }],
  'status_logs': [{
    'id': 30,
    'status': 'masuk',
    'changed_by': 7,
    'changed_by_name': 'Operator',
    'created_at': '2026-07-16T10:00:00.000Z',
  }],
};
