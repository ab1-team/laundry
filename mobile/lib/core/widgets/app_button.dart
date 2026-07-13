import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, tonal }

/// Pill-shaped button (per DESIGN.md).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    // `disabled` = no callback yet, OR callback exists but a spinner is
    // running. Both states should look the same — a faded surface fill
    // — so the operator instantly reads the button as not-yet-actionable.
    // Without this override the InkWell silently swallowed taps while
    // the primary fill stayed full-strength, which looked like a bug.
    final disabled = onPressed == null || loading;

    Color bg, fg;
    if (disabled) {
      // Disabled: neutral surface fill + muted text. Same pair for all
      // variants so the affordance is consistent — the user learns
      // "filled = active, faded = disabled" regardless of variant.
      bg = AppColors.surfaceContainerHigh;
      fg = AppColors.onSurfaceVariant;
    } else {
      switch (variant) {
        case AppButtonVariant.primary:
          // DESIGN.md primary: navy pill, white text.
          bg = AppColors.primary;
          fg = AppColors.onPrimary;
          break;
        case AppButtonVariant.secondary:
          // DESIGN.md quick-action primary: secondaryContainer bg + onSecondaryContainer fg.
          bg = AppColors.secondaryContainer;
          fg = AppColors.onSecondaryContainer;
          break;
        case AppButtonVariant.tonal:
          // DESIGN.md secondary quick-action: surface-container-high fill, onSurface text — no border.
          bg = AppColors.surfaceContainerHigh;
          fg = AppColors.onSurface;
          break;
      }
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else if (icon != null) ...[
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 8),
              ],
              if (!loading)
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.labelLg.copyWith(color: fg, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
