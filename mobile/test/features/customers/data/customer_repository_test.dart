import '../../../helpers/secure_storage_test_channel.dart';
import 'package:laundry/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/features/customers/data/customer_repository.dart';

import '../../../helpers/test_dio_adapter.dart';

void main() {
  late final SecureStorageTestChannel secureStorage;
  setUpAll(() {
    secureStorage = SecureStorageTestChannel();
    secureStorage.install();
  });

  late ApiClient apiClient;
  late CustomerRepository repository;
  late Object? capturedData;
  late Map<String, dynamic>? capturedQuery;

  setUp(() {
    secureStorage.values.clear();
    apiClient = ApiClient.instance;
    final adapter = TestDioAdapter((options) async => jsonResponse(null));
    apiClient.dio.httpClientAdapter = adapter;
    repository = CustomerRepository(apiClient);
    capturedQuery = null;
    capturedData = null;
  });

  void installAdapter(Object? body, {int status = 200}) {
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      capturedQuery = options.queryParameters.cast<String, dynamic>();
      capturedData = options.data;
      return jsonResponse(body, statusCode: status);
    });
  }

  test('list sends optional search and parses decimal strings', () async {
    installAdapter({'data': [
      {'id': 1, 'name': 'Budi', 'total_orders': 3, 'total_spent': '120.50'},
    ]});
    final customers = await repository.list(search: 'bud');
    expect(capturedQuery, {'search': 'bud'});
    expect(customers.single.totalSpent, 120.5);
  });

  test('create posts nullable fields and unwraps data', () async {
    installAdapter({'data': customerJson});
    final created = await repository.create(name: 'Budi');
    expect(capturedData, {
      'name': 'Budi', 'phone': null, 'address': null, 'notes': null,
    });
    expect(created.name, 'Budi');
  });

  test('update sends id path and payload', () async {
    installAdapter({'data': customerJson});
    await repository.update(9, name: 'Sinta', phone: '+62');
    expect(capturedData, {'name': 'Sinta', 'phone': '+62', 'address': null, 'notes': null});
  });

  test('delete calls expected endpoint', () async {
    var path = '';
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      path = options.path;
      return jsonResponse(null);
    });
    await repository.delete(9);
    expect(path, '/customers/9');
  });

  test('create rejects malformed envelope with readable exception', () async {
    installAdapter({'message': 'Validation failed'}, status: 422);
    await expectLater(
      repository.create(name: ''),
      throwsA(predicate((e) => e is Exception && '$e'.contains('Validation failed'))),
    );
  });
}

const customerJson = <String, dynamic>{
  'id': 1,
  'name': 'Budi',
};
