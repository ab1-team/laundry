import '../../../core/network/api_client.dart';

/// Repository for the `PUT /api/v1/auth/password` endpoint.
class PasswordRepository {
  PasswordRepository(this._api);
  final ApiClient _api;

  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    await _api.dio.put('/auth/password', data: {
      'current_password': current,
      'password': next,
      'password_confirmation': next,
    });
  }
}
