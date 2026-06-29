import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_ext.dart';

/// Visual variant for [showAppSnackBar]. Drives the leading icon
/// (success = check, error = warning, info = info) and the icon tint.
/// Background stays the same so all three read as the same component.
enum AppSnackBarType { success, error, info }

/// Show a branded snackbar matching the app's card chrome:
///   - surface background (light) / surfaceContainerHighest (dark)
///   - 1px outlineVariant border
///   - AppRadius.card (rounded, same as dialogs)
///   - soft primary-tinted shadow, offset down
///   - leading icon tinted per type (secondary/error/primary)
///   - floating behavior with 20px horizontal margin + 16px bottom inset
///   - bodyMd text on surface
///
/// Floating keeps the snackbar above the bottom nav and avoids the
/// default Material drop-shadow rectangle, so it visually anchors to
/// the floating cards used elsewhere in the app (OrderSummaryCard etc.).
///
/// Replaces direct `ScaffoldMessenger.showSnackBar(SnackBar(...))` calls.
void showAppSnackBar(
  BuildContext context,
  String message, {
  AppSnackBarType type = AppSnackBarType.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      // Strip Material's default inset + vertical padding so our
      // custom chrome owns the entire visual.
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: EdgeInsets.zero,
      elevation: 0,
      // Match the content's rounded shape so the SnackBar's Material
      // container clips its own bounds to the same radius — without
      // this, Material's default rounded container plus our rounded
      // content produces a visible "second" rectangle (shadow box
      // leaking past the rounded corners).
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.hardEdge,
      duration: duration,
      content: _AppSnackBarContent(message: message, type: type),
    ),
  );
}

class _AppSnackBarContent extends StatelessWidget {
  const _AppSnackBarContent({required this.message, required this.type});
  final String message;
  final AppSnackBarType type;

  IconData get _icon {
    switch (type) {
      case AppSnackBarType.success:
        return Icons.check_circle;
      case AppSnackBarType.error:
        return Icons.error_outline;
      case AppSnackBarType.info:
        return Icons.info_outline;
    }
  }

  Color get _iconColor {
    switch (type) {
      case AppSnackBarType.success:
        return AppColors.secondary;
      case AppSnackBarType.error:
        return AppColors.error;
      case AppSnackBarType.info:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        // Surface (light) or surfaceContainerHighest (dark) — matches the
        // outer page surface so the snackbar feels like a sheet rising
        // from the page, not a Material default black pill.
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: context.colors.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            // Same primary-tinted soft shadow used by the floating
            // order summary cards on the dashboard list.
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_icon, color: _iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyMd.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}