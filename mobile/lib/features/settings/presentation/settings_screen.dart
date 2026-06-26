import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/asset_url.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../auth/data/user_model.dart';
import '../../auth/presentation/auth_provider.dart';

/// Settings screen — opened from the gear icon in [AppTabHeader]. Shows
/// the current tenant + user profile, a grouped list of menu items, and a
/// logout button at the bottom that resets [authProvider] so the router
/// redirect sends the user back to /login.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(
          'Pengaturan',
          style: AppTextStyles.headlineMd.copyWith(
            fontSize: 20,
            color: context.colors.onSurface,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _ProfileCard(user: user),
          const SizedBox(height: 16),
          _MenuGroup(
            title: 'Profil Toko',
            items: const [
              _MenuItemData(
                icon: Icons.storefront_outlined,
                label: 'Informasi Toko',
                route: '/settings/tenant/info',
              ),
              _MenuItemData(
                icon: Icons.location_on_outlined,
                label: 'Alamat & Kontak',
                route: '/settings/tenant/contact',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MenuGroup(
            title: 'Akun',
            items: const [
              _MenuItemData(
                icon: Icons.person_outline,
                label: 'Edit Profil',
                route: '/settings/profile',
              ),
              _MenuItemData(
                icon: Icons.lock_outline,
                label: 'Ubah Password',
                route: '/settings/password',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MenuGroup(
            title: 'Preferensi',
            items: const [
              _MenuItemData(
                icon: Icons.notifications_outlined,
                label: 'Notifikasi',
                route: '/settings/notifications',
              ),
              _MenuItemData(
                icon: Icons.tune_outlined,
                label: 'Bahasa & Tampilan',
                route: '/settings/preferences',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _LogoutButton(
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Keluar dari aplikasi?'),
        content: const Text('Anda harus login kembali untuk menggunakan aplikasi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final tenant = user?.tenantName ?? '—';
    final displayName = user?.name ?? 'Pengguna';
    final email = user?.email ?? '';
    final role = _roleLabel(user?.role);
    final logoUrl = resolveAssetUrl(user?.tenantLogoUrl);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        // Flat — tidak ada gradient di app ini, jadi pakai surface solid
        // seperti card lain, dengan shadow halus untuk elevasi.
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: logo bulat 64 + role chip (floating, pojok kanan)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LogoAvatar(url: logoUrl, fallbackText: displayName, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      tenant,
                      style: AppTextStyles.titleLg.copyWith(
                        color: context.colors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: context.colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (role != null) ...[
                const SizedBox(width: 8),
                _RoleChip(label: role),
              ],
            ],
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: context.colors.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.alternate_email,
                    size: 18,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: AppTextStyles.bodySm.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
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
    );
  }

  String? _roleLabel(String? role) {
    switch (role) {
      case 'owner':     return 'Pemilik';
      case 'operator':  return 'Operator';
      case 'super_admin': return 'Super Admin';
      default: return null;
    }
  }
}

/// Logo bulat 64px. Image network / inisial memenuhi SELURUH area
/// lingkaran — tidak ada border inset yang memperkecil image. Subtle
/// outer hairline ring + shadow untuk elevasi, tidak menutupi image.
class _LogoAvatar extends StatelessWidget {
  const _LogoAvatar({
    required this.url,
    required this.fallbackText,
    this.size = 64,
  });
  final String url;
  final String fallbackText;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = fallbackText.isEmpty
        ? '?'
        : fallbackText.substring(0, 1).toUpperCase();
    final hasUrl = url.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          width: size,
          height: size,
          color: AppColors.secondaryContainer,
          child: hasUrl
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  errorBuilder: (_, __, ___) => _initials(initials),
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : _initials(initials),
                )
              : _initials(initials),
        ),
      ),
    );
  }

  Widget _initials(String initials) {
    return Center(
      child: Text(
        initials,
        style: AppTextStyles.titleLg.copyWith(
          color: AppColors.onSecondaryContainer,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Chip role di pojok kanan card — visual lebih "badge" dari versi
/// in-place sebelumnya (background filled, padding lebih besar).
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.title, required this.items});
  final String title;
  final List<_MenuItemData> items;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: AppTextStyles.labelSm.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        // ClipRRect memastikan ripple dari InkWell di tiap tile mengikuti
        // sudut rounded container (tanpa ini, hover overlay muncul kotak).
        ClipRRect(
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: radius,
              border: Border.all(color: context.colors.surfaceContainerHigh, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  _MenuTile(
                    data: items[i],
                    radius: _tileRadius(i, items.length, radius),
                  ),
                  if (i < items.length - 1)
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
        ),
      ],
    );
  }

  /// Radius per tile: hanya tile pertama/terakhir yang punya sudut rounded,
  /// tile tengah pakai radius 0 supaya divider-nya pas menyambung edge.
  BorderRadius _tileRadius(int index, int length, BorderRadius outer) {
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
}

class _MenuItemData {
  const _MenuItemData({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.data, required this.radius});
  final _MenuItemData data;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: () => context.push(data.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(data.icon, size: 22, color: context.colors.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(
                child: Text(data.label, style: AppTextStyles.bodyLg.copyWith(color: context.colors.onSurface)),
              ),
              Icon(
                Icons.chevron_right,
                color: context.colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.logout, color: context.colors.error),
        label: Text(
          'Keluar',
          style: TextStyle(color: context.colors.error, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: context.colors.error, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}