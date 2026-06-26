import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography — DM Sans, sourced from DESIGN.md type scale.
///
/// No default `color:` is set here on purpose. Callers always apply
/// `context.colors.onSurface` (or `onSurfaceVariant` for muted text) via
/// `.copyWith(...)`, otherwise the inherited light token leaks into dark
/// mode. The exception is when a TextStyle is used inside a `ThemeData`
/// (e.g. `textTheme:` in `AppTheme`), where we explicitly pick the right
/// color for that brightness.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get displayLg => GoogleFonts.dmSans(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.25, // 40/32
        letterSpacing: -0.02 * 32 / 32, // -0.02em
      );

  static TextStyle get headlineMd => GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.27, // 28/22
      );

  static TextStyle get titleLg => GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.33, // 24/18
      );

  static TextStyle get bodyLg => GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5, // 24/16
      );

  static TextStyle get bodyMd => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43, // 20/14
      );

  static TextStyle get bodySm => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.33, // 16/12
      );

  static TextStyle get labelLg => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43, // 20/14
        letterSpacing: 0.1,
      );

  static TextStyle get labelSm => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.45, // 16/11
        letterSpacing: 0.5,
      );
}
