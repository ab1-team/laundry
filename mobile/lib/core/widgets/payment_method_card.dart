import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_ext.dart';

/// Card-shaped payment-method picker. Used both on the create-order
/// payment row (Cash / Transfer / QRIS) and inside the order-detail
/// pay sheet. The visual is identical on both screens so operators
/// see the same chrome regardless of where they're recording a
/// payment from.
///
/// - Selected: secondary wash (5% opacity) + 2px secondary border +
///   secondary icon/text.
/// - Unselected: surface + outlineVariant border + onSurfaceVariant fg.
/// - Disabled: same surface chrome but dimmed to 45% opacity with a
///   caption underneath explaining the unavailability. The user
///   cannot tap a disabled card.
class PaymentMethodCard extends StatelessWidget {
  const PaymentMethodCard({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.disabled = false,
    this.disabledHint,
  });

  final String label;
  final IconData icon;
  final bool selected;

  /// Fired when the user taps the card. Ignored when [disabled] is true
  /// — disabled cards become non-interactive so the operator can't
  /// queue an invalid payment.
  final VoidCallback onTap;

  /// When true, the card dims to indicate the option is reserved for a
  /// future release. The user cannot tap it; tapping is a no-op.
  final bool disabled;

  /// Small caption rendered under [label] when [disabled] is true, e.g.
  /// "Segera hadir" — explains why the option is greyed out.
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: Material(
          color: selected
              ? AppColors.secondary.withValues(alpha: 0.05)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected ? AppColors.secondary : context.colors.outlineVariant,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: selected ? AppColors.secondary : context.colors.onSurfaceVariant,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: AppTextStyles.labelSm.copyWith(
                      color: selected ? AppColors.secondary : context.colors.onSurfaceVariant,
                    ),
                  ),
                  if (disabled && disabledHint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      disabledHint!,
                      style: AppTextStyles.labelSm.copyWith(
                        color: context.colors.outline,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}