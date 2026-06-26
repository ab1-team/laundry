import 'package:flutter/material.dart';

/// App color tokens — sourced from `.design/laundry_management_system/DESIGN.md`.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary        = Color(0xFF1A2340); // Deep Navy
  static const Color primaryDim     = Color(0xFF040D2A);
  static const Color onPrimary      = Color(0xFFFFFFFF);
  static const Color primaryContainer    = Color(0xFF3D4665);
  static const Color onPrimaryContainer  = Color(0xFF828AAD);

  // Accent
  static const Color secondary      = Color(0xFF4FC3F7); // Sky Blue
  static const Color onSecondary    = Color(0xFFFFFFFF);
  static const Color secondaryContainer  = Color(0xFFC2E8FF);
  static const Color onSecondaryContainer = Color(0xFF005370);
  // DESIGN.md `secondary` token (#006688) — the deeper sky used by
  // detail-order pipeline connectors, the FAB glow, and the customer's
  // "INFO PEMBAYARAN" icon/label. Kept separate from the lighter
  // `secondary` (#4FC3F7) which marks the active pipeline dots and
  // selected payment method borders, so we can swap either without
  // touching the other.
  static const Color secondaryDeep       = Color(0xFF006688);
  // DESIGN.md secondary-fixed tokens — used by "Total Order Aktif" subtitle chip.
  static const Color secondaryFixed       = Color(0xFFC2E8FF);
  static const Color onSecondaryFixed     = Color(0xFF001E2B);

  // Surface
  static const Color background     = Color(0xFFF5F7FA);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color onSurface      = Color(0xFF1B1B1E);
  static const Color onSurfaceVariant = Color(0xFF45464D);
  static const Color outline        = Color(0xFFC6C6CE);
  static const Color outlineVariant = Color(0xFFE4E2E5);
  // DESIGN.md surface-container-high — used for tonal quick-action buttons.
  static const Color surfaceContainerHigh = Color(0xFFEAE7EA);
  // DESIGN.md surface-container-low — softer bg for grouped information
  // blocks (e.g. payment info on order detail).
  static const Color surfaceContainerLow = Color(0xFFF6F3F6);

  // Status — Order pipeline
  static const Color statusMasuk      = Color(0xFFFFB74D); // Amber
  static const Color statusDicuci     = Color(0xFF42A5F5); // Blue
  static const Color statusSelesai    = Color(0xFF66BB6A); // Green
  static const Color statusDiambil    = Color(0xFF90A4AE); // Gray
  static const Color statusDibatalkan = Color(0xFFEF5350); // Red

  // Status backgrounds (15% opacity for chip wash)
  static Color statusMasukBg      = statusMasuk.withValues(alpha: 0.15);
  static Color statusDicuciBg     = statusDicuci.withValues(alpha: 0.15);
  static Color statusSelesaiBg    = statusSelesai.withValues(alpha: 0.15);
  static Color statusDiambilBg    = statusDiambil.withValues(alpha: 0.15);
  static Color statusDibatalkanBg = statusDibatalkan.withValues(alpha: 0.15);

  // Error
  static const Color error       = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
}
