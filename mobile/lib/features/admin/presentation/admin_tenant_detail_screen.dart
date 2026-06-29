import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/asset_url.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme_ext.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../data/admin_providers.dart';

/// Super-Admin → detail tenant + aksi Activate / Suspend.
class AdminTenantDetailScreen extends ConsumerStatefulWidget {
  const AdminTenantDetailScreen({super.key, required this.tenantId});
  final int tenantId;

  @override
  ConsumerState<AdminTenantDetailScreen> createState() => _AdminTenantDetailScreenState();
}

class _AdminTenantDetailScreenState extends ConsumerState<AdminTenantDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(adminTenantsRepositoryProvider).show(widget.tenantId);
  }

  void _reload() {
    setState(() {
      _future = ref.read(adminTenantsRepositoryProvider).show(widget.tenantId);
    });
    ref.read(adminTenantsRefreshProvider.notifier).state++;
  }

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
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin/tenants'),
        ),
        title: Text(
          'Detail Tenant',
          style: AppTextStyles.headlineMd.copyWith(fontSize: 20, color: context.colors.onSurface),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
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
          final t = snap.data!;
          final status = (t['status'] as String?) ?? 'trial';
          final name = (t['name'] as String?) ?? '—';
          final slug = (t['slug'] as String?) ?? '';
          final phone = (t['phone'] as String?) ?? '';
          final address = (t['address'] as String?) ?? '';
          final city = (t['city'] as String?) ?? '';
          final logoUrl = resolveAssetUrl(t['logo_url'] as String?);
          final usersCount = (t['users_count'] as int?) ?? 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _Header(
                name: name,
                slug: slug,
                status: status,
                logoUrl: logoUrl,
              ),
              const SizedBox(height: 16),
              _InfoRow(label: 'Slug', value: slug),
              _InfoRow(label: 'Phone', value: phone.isEmpty ? '—' : phone),
              _InfoRow(label: 'Kota', value: city.isEmpty ? '—' : city),
              _InfoRow(label: 'Alamat', value: address.isEmpty ? '—' : address),
              _InfoRow(label: 'User', value: '$usersCount'),
              const SizedBox(height: 24),
              if (status == 'active') ...[
                FilledButton.icon(
                  onPressed: () => _confirmSuspend(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                  icon: const Icon(Icons.block),
                  label: const Text('Suspend Tenant'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: () => _activate(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.statusSelesai,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(status == 'suspended' ? 'Aktifkan Kembali' : 'Aktifkan Tenant'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _activate(BuildContext context) async {
    try {
      await ref.read(adminTenantsRepositoryProvider).activate(widget.tenantId);
      if (!context.mounted) return;
      showAppSnackBar(context, 'Tenant diaktifkan', type: AppSnackBarType.success);
      _reload();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      _toast(context, e.message);
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, 'Gagal: $e');
    }
  }

  Future<void> _confirmSuspend(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('Suspend tenant ini?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Owner & operator tidak akan bisa login sampai diaktifkan kembali.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Alasan (opsional)',
                hintText: 'Misal: pembayaran overdue',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: ctx.colors.error),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminTenantsRepositoryProvider).suspend(
            widget.tenantId,
            reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
          );
      if (!context.mounted) return;
      showAppSnackBar(context, 'Tenant di-suspend', type: AppSnackBarType.success);
      _reload();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      _toast(context, e.message);
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, 'Gagal: $e');
    }
  }
}

void _toast(BuildContext context, String msg) {
  showAppSnackBar(context, msg, type: AppSnackBarType.error);
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.slug, required this.status, required this.logoUrl});
  final String name;
  final String slug;
  final String status;
  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status) {
      'active' => AppColors.statusSelesai,
      'suspended' => AppColors.error,
      _ => AppColors.statusMasuk,
    };
    final statusLabel = switch (status) {
      'active' => 'Aktif',
      'suspended' => 'Suspended',
      _ => 'Trial',
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.secondaryContainer),
            clipBehavior: Clip.antiAlias,
            child: logoUrl.isNotEmpty
                ? Image.network(logoUrl, fit: BoxFit.cover, width: 64, height: 64,
                    errorBuilder: (_, __, ___) => _initials(context, name))
                : _initials(context, name),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.titleLg.copyWith(color: context.colors.onSurface)),
                const SizedBox(height: 4),
                Text(slug, style: AppTextStyles.bodySm.copyWith(color: context.colors.onSurfaceVariant)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    statusLabel,
                    style: AppTextStyles.labelSm.copyWith(color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials(BuildContext context, String name) {
    final i = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return Center(
      child: Text(i, style: AppTextStyles.titleLg.copyWith(color: AppColors.onSecondaryContainer)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: AppTextStyles.labelLg.copyWith(color: context.colors.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodyLg.copyWith(color: context.colors.onSurface)),
          ),
        ],
      ),
    );
  }
}