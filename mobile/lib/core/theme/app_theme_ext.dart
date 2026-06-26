import 'package:flutter/material.dart';

/// Shortcuts for the active Material 3 color scheme and text theme.
///
/// Use [context.colors] instead of `Theme.of(context).colorScheme` at every
/// call site that needs a structural color — those colors auto-swap between
/// light and dark mode via the active [ThemeData]. Brand tokens (primary,
/// secondary, status pipeline) still live on `AppColors` and are read
/// directly because they should stay identical across themes.
extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textStyles => Theme.of(this).textTheme;
}