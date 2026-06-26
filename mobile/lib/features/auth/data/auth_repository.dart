import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import 'user_model.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<({String token, UserModel user})> login(String email, String password) async {
    final res = await _api.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final data = res.data as Map<String, dynamic>;
    final token = (data['data'] as Map)['access_token'] as String;
    final userJson = (data['data'] as Map)['user'] as Map<String, dynamic>;
    final user = UserModel.fromJson(userJson);

    await SecureStorage.instance.saveToken(token);
    return (token: token, user: user);
  }

  Future<UserModel> me() async {
    final res = await _api.dio.get('/auth/me');
    final user = ((res.data as Map)['data'] as Map)['user'] as Map<String, dynamic>;
    return UserModel.fromJson(user);
  }

  /// PUT /auth/profile — update nama + email user yang sedang login.
  /// Backend mengembalikan UserResource baru (langsung di `data`).
  Future<UserModel> updateProfile({required String name, required String email}) async {
    final res = await _api.dio.put('/auth/profile', data: {
      'name': name,
      'email': email,
    });
    final user = (res.data as Map)['data'] as Map<String, dynamic>;
    return UserModel.fromJson(user);
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/auth/logout');
    } catch (_) {
      // ignore — token might already be invalid
    } finally {
      await SecureStorage.instance.deleteToken();
    }
  }
}
