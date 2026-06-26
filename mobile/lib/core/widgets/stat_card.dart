import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_ext.dart';

/// Statistic card used in dashboard.
/// Variants: `primary` (navy), `attention` (pink/red), `default` (white).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    this.subtitle,
    this.icon,
    this.variant = StatCardVariant.default_,
    this.valueColorOverride,
  });

  final String title;
  final String value;
  final String? unit;
  final String? subtitle;
  final IconData? icon;
  final StatCardVariant variant;
  // Optional override for the value text color. When null, falls back to the
  // variant's default (e.g. DESIGN.md "Menunggu Diambil" uses secondary).
  final Color? valueColorOverride;

  // Per-variant watermark icon — fills the right-bottom empty area.
  IconData get _watermarkIcon {
    if (icon != null) return icon!;
    switch (variant) {
      case StatCardVariant.primary:   return Icons.local_laundry_service;
      case StatCardVariant.attention: return Icons.account_balance_wallet_outlined;
      case StatCardVariant.default_:  return Icons.inventory_2_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPrimary   = variant == StatCardVariant.primary;
    final isAttention = variant == StatCardVariant.attention;

    final Color bg;
    final Color titleColor;
    final Color valueColor;
    if (isPrimary) {
      bg = AppColors.primary;
      titleColor = AppColors.onPrimary;
      valueColor = AppColors.onPrimary;
    } else if (isAttention) {
      // DESIGN.md: piutang card uses errorContainer wash with onErrorContainer text.
      bg = context.colors.errorContainer;
      titleColor = AppColors.error; // onErrorContainer token not yet in palette
      valueColor = AppColors.error;
    } else {
      bg = context.colors.surface;
      titleColor = context.colors.onSurfaceVariant;
      valueColor = context.colors.onSurface;
    }

    return SizedBox(
      width: double.infinity,
      height: 128,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.summary),
          boxShadow: isPrimary
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Watermark icon — primary only. Other variants stay clean;
            // the value text carries the visual weight.
            if (isPrimary)
              Positioned(
                right: -8,
                bottom: -8,
                child: Opacity(
                  opacity: 0.2,
                  child: Icon(
                    _watermarkIcon,
                    size: 96,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            // Content fills the card: title at top, value prominent in the
            // middle, footer (chip for primary, unit for the others) at bottom.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top: title (small label)
                Text(title, style: AppTextStyles.labelLg.copyWith(color: titleColor)),
                // Middle: value — always rendered so the headline number is
                // never missing on any variant.
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (isPrimary
                          ? AppTextStyles.displayLg
                          : AppTextStyles.headlineMd.copyWith(fontSize: 28))
                      .copyWith(color: valueColorOverride ?? valueColor),
                ),
                // Bottom: subtitle chip (primary) or unit label (non-primary).
                if (isPrimary && subtitle != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      subtitle!,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onSecondaryFixed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (unit != null)
                  Text(
                    unit!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // DESIGN.md: secondary wash text — tinted to the variant
                    // (red for attention, neutral gray for default).
                    style: AppTextStyles.labelLg.copyWith(
                      color: isAttention ? AppColors.error : context.colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum StatCardVariant { default_, primary, attention }