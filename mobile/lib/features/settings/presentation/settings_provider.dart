import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../data/password_repository.dart';
import '../data/preferences_repository.dart';
import '../data/tenant_settings_repository.dart';

// ============================================================
// Repositories
// ============================================================

final tenantSettingsRepositoryProvider = Provider<TenantSettingsRepository>((ref) {
  return TenantSettingsRepository(ApiClient.instance);
});

final passwordRepositoryProvider = Provider<PasswordRepository>((ref) {
  return PasswordRepository(ApiClient.instance);
});

/// Overridden in `main()` after `SharedPreferences.getInstance()` resolves —
/// keeps reads synchronous for the rest of the app.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepository(ref.watch(sharedPreferencesProvider));
});

// ============================================================
// Tenant settings
// ============================================================

/// Fetches the authenticated user's tenant row. Auto-disposed so the screens
/// that open from settings re-fetch fresh data each visit.
final tenantSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.read(tenantSettingsRepositoryProvider);
  return repo.getTenant();
});

// ============================================================
// Theme mode (persisted locally)
// ============================================================

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._prefs) : super(_prefs.getThemeMode());
  final PreferencesRepository _prefs;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _prefs.setThemeMode(mode);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(preferencesRepositoryProvider));
});

// ============================================================
// Locale (persisted locally)
// ============================================================

class LocaleController extends StateNotifier<Locale?> {
  LocaleController(this._prefs) : super(_prefs.getLocale());
  final PreferencesRepository _prefs;

  Future<void> set(Locale? locale) async {
    state = locale;
    await _prefs.setLocale(locale);
  }
}

final localeProvider = StateNotifierProvider<LocaleController, Locale?>((ref) {
  return LocaleController(ref.watch(preferencesRepositoryProvider));
});
