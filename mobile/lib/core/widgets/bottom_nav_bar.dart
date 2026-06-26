import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_theme_ext.dart';

/// Bottom navigation with 28px top-corner radius (per DESIGN.md). Supports a
/// single [center] item rendered as a raised circular button to draw the eye.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.centerIndex,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItem> items;

  /// When non-null, the item at this index is rendered as a raised circle
  /// (the "center" button of the nav bar).
  final int? centerIndex;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomNav),
          topRight: Radius.circular(AppRadius.bottomNav),
        ),
        boxShadow: [
          BoxShadow(
            // Brand-tinted shadow that works on both light & dark — primary
            // is Navy in both modes; alpha 0.06 stays subtle.
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              return Expanded(
                child: i == centerIndex
                    ? _buildCenterItem(items[i], i)
                    : _buildStandardItem(context, items[i], i),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardItem(BuildContext context, BottomNavItem item, int i) {
    final active = i == currentIndex;
    // Active item foreground reads from `context.colors.primary` so it
    // follows the active theme — Navy in light, Sky Blue in dark — and
    // stays visible against the dark surface. `AppColors.primary` (Navy)
    // would disappear into the dark Navy-tinted background.
    final fg = active ? context.colors.primary : context.colors.onSurfaceVariant;
    return InkWell(
      onTap: () => onTap(i),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            active ? item.activeIcon : item.icon,
            color: fg,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: fg,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: active ? context.colors.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterItem(BottomNavItem item, int i) {
    // Center item: a single 44×44 filled circle that's always primary navy.
    // No state change between active/inactive — the circle is the constant
    // visual centerpiece of the nav bar.
    return Center(
      child: SizedBox(
        width: 64,
        height: 64,
        child: InkWell(
          onTap: () => onTap(i),
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.activeIcon,
                color: AppColors.onPrimary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BottomNavItem {
  const BottomNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
  final String label;
  final IconData icon;
  final IconData activeIcon;
}