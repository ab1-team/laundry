import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Order status — values match backend enum.
enum OrderStatus { masuk, dicuci, selesai, diambil, dibatalkan }

extension OrderStatusX on OrderStatus {
  String get raw => name;

  String get label {
    switch (this) {
      case OrderStatus.masuk:      return 'Menunggu';
      case OrderStatus.dicuci:     return 'Proses';
      case OrderStatus.selesai:    return 'Selesai';
      case OrderStatus.diambil:    return 'Diambil';
      case OrderStatus.dibatalkan: return 'Batal';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.masuk:      return AppColors.statusMasuk;
      case OrderStatus.dicuci:     return AppColors.statusDicuci;
      case OrderStatus.selesai:    return AppColors.statusSelesai;
      case OrderStatus.diambil:    return AppColors.statusDiambil;
      case OrderStatus.dibatalkan: return AppColors.statusDibatalkan;
    }
  }

  Color get background {
    switch (this) {
      case OrderStatus.masuk:      return AppColors.statusMasukBg;
      case OrderStatus.dicuci:     return AppColors.statusDicuciBg;
      case OrderStatus.selesai:    return AppColors.statusSelesaiBg;
      case OrderStatus.diambil:    return AppColors.statusDiambilBg;
      case OrderStatus.dibatalkan: return AppColors.statusDibatalkanBg;
    }
  }

  static OrderStatus fromString(String? s) {
    switch (s) {
      case 'dicuci':     return OrderStatus.dicuci;
      case 'selesai':    return OrderStatus.selesai;
      case 'diambil':    return OrderStatus.diambil;
      case 'dibatalkan': return OrderStatus.dibatalkan;
      default:           return OrderStatus.masuk;
    }
  }
}

/// Pill-shaped status chip with 15% opacity background (per DESIGN.md).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    // Use Material+InkWell-free DecoratedBox to avoid Material's default
    // text-baseline alignment which can clip ascenders on small labels.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        // line-height 1.4 leaves enough room above/below the 11px glyphs.
        child: Text(
          status.label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: AppTextStyles.labelSm.copyWith(
            color: status.color,
            fontWeight: FontWeight.w600,
            height: 1.4,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
