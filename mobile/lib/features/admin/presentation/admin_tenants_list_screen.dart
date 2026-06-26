import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/asset_url.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/admin_providers.dart';

/// Super-Admin → list semua tenant dengan search + status filter.
/// Akses dari `/admin/tenants`. Hanya untuk role super_admin.
class AdminTenantsListScreen extends ConsumerStatefulWidget {
  const AdminTenantsListScreen({super.key});

  @override
  ConsumerState<AdminTenantsListScreen> createState() => _AdminTenantsListScreenState();
}

class _AdminTenantsListScreenState extends ConsumerState<AdminTenantsListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminTenantFilterProvider);
    final refreshKey = ref.watch(adminTenantsRefreshProvider);
    final repo = ref.read(adminTenantsRepositoryProvider);

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Kelola Tenant',
          style: AppTextStyles.headlineMd.copyWith(
            fontSize: 20,
            color: context.colors.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: context.colors.primary,
        foregroundColor: AppColors.onPrimary,
        onPressed: () => context.push('/admin/tenants/new'),
        icon: const Icon(Icons.add),
        label: const Text('Tenant Baru'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: AppTextField(
              label: '',
              hint: 'Cari nama atau slug...',
              controller: _searchCtrl,
              prefixIcon: Icons.search,
              variant: AppTextFieldVariant.search,
              onChanged: (v) => ref.read(adminTenantFilterProvider.notifier).state =
                  ref.read(adminTenantFilterProvider).copyWith(search: v),
            ),
          ),
          _StatusFilter(
            current: filter.status,
            onChanged: (s) {
              ref.read(adminTenantFilterProvider.notifier).state =
                  ref.read(adminTenantFilterProvider).copyWith(
                        status: s,
                        clearStatus: s == null,
                      );
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder(
              key: ValueKey('list-$refreshKey-${filter.search}-${filter.status}'),
              future: repo.list(search: filter.search, status: filter.status),
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Gagal memuat: ${snap.error}',
                        style: TextStyle(color: context.colors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final result = snap.data!;
                if (result.items.isEmpty) {
                  return const Center(child: Text('Tidak ada tenant'));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.read(adminTenantsRefreshProvider.notifier).state++;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: result.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _TenantCard(tenant: result.items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Keluar dari admin?'),
        content: const Text('Anda harus login kembali untuk mengakses panel admin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
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
      if (context.mounted) context.go('/login');
    }
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.current, required this.onChanged});
  final String? current;
  final ValueChanged<String?> onChanged;

  static const _options = [
    (label: 'Semua', value: null),
    (label: 'Trial', value: 'trial'),
    (label: 'Aktif', value: 'active'),
    (label: 'Suspended', value: 'suspended'),
  ];

  @override
  Widget build(BuildContext context) {
    // 72 (16 top + 40 chip + 16 bottom) supaya pill 40px tidak ter-clip.
    return SizedBox(
      height: 72,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            for (int i = 0; i < _options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _AdminFilterChip(
                label: _options[i].label,
                selected: current == _options[i].value,
                onTap: () => onChanged(_options[i].value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pill filter chip — selected = primary fill, idle = surfaceContainerHigh.
/// Pola yang sama dengan `_FilterChip` di OrdersListScreen agar konsisten.
class _AdminFilterChip extends StatelessWidget {
  const _AdminFilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : context.colors.surfaceContainerHigh;
    final fg = selected ? AppColors.onPrimary : context.colors.onSurfaceVariant;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(label, style: AppTextStyles.labelLg.copyWith(color: fg)),
        ),
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({required this.tenant});
  final Map<String, dynamic> tenant;

  @override
  Widget build(BuildContext context) {
    final name = tenant['name']?.toString() ?? '—';
    final slug = tenant['slug']?.toString() ?? '';
    final status = tenant['status']?.toString() ?? 'trial';
    final logoUrl = resolveAssetUrl(tenant['logo_url'] as String?);
    final usersCount = (tenant['users_count'] as int?) ?? 0;
    final city = (tenant['city'] as String?) ?? '';

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/admin/tenants/${tenant['id']}'),
        child: Container(
          decoration: BoxDecoration(
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _TenantLogoSmall(url: logoUrl, fallback: name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.titleLg.copyWith(color: context.colors.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        slug,
                        if (city.isNotEmpty) city,
                      ].join(' • '),
                      style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatusBadge(status: status),
                        const SizedBox(width: 8),
                        Icon(Icons.people_outline, size: 14, color: context.colors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '$usersCount user',
                          style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _TenantLogoSmall extends StatelessWidget {
  const _TenantLogoSmall({required this.url, required this.fallback, this.size = 44});
  final String url;
  final String fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = fallback.isEmpty ? '?' : fallback.substring(0, 1).toUpperCase();
    final hasUrl = url.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondaryContainer,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? Image.network(
              url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, __, ___) => Center(
                child: Text(initials, style: AppTextStyles.titleLg.copyWith(color: AppColors.onSecondaryContainer)),
              ),
            )
          : Center(
              child: Text(initials, style: AppTextStyles.titleLg.copyWith(color: AppColors.onSecondaryContainer)),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppColors.statusSelesai,
      'suspended' => AppColors.error,
      _ => AppColors.statusMasuk, // trial
    };
    final label = switch (status) {
      'active' => 'Aktif',
      'suspended' => 'Suspended',
      _ => 'Trial',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}