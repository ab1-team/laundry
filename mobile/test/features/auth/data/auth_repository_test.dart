import 'package:flutter_test/flutter_test.dart';
import 'package:laundry/core/network/api_client.dart';
import 'package:laundry/core/network/api_exception.dart';
import 'package:laundry/core/storage/secure_storage.dart';
import 'package:laundry/features/auth/data/auth_repository.dart';

import '../../../helpers/test_dio_adapter.dart';
import '../../../helpers/secure_storage_test_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient apiClient;
  late AuthRepository repository;
  late TestDioAdapter adapter;
  final storage = SecureStorageTestChannel();

  setUpAll(storage.install);


  setUp(() {
    storage.values.clear();
    apiClient = ApiClient.instance;
    adapter = TestDioAdapter((options) async => jsonResponse(null));
    apiClient.dio.httpClientAdapter = adapter;
    repository = AuthRepository(apiClient);
  });

  test('login posts credentials, saves token, and maps user', () async {
    adapter = TestDioAdapter((options) async {
      expect(options.path, '/auth/login');
      expect(options.data, {'email': 'owner@test.dev', 'password': 'secret'});
      return jsonResponse({
        'data': {
          'access_token': 'token-1',
          'user': {'id': 7, 'name': 'Owner', 'email': 'owner@test.dev', 'role': 'owner'},
        },
      });
    });

    apiClient.dio.httpClientAdapter = adapter;
    final result = await repository.login('owner@test.dev', 'secret');
    expect(result.token, 'token-1');
    expect(result.user.name, 'Owner');
    expect(result.user.isOwner, isTrue);
    expect(storage.values['auth_token'], 'token-1');
  });

  test('me and updateProfile unwrap user payloads', () async {
    adapter = TestDioAdapter((options) async {
      if (options.path == '/auth/me') {
        return jsonResponse({'data': {'user': userJson}});
      }
      expect(options.path, '/auth/profile');
      return jsonResponse({'data': userJson});
    });
    apiClient.dio.httpClientAdapter = adapter;
    await SecureStorage.instance.saveToken('ignored');

    final me = await repository.me();
    expect(me.email, 'owner@test.dev');
    final updated = await repository.updateProfile(name: 'New Name', email: 'new@test.dev');
    expect(updated.name, 'Owner');
  });

  test('logout deletes token even if request fails', () async {
    adapter = TestDioAdapter((options) async => jsonResponse({}, statusCode: 401));
    apiClient.dio.httpClientAdapter = adapter;
    await SecureStorage.instance.saveToken('token');

    await repository.logout();
    expect(storage.values, isEmpty);
  });

  test('throws ApiException for malformed login response', () async {
    adapter = TestDioAdapter((options) async => jsonResponse({'message': 'bad'}));
    apiClient.dio.httpClientAdapter = adapter;
    await expectLater(repository.login('a@b.co', 'x'), throwsA(isA<ApiException>()));
  });
}

const userJson = <String, dynamic>{
  'id': 7,
  'name': 'Owner',
  'email': 'owner@test.dev',
  'role': 'owner',
  'is_active': true,
  'tenant_id': 2,
};
