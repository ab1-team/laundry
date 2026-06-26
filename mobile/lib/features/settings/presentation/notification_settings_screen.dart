import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';

/// Notification preferences. Today the only channel is WhatsApp (status,
/// payment, pickup reminders) and that channel isn't user-toggleable — the
/// switch is rendered disabled with a "Coming soon" hint so the user sees
/// the destination exists but isn't faked as configurable.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // Disabled toggles in this build — pass `onChanged: null` to each switch.
  // Will become mutable once the WA gateway integration lands; the
  // `prefer_final_fields` info on these is expected for now.
  bool _waStatus  = false;
  bool _waPayment = false;
  bool _waPickup  = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
        ),
        title: Text(
          'Notifikasi',
          style: AppTextStyles.headlineMd.copyWith(fontSize: 20, color: context.colors.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _ChannelCard(
            icon: Icons.chat_bubble_outline,
            title: 'WhatsApp ke Pelanggan',
            subtitle: 'Notifikasi status cucian, pembayaran, dan pengambilan dikirim lewat WhatsApp.',
          ),
          const SizedBox(height: 12),
          _ToggleRow(
            label: 'Status order berubah',
            value: _waStatus,
            onChanged: null,
          ),
          Divider(height: 1, color: context.colors.outlineVariant, indent: 56),
          _ToggleRow(
            label: 'Pembayaran diterima',
            value: _waPayment,
            onChanged: null,
          ),
          Divider(height: 1, color: context.colors.outlineVariant, indent: 56),
          _ToggleRow(
            label: 'Cucian siap diambil',
            value: _waPickup,
            onChanged: null,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: context.colors.surfaceContainerHigh, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: context.colors.onSurfaceVariant, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pengaturan detail notifikasi akan tersedia setelah integrasi WhatsApp gateway aktif.',
                    style: AppTextStyles.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.surfaceContainerHigh, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: AppColors.secondary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleLg.copyWith(color: context.colors.onSurface)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surface,
      child: SwitchListTile(
        title: Text(label, style: AppTextStyles.bodyLg.copyWith(color: context.colors.onSurface)),
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }
}