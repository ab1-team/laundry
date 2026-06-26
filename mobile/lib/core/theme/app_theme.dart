import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      // Scaffold uses `surface` (not the more saturated `background`) so
      // cards and tabs share the same neutral surface and feel consistent
      // with Material 3 defaults. `background` is reserved for areas the
      // scaffold paints behind M3's tonal elevation.
      scaffoldBackgroundColor: AppColors.surface,
      canvasColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      // M3 surface tint adds a subtle primary-tinted overlay to scaffold,
      // creating a faint line at the top/bottom of the surface. Disable it
      // so the background bleeds edge-to-edge with the system nav bar.
      bottomSheetTheme: const BottomSheetThemeData(surfaceTintColor: Colors.transparent),
      dialogTheme: const DialogThemeData(surfaceTintColor: Colors.transparent),
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.secondary,
        onTertiary: AppColors.onSecondary,
        error: AppColors.error,
        onError: AppColors.onPrimary,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: Color(0xFF93000A),
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceContainerLowest: AppColors.background,
        surfaceContainerLow: AppColors.surfaceContainerLow,
        surfaceContainer: AppColors.background,
        surfaceContainerHigh: AppColors.surfaceContainerHigh,
        surfaceContainerHighest: AppColors.outlineVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLg,
        headlineMedium: AppTextStyles.headlineMd,
        titleLarge: AppTextStyles.titleLg,
        bodyLarge: AppTextStyles.bodyLg,
        bodyMedium: AppTextStyles.bodyMd,
        labelLarge: AppTextStyles.labelLg,
        labelSmall: AppTextStyles.labelSm,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.titleLg,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          // Match the AppBar background so the gesture/nav bar blends with
          // the top surface when the app scrolls edge-to-edge.
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: AppColors.background,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
      ),
      dividerColor: AppColors.outlineVariant,
    );
  }

  /// Dark variant — mirrors the elevation ladder defined for the light
  /// theme in `app_colors.dart` so a screen that reads well in light also
  /// reads well in dark. Same 4-step neutral scale (`background` →
  /// `surfaceContainerLow` → `surface` → `surfaceContainerHigh`) and the
  /// same brand tokens for `primary` / `secondary` / status pipeline so a
  /// status chip looks identical in both modes.
  static ThemeData get dark {
    // Neutrals — match the relative spacing of the light palette:
    //   background              = deepest layer (scaffold behind cards)
    //   surfaceContainerLow    = gentle info block (payment info etc)
    //   surface                 = card / sheet (the workhorse)
    //   surfaceContainerHigh    = FAB tonal / chip backgrounds
    const background       = Color(0xFF15171C);
    const surface          = Color(0xFF1F2228);
    const surfaceContLow   = Color(0xFF1B1E23);
    const surfaceCont      = Color(0xFF222630);
    const surfaceContHigh  = Color(0xFF2A2E37);
    const surfaceContHighest = Color(0xFF343841);
    // Text — softened from pure white for OLED comfort while still passing
    // WCAG AA contrast on the `surface` tone above.
    const onSurface      = Color(0xFFE3E4E8);
    const onSurfaceVar   = Color(0xFFB8BBC3);
    const outline        = Color(0xFF6E7280);
    const outlineVar     = Color(0xFF383B43);
    // Brand containers — tuned darker than the M3 default so chips reading
    // "Pemilik" / role badges look intentional, not glaring.
    const primaryCont    = Color(0xFF2D3654);
    const onPrimaryCont  = Color(0xFFD0D5E8);
    const secondaryCont  = Color(0xFF003E55);
    const onSecondaryCont = Color(0xFFC2E8FF);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: InkSparkle.splashFactory,
      bottomSheetTheme: const BottomSheetThemeData(surfaceTintColor: Colors.transparent),
      dialogTheme: const DialogThemeData(surfaceTintColor: Colors.transparent),
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        // In dark mode `primary` is the brand Sky Blue, NOT Navy. The
        // Navy (`AppColors.primary`) on the dark Navy-tinted background
        // (`#15171C`) collapses to a single near-black blob and the
        // primary buttons, FAB, AppBar title all become invisible. Sky
        // Blue is the same brand token and reads well on the dark
        // surface. Navy stays where it's hardcoded — FAB center circle,
        // logo, role chip, accent strokes — preserving brand identity.
        primary: AppColors.secondary,
        onPrimary: AppColors.onSecondary,
        primaryContainer: secondaryCont,
        onPrimaryContainer: onSecondaryCont,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: secondaryCont,
        onSecondaryContainer: onSecondaryCont,
        tertiary: AppColors.secondary,
        onTertiary: AppColors.onSecondary,
        error: AppColors.error,
        onError: AppColors.onPrimary,
        errorContainer: Color(0xFF601410),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: surface,
        onSurface: onSurface,
        surfaceContainerLowest: background,
        surfaceContainerLow: surfaceContLow,
        surfaceContainer: surfaceCont,
        surfaceContainerHigh: surfaceContHigh,
        surfaceContainerHighest: surfaceContHighest,
        outline: outline,
        outlineVariant: outlineVar,
      ),
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLg.copyWith(color: onSurface),
        headlineMedium: AppTextStyles.headlineMd.copyWith(color: onSurface),
        titleLarge: AppTextStyles.titleLg.copyWith(color: onSurface),
        bodyLarge: AppTextStyles.bodyLg.copyWith(color: onSurface),
        bodyMedium: AppTextStyles.bodyMd.copyWith(color: onSurface),
        bodySmall: AppTextStyles.bodySm.copyWith(color: onSurfaceVar),
        labelLarge: AppTextStyles.labelLg.copyWith(color: onSurface),
        labelSmall: AppTextStyles.labelSm.copyWith(color: onSurfaceVar),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.titleLg.copyWith(color: onSurface),
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: background,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: background,
          systemNavigationBarContrastEnforced: false,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
      ),
      dividerColor: outlineVar,
    );
  }
}
