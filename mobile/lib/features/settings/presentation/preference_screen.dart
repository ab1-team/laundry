import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_snackbar.dart';
import 'settings_provider.dart';

/// Combined "Bahasa & Tampilan" screen. Both prefs live in SharedPreferences
/// (no backend) so the user changes apply immediately and survive restart.
class PreferenceScreen extends ConsumerWidget {
  const PreferenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale    = ref.watch(localeProvider);

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
          'Bahasa & Tampilan',
          style: AppTextStyles.headlineMd.copyWith(fontSize: 20, color: context.colors.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _Group(
            title: 'Bahasa',
            children: [
              _RadioRow(
                icon: Icons.translate,
                label: 'Bahasa Indonesia',
                subtitle: 'Default',
                selected: locale?.languageCode == 'id' || locale == null,
                onTap: () => ref.read(localeProvider.notifier).set(const Locale('id')),
                radius: _rowRadius(0, 2, BorderRadius.circular(AppRadius.card)),
              ),
              _RadioRow(
                icon: Icons.translate,
                label: 'English',
                subtitle: 'Coming soon',
                selected: locale?.languageCode == 'en',
                onTap: () {
                  showAppSnackBar(context, 'English segera hadir');
                },
                radius: _rowRadius(1, 2, BorderRadius.circular(AppRadius.card)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Group(
            title: 'Tampilan',
            children: [
              _RadioRow(
                icon: Icons.light_mode_outlined,
                label: 'Light',
                selected: themeMode == ThemeMode.light,
                onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.light),
                radius: _rowRadius(0, 3, BorderRadius.circular(AppRadius.card)),
              ),
              _RadioRow(
                icon: Icons.dark_mode_outlined,
                label: 'Dark',
                selected: themeMode == ThemeMode.dark,
                onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.dark),
                radius: _rowRadius(1, 3, BorderRadius.circular(AppRadius.card)),
              ),
              _RadioRow(
                icon: Icons.brightness_auto_outlined,
                label: 'Ikuti Sistem',
                subtitle: 'Otomatis sesuai pengaturan perangkat',
                selected: themeMode == ThemeMode.system,
                onTap: () => ref.read(themeModeProvider.notifier).set(ThemeMode.system),
                radius: _rowRadius(2, 3, BorderRadius.circular(AppRadius.card)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: AppTextStyles.labelSm.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
        Container(
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
          // Clip children supaya divider antar-row tidak bocor keluar
          // rounded corner card.
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: context.colors.outlineVariant,
                    indent: 56,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.radius,
    this.subtitle,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Ripple/hover mengikuti shape row — first row rounded atas,
        // middle zero, last rounded bawah. Sebelumnya pakai radius card
        // penuh untuk semua row, sehingga ripple 'tembus' keluar card
        // rounded di tengah & terlihat kotak (lihat screenshot).
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: context.colors.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.bodyLg.copyWith(color: context.colors.onSurface)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: AppColors.secondary, size: 22)
              else
                Icon(Icons.radio_button_unchecked, color: context.colors.outline, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper untuk derive radius tiap row dalam satu group, sehingga ripple
/// match shape card luar: first = top rounded, middle = zero, last =
/// bottom rounded. Konsisten dengan pola `_tileRadius` di SettingsScreen.
BorderRadius _rowRadius(int index, int length, BorderRadius outer) {
  if (length == 1) return outer;
  if (index == 0) {
    return BorderRadius.only(
      topLeft: outer.topLeft,
      topRight: outer.topRight,
    );
  }
  if (index == length - 1) {
    return BorderRadius.only(
      bottomLeft: outer.bottomLeft,
      bottomRight: outer.bottomRight,
    );
  }
  return BorderRadius.zero;
}