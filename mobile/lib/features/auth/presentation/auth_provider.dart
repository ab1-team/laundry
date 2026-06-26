import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_message.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_repository.dart';
import '../data/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ApiClient.instance);
});

/// Auth state — drives navigation: unauthenticated → login, authenticated → home.
class AuthState {
  const AuthState({this.user, this.loading = false, this.error});
  final UserModel? user;
  final bool loading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({UserModel? user, bool? loading, String? error, bool clearUser = false, bool clearError = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(const AuthState());

  final AuthRepository _repo;

  /// Try restoring session on app boot.
  Future<bool> bootstrap() async {
    final token = await SecureStorage.instance.readToken();
    if (token == null || token.isEmpty) return false;
    try {
      final user = await _repo.me();
      state = state.copyWith(user: user);
      return true;
    } catch (_) {
      await SecureStorage.instance.deleteToken();
      return false;
    }
  }

  /// Re-fetch the authenticated user from `/auth/me` and merge it into the
  /// current state. Used after the user edits fields that the cached user
  /// object exposes (e.g. tenant name) so screens reading `authProvider`
  /// update without a full logout/login cycle.
  Future<void> refreshUser() async {
    try {
      final user = await _repo.me();
      state = state.copyWith(user: user);
    } catch (_) {
      // Silent — caller just won't see a fresh user.
    }
  }

  /// Replace the cached [UserModel] without a network round-trip — caller
  /// already has the updated object (e.g. from PUT /auth/profile response).
  /// Keeps the notifier's `state` setter private to this class.
  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
  }

  /// Clear the error message without touching user/loading.
  /// Called by the login screen when user starts editing fields again so
  /// a stale error ("Email atau password salah") doesn't linger after
  /// the user typed the correct credentials.
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await _repo.login(email, password);
      state = state.copyWith(user: res.user, loading: false);
      return true;
    } on Exception catch (e) {
      state = state.copyWith(loading: false, error: extractApiMessage(e));
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.read(authRepositoryProvider));
});
