import '../../../helpers/secure_storage_test_channel.dart';
import 'package:laundry/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/features/admin/data/admin_providers.dart';
import 'package:laundry/features/admin/data/admin_tenants_repository.dart';

import '../../../helpers/test_dio_adapter.dart';

void main() {
  late final SecureStorageTestChannel secureStorage;
  setUpAll(() {
    secureStorage = SecureStorageTestChannel();
    secureStorage.install();
  });

  late ApiClient apiClient;
  late AdminTenantsRepository repository;
  late Map<String, dynamic> query;
  late Object? data;
  late String path;
  late String method;

  setUp(() {
    secureStorage.values.clear();
    apiClient = ApiClient.instance;
    final adapter = TestDioAdapter((options) async => jsonResponse(null));
    apiClient.dio.httpClientAdapter = adapter;
    repository = AdminTenantsRepository(apiClient);
    query = {};
    data = null;
    path = '';
    method = '';
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      query = options.queryParameters.cast<String, dynamic>();
      data = options.data;
      path = options.path;
      return jsonResponse({'data': [tenantJson], 'meta': {'current_page': 2, 'last_page': 5, 'total': 42}});
    });
  });

  test('list returns normalized pagination and filters', () async {
    final result = await repository.list(search: 'clean', status: 'active', page: 2);
    expect(query, {'search': 'clean', 'status': 'active', 'page': 2});
    expect(result.items.single, tenantJson);
    expect(result.currentPage, 2);
    expect(result.lastPage, 5);
    expect(result.total, 42);
  });

  test('create omits blank optional tenant fields', () async {
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      data = options.data;
      path = options.path;
      return jsonResponse({'data': tenantJson});
    });
    await repository.create(
      name: 'Clean',
      slug: 'clean',
      phone: '',
      address: null,
      ownerName: 'Owner',
      ownerEmail: 'owner@test.dev',
      ownerPassword: 'secret',
    );
    expect(path, '/admin/tenants');
    expect(data, {
      'name': 'Clean',
      'slug': 'clean',
      'owner_name': 'Owner',
      'owner_email': 'owner@test.dev',
      'owner_password': 'secret',
    });
  });

  test('activate and suspend use PATCH with optional reason', () async {
    Object? activateData;
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      method = options.method;
      path = options.path;
      data = options.data;
      final response = jsonResponse({'data': tenantJson});
      if (options.path.endsWith('/activate')) activateData = response;
      return response;
    });
    await repository.activate(9);
    expect('$method $path', 'PATCH /admin/tenants/9/activate');
    expect(activateData, isNotNull);
    await repository.suspend(9, reason: 'overdue');
    expect('$method $path', 'PATCH /admin/tenants/9/suspend');
    expect(data, {'reason': 'overdue'});
    await repository.suspend(9);
    expect(data, isEmpty);
    expect(activateData, isNotNull);
  });

  test('filter copyWith supports replacement and explicit clearing', () {
    const filter = AdminTenantListFilter(search: 'a', status: 'active');
    expect(filter.copyWith(search: 'b').search, 'b');
    expect(filter.copyWith(status: 'suspended').status, 'suspended');
    expect(filter.copyWith(clearStatus: true).status, isNull);
  });
}

const tenantJson = <String, dynamic>{'id': 9, 'name': 'Clean'};
