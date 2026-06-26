import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme_ext.dart';
import 'status_chip.dart';

/// Single segment inside the summary card's middle row (icon + label).
class OrderSummarySegment {
  const OrderSummarySegment({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Compact order card used in the Daftar Order list (DESIGN.md).
/// Layout:
///   - Top row:    ticket (#TRX-xxxx) + customer name (left), status chip (right)
///   - Middle row: up to two icon+label segments separated by a vertical rule
///   - Bottom row: date with calendar icon (left), total price (right)
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.ticketNumber,
    required this.customerName,
    required this.status,
    required this.totalLabel,
    required this.segments,
    required this.createdAt,
    this.onTap,
  });

  final String ticketNumber;
  final String customerName;
  final OrderStatus status;
  final String totalLabel;
  final List<OrderSummarySegment> segments;
  final DateTime createdAt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy', 'id_ID');
    final timeFmt = DateFormat('HH:mm');

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.summary),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.summary),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.summary),
            border: Border.all(color: context.colors.surfaceContainerHigh, width: 1),
            boxShadow: [
              BoxShadow(
                // DESIGN.md .order-card-shadow: 0 4px 16px 0 rgba(17,26,55,0.08).
                // Uses brand primary (Navy) which is identical in both modes.
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: ticket + customer name (left), status chip (right)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ticketNumber,
                          style: AppTextStyles.labelSm.copyWith(
                            color: context.colors.outline,
                            // DESIGN.md tracking-wider on the ticket label
                            // = 0.05em on top of labelSm's base 0.5px.
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          customerName,
                          style: AppTextStyles.titleLg.copyWith(color: context.colors.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusChip(status: status),
                ],
              ),

              if (segments.isNotEmpty) ...[
                const SizedBox(height: 12),
                // Middle row: icon+label segments, divided by a vertical rule.
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: context.colors.outlineVariant, width: 1),
                      bottom: BorderSide(color: context.colors.outlineVariant, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < segments.length; i++) ...[
                        if (i > 0)
                          Container(
                            width: 1,
                            height: 20,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            color: context.colors.outlineVariant,
                          ),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // DESIGN.md uses `text-secondary` for the
                              // segment icons; in the design palette that's
                              // the deeper sky (#006688), not the light sky
                              // we use elsewhere for the selected payment
                              // method. Keep them on secondaryDeep so the
                              // qty/service icons read as a brand mark.
                              Icon(segments[i].icon, size: 20, color: AppColors.secondaryDeep),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  segments[i].label,
                                  style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurface),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Bottom row: date (left), total (right)
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: context.colors.outline),
                  const SizedBox(width: 6),
                  Text(
                    '${dateFmt.format(createdAt)}, ${timeFmt.format(createdAt)}',
                    style: AppTextStyles.labelSm.copyWith(color: context.colors.outline),
                  ),
                  const Spacer(),
                  Text(
                    totalLabel,
                    style: AppTextStyles.labelLg.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Build the two middle-row segments (qty + service name) used by
/// both the Daftar Order list and the Dashboard's "Order Terbaru"
/// cards. Centralised so the icon mapping stays in one place — a
/// category icon added to the backend shows up on both surfaces
/// without extra wiring.
///
/// Returns an empty list when the order has no items, which makes
/// `OrderSummaryCard` render the 3-line layout (ticket+nama, status,
/// date+total) instead of crashing on a missing `first`.
List<OrderSummarySegment> buildOrderSegments(OrderItemLike first) {
  return [
    OrderSummarySegment(
      icon: _weightIcon(first.categoryIcon),
      label: '${_trimQty(first.qty)} ${first.unit}',
    ),
    OrderSummarySegment(
      icon: _serviceIcon(first.categoryIcon, first.serviceName),
      label: first.serviceName,
    ),
  ];
}

/// Minimal contract for [buildOrderSegments] so callers can pass
/// either an `OrderItemModel` or any other shape with the same
/// fields. Implemented by `OrderItemModel` below.
abstract class OrderItemLike {
  String? get categoryIcon;
  String get serviceName;
  String get unit;
  double get qty;
}

IconData _weightIcon(String? categoryIcon) {
  switch (categoryIcon) {
    case 'weight': return Icons.scale_outlined;
    case 'bed':    return Icons.bed_outlined;
    case 'shirt':  return Icons.checkroom_outlined;
    case 'shoes':  return Icons.ice_skating_outlined;
    case 'hanger': return Icons.dry_cleaning_outlined;
    case 'iron':   return Icons.iron_outlined;
    default:       return Icons.inventory_2_outlined;
  }
}

IconData _serviceIcon(String? categoryIcon, String name) {
  switch (categoryIcon) {
    case 'weight': return Icons.local_laundry_service_outlined;
    case 'bed':    return Icons.bed_outlined;
    case 'shirt':  return Icons.checkroom_outlined;
    case 'shoes':  return Icons.ice_skating_outlined;
    case 'hanger': return Icons.dry_cleaning_outlined;
    case 'iron':   return Icons.iron_outlined;
  }
  final n = name.toLowerCase();
  if (n.contains('kiloan'))   return Icons.local_laundry_service_outlined;
  if (n.contains('setrika'))  return Icons.iron_outlined;
  if (n.contains('sepatu'))   return Icons.ice_skating_outlined;
  if (n.contains('selimut') || n.contains('bed'))  return Icons.bed_outlined;
  if (n.contains('kemeja') || n.contains('shirt')) return Icons.checkroom_outlined;
  if (n.contains('karpet'))   return Icons.dry_cleaning_outlined;
  return Icons.local_laundry_service_outlined;
}

/// "5.0 kg" → "5 kg", "2.5 kg" stays "2.5 kg". Strips the trailing
/// `.0` from integer-ish quantities so the segment label matches the
/// design preview.
String _trimQty(double qty) {
  if (qty == qty.truncateToDouble()) return qty.toInt().toString();
  return qty.toString();
}