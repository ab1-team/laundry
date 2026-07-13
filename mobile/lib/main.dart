import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart' as pkg_info_plus;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/update/update_gate.dart';
import 'core/update/update_service.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/settings/presentation/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Init locale data for intl DateFormat (id_ID used across screens).
  await initializeDateFormatting('id_ID', null);
  // Resolve SharedPreferences before runApp so the themeMode + locale
  // providers can read their initial value synchronously (avoids a
  // light-to-dark flash on first frame).
  final prefs = await SharedPreferences.getInstance();
  // Baca versi runtime dari PackageManager SEBELUM runApp. Tanpa ini,
  // update_flow pakai fallback statis dari packageInfoProvider (0.0.0+0
  // atau 1.0.0+1) → mobile pikir dirinya selalu versi lama → infinite
  // "update available" loop walau user sudah install versi terbaru.
  //
  // Kalau PackageManager gagal baca (mis. unit test tanpa Android context),
  // pakai fallback _readPackageInfo (1.0.0+1) — bukan crash.
  final pkg = await _readPackageInfo();
  // Pick the initial system bar style from the saved theme mode so the
  // status bar icons are readable from the splash onward — no flash
  // when MaterialApp.router takes over.
  final initialMode = _readThemeMode(prefs);
  final isDark = initialMode == ThemeMode.dark ||
      (initialMode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    // Match the scaffold surface so the system nav bar sits flush with
    // the bottom nav in both light and dark.
    systemNavigationBarColor:
        isDark ? const Color(0xFF15171C) : AppColors.surface,
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarDividerColor:
        isDark ? const Color(0xFF15171C) : AppColors.surface,
    systemNavigationBarContrastEnforced: false,
  ));
  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      packageInfoProvider.overrideWithValue(pkg),
    ],
    child: const LaundryApp(),
  ));
}

/// Baca versionName + versionCode dari PackageManager.
/// Default fallback `1.0.0+1` dipakai kalau PackageManager gagal (mis.
/// unit test tanpa Android context, atau build target non-Android) —
/// lebih buruk dari yang sebenarnya tapi tidak crash. Update flow tetap
/// berjalan: kalau server latest > 1.0.0 akan trigger update.
Future<PackageInfo> _readPackageInfo() async {
  try {
    final info = await pkg_info_plus.PackageInfo.fromPlatform();
    return PackageInfo(versionName: info.version, versionCode: int.tryParse(info.buildNumber) ?? 0);
  } catch (_) {
    return const PackageInfo(versionName: '1.0.0', versionCode: 1);
  }
}

ThemeMode _readThemeMode(SharedPreferences prefs) {
  // Default: light. Konsisten dengan PreferencesRepository.getThemeMode()
  // supaya initial system bar style + MaterialApp.themeMode pakai nilai
  // yang sama sebelum themeModeProvider di-read.
  switch (prefs.getString('pref.themeMode')) {
    case 'light':  return ThemeMode.light;
    case 'dark':   return ThemeMode.dark;
    case 'system': return ThemeMode.system;
    default:       return ThemeMode.light;
  }
}

class LaundryApp extends ConsumerStatefulWidget {
  const LaundryApp({super.key});

  @override
  ConsumerState<LaundryApp> createState() => _LaundryAppState();
}

class _LaundryAppState extends ConsumerState<LaundryApp> {
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authProvider.notifier).bootstrap();
      if (mounted) setState(() => _booting = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Single MaterialApp.router for the entire app lifecycle — keeps a
    // consistent SystemUiOverlayStyle from boot to route changes.
    // While booting, swap routerConfig for a static splash route. The
    // splash also reads the saved theme mode so the spinner sits on a
    // dark surface when the user picked dark.
    if (_booting) {
      final mode = ref.read(themeModeProvider);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: Scaffold(
          backgroundColor: mode == ThemeMode.dark
              ? const Color(0xFF15171C)
              : AppColors.surface,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return _RouterApp();
  }
}

class _RouterApp extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RouterApp> createState() => _RouterAppState();
}

class _RouterAppState extends ConsumerState<_RouterApp> {
  // Build GoRouter sekali di initState. Kalau di-rebuild setiap frame,
  // perubahan theme/locale akan reset router kembali ke initialLocation
  // ('/login') dan redirect melompat ke /home — blank page effect untuk
  // user yang sedang di /settings/preferences. Dengan caching di state,
  // router instance tetap sama sepanjang app lifecycle.
  late final _router = AppRouter.build(ref);

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'LaundryAja',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      routerConfig: _router,
      // UpdateGate harus di DALAM MaterialApp.router supaya
      // showModalBottomSheet() dapat MaterialLocalizations ancestor.
      // Taruh di luar = crash "No MaterialLocalizations found" karena
      // modal route push butuh Localizations dari MaterialApp di atasnya.
      // Pakai `builder` callback supaya UpdateGate membungkus child router,
      // bukan MaterialApp itu sendiri — agar navigator context + tema
      // tetap milik MaterialApp saat sheet push.
      builder: (context, child) => UpdateGate(
        key: updateGateKey,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}