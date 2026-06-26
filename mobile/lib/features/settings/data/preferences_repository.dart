import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only preferences for the current device: theme mode + language.
/// Persisted via SharedPreferences (no backend round-trip). Designed to be
/// read once at boot and exposed as Riverpod notifiers so the app shell can
/// react to changes.
class PreferencesRepository {
  PreferencesRepository(this._prefs);
  final SharedPreferences _prefs;

  static const _kThemeMode = 'pref.themeMode';
  static const _kLocale    = 'pref.locale';

  // ---- Theme ----

  ThemeMode getThemeMode() {
    // Default: light. Pengguna yang ingin dark/system bisa ganti dari
    // Pengaturan → Bahasa & Tampilan.
    switch (_prefs.getString(_kThemeMode)) {
      case 'light':  return ThemeMode.light;
      case 'dark':   return ThemeMode.dark;
      case 'system': return ThemeMode.system;
      default:       return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_kThemeMode, value);
  }

  // ---- Locale ----

  /// `null` = system default (Indonesian on Indonesian device, etc).
  Locale? getLocale() {
    final code = _prefs.getString(_kLocale);
    if (code == null || code.isEmpty) return null;
    return Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale == null) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, locale.languageCode);
    }
  }
}
