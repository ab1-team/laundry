import '../../../helpers/secure_storage_test_channel.dart';
import 'package:laundry/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/features/master/data/icon_repository.dart';
import 'package:laundry/features/master/data/master_repository.dart';

import '../../../helpers/test_dio_adapter.dart';

void main() {
  late final SecureStorageTestChannel secureStorage;
  setUpAll(() {
    secureStorage = SecureStorageTestChannel();
    secureStorage.install();
  });

  late ApiClient apiClient;
  late MasterRepository repository;
  late IconRepository iconRepository;
  Object? query;
  Object? data;
  late String path;
  late String method;

  setUp(() {
    secureStorage.values.clear();
    apiClient = ApiClient.instance;
    final adapter = TestDioAdapter((options) async => jsonResponse(null));
    apiClient.dio.httpClientAdapter = adapter;
    repository = MasterRepository(apiClient);
    iconRepository = IconRepository(apiClient);
    data = null;
    query = null;
    path = '';
    method = '';
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      query = options.queryParameters.cast<String, dynamic>();
      data = options.data;
      path = options.path;
      method = options.method;
      return jsonResponse({'data': categoryJson});
    });
  });

  test('listCategories optionally requests active records', () async {
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      query = options.queryParameters.cast<String, dynamic>();
      path = options.path;
      return jsonResponse({'data': [categoryJson]});
    });
    await repository.listCategories();
    final firstQuery = query!;
    final firstPath = path;
    query = null;
    await repository.listCategories(activeOnly: true);
    final secondQuery = query!;
    expect(firstQuery, isEmpty);
    expect(secondQuery, {'active_only': true});
    expect(firstPath, '/master/service-categories');
  });

  test('createCategory sends defaults and parses model', () async {
    final created = await repository.createCategory(name: 'Cuci');
    expect(method, 'POST');
    expect(data, {'name': 'Cuci', 'icon_id': null, 'sort_order': 0, 'is_active': true});
    expect(created.name, 'Kategori');
  });

  test('updateCategory preserves explicit icon clearing', () async {
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      method = options.method;
      data = options.data;
      return jsonResponse({'data': categoryJson});
    });
    await repository.updateCategory(3, name: 'New', iconId: null);
    expect(method, 'PUT');
    expect(data, {'name': 'New'});
  });

  test('service CRUD sends filters and payloads', () async {
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      query = options.queryParameters.cast<String, dynamic>();
      data = options.data;
      method = options.method;
      if (options.path == '/master/services' && options.method == 'GET') {
        return jsonResponse({'data': [serviceJson]});
      }
      if (options.path.startsWith('/master/services')) {
        return jsonResponse({'data': serviceJson});
      }
      return jsonResponse({'data': categoryJson});
    });
    await repository.listServices(categoryId: 4, search: '', activeOnly: true);
    expect(query, {'category_id': 4, 'active_only': true});

    await repository.createService(
      categoryId: 4,
      name: 'Kiloan',
      price: 7000,
      unit: 'kg',
      durationHours: 48,
    );
    final createPayload = data;
    expect(createPayload, isNotNull);
    expect(createPayload, {
      'category_id': 4,
      'icon_id': null,
      'name': 'Kiloan',
      'price': 7000.0,
      'unit': 'kg',
      'duration_hours': 48,
      'is_active': true,
    });
    expect(createPayload, isMap);

    await repository.updateService(8, isActive: false);
    expect(data, {'is_active': false});
  });

  test('delete endpoints are called correctly', () async {
    await repository.deleteCategory(1);
    expect('$method $path', 'DELETE /master/service-categories/1');
    await repository.deleteService(2);
    expect('$method $path', 'DELETE /master/services/2');
  });

  test('icon repository sends active filter and resolves URLs', () async {
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      query = options.queryParameters.cast<String, dynamic>();
      return jsonResponse({'data': [
        {...iconJson, 'icon_url': '/storage/icons/shirt.png'},
        {...iconJson, 'id': 2, 'icon_url': 'https://cdn.test/x.png'},
      ]});
    });
    final icons = await iconRepository.listIcons();
    expect(query, {'active_only': true});
    expect(icons.first.iconUrl, contains('/storage/icons/shirt.png'));
    expect(icons.last.iconUrl, 'https://cdn.test/x.png');
  });

  test('updateCategory sends icon_id only when caller opts in (clearIcon)', () async {
    // Bug: versi lama mengirim icon_id = null hanya kalau semua field
    // lain null, sehingga `updateCategory(id, name:'X', iconId:null)`
    // diam-diam TIDAK mengirim icon_id dan backend tidak bisa clear.
    // Fix: tambah flag eksplisit `clearIcon` — null saja tanpa flag
    // tidak boleh mengirim key icon_id.
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      data = options.data;
      return jsonResponse({'data': categoryJson});
    });

    // 1) Hanya set nama → icon_id TIDAK boleh dikirim.
    await repository.updateCategory(10, name: 'Baru');
    expect(data, {'name': 'Baru'});

    // 2) Clear icon secara eksplisit → key icon_id HARUS dikirim (null).
    await repository.updateCategory(10, clearIcon: true);
    expect(data, {'icon_id': null});

    // 3) Set icon ke nilai baru → key icon_id HARUS dikirim (non-null).
    await repository.updateCategory(10, iconId: 7);
    expect(data, {'icon_id': 7});
  });

  test('updateService honors clearIcon for explicit icon unset', () async {
    apiClient.dio.httpClientAdapter = TestDioAdapter((options) async {
      data = options.data;
      return jsonResponse({'data': serviceJson});
    });
    // Hanya set nama → icon_id TIDAK boleh dikirim (sesuai fix).
    await repository.updateService(11, name: 'Baru');
    expect(data, {'name': 'Baru'});

    // Clear icon → key icon_id HARUS dikirim sebagai null.
    await repository.updateService(11, clearIcon: true);
    expect(data, {'icon_id': null});
  });
}

const categoryJson = <String, dynamic>{
  'id': 10,
  'name': 'Kategori',
};

const serviceJson = <String, dynamic>{
  'id': 11,
  'category_id': 4,
  'name': 'Kiloan',
  'price': '7000',
  'unit': 'kg',
};

const iconJson = <String, dynamic>{
  'id': 5,
  'name': 'Shirt',
};
